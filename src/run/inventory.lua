-- inventory.lua: mochila, pasivas, tienda de engranajes y alquimia.
-- Las funciones reciben run como primer argumento y run.lua las monta
-- como métodos para conservar la API run:metodo(...).
local Data = require("src.run.data")
local Save = require("src.run.save")
local FX = require("src.run.fx")
local Hud = require("src.run.hud")

local Inventory = {}

function Inventory.ownsPet(run, kind)
  for _, pet in ipairs(run.pets or {}) do
    if not pet.dead and pet.kind == kind then return true end
  end
  return false
end

function Inventory.passiveMaxed(run, id)
  local def = Data.items[id]
  if not def or def.kind ~= "passive" then return false end
  local stacks = (run.passiveStacks and run.passiveStacks[id]) or 0
  return stacks >= (def.maxStacks or 1)
end

function Inventory.findInventoryItem(run, itemId)
  for index, slot in ipairs(run.inventory or {}) do
    if slot.itemId == itemId then return slot, index end
  end
  return nil, nil
end

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

function Inventory.addItemToInventory(run, itemId, amount)
  local def = Data.items[itemId]
  if not def then return "invalid" end
  amount = math.max(1, math.floor(amount or 1))

  local existing = run:findInventoryItem(itemId)
  if def.kind == "passive" then
    -- Cada copia ocupa su espacio para poder combinarlas con alquimia.
    if not def.stackable and existing then return "duplicate" end
    if def.stackable and run:passiveMaxed(itemId) then return "duplicate" end
    amount = math.min(amount, def.maxStacks or 1)
  elseif def.kind == "pet" then
    if existing or run:ownsPet(def.pet) then return "duplicate" end
  end

  if #(run.inventory or {}) >= Data.inventory.maxSlots then
    return "full"
  end

  run.inventory[#run.inventory + 1] = {
    itemId = itemId,
    amount = def.kind == "passive" and amount or 1,
  }

  if def.kind == "passive" then
    run:rebuildPassives()
  elseif def.kind == "pet" then
    run:addPet(def.pet, run.player.x, run.player.y)
  end
  return "ok", amount
end

function Inventory.removeInventoryAt(run, index)
  local slot = run.inventory and run.inventory[index]
  if not slot then return nil end
  table.remove(run.inventory, index)

  local def = Data.items[slot.itemId]
  if def and def.kind == "passive" then
    run:rebuildPassives()
  elseif def and def.kind == "pet" then
    run:removePetByKind(def.pet)
  end

  local count = #run.inventory
  if count == 0 then
    run.selectedInventory = 1
  elseif run.selectedInventory > count then
    run.selectedInventory = count
  end
  return slot
end

function Inventory.shopPrice(run, itemId)
  return Data.shop.prices[itemId]
end

function Inventory.alchemyCost(run, amount)
  return Data.alchemy.costs[amount + 1]
end

function Inventory.buyItem(run, itemId)
  local price = run:shopPrice(itemId)
  if not price then return "invalid" end
  if Save.data.coins < price then return "coins" end

  local status = run:addItemToInventory(itemId, 1)
  if status ~= "ok" then return status end

  Save.data.coins = Save.data.coins - price
  Save.save()
  run:notify(
    "Comprado: " .. Data.items[itemId].name .. " (-" .. price .. ")",
    Data.items[itemId].color
  )
  return "ok"
end

function Inventory.alchemyCandidates(run)
  local out = {}
  local inventory = run.inventory or {}
  for i = 1, #inventory do
    local a = inventory[i]
    local def = Data.items[a.itemId]
    if def and def.kind == "passive" and def.stackable
      and (a.amount or 1) < (def.maxStacks or Data.alchemy.maxAmount) then
      for j = i + 1, #inventory do
        local b = inventory[j]
        if b.itemId == a.itemId and (b.amount or 1) == (a.amount or 1) then
          local result = (a.amount or 1) + 1
          out[#out + 1] = {
            itemId = a.itemId,
            index1 = i,
            index2 = j,
            amount = a.amount or 1,
            result = result,
            cost = run:alchemyCost(a.amount or 1),
          }
        end
      end
    end
  end
  return out
end

function Inventory.combineAlchemy(run, candidate)
  if not candidate then return false end
  local inventory = run.inventory or {}
  local a = inventory[candidate.index1]
  local b = inventory[candidate.index2]
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

  table.remove(inventory, math.max(candidate.index1, candidate.index2))
  table.remove(inventory, math.min(candidate.index1, candidate.index2))
  table.insert(inventory, math.min(candidate.index1, candidate.index2), {
    itemId = a.itemId,
    amount = (a.amount or 1) + 1,
  })

  Save.data.coins = Save.data.coins - cost
  Save.save()
  run:rebuildPassives()
  run:notify(
    def.name .. " x" .. (a.amount + 1) .. " combinado",
    def.color
  )
  return true
end

function Inventory.equipInventoryAbility(run, index, slot)
  if slot ~= 1 and slot ~= 2 then return false end
  local item = run.inventory and run.inventory[index]
  if not item then return false end
  local def = Data.items[item.itemId]
  if not def or def.kind ~= "ability" then return false end

  table.remove(run.inventory, index)
  run:equipAbility(slot, def.abilityId)
  local count = #run.inventory
  if count == 0 then
    run.selectedInventory = 1
  elseif run.selectedInventory > count then
    run.selectedInventory = count
  end

  FX.add(
    def.name .. " → A" .. slot,
    run.player.x,
    run.player.y - 30,
    def.color
  )
  return true
end

function Inventory.toggleBackpack(run)
  if run.overlay == "backpack" then
    run.overlay = nil
  else
    run.overlay = "backpack"
    local count = #(run.inventory or {})
    if count == 0 then
      run.selectedInventory = 1
    elseif run.selectedInventory > count then
      run.selectedInventory = count
    end
  end
  run:clearInput()
end

function Inventory.openShop(run)
  if run.overlay == "shop" then
    run.overlay = nil
    run:clearInput()
    return
  end
  if not Hud.shopUnlocked(run) then
    run:notify("Tienda: alcanza el nivel 15 y el piso 10", { 1.00, 0.55, 0.40 })
    return
  end
  run.overlay = "shop"
  run.shopTab = "buy"
  run:clearInput()
end

return Inventory
