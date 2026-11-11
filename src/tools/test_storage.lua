-- test_storage.lua: activos vs guardados, intercambio y alquimia.
package.path = "./?.lua;" .. package.path

love = {
  math = {
    random = function(a, b)
      if a and b then return a end
      return 0.5
    end,
  },
  timer = {
    getTime = function()
      return 0
    end,
  },
  filesystem = {
    getInfo = function()
      return nil
    end,
    write = function()
      return true
    end,
  },
}

-- Stubs de dibujo para validar las pantallas sin abrir LÖVE.
local function noop() end
love.graphics = {
  setColor = noop,
  rectangle = noop,
  print = noop,
  printf = noop,
  setFont = noop,
  circle = noop,
  setLineWidth = noop,
}

local Data = require("src.run.data")
local Save = require("src.run.save")
local Hud = require("src.run.hud")
local Shop = require("src.run.shop")
local Backpack = require("src.run.backpack")
local Run = require("src.run.run")

Save.load()
Run.player = { x = 0, y = 0, radius = 16 }

local function reset()
  Run.inventory = {}
  Run.storage = {}
  Run.pets = {}
  Run.passiveStacks = {}
  Run.selectionSection = "active"
  Run.selectedInventory = 1
  Run.selectedStorage = 1
  Run.pendingStorageIndex = nil
end

local function fillActive()
  for _, id in ipairs({ "poison", "vampire", "fairy", "gunpowder", "drum" }) do
    assert(Run:addItemToInventory(id, 1) == "ok", "debe caber en activos: " .. id)
  end
end

-- Colocación: habilidades a guardados, pasivas y mascotas a activos.
reset()
assert(Run:addItemToInventory("light_arrow_skill", 1) == "stored", "la habilidad va a guardados")
assert(#Run.inventory == 0 and #Run.storage == 1, "la habilidad no ocupa un activo")
assert(Run:addItemToInventory("poison", 1) == "ok", "la pasiva va a activos")
assert(Run.passiveStacks.poison == 1, "la pasiva activa aplica de inmediato")

-- Con activos llenos el pickup desborda a guardados sin efectos.
reset()
fillActive()
assert(#Run.inventory == Data.inventory.maxActive, "los cinco activos deben llenarse")
assert(Run:addItemToInventory("flute", 1) == "stored", "el sexto debe desbordar a guardados")
assert(#Run.storage == 1 and Run.passiveStacks.flute == nil, "guardado no aplica efectos")

-- El tope de copias es global: activos + guardados.
reset()
assert(Run:addItemToInventory("poison", 1) == "ok")
assert(Run:addItemToInventory("poison", 1) == "ok")
assert(Run:storeActive(1) == "ok" and Run:storeActive(1) == "ok", "dos copias al guardado")
for _ = 1, 3 do
  assert(Run:addItemToInventory("poison", 1) == "ok", "tres copias más a activos")
end
assert(Run:addItemToInventory("poison", 1) == "duplicate", "las guardadas cuentan al tope global")

-- Activar con hueco libre mueve el ítem y recalcula efectos.
reset()
assert(Run:addItemToInventory("poison", 1) == "ok")
assert(Run:storeActive(1) == "ok", "debe poder guardarse un activo")
assert(#Run.storage == 1 and Run.passiveStacks.poison == nil, "guardar quita el efecto")
assert(Run:activateStored(1) == "ok", "debe activarse con hueco libre")
assert(#Run.inventory == 1 and #Run.storage == 0, "el ítem debe subir a activos")
assert(Run.passiveStacks.poison == 1, "activar pasiva debe aplicarla")

-- Activar con activos llenos pide intercambio y no pierde nada.
reset()
fillActive()
assert(Run:addItemToInventory("flute", 1) == "stored")
assert(Run:activateStored(1) == "needs_swap", "sin hueco debe pedir intercambio")
assert(Run:swapActiveForStored(1, 1), "el intercambio debe completarse")
assert(#Run.inventory == Data.inventory.maxActive and #Run.storage == 1, "nada se pierde")
assert(Run.inventory[1].itemId == "flute", "el guardado entra al activo elegido")
assert(Run.storage[1].itemId == "poison", "el activo desalojado queda guardado")
assert(Run.passiveStacks.flute == 1 and Run.passiveStacks.poison == nil, "efectos tras intercambio")

-- Intercambio de mascotas baja y sube al compañero correcto.
reset()
fillActive()
assert(Run:addItemToInventory("dog", 1) == "stored", "la mascota debe quedar guardada")
assert(#Run.pets == 0, "la mascota guardada no aparece")
assert(Run:swapActiveForStored(2, 1), "la mascota debe poder intercambiarse")
assert(#Run.pets == 1 and Run.pets[1].kind == "dog", "la mascota activa debe aparecer")
assert(Run:storeActive(2) == "ok", "la mascota debe poder guardarse")
assert(#Run.pets == 0 or Run.pets[1].dead, "guardar la mascota la retira")

-- Tirar y guardar respetan selección y límites.
reset()
assert(Run:addItemToInventory("poison", 1) == "ok")
assert(Run:addItemToInventory("vampire", 1) == "ok")
Run.selectedInventory = 2
assert(Run:discardSelected(), "debe tirar el ítem seleccionado")
assert(#Run.inventory == 1 and Run.selectedInventory == 1, "la selección debe ajustarse")

-- Ciclo de selección: 5 activos y 15 guardados.
reset()
Run.selectionSection = "active"
Run.selectedInventory = 1
Run:cycleSelection(-1)
assert(Run.selectionSection == "inactive" and Run.selectedStorage == Data.inventory.maxInactive, "debe envolver al último guardado")
Run:cycleSelection(1)
assert(Run.selectionSection == "active" and Run.selectedInventory == 1, "debe envolver al primer activo")
Run:cycleSelection(4)
assert(Run.selectionSection == "active" and Run.selectedInventory == 5, "debe avanzar dentro de activos")
Run:cycleSelection(1)
assert(Run.selectionSection == "inactive" and Run.selectedStorage == 1, "debe entrar a guardados")

-- Acciones de teclado sobre la selección.
reset()
assert(Run:addItemToInventory("light_arrow_skill", 1) == "stored")
Run.abilitySlot1 = nil
Run.selectionSection = "inactive"
Run.selectedStorage = 1
assert(Run:assignSelected(1), "Q debe asignar desde guardados")
assert(Run.abilitySlot1 == "light_arrow" and #Run.storage == 0, "asignar consume el guardado")
assert(Run:addItemToInventory("poison", 1) == "ok")
Run.selectionSection = "active"
Run.selectedInventory = 1
assert(Run:primarySelected() == "ok" and #Run.storage == 1, "Enter guarda el activo")
assert(Run.passiveStacks.poison == nil, "guardar quita el efecto")
Run.selectionSection = "inactive"
Run.selectedStorage = 1
Run.inventory = {}
fillActive()
assert(Run:primarySelected() == "needs_swap", "Enter pide intercambio con activos llenos")

-- Alquimia: solo ve guardados.
reset()
assert(Run:addItemToInventory("poison", 1) == "ok")
assert(Run:addItemToInventory("poison", 1) == "ok")
assert(#Run:alchemyCandidates() == 0, "los activos no son candidatos")
assert(Run:storeActive(1) == "ok" and Run:storeActive(1) == "ok")
Save.data.coins = 10
local candidate = Run:alchemyCandidates()[1]
assert(candidate and candidate.cost == 10, "dos guardados iguales deben ser candidatos")
assert(Run:combineAlchemy(candidate), "la combinación debe aplicarse")
assert(#Run.storage == 1 and Run.storage[1].amount == 2, "el resultado queda guardado")

-- Todo lleno: activos en 5 y guardados en 15.
reset()
fillActive()
for index = 1, Data.inventory.maxInactive do
  Run.storage[index] = { itemId = "poison", amount = 1 }
end
assert(Run:addItemToInventory("flute", 1) == "full", "sin huecos en ningún lado no entra")

-- Geometría: todo cabe en el panel y las zonas no se traslapan.
local panel = Backpack.panel
local function insidePanel(rect)
  return rect.x >= panel.x and rect.y >= panel.y
    and rect.x + rect.w <= panel.x + panel.w
    and rect.y + rect.h <= panel.y + panel.h
end
local lastActive = Backpack.activeRect(Data.inventory.maxActive)
local lastStorage = Backpack.storageRect(Data.inventory.maxInactive)
local lastAction = Backpack.actionRect(4)
assert(insidePanel(lastActive) and insidePanel(lastStorage) and insidePanel(lastAction), "la mochila debe caber en el panel")
assert(lastActive.y + lastActive.h < Backpack.storageRect(1).y, "activos y guardados no deben traslaparse")
assert(lastStorage.y + lastStorage.h <= 306, "la rejilla no debe invadir el detalle")
assert(lastAction.y + lastAction.h < panel.y + panel.h - 28, "las acciones deben quedar sobre el pie")

-- Humo de UI: mochila, acciones, intercambio, HUD y tienda.
reset()
Run.inventory = { { itemId = "poison", amount = 1 } }
Run.storage = { { itemId = "light_arrow_skill", amount = 1 } }
Run.overlay = "backpack"
Run.selectionSection = "active"
Run.selectedInventory = 1
Backpack.draw(Run)
Hud.drawInventory(Run)

Run.selectionSection = "inactive"
Run.selectedStorage = 1
Run.abilitySlot1 = nil
Backpack.draw(Run)
assert(Backpack.pressed(Run, 408, 374), "el clic en A1 debe consumirse")
assert(Run.abilitySlot1 == "light_arrow", "el clic en A1 debe asignar la habilidad")

reset()
fillActive()
assert(Run:addItemToInventory("flute", 1) == "stored")
Run.overlay = "backpack"
Run.selectionSection = "inactive"
Run.selectedStorage = 1
Backpack.pressed(Run, 260, 374)
assert(Run.pendingStorageIndex == 1, "activar sin hueco debe abrir el intercambio")
Backpack.draw(Run)
Backpack.pressed(Run, 250, 150)
assert(Run.pendingStorageIndex == nil, "el clic en un activo debe cerrar el intercambio")
assert(Run.inventory[1].itemId == "flute", "el activo tocado recibe el guardado")

Run.storage = {
  { itemId = "poison", amount = 1 },
  { itemId = "poison", amount = 1 },
}
Run.shopTab = "alchemy"
Save.data.coins = 100
Shop.draw(Run)
Run.shopTab = "buy"
Shop.draw(Run)

print("OK activos, guardados, intercambio y alquimia")
