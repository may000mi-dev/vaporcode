-- inventory.lua: espacios activos, pasivas, mascotas y tienda.
-- Los guardados y la alquimia viven en storage.lua. Las funciones reciben
-- run como primer argumento y run.lua las monta como métodos run:metodo(...).
local Data = require("src.run.data")
local Save = require("src.run.save")
local FX = require("src.run.fx")
local Hud = require("src.run.hud")

local Inventory = {}

local selectionKeys = { active = "selectedInventory", inactive = "selectedStorage" }

function Inventory.totalAmount(run, itemId)
  local total = 0
  for _, list in ipairs({ run.inventory or {}, run.storage or {} }) do
    for _, slot in ipairs(list) do
      if slot.itemId == itemId then
        total = total + (slot.amount or 1)
      end
    end
  end
  return total
end

function Inventory.ownsPet(run, kind)
  for _, pet in ipairs(run.pets or {}) do
    if not pet.dead and pet.kind == kind then return true end
  end
  return false
end

local function freeSlots(run)
  local active = math.max(0, Data.inventory.maxActive - #(run.inventory or {}))
  local stored = math.max(0, Data.inventory.maxInactive - #(run.storage or {}))
  return active + stored, active, stored
end

-- Una pila nunca pasa de maxStacks, pero el jugador puede tener tantas pilas
-- como quepan en la mochila. Así se pueden preparar pares para la alquimia.
function Inventory.canAddItem(run, itemId, amount)
  local def = Data.items[itemId]
  if not def then return false end
  amount = math.max(1, math.floor(amount or 1))
  local totalFree, _, storageFree = freeSlots(run)

  if def.kind == "passive" then
    if not def.stackable then
      return run:totalAmount(itemId) == 0 and totalFree >= 1
    end
    local cap = def.maxStacks or Data.alchemy.maxAmount
    return totalFree >= math.ceil(amount / cap)
  elseif def.kind == "pet" then
    return run:totalAmount(itemId) == 0
      and not run:ownsPet(def.pet)
      and totalFree >= 1
  elseif def.kind == "ability" then
    return storageFree >= 1
  end
  return totalFree >= 1
end

-- Compatibilidad con la llamada anterior: ahora significa "no cabe otra pila".
function Inventory.passiveMaxed(run, id)
  local def = Data.items[id]
  if not def or def.kind ~= "passive" or not def.stackable then return false end
  return not Inventory.canAddItem(run, id, 1)
end

function Inventory.findInventoryItem(run, itemId)
  for index, slot in ipairs(run.inventory or {}) do
    if slot.itemId == itemId then return slot, index, "active" end
  end
  for index, slot in ipairs(run.storage or {}) do
    if slot.itemId == itemId then return slot, index, "inactive" end
  end
  return nil, nil, nil
end

-- Solo los activos aportan efectos; los guardados esperan a ser activados.
function Inventory.rebuildPassives(run)
  run.passiveStacks = {}
  for _, slot in ipairs(run.inventory or {}) do
    local def = Data.items[slot.itemId]
    if def and def.kind == "passive" then
      run.passiveStacks[slot.itemId] =
        (run.passiveStacks[slot.itemId] or 0) + (slot.amount or 1)
    end
  end
end

function Inventory.removePetByKind(run, kind)
  for _, pet in ipairs(run.pets or {}) do
    if not pet.dead and pet.kind == kind then
      pet.dead = true
    end
  end
end

function Inventory.clampSelection(run, section)
  local key = selectionKeys[section]
  local list = section == "active" and run.inventory or run.storage
  local count = #(list or {})
  if count == 0 then
    run[key] = 1
  elseif (run[key] or 1) > count then
    run[key] = count
  end
end

local function pushToList(run, section, slot)
  local limit, list
  if section == "active" then
    limit, list = Data.inventory.maxActive, run.inventory
  else
    limit, list = Data.inventory.maxInactive, run.storage
  end
  if #list >= limit then return false end
  list[#list + 1] = slot
  return true
end

-- Colocación: las habilidades siempre van a guardados; pasivas y mascotas
-- se activan si hay hueco y, si no, quedan guardadas. Devuelve "ok" cuando
-- todo quedó activo y "stored" cuando alguna pila solo quedó en la reserva.
function Inventory.addItemToInventory(run, itemId, amount)
  local def = Data.items[itemId]
  if not def then return "invalid" end
  amount = math.max(1, math.floor(amount or 1))
  if not Inventory.canAddItem(run, itemId, amount) then
    if def.kind == "passive" and not def.stackable
      and run:totalAmount(itemId) > 0 then
      return "duplicate"
    end
    if def.kind == "pet"
      and (run:totalAmount(itemId) > 0 or run:ownsPet(def.pet)) then
      return "duplicate"
    end
    return "full"
  end

  local cap = def.maxStacks or Data.alchemy.maxAmount
  local remaining = amount
  local anyStored = false
  local anyActive = false
  if def.kind ~= "passive" or not def.stackable then
    remaining = 1
  end

  while remaining > 0 do
    local stackAmount = def.kind == "passive" and def.stackable
      and math.min(remaining, cap) or 1
    local slot = {
      itemId = itemId,
      amount = def.kind == "passive" and stackAmount or 1,
    }
    local placed
    if def.kind == "ability" then
      placed = pushToList(run, "inactive", slot)
    else
      placed = pushToList(run, "active", slot) or pushToList(run, "inactive", slot)
    end
    if not placed then return "full" end

    if run.storage[#run.storage] == slot then
      anyStored = true
    else
      anyActive = true
    end
    remaining = remaining - stackAmount
  end

  if def.kind == "passive" then
    run:rebuildPassives()
  elseif def.kind == "pet" and anyActive then
    run:addPet(def.pet, run.player.x, run.player.y)
  end
  return anyStored and "stored" or "ok", amount
end

function Inventory.removeItemAt(run, section, index)
  local list = section == "active" and run.inventory or run.storage
  local slot = list and list[index]
  if not slot then return nil end
  table.remove(list, index)

  if section == "active" then
    local def = Data.items[slot.itemId]
    if def and def.kind == "passive" then
      run:rebuildPassives()
    elseif def and def.kind == "pet" then
      run:removePetByKind(def.pet)
    end
  end

  Inventory.clampSelection(run, section)
  return slot
end

function Inventory.shopPrice(run, itemId)
  return Data.shop.prices[itemId]
end

function Inventory.buyItem(run, itemId)
  if run.sandbox then return "sandbox" end
  local price = run:shopPrice(itemId)
  if not price then return "invalid" end
  if Save.data.coins < price then return "coins" end

  local status = run:addItemToInventory(itemId, 1)
  if status ~= "ok" and status ~= "stored" then return status end

  Save.data.coins = Save.data.coins - price
  Save.save()
  local suffix = status == "stored" and " · guardado" or ""
  run:notify(
    "Comprado: " .. Data.items[itemId].name .. " (-" .. price .. ")" .. suffix,
    Data.items[itemId].color
  )
  return status
end

function Inventory.toggleBackpack(run)
  if run.overlay == "backpack" then
    run.overlay = nil
    run.pendingStorageIndex = nil
  else
    run.overlay = "backpack"
    run.pendingStorageIndex = nil
    run.selectionSection = run.selectionSection or "active"
    run:clampSelection("active")
    run:clampSelection("inactive")
  end
  run:clearInput()
end

function Inventory.openShop(run)
  if run.overlay == "shop" then
    run.overlay = nil
    run:clearInput()
    return
  end
  if run.sandbox then
    run:notify("La tienda no está disponible en pruebas", { 1.00, 0.65, 0.40 })
    return
  end
  if not Hud.shopUnlocked(run) then
    run:notify("Tienda: alcanza el nivel 15 y el piso 10", { 1.00, 0.55, 0.40 })
    return
  end
  run.overlay = "shop"
  run.pendingStorageIndex = nil
  run.shopTab = "buy"
  run:clearInput()
end

return Inventory
