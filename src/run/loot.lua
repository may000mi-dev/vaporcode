-- loot.lua: botín de enemigos y cofres, recogidas y desbloqueo de personajes.
-- Las funciones reciben run como primer argumento y run.lua las monta
-- como métodos para conservar la API run:metodo(...).
local Data = require("src.run.data")
local Save = require("src.run.save")
local ItemDrop = require("src.run.item_drop")
local FX = require("src.run.fx")

local Loot = {}

function Loot.itemCandidates(run, poolName)
  local pool = Data.itemPool[poolName] or Data.itemPool.normal
  local out = {}
  local total = 0
  for _, id in ipairs(pool) do
    local def = Data.items[id]
    local allowed = true
    if def.kind == "passive" and def.stackable and run:passiveMaxed(id) then
      allowed = false
    elseif def.maxStacks == 1 and run:totalAmount(id) > 0 then
      allowed = false
    elseif def.kind == "pet" and run:ownsPet(def.pet) then
      allowed = false
    end
    if allowed and (def.weight or 0) > 0 then
      total = total + def.weight
      out[#out + 1] = { id = id, weight = def.weight }
    end
  end
  return out, total
end

function Loot.chooseItem(run, poolName, roll)
  local candidates, total = run:itemCandidates(poolName)
  if #candidates == 0 or total <= 0 then return nil end

  if roll == nil then roll = love.math.random() end
  local pick = roll * total
  for _, candidate in ipairs(candidates) do
    pick = pick - candidate.weight
    if pick <= 0 then return candidate.id end
  end
  return candidates[#candidates].id
end

function Loot.dropItem(run, itemId, x, y, amount)
  local item = ItemDrop.new(itemId, x, y, amount)
  if not item then return nil end
  run.itemDrops[#run.itemDrops + 1] = item
  FX.ring(x, y, 16, item.def.color)
  return item
end

function Loot.dropCharacterItem(run, characterId, x, y)
  local itemId = Data.characterItem[characterId]
  if not itemId then return false end
  local item = run:dropItem(itemId, x, y, 1)
  if not item then return false end
  run.unlockNotices[characterId] = true
  FX.add(
    "Ítem de " .. Data.characters[characterId].name,
    x,
    y - 30,
    Data.characters[characterId].color
  )
  return true
end

function Loot.maybeDropCharacter(run, chest)
  if chest.source ~= "wall" then return false end

  local locked = {}
  for _, id in ipairs(Data.characterOrder) do
    if not Save.isCharacterUnlocked(id) then
      locked[#locked + 1] = id
    end
  end
  if #locked == 0 then return false end
  if love.math.random() > Data.drop.characterChance then return false end

  local characterId = locked[love.math.random(1, #locked)]
  return run:dropCharacterItem(characterId, chest.x, chest.y - 6)
end

function Loot.chestItemAmount(run, def)
  if not def.stackable then return 1 end
  local roll = love.math.random()
  if roll < Data.drop.chestTripleChance then return 3 end
  if roll < Data.drop.chestDoubleChance then return 2 end
  return 1
end

function Loot.openChestLoot(run, chest)
  if run:maybeDropCharacter(chest) then return true end

  local itemId = run:chooseItem("chest")
  if not itemId then return false end

  local def = Data.items[itemId]
  local amount = run:chestItemAmount(def)
  run:dropItem(itemId, chest.x, chest.y - 6, amount)
  FX.add(
    def.name .. (amount > 1 and (" x" .. amount) or ""),
    chest.x,
    chest.y - 28,
    def.color
  )
  return true
end

function Loot.openChest(run, chest)
  local def = Data.chest
  local depth = run.depth
  local xp = def.xpBase + math.floor((depth - 1) * def.xpPerDepth)
  local coins = def.coinsBase + math.floor((depth - 1) * def.coinsPerDepth)

  run:addXp(xp)
  run:addCoins(coins)

  FX.burst(chest.x, chest.y - 8, 16, def.color)
  FX.collect(chest.x, chest.y, 12, def.color, run.player.x, run.player.y)
  FX.add(
    "+" .. xp .. " XP  +" .. coins .. " monedas",
    chest.x,
    chest.y - 14,
    { 0.55, 1.00, 0.65 }
  )
  run:openChestLoot(chest)
  run:shake(2, 0.12)
end

function Loot.onPetKilled(run, pet)
  local item, index, section = run:findInventoryItem(pet.kind)
  if item and index then
    run:removeItemAt(section or "active", index)
  end
  FX.burst(pet.x, pet.y, 14, Data.items[pet.kind].color)
  FX.add(
    Data.items[pet.kind].name .. " ha caído",
    pet.x,
    pet.y - 24,
    Data.items[pet.kind].color
  )
  run:shake(3, 0.18)
end

function Loot.pickupItem(run, item, pet)
  local def = item.def
  local x, y = item.x, item.y
  local player = run.player

  if def.kind == "character" then
    local characterId = def.characterId
    if run.sandbox then
      FX.add(
        "Desbloqueo omitido en pruebas",
        player.x,
        player.y - 34,
        def.color
      )
    else
      Save.unlockCharacter(characterId)
      run.unlockNotices[characterId] = nil
      FX.add(
        "¡" .. Data.characters[characterId].name .. " desbloqueada!",
        player.x,
        player.y - 34,
        def.color
      )
    end
  else
    local status, added = run:addItemToInventory(item.itemId, item.amount)
    if status == "full" then
      if (run.inventoryFullTimer or 0) <= 0 then
        FX.add("Mochila llena", player.x, player.y - 30, { 1.00, 0.40, 0.30 })
        run.inventoryFullTimer = 1.2
      end
      return false
    elseif status == "duplicate" then
      local reward = def.kind == "pet" and 8 or (5 * (item.amount or 1))
      run:addCoins(reward)
      FX.add("+" .. reward .. " monedas", x, y - 24, { 1.00, 0.86, 0.35 })
    elseif status == "ok" then
      if def.kind == "passive" then
        local stacks = run.passiveStacks[item.itemId] or 0
        local suffix = def.stackable
          and (" x" .. stacks .. "/" .. def.maxStacks)
          or ""
        FX.add(def.name .. suffix, x, y - 24, def.color)
      elseif def.kind == "pet" then
        FX.add("¡" .. def.name .. " se une!", x, y - 24, def.color)
      elseif def.kind == "ability" then
        FX.add(def.name .. " · abre la mochila", x, y - 24, def.color)
      end
    elseif status == "stored" then
      if def.kind == "ability" then
        FX.add(def.name .. " · abre la mochila", x, y - 24, def.color)
      else
        FX.add(def.name .. " · guardado", x, y - 24, def.color)
      end
    end
  end

  FX.burst(x, y, 10, def.color)
  if player then
    FX.collect(x, y, 8, def.color, player.x, player.y)
  end
  return true
end

function Loot.maybeDropItem(run, enemy)
  if enemy.def.noDrop then return end
  local chance = enemy.def.boss and Data.drop.bossChance or Data.drop.enemyChance
  if love.math.random() > chance then return end

  local pool = enemy.def.boss and "boss" or "normal"
  local itemId = run:chooseItem(pool)
  if not itemId then return end
  run:dropItem(itemId, enemy.x, enemy.y, 1)
end

return Loot
