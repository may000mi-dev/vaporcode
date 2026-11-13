-- storage.lua: 15 espacios guardados, activación, intercambio y alquimia.
-- Nada de lo guardado aporta efectos hasta pasar a un espacio activo.
local Data = require("src.run.data")
local Save = require("src.run.save")
local FX = require("src.run.fx")
local Inventory = require("src.run.inventory")

local Storage = {}

local selectionKeys = { active = "selectedInventory", inactive = "selectedStorage" }

local function listOf(run, section)
  if section == "active" then return run.inventory end
  return run.storage
end

-- Devuelve sección, índice, espacio y definición del ítem seleccionado.
function Storage.selectedSlot(run)
  local section = run.selectionSection or "active"
  local list = listOf(run, section) or {}
  local index = run[selectionKeys[section]] or 1
  local slot = list[index]
  return section, index, slot, slot and Data.items[slot.itemId]
end

function Storage.cycleSelection(run, step)
  local maxActive = Data.inventory.maxActive
  local total = maxActive + Data.inventory.maxInactive
  local section, index = Storage.selectedSlot(run)
  local flat = section == "active" and index or (maxActive + index)
  flat = ((flat - 1 + (step or 1)) % total) + 1
  if flat <= maxActive then
    run.selectionSection = "active"
    run.selectedInventory = flat
  else
    run.selectionSection = "inactive"
    run.selectedStorage = flat - maxActive
  end
end

-- Activa un guardado. Con activos llenos devuelve "needs_swap" para que la
-- UI pida qué ítem activo baja; la habilidad se asigna con assignSelected.
function Storage.activateStored(run, index)
  local slot = run.storage and run.storage[index]
  if not slot then return "empty" end
  local def = Data.items[slot.itemId]
  if not def then return "invalid" end
  if def.kind == "ability" then return "ability" end
  if def.kind ~= "passive" and def.kind ~= "pet" then return "invalid" end
  if #run.inventory >= Data.inventory.maxActive then return "needs_swap" end

  table.remove(run.storage, index)
  run.inventory[#run.inventory + 1] = slot
  if def.kind == "passive" then
    run:rebuildPassives()
  else
    run:addPet(def.pet, run.player.x, run.player.y)
  end
  Inventory.clampSelection(run, "inactive")
  return "ok"
end

-- Intercambio sin pérdida: el guardado entra al espacio activo elegido y
-- el activo desalojado ocupa exactamente el hueco que dejó el guardado.
function Storage.swapActiveForStored(run, activeIndex, storageIndex)
  local activeSlot = run.inventory and run.inventory[activeIndex]
  local storedSlot = run.storage and run.storage[storageIndex]
  if not activeSlot or not storedSlot then return false end

  run.inventory[activeIndex] = storedSlot
  run.storage[storageIndex] = activeSlot

  -- Primero baja la mascota saliente; así una especie distinta puede subir.
  local down = Data.items[activeSlot.itemId]
  if down and down.kind == "pet" then
    run:removePetByKind(down.pet)
  end
  local up = Data.items[storedSlot.itemId]
  if up and up.kind == "pet" then
    run:addPet(up.pet, run.player.x, run.player.y)
  end

  run:rebuildPassives()
  return true
end

function Storage.storeActive(run, index)
  local slot = run.inventory and run.inventory[index]
  if not slot then return "empty" end
  if #run.storage >= Data.inventory.maxInactive then return "full" end

  table.remove(run.inventory, index)
  run.storage[#run.storage + 1] = slot
  local def = Data.items[slot.itemId]
  if def and def.kind == "passive" then
    run:rebuildPassives()
  elseif def and def.kind == "pet" then
    run:removePetByKind(def.pet)
  end
  Inventory.clampSelection(run, "active")
  return "ok"
end

function Storage.discardSelected(run)
  local section, index = Storage.selectedSlot(run)
  if not index then return false end
  return run:removeItemAt(section, index) ~= nil
end

-- Acción principal: Enter o el botón izquierdo de la fila de acciones.
function Storage.primarySelected(run)
  local section, index, slot = Storage.selectedSlot(run)
  if not slot then return "empty" end
  if section == "active" then
    return run:storeActive(index)
  end
  return run:activateStored(index)
end

function Storage.assignSelected(run, abilitySlot)
  local section, index = Storage.selectedSlot(run)
  if section ~= "inactive" then return false end
  return run:equipStoredAbility(index, abilitySlot)
end

function Storage.equipStoredAbility(run, index, abilitySlot)
  if abilitySlot ~= 1 and abilitySlot ~= 2 then return false end
  local item = run.storage and run.storage[index]
  if not item then return false end
  local def = Data.items[item.itemId]
  if not def or def.kind ~= "ability" then return false end

  table.remove(run.storage, index)
  run:equipAbility(abilitySlot, def.abilityId)
  Inventory.clampSelection(run, "inactive")

  FX.add(
    def.name .. " → A" .. abilitySlot,
    run.player.x,
    run.player.y - 30,
    def.color
  )
  return true
end

function Storage.alchemyCost(run, amount)
  return Data.alchemy.costs[amount + 1]
end

function Storage.alchemyCandidates(run)
  local out = {}
  local storage = run.storage or {}
  for i = 1, #storage do
    local a = storage[i]
    local def = Data.items[a.itemId]
    if def and def.kind == "passive" and def.stackable
      and (a.amount or 1) < (def.maxStacks or Data.alchemy.maxAmount) then
      for j = i + 1, #storage do
        local b = storage[j]
        if b.itemId == a.itemId and (b.amount or 1) == (a.amount or 1) then
          out[#out + 1] = {
            itemId = a.itemId,
            index1 = i,
            index2 = j,
            amount = a.amount or 1,
            result = (a.amount or 1) + 1,
            cost = run:alchemyCost(a.amount or 1),
          }
        end
      end
    end
  end
  return out
end

function Storage.combineAlchemy(run, candidate)
  -- La alquimia gasta monedas reales; en pruebas se bloquea incluso si una
  -- interfaz futura llegara a invocarla sin pasar por la tienda.
  if run.sandbox then return false end
  if not candidate then return false end
  local storage = run.storage or {}
  local a = storage[candidate.index1]
  local b = storage[candidate.index2]
  if not a or not b then return false end
  if a.itemId ~= b.itemId then return false end
  if (a.amount or 1) ~= (b.amount or 1) then return false end

  local def = Data.items[a.itemId]
  if not def or def.kind ~= "passive" or not def.stackable then return false end
  if (a.amount or 1) >= (def.maxStacks or Data.alchemy.maxAmount) then
    return false
  end

  local cost = run:alchemyCost(a.amount or 1)
  if Save.data.coins < cost then return false end

  table.remove(storage, math.max(candidate.index1, candidate.index2))
  table.remove(storage, math.min(candidate.index1, candidate.index2))
  table.insert(storage, math.min(candidate.index1, candidate.index2), {
    itemId = a.itemId,
    amount = (a.amount or 1) + 1,
  })

  Save.data.coins = Save.data.coins - cost
  Save.save()
  Inventory.clampSelection(run, "inactive")
  run:notify(
    def.name .. " x" .. (a.amount + 1) .. " guardado",
    def.color
  )
  return true
end

return Storage
