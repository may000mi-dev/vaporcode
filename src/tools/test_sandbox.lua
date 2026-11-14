-- test_sandbox.lua: la sala de pruebas no debe tocar el progreso persistente.
package.path = "./?.lua;" .. package.path

local function rng(seed)
  local state = seed or 1
  return {
    random = function(_, a, b)
      state = (state * 1103515245 + 12345) % 2147483648
      local value = state / 2147483648
      if a and b then
        return math.floor(value * (b - a + 1)) + a
      elseif a then
        return math.floor(value * a) + 1
      end
      return value
    end,
  }
end

love = {
  math = {
    random = function(a, b)
      if a and b then return a end
      return 0.5
    end,
    newRandomGenerator = rng,
  },
  timer = {
    getTime = function()
      return 0
    end,
  },
  system = {
    getOS = function()
      return "Linux"
    end,
  },
  filesystem = {
    getInfo = function()
      return nil
    end,
    write = function()
      return true
    end,
    remove = function()
      return true
    end,
  },
}

local function noop() end
love.graphics = {
  setColor = noop,
  rectangle = noop,
  print = noop,
  printf = noop,
  rotate = noop,
  polygon = noop,
  setFont = noop,
  circle = noop,
  line = noop,
  arc = noop,
  setLineWidth = noop,
  push = noop,
  pop = noop,
  translate = noop,
}

local Data = require("src.run.data")
local Save = require("src.run.save")
local Run = require("src.run.run")
local Sandbox = require("src.run.sandbox")

Save.load()

-- La sala permite personajes bloqueados para poder probar sus habilidades.
Run.enter("sandbox", "mar")
assert(Run.sandbox, "debe marcar la run como sandbox")
assert(Run.characterId == "mar", "sandbox debe permitir personajes bloqueados")
assert(Run.timeLeft == 0, "sandbox no debe tener límite de tiempo")
assert(#Run.enemies == 0, "sandbox no debe generar oleadas")

Run:spawnEnemies()
assert(#Run.enemies == 0, "spawnEnemies debe respetar el sandbox")
assert(Run:buyItem("poison") == "sandbox", "la tienda debe estar bloqueada")
assert(Run:combineAlchemy(nil) == false, "la alquimia debe estar bloqueada")

-- Las monedas se contabilizan en la run pero no en el guardado.
local storedCoins = Save.data.coins
Run:addCoins(25)
assert(Save.data.coins == storedCoins, "sandbox no debe guardar monedas")
assert(Run.coinsEarned == 25, "sandbox debe conservar el contador local")

-- Morir no termina la sesión de pruebas y restaura la vida.
Run.hp = 1
Run.projectiles = { {} }
Run.hazards = { {} }
Run:gameOver("death")
assert(not Run.over, "sandbox no debe terminar en game over")
assert(Run.hp == Run.stats.maxHp, "sandbox debe restaurar la vida")
assert(#Run.projectiles == 0 and #Run.hazards == 0, "sandbox debe limpiar peligros")
assert(Run.player.invuln > 0, "sandbox debe dar invulnerabilidad temporal")

-- El panel permite invocar un enemigo concreto y cerrarse.
Run.overlay = "sandbox"
Sandbox.reset()
Sandbox.layout()
local target
for _, rect in ipairs(Sandbox.gridRects) do
  if rect.id == "automaton" then
    target = rect
    break
  end
end
assert(target, "el panel debe listar enemigos")
Sandbox.pressed(Run, target.x + 2, target.y + 2)
assert(#Run.enemies == 1, "el panel debe invocar exactamente un enemigo")
assert(Run.overlay == nil, "invocar debe cerrar el panel para pelear")

-- Con cantidad x5, el mismo botón crea cinco enemigos del tipo elegido.
Run.enemies = {}
Run.boss = nil
Run.overlay = "sandbox"
Sandbox.quantity = 5
Sandbox.pressed(Run, target.x + 2, target.y + 2)
assert(#Run.enemies == 5, "cantidad x5 debe invocar cinco enemigos")
for _, enemy in ipairs(Run.enemies) do
  assert(enemy.kind == "automaton", "los cinco enemigos deben ser del tipo elegido")
end
Run.enemies = {}
Run.boss = nil
Sandbox.quantity = 1

-- La pestaña de ítems debe usar ids válidos y entregar el objeto a la run.
Run.inventory = {}
Run.storage = {}
Run:rebuildPassives()
Run.overlay = "sandbox"
Sandbox.activeTab = "items"
Sandbox.layout()
local itemRect
for _, rect in ipairs(Sandbox.gridRects) do
  if Data.items[rect.id] then
    itemRect = rect
    break
  end
end
assert(itemRect, "el panel debe listar ítems por id")
Sandbox.pressed(Run, itemRect.x + 2, itemRect.y + 2)
assert(#Run.inventory + #Run.storage == 1, "el panel debe entregar el ítem")

-- Un jefe invocado debe poder actualizarse varios segundos sin cerrar la run.
Run.overlay = "sandbox"
Sandbox.activeTab = "enemies"
Sandbox.layout()
local bossRect
for _, rect in ipairs(Sandbox.gridRects) do
  local def = Data.enemyTypes[rect.id]
  if def and def.boss then
    bossRect = rect
    break
  end
end
assert(bossRect, "el panel debe listar al menos un jefe")
Sandbox.pressed(Run, bossRect.x + 2, bossRect.y + 2)
assert(Run.boss, "invocar un jefe debe registrarlo en la run")

Run.sandboxInvuln = true
local hpBefore = Run.hp
Run.player:takeDamage(999, Run)
assert(Run.hp == hpBefore, "invulnerabilidad de pruebas debe evitar daño")
for _ = 1, 300 do
  Run.update(1 / 60)
end
assert(not Run.over and Run.hp == hpBefore, "sandbox debe seguir tras 5 segundos")

-- Pausar y salir en sandbox no escriben el guardado.
local saves = 0
local originalSave = Save.save
Save.save = function()
  saves = saves + 1
  return true
end

Run:setPaused(true)
assert(saves == 0, "pausar en sandbox no debe guardar")
Run:requestExitToMenu()
assert(Run.pauseExitConfirm, "pausar y pedir salir debe armar la confirmación")
Run.update(4)
assert(not Run.pauseExitConfirm, "la confirmación debe expirar en 3 segundos")
Run:setPaused(false)

Run:requestExitToMenu()
assert(Run.pauseExitConfirm, "el primer toque debe armar la confirmación")
Run:requestExitToMenu()
assert(saves == 0, "salir de sandbox no debe guardar")
Run:requestExitToMenu()
assert(saves == 0, "salir de sandbox no debe guardar")

Save.save = originalSave

-- Una run normal sí suma monedas al guardado.
Run.enter("cripta", "amado")
local normalCoins = Save.data.coins
Run:addCoins(7)
assert(Save.data.coins == normalCoins + 7, "la run normal debe guardar monedas")
Run:setPaused(false)

print("OK sala de pruebas aislada del guardado")
