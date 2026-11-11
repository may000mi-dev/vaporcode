-- run.lua: partida activa, combate, ritmo y progresión de nivel.
local Data = require("src.run.data")
local Save = require("src.run.save")
local State = require("src.estados")
local Rhythm = require("src.run.rhythm")
local Dungeon = require("src.run.dungeon")
local Camera = require("src.utils.camera")
local Player = require("src.run.player")
local Enemy = require("src.run.enemy")
local Projectile = require("src.run.projectile")
local FX = require("src.run.fx")
local Hud = require("src.run.hud")
local Joystick = require("src.utils.joystick")
local Buttons = require("src.utils.buttons")
local Input = require("src.utils.input")
local Util = require("src.utils.util")
local Targeting = require("src.run.targeting")
local Aim = require("src.run.aim")
local Abilities = require("src.run.abilities")
local Shadow = require("src.run.shadow")
local Floor = require("src.run.floor")
local Valve = require("src.run.valve")
local Chest = require("src.run.chest")
local ItemDrop = require("src.run.item_drop")
local Pet = require("src.run.pet")
local Backpack = require("src.run.backpack")
local Hazard = require("src.run.hazard")
local Shop = require("src.run.shop")

local Run = {
  def = nil,
  depth = 1,
  playerLevel = 1,
  hp = 100,
  xp = 0,
  xpToNext = 20,
  kills = 0,
  coinsEarned = 0,
  enemies = {},
  projectiles = {},
  valves = {},
  chests = {},
  itemDrops = {},
  hazards = {},
  passiveStacks = {},
  pets = {},
  petSnapshot = nil,
  tornado = nil,
  fluteReady = false,
  unlockNotices = {},
  player = nil,
  dungeon = nil,
  exitX = 0,
  exitY = 0,
  exitOpen = false,
  exitTimer = 0,
  paused = false,
  over = false,
  characterId = "amado",
  abilitySlot1 = nil,
  abilitySlot2 = nil,
  abilitySlot3 = "shield",
  abilitySlot4 = "turbo",
  cooldowns = {},
  inventory = {},
  inventoryFullTimer = 0,
  overlay = nil,
  selectedInventory = 1,
  shopTab = "buy",
  turboTimer = 0,
  mana = Data.mana.max,
  manaMax = Data.mana.max,
  manaIdleTimer = 0,
  manaFlash = 0,
  abilityLockTimer = 0,
  timeLeft = Data.floor.timeLimit,
  floorSnapshot = nil,
  shadow = nil,
  aim = nil,
  joystick = nil,
  buttons = nil,
  touchUI = false,
  stats = {},
  gameOverInfo = nil,
}

function Run:xpForLevel(level)
  return Data.player.xpBase + (level - 1) * Data.player.xpStep
end

function Run.enter(dungeonId, characterId, abilityId)
  if type(dungeonId) == "table" then
    Run.retryFloor(dungeonId)
    return
  end

  Run.def = Data.dungeonById[dungeonId] or Data.dungeons[1]

  if characterId
    and Data.characters[characterId]
    and Save.isCharacterUnlocked(characterId) then
    Run.characterId = characterId
  else
    Run.characterId = "amado"
  end
  Run.abilitySlot1 = nil
  Run.abilitySlot2 = nil
  Run.abilitySlot3 = "shield"
  Run.abilitySlot4 = "turbo"
  if abilityId and Data.exchangeableSet[abilityId] then
    Run.abilitySlot1 = abilityId
  end

  Run.seed = os.time() + math.floor(love.timer.getTime() * 1000)
  Run.depth = 1
  Run.playerLevel = 1
  Run.kills = 0
  Run.coinsEarned = 0
  Run.over = false
  Run.paused = false
  Run.exitOpen = false
  Run.exitTimer = 0
  Run.cooldowns = {}
  Run.turboTimer = 0
  Run.manaMax = Data.mana.max
  Run.mana = Run.manaMax
  Run.manaIdleTimer = 0
  Run.manaFlash = 0
  Run.abilityLockTimer = 0
  Run.timeLeft = Data.floor.timeLimit
  Run.floorSnapshot = nil
  Run.shadow = nil
  Run.aim = Aim.new()
  Run.gameOverInfo = nil
  Run.projectiles = {}
  Run.valves = {}
  Run.chests = {}
  Run.itemDrops = {}
  Run.hazards = {}
  Run.inventory = {}
  Run.inventoryFullTimer = 0
  Run.tornado = nil
  Run.unlockNotices = {}
  Run.overlay = nil
  Run.selectedInventory = 1
  Run.shopTab = "buy"
  Run.touchUI = Util.isMobile()
  Run.joystick = Joystick.new()
  Run.buttons = Buttons.new()

  local character = Data.characters[Run.characterId]
  Run.stats = {
    damage = Save.stat("damage"),
    maxHp = Save.stat("maxHp"),
    speed = Save.stat("speed"),
    attackRate = character.attackRate,
  }

  Run.hp = Run.stats.maxHp
  Run.xp = 0
  Run.xpToNext = Run:xpForLevel(Run.playerLevel)

  FX.clear()
  Input.reset()
  Rhythm.enter(Run.def.song)
  Run:enterLevel()
end

function Run:enterLevel()
  -- La semilla de la partida hace reproducibles todos sus pisos.
  local seed = Run.seed + Run.depth * 7919
  Run.dungeon = Dungeon.new({ depth = Run.depth }, seed)

  local px, py = Run.dungeon:spawnPoint()
  Run.player = Player.new(px, py, Run.characterId)
  Run.player:setupShield(Run.stats.maxHp)
  Camera.reset(px, py)
  Run.spawnX = px
  Run.spawnY = py
  Run.exitX, Run.exitY = Run.dungeon:exitPoint()
  Run.exitOpen = false
  Run.exitTimer = 0
  Run.enemies = {}
  Run.projectiles = {}
  Run.valves = {}
  Run.chests = {}
  Run.itemDrops = {}
  Run.hazards = {}
  Run.tornado = nil
  Run.enemyCount = 0
  Run.boss = nil
  Run.shadow = nil
  Run.manaFlash = 0
  Run.abilityLockTimer = 0
  if Run.aim then
    Run.aim:cancel()
  end

  for _, spot in ipairs(Run.dungeon.valveSpots) do
    Run.valves[#Run.valves + 1] = Valve.new(spot.x, spot.y)
  end

  for _, spot in ipairs(Run.dungeon.chestSpots) do
    local lootIndex = ((spot.tx * 31 + spot.ty * 17 + Run.depth * 13)
      % 997) + 1
    Run.chests[#Run.chests + 1] = Chest.new(
      spot.x,
      spot.y,
      lootIndex,
      "floor"
    )
  end

  if Run.petSnapshot then
    Run.pets = {}
    for index, data in ipairs(Run.petSnapshot) do
      local pet = Pet.new(data.kind, px, py, data)
      if pet then
        pet:placeNear(Run.player, index)
        Run.pets[#Run.pets + 1] = pet
      end
    end
    Run.petSnapshot = nil
  else
    for index, pet in ipairs(Run.pets) do
      if not pet.dead then
        pet:placeNear(Run.player, index)
      end
    end
  end

  FX.clear()
  Run.timeLeft = Data.floor.timeLimit
  Run:spawnEnemies()
  Run.floorSnapshot = Floor.capture(Run)
end

function Run.retryFloor(snapshot)
  if not Floor.restore(Run, snapshot) then
    Run.enter("cripta")
    return
  end

  Run.def = Data.dungeonById[snapshot.dungeonId] or Data.dungeons[1]
  Run.over = false
  Run.paused = false
  Run.exitOpen = false
  Run.exitTimer = 0
  Run.manaFlash = 0
  Run.shadow = nil
  Run.aim = Aim.new()
  Run.gameOverInfo = nil
  Run.projectiles = {}
  Run.valves = {}
  Run.chests = {}
  Run.itemDrops = {}
  Run.hazards = {}
  Run.tornado = nil
  Run.unlockNotices = {}
  Run.overlay = nil
  Run.selectedInventory = 1
  Run.shopTab = "buy"
  Run.touchUI = Util.isMobile()
  Run.joystick = Joystick.new()
  Run.buttons = Buttons.new()

  FX.clear()
  Input.reset()
  Rhythm.enter(Run.def.song)
  Run:enterLevel()
  return true
end

function Run:createEnemy(kind, x, y, options)
  options = options or {}
  local def = Data.enemyTypes[kind]
  if not def then return nil end

  local hpScale = 1 + (Run.depth - 1) * Run.def.hpScale
  local damageScale = 1 + (Run.depth - 1) * Run.def.damageScale
  local hp = options.hp or math.floor(def.hp * hpScale)
  local damage = options.damage or math.floor(def.damage * damageScale)

  local elite = options.elite
  if not elite and not options.noElite and not def.boss and not def.noElite then
    if Run.dungeon.rng:random() < Data.elite.chance then
      local roll = Run.dungeon.rng:random(1, 3)
      elite = roll == 1 and "volatile" or (roll == 2 and "armored" or "spectral")
    end
  end

  local enemy = Enemy.new(kind, x, y, hp, damage, def.xp, { elite = elite })
  Run.enemies[#Run.enemies + 1] = enemy
  return enemy
end

function Run:spawnEnemies()
  local count = Run.def.spawnBase
    + math.floor((Run.depth - 1) * Data.spawn.perDepth)
  count = math.min(count, Data.spawn.maxEnemies)

  local pool = Run.def.enemies

  for _ = 1, count do
    local kind = pool[Run.dungeon.rng:random(1, #pool)]
    local def = Data.enemyTypes[kind]
    local x, y = Run.dungeon:randomFloorPoint(
      Run.spawnX,
      Run.spawnY,
      Data.spawn.minDistance,
      def.radius
    )

    if x then
      Run:createEnemy(kind, x, y)
    end
  end

  if Run.depth % Data.bossEvery == 0 then
    local bossDef = Data.enemyTypes[Run.def.boss or "guardian"]
    local bx, by = Run.dungeon:randomFloorPoint(
      Run.spawnX,
      Run.spawnY,
      Data.spawn.bossMinDistance,
      bossDef.radius
    )
    if not bx then
      bx, by = Run.dungeon:randomFloorPoint(
        Run.spawnX,
        Run.spawnY,
        Data.spawn.bossFallbackDistance,
        bossDef.radius
      )
    end
    if not bx then
      bx, by = Run.dungeon:randomFloorPoint(nil, nil, 0, bossDef.radius)
    end

    if bx then
      local boss = Run:createEnemy(bossDef.id or (Run.def.boss or "guardian"), bx, by, {
        noElite = true,
      })
      Run.boss = boss
    end
  end

  Run.enemyCount = #Run.enemies
end

function Run:spawnHazard(kind, x, y, options)
  local hazard = Hazard.new(kind, x, y, options)
  Run.hazards[#Run.hazards + 1] = hazard
  return hazard
end

function Run:damagePlayerInRadius(x, y, radius, damage)
  local reach = radius + Run.player.radius
  if Util.dist2(x, y, Run.player.x, Run.player.y) <= reach * reach then
    return Run.player:takeDamage(damage, Run)
  end
  return false
end

function Run:healEnemiesAround(x, y, radius, percent)
  local reach2 = radius * radius
  local healed = 0
  for _, enemy in ipairs(Run.enemies) do
    if not enemy.dead and Util.dist2(x, y, enemy.x, enemy.y) <= reach2 then
      local amount = enemy.maxHp * percent
      if enemy.hp < enemy.maxHp then
        enemy.hp = math.min(enemy.maxHp, enemy.hp + amount)
        healed = healed + 1
      end
    end
  end
  if healed > 0 then
    FX.ring(x, y, radius, { 0.98, 0.86, 0.38 })
    FX.add("+15% vida enemiga", x, y - 28, { 0.98, 0.86, 0.38 })
  end
  return healed
end

function Run:explodeVolatile(enemy)
  local radius = Data.elite.volatileRadius
  local damage = math.max(
    enemy.damage * Data.elite.volatileDamageScale,
    enemy.maxHp * 0.35
  )
  if Util.dist2(enemy.x, enemy.y, Run.player.x, Run.player.y)
    <= (radius + Run.player.radius) ^ 2
  then
    Run.player:takeDamage(damage, Run)
  end
  for _, other in ipairs(Run.enemies) do
    if other ~= enemy and not other.dead then
      local reach = radius + other.radius
      if Util.dist2(enemy.x, enemy.y, other.x, other.y) <= reach * reach then
        other:takeDamage(damage, Run, "elite")
      end
    end
  end
  FX.ring(enemy.x, enemy.y, radius, { 1.00, 0.55, 0.24 })
  FX.burst(enemy.x, enemy.y, 22, { 1.00, 0.55, 0.24 })
  if Run.shake then Run:shake(5, 0.26) end
end

function Run:spawnProjectile(x, y, angle, damage, hostile, options)
  local speed = options and options.speed
    or (hostile and Data.projectile.hostileSpeed or Data.projectile.friendlySpeed)
  Run.projectiles[#Run.projectiles + 1] = Projectile.new(
    x,
    y,
    angle,
    speed,
    damage,
    not hostile,
    options
  )
end

function Run:nearestEnemy(maxDistance, requireLineOfSight)
  return Targeting.nearestVisible(
    Run.player.x,
    Run.player.y,
    Run.enemies,
    maxDistance,
    Run.dungeon,
    requireLineOfSight
  )
end

function Run:shake(magnitude, duration)
  Camera.shake(magnitude, duration)
end

function Run:onManaFail(ability)
  Run.manaFlash = Data.mana.flashDuration
  Rhythm.playLockedClick()
  if ability and Run.player then
    FX.ring(Run.player.x, Run.player.y, 28, { 0.95, 0.25, 0.25 })
  end
end

function Run:updateMana(dt)
  Run.manaFlash = math.max(0, (Run.manaFlash or 0) - dt)
  Run.manaIdleTimer = (Run.manaIdleTimer or 0) + dt

  local idle = Run.manaIdleTimer >= Data.mana.idleDelay
  local multiplier = idle and Data.mana.idleMultiplier or 1
  local regen = Data.mana.regen * multiplier
  Run.mana = math.min(Run.manaMax, (Run.mana or 0) + regen * dt)
end

function Run:markEnemy(enemy)
  if enemy.dead then return false end

  if enemy.markTimer > 0 then
    enemy:applyMark(Data.mark.duration)
    return true
  end

  local marked = 0
  for _, other in ipairs(Run.enemies) do
    if not other.dead and other.markTimer > 0 then
      marked = marked + 1
    end
  end
  if marked >= Data.mark.maxMarks then return false end

  enemy:applyMark(Data.mark.duration)
  return true
end

function Run:meleeSpin(player, range, damage)
  player.spinTimer = 0.25
  local range2 = range * range

  for _, enemy in ipairs(Run.enemies) do
    if not enemy.dead then
      if Util.dist2(player.x, player.y, enemy.x, enemy.y) <= range2 then
        if Run.dungeon:lineOfSight(player.x, player.y, enemy.x, enemy.y) then
          enemy:takeDamage(damage, Run, "basic")
        end
      end
    end
  end

  FX.ring(player.x, player.y, range, Data.characters.mar.color)
end

function Run:spawnShadow(x, y)
  Run.shadow = Shadow.new(x, y, Data.abilities.shadow_swap)
end

function Run:abilityIdForSlot(slot)
  if slot == 1 then return Run.abilitySlot1 end
  if slot == 2 then return Run.abilitySlot2 end
  if slot == 4 then return Run.abilitySlot4 end
  return Run.abilitySlot3
end

function Run:cooldownKeyForSlot(slot)
  if slot == 1 then return "a1" end
  if slot == 2 then return "a2" end
  if slot == 3 then return "shield" end
  if slot == 4 then return "turbo" end
  return tostring(slot)
end

function Run:equipAbility(slot, abilityId)
  if slot ~= 1 and slot ~= 2 then return false end
  if not Data.exchangeableSet[abilityId] then return false end
  if slot == 1 then
    Run.abilitySlot1 = abilityId
  else
    Run.abilitySlot2 = abilityId
  end
  Run.cooldowns[Run:cooldownKeyForSlot(slot)] = 0
  return true
end

function Run:marDash(angle, allowAtRest)
  local player = Run.player
  if not player then return false end
  if not player.moving and not allowAtRest then return false end

  local def = Data.characters.mar
  local dx, dy
  if player.moving then
    dx, dy = player.moveX, player.moveY
  elseif angle then
    dx, dy = math.cos(angle), math.sin(angle)
  else
    dx, dy = player.facingX, player.facingY
  end

  local distance = def.dashRadiusFactor * player.radius
  local targetX = player.x + dx * distance
  local targetY = player.y + dy * distance
  local landingX, landingY = Run.dungeon:nearestWalkable(
    targetX,
    targetY,
    player.radius,
    def.dashSearch
  )
  if not landingX then return false end

  player.x = landingX
  player.y = landingY
  player.invuln = math.max(player.invuln, def.dashInvuln)
  FX.ring(player.x, player.y, player.radius + 10, def.color)
  return true
end

function Run:onAbilityActivated(abilityId, aim, meta)
  if meta and meta.skipPassive then return end
  if Run.characterId == "mar" and Run.player.moving then
    Run:marDash(nil, false)
  end
end

function Run:onEnemyKilled(enemy)
  Run.kills = Run.kills + 1

  if not enemy.def.noDrop then
    local coins = Data.economy.coinsBase
      + math.floor(enemy.xp / Data.economy.xpPerCoin)
    Save.data.coins = Save.data.coins + coins
    Run.coinsEarned = Run.coinsEarned + coins
    Run:addXp(enemy.xp)
  end
  local count = enemy.def.boss and 36 or 14
  FX.burst(enemy.x, enemy.y, math.floor(count * 0.35), enemy.def.color)
  if Run.player then
    FX.collect(
      enemy.x,
      enemy.y,
      count,
      enemy.def.color,
      Run.player.x,
      Run.player.y
    )
  end
  if not enemy.def.noDrop then
    FX.add("+" .. enemy.xp .. " XP", enemy.x, enemy.y - 14, { 0.45, 0.90, 1.00 })
    Run:maybeDropItem(enemy)
  end
  if enemy.elite == "volatile" then
    Run:explodeVolatile(enemy)
  end
  if enemy.def.boss then
    Run:shake(8, 0.40)
    FX.add(
      "¡Jefe derrotado!",
      enemy.x,
      enemy.y - 34,
      { 1.00, 0.80, 0.30 }
    )
  end
end

function Run:hitValve(x, y, radius)
  if not Run.valves then return false end

  for _, valve in ipairs(Run.valves) do
    local reach = radius + valve.radius
    if Util.dist2(x, y, valve.x, valve.y) <= reach * reach then
      valve:trigger(Run)
      return true
    end
  end
  return false
end

function Run:triggerValvesInRadius(x, y, radius)
  if not Run.valves then return end

  local reach2 = radius * radius
  for _, valve in ipairs(Run.valves) do
    if Util.dist2(x, y, valve.x, valve.y) <= reach2 then
      valve:trigger(Run)
    end
  end
end

function Run:triggerValvesOnSegment(x1, y1, x2, y2, width)
  if not Run.valves then return end

  for _, valve in ipairs(Run.valves) do
    local reach = width + valve.radius
    local d2 = Util.pointSegmentDist2(
      valve.x,
      valve.y,
      x1,
      y1,
      x2,
      y2
    )
    if d2 <= reach * reach then
      valve:trigger(Run)
    end
  end
end

function Run:damageWallAt(tx, ty, amount)
  local dungeon = Run.dungeon
  if not dungeon:isDestructibleTile(tx, ty) then return false end

  local broken, wall = dungeon:damageWall(tx, ty, amount)
  local x, y = dungeon:tileCenter(tx, ty)
  if not broken then
    FX.burst(x, y, 5, Data.destructible.crack)
    FX.ring(x, y, 12, Data.destructible.crack)
    return false
  end

  Run:onWallBroken(tx, ty, wall, x, y)
  return true
end

function Run:damageWallsInRadius(x, y, radius, amount)
  local dungeon = Run.dungeon
  local hits = {}
  local reach = radius + dungeon.tile * 0.5
  local reach2 = reach * reach

  for ty, row in pairs(dungeon.destructible) do
    for tx in pairs(row) do
      local wx, wy = dungeon:tileCenter(tx, ty)
      if Util.dist2(x, y, wx, wy) <= reach2 then
        hits[#hits + 1] = { tx = tx, ty = ty }
      end
    end
  end

  local broken = false
  for _, hit in ipairs(hits) do
    if Run:damageWallAt(hit.tx, hit.ty, amount) then
      broken = true
    end
  end
  return broken
end

function Run:onWallBroken(tx, ty, wall, x, y)
  local def = Data.destructible
  FX.burst(x, y, 20, def.crack)
  FX.ring(x, y, 28, def.crack)
  FX.add("¡Pared destruida!", x, y - 24, def.crack)
  Run:shake(4, 0.20)

  if wall and wall.loot then
    Run:spawnChest(x, y, "wall")
  end
end

function Run:spawnChest(x, y, source)
  local lootIndex = love.math.random(1, 997)
  Run.chests[#Run.chests + 1] = Chest.new(x, y, lootIndex, source)
  FX.ring(x, y, 22, Data.chest.color)
end

function Run:ownsPet(kind)
  for _, pet in ipairs(Run.pets or {}) do
    if not pet.dead and pet.kind == kind then return true end
  end
  return false
end

function Run:passiveMaxed(id)
  local def = Data.items[id]
  if not def or def.kind ~= "passive" then return false end
  local stacks = (Run.passiveStacks and Run.passiveStacks[id]) or 0
  return stacks >= (def.maxStacks or 1)
end

function Run:findInventoryItem(itemId)
  for index, slot in ipairs(Run.inventory or {}) do
    if slot.itemId == itemId then return slot, index end
  end
  return nil, nil
end

function Run:rebuildPassives()
  Run.passiveStacks = {}
  for _, slot in ipairs(Run.inventory or {}) do
    local def = Data.items[slot.itemId]
    if def and def.kind == "passive" then
      Run.passiveStacks[slot.itemId] =
        (Run.passiveStacks[slot.itemId] or 0) + (slot.amount or 1)
    end
  end
end

function Run:removePetByKind(kind)
  for _, pet in ipairs(Run.pets or {}) do
    if not pet.dead and pet.kind == kind then
      pet.dead = true
    end
  end
end

function Run:addItemToInventory(itemId, amount)
  local def = Data.items[itemId]
  if not def then return "invalid" end
  amount = math.max(1, math.floor(amount or 1))

  local existing = Run:findInventoryItem(itemId)
  if def.kind == "passive" then
    -- Cada copia ocupa su espacio para poder combinarlas con alquimia.
    if not def.stackable and existing then return "duplicate" end
    if def.stackable and Run:passiveMaxed(itemId) then return "duplicate" end
    amount = math.min(amount, def.maxStacks or 1)
  elseif def.kind == "pet" then
    if existing or Run:ownsPet(def.pet) then return "duplicate" end
  end

  if #(Run.inventory or {}) >= Data.inventory.maxSlots then
    return "full"
  end

  Run.inventory[#Run.inventory + 1] = {
    itemId = itemId,
    amount = def.kind == "passive" and amount or 1,
  }

  if def.kind == "passive" then
    Run:rebuildPassives()
  elseif def.kind == "pet" then
    Run:addPet(def.pet, Run.player.x, Run.player.y)
  end
  return "ok", amount
end

function Run:removeInventoryAt(index)
  local slot = Run.inventory and Run.inventory[index]
  if not slot then return nil end
  table.remove(Run.inventory, index)

  local def = Data.items[slot.itemId]
  if def and def.kind == "passive" then
    Run:rebuildPassives()
  elseif def and def.kind == "pet" then
    Run:removePetByKind(def.pet)
  end

  local count = #Run.inventory
  if count == 0 then
    Run.selectedInventory = 1
  elseif Run.selectedInventory > count then
    Run.selectedInventory = count
  end
  return slot
end

function Run:shopPrice(itemId)
  return Data.shop.prices[itemId]
end

function Run:alchemyCost(amount)
  return Data.alchemy.costs[amount + 1]
end

function Run:buyItem(itemId)
  local price = Run:shopPrice(itemId)
  if not price then return "invalid" end
  if Save.data.coins < price then return "coins" end

  local status = Run:addItemToInventory(itemId, 1)
  if status ~= "ok" then return status end

  Save.data.coins = Save.data.coins - price
  Save.save()
  Run:notify(
    "Comprado: " .. Data.items[itemId].name .. " (-" .. price .. ")",
    Data.items[itemId].color
  )
  return "ok"
end

function Run:alchemyCandidates()
  local out = {}
  local inventory = Run.inventory or {}
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
            cost = Run:alchemyCost(a.amount or 1),
          }
        end
      end
    end
  end
  return out
end

function Run:combineAlchemy(candidate)
  if not candidate then return false end
  local inventory = Run.inventory or {}
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

  local cost = Run:alchemyCost(a.amount or 1)
  if Save.data.coins < cost then return false end

  table.remove(inventory, math.max(candidate.index1, candidate.index2))
  table.remove(inventory, math.min(candidate.index1, candidate.index2))
  table.insert(inventory, math.min(candidate.index1, candidate.index2), {
    itemId = a.itemId,
    amount = (a.amount or 1) + 1,
  })

  Save.data.coins = Save.data.coins - cost
  Save.save()
  Run:rebuildPassives()
  Run:notify(
    def.name .. " x" .. (a.amount + 1) .. " combinado",
    def.color
  )
  return true
end

function Run:equipInventoryAbility(index, slot)
  if slot ~= 1 and slot ~= 2 then return false end
  local item = Run.inventory and Run.inventory[index]
  if not item then return false end
  local def = Data.items[item.itemId]
  if not def or def.kind ~= "ability" then return false end

  table.remove(Run.inventory, index)
  Run:equipAbility(slot, def.abilityId)
  local count = #Run.inventory
  if count == 0 then
    Run.selectedInventory = 1
  elseif Run.selectedInventory > count then
    Run.selectedInventory = count
  end

  FX.add(
    def.name .. " → A" .. slot,
    Run.player.x,
    Run.player.y - 30,
    def.color
  )
  return true
end

function Run:itemCandidates(poolName)
  local pool = Data.itemPool[poolName] or Data.itemPool.normal
  local out = {}
  local total = 0
  for _, id in ipairs(pool) do
    local def = Data.items[id]
    local allowed = true
    if def.kind == "passive" and def.stackable and Run:passiveMaxed(id) then
      allowed = false
    elseif def.maxStacks == 1
      and ((Run.passiveStacks and Run.passiveStacks[id]) or 0) > 0 then
      allowed = false
    elseif def.kind == "pet" and Run:ownsPet(def.pet) then
      allowed = false
    end
    if allowed and (def.weight or 0) > 0 then
      total = total + def.weight
      out[#out + 1] = { id = id, weight = def.weight }
    end
  end
  return out, total
end

function Run:chooseItem(poolName, roll)
  local candidates, total = Run:itemCandidates(poolName)
  if #candidates == 0 or total <= 0 then return nil end

  if roll == nil then roll = love.math.random() end
  local pick = roll * total
  for _, candidate in ipairs(candidates) do
    pick = pick - candidate.weight
    if pick <= 0 then return candidate.id end
  end
  return candidates[#candidates].id
end

function Run:dropItem(itemId, x, y, amount)
  local item = ItemDrop.new(itemId, x, y, amount)
  if not item then return nil end
  Run.itemDrops[#Run.itemDrops + 1] = item
  FX.ring(x, y, 16, item.def.color)
  return item
end

function Run:dropCharacterItem(characterId, x, y)
  local itemId = Data.characterItem[characterId]
  if not itemId then return false end
  local item = Run:dropItem(itemId, x, y, 1)
  if not item then return false end
  Run.unlockNotices[characterId] = true
  FX.add(
    "Ítem de " .. Data.characters[characterId].name,
    x,
    y - 30,
    Data.characters[characterId].color
  )
  return true
end

function Run:maybeDropCharacter(chest)
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
  return Run:dropCharacterItem(characterId, chest.x, chest.y - 6)
end

function Run:chestItemAmount(def)
  if not def.stackable then return 1 end
  local roll = love.math.random()
  if roll < Data.drop.chestTripleChance then return 3 end
  if roll < Data.drop.chestDoubleChance then return 2 end
  return 1
end

function Run:openChestLoot(chest)
  if Run:maybeDropCharacter(chest) then return true end

  local itemId = Run:chooseItem("chest")
  if not itemId then return false end

  local def = Data.items[itemId]
  local amount = Run:chestItemAmount(def)
  Run:dropItem(itemId, chest.x, chest.y - 6, amount)
  FX.add(
    def.name .. (amount > 1 and (" x" .. amount) or ""),
    chest.x,
    chest.y - 28,
    def.color
  )
  return true
end

function Run:openChest(chest)
  local def = Data.chest
  local depth = Run.depth
  local xp = def.xpBase + math.floor((depth - 1) * def.xpPerDepth)
  local coins = def.coinsBase + math.floor((depth - 1) * def.coinsPerDepth)

  Run:addXp(xp)
  Save.data.coins = Save.data.coins + coins
  Run.coinsEarned = Run.coinsEarned + coins

  FX.burst(chest.x, chest.y - 8, 16, def.color)
  FX.collect(chest.x, chest.y, 12, def.color, Run.player.x, Run.player.y)
  FX.add(
    "+" .. xp .. " XP  +" .. coins .. " monedas",
    chest.x,
    chest.y - 14,
    { 0.55, 1.00, 0.65 }
  )
  Run:openChestLoot(chest)
  Run:shake(2, 0.12)
end

function Run:addPet(kind, x, y)
  if Run:ownsPet(kind) then return false end
  local pet = Pet.new(kind, x, y)
  if not pet then return false end
  pet:placeNear(Run.player, #Run.pets + 1)
  Run.pets[#Run.pets + 1] = pet
  return true
end

function Run:onPetKilled(pet)
  local item, index = Run:findInventoryItem(pet.kind)
  if item and index then
    table.remove(Run.inventory, index)
    local count = #Run.inventory
    if count == 0 then
      Run.selectedInventory = 1
    elseif Run.selectedInventory > count then
      Run.selectedInventory = count
    end
  end
  FX.burst(pet.x, pet.y, 14, Data.items[pet.kind].color)
  FX.add(
    Data.items[pet.kind].name .. " ha caído",
    pet.x,
    pet.y - 24,
    Data.items[pet.kind].color
  )
  Run:shake(3, 0.18)
end

function Run:pickupItem(item, pet)
  local def = item.def
  local x, y = item.x, item.y
  local player = Run.player

  if def.kind == "character" then
    local characterId = def.characterId
    Save.unlockCharacter(characterId)
    Run.unlockNotices[characterId] = nil
    FX.add(
      "¡" .. Data.characters[characterId].name .. " desbloqueada!",
      player.x,
      player.y - 34,
      def.color
    )
  else
    local status, added = Run:addItemToInventory(item.itemId, item.amount)
    if status == "full" then
      if (Run.inventoryFullTimer or 0) <= 0 then
        FX.add("Mochila llena", player.x, player.y - 30, { 1.00, 0.40, 0.30 })
        Run.inventoryFullTimer = 1.2
      end
      return false
    elseif status == "duplicate" then
      local reward = def.kind == "pet" and 8 or (5 * (item.amount or 1))
      Save.data.coins = Save.data.coins + reward
      Run.coinsEarned = Run.coinsEarned + reward
      FX.add("+" .. reward .. " monedas", x, y - 24, { 1.00, 0.86, 0.35 })
    elseif status == "ok" then
      if def.kind == "passive" then
        local stacks = Run.passiveStacks[item.itemId] or 0
        local suffix = def.stackable
          and (" x" .. stacks .. "/" .. def.maxStacks)
          or ""
        FX.add(def.name .. suffix, x, y - 24, def.color)
      elseif def.kind == "pet" then
        FX.add("¡" .. def.name .. " se une!", x, y - 24, def.color)
      elseif def.kind == "ability" then
        FX.add(def.name .. " · abre la mochila", x, y - 24, def.color)
      end
    end
  end

  FX.burst(x, y, 10, def.color)
  if player then
    FX.collect(x, y, 8, def.color, player.x, player.y)
  end
  return true
end

function Run:maybeDropItem(enemy)
  if enemy.def.noDrop then return end
  local chance = enemy.def.boss and Data.drop.bossChance or Data.drop.enemyChance
  if love.math.random() > chance then return end

  local pool = enemy.def.boss and "boss" or "normal"
  local itemId = Run:chooseItem(pool)
  if not itemId then return end
  Run:dropItem(itemId, enemy.x, enemy.y, 1)
end

function Run:onEnemyDamaged(enemy, amount, source)
  if amount <= 0 then return end

  local poisonStacks = (Run.passiveStacks and Run.passiveStacks.poison) or 0
  if poisonStacks > 0 and source ~= "poison" and not enemy.dead then
    local def = Data.items.poison
    local dps = def.dpsBase + (poisonStacks - 1) * def.dpsPerStack
    enemy:applyPoison(dps, def.duration)
  end

  if source == "basic" then
    Run:onBasicDamage(enemy, amount)
  end
end

function Run:onBasicDamage(enemy, amount)
  local vampire = (Run.passiveStacks and Run.passiveStacks.vampire) or 0
  local fairy = (Run.passiveStacks and Run.passiveStacks.fairy) or 0
  local synergy = vampire > 0 and fairy > 0

  if vampire > 0 then
    local def = Data.items.vampire
    local rate = synergy and def.healSynergy or def.healPerStack
    local heal = amount * math.min(rate * vampire, def.healCap)
    Run.hp = math.min(Run.stats.maxHp, Run.hp + heal)
  end

  if fairy > 0 then
    local def = Data.items.fairy
    local rate = synergy and def.healSynergy or def.healPerStack
    local restore = amount * math.min(rate * fairy, def.healCap)
    Run.mana = math.min(Run.manaMax, (Run.mana or 0) + restore)
  end

  local gunpowder = (Run.passiveStacks and Run.passiveStacks.gunpowder) or 0
  if gunpowder > 0 and love.math.random() < Data.items.gunpowder.chance then
    Run:triggerGunpowder(enemy, gunpowder)
  end

  if Run.fluteReady then
    Run.fluteReady = false
    Run:spawnTornado(enemy.x, enemy.y)
  end
end

function Run:triggerGunpowder(enemy, stacks)
  local def = Data.items.gunpowder
  local damage = Run.stats.damage
    * (def.damageBase + (stacks - 1) * def.damagePerStack)
  local radius = def.radiusBase + (stacks - 1) * def.radiusPerStack
  local radius2 = radius * radius

  for _, other in ipairs(Run.enemies) do
    if not other.dead then
      local dx = other.x - enemy.x
      local dy = other.y - enemy.y
      local d2 = dx * dx + dy * dy
      if d2 <= radius2 then
        other:takeDamage(damage, Run, "gunpowder")
        if not other.dead and other.applyStun then
          other:applyStun(def.stun)
        end
        if not other.dead then
          local distance = math.sqrt(d2)
          local nx, ny = 1, 0
          if distance > 0.001 then
            nx, ny = dx / distance, dy / distance
          end
          other.x, other.y = Run.dungeon:moveCircle(
            other.x,
            other.y,
            nx * 28,
            ny * 28,
            other.radius
          )
        end
      end
    end
  end

  FX.burst(enemy.x, enemy.y, 20, def.color)
  FX.ring(enemy.x, enemy.y, radius, def.color)
  Run:shake(4, 0.20)
end

function Run:spawnTornado(x, y)
  local def = Data.items.flute
  Run.tornado = {
    x = x,
    y = y,
    radius = def.radius,
    time = def.duration,
    maxTime = def.duration,
    tick = 0,
    phase = love.math.random() * math.pi * 2,
  }
  FX.ring(x, y, def.radius, def.color)
  FX.add("¡Tornado!", x, y - 34, def.color)
end

function Run:updateTornado(dt)
  local tornado = Run.tornado
  if not tornado then return end

  local def = Data.items.flute
  tornado.time = tornado.time - dt
  tornado.tick = tornado.tick - dt
  if tornado.time <= 0 then
    Run.tornado = nil
    return
  end
  if tornado.tick > 0 then return end

  tornado.tick = def.tickInterval
  local damage = Run.stats.damage
    * def.damageMultiplier
    * def.tickScale
  local radius2 = tornado.radius * tornado.radius
  for _, enemy in ipairs(Run.enemies) do
    if not enemy.dead then
      if Util.dist2(tornado.x, tornado.y, enemy.x, enemy.y) <= radius2 then
        enemy:takeDamage(damage, Run, "ability")
        if not enemy.dead and enemy.applySlow then
          enemy:applySlow(def.tickInterval + 0.1, 1 - def.slow)
        end
      end
    end
  end
  FX.ring(tornado.x, tornado.y, tornado.radius, def.color)
end

function Run:updateItemDrops(dt)
  for _, item in ipairs(Run.itemDrops) do
    if not item.dead then
      item:update(dt, Run)
    end
  end
end

function Run:updatePets(dt)
  for _, pet in ipairs(Run.pets) do
    if not pet.dead then
      pet:update(dt, Run)
    end
  end
end

function Run:commitUnlockNotices()
  local messages = {}
  for _, id in ipairs(Data.characterOrder) do
    if Run.unlockNotices[id] then
      Save.unlockCharacter(id)
      messages[#messages + 1] = "¡"
        .. Data.characters[id].name
        .. " desbloqueada!"
      Run.unlockNotices[id] = nil
    end
  end
  return messages
end

function Run:drawTornado()
  local tornado = Run.tornado
  if not tornado then return end

  local def = Data.items.flute
  local t = love.timer.getTime()
  local alpha = math.min(1, tornado.time / math.max(0.001, tornado.maxTime))
  love.graphics.setColor(def.color[1], def.color[2], def.color[3], 0.10 * alpha)
  love.graphics.circle("fill", tornado.x, tornado.y, tornado.radius)
  love.graphics.setColor(def.color[1], def.color[2], def.color[3], 0.55 * alpha)
  love.graphics.setLineWidth(3)
  for i = 0, 3 do
    local phase = t * 4 + tornado.phase + i * math.pi * 0.5
    local radius = tornado.radius * (0.35 + i * 0.18)
    love.graphics.arc(
      "line",
      tornado.x,
      tornado.y,
      radius,
      phase,
      phase + 1.4
    )
  end
  love.graphics.setLineWidth(1)
end

function Run:updateFeatures(dt)
  for _, valve in ipairs(Run.valves) do
    valve:update(dt, Run)
  end
  if Run.over then return end

  for _, chest in ipairs(Run.chests) do
    chest:update(dt, Run)
  end
end

function Run:addXp(amount)
  Run.xp = Run.xp + amount

  while Run.xp >= Run.xpToNext do
    Run.xp = Run.xp - Run.xpToNext
    Run.playerLevel = Run.playerLevel + 1
    Run.xpToNext = Run:xpForLevel(Run.playerLevel)
    Run.stats.damage = Run.stats.damage + Data.player.levelDamage
    Run.stats.maxHp = Run.stats.maxHp + Data.player.levelMaxHp
    Run.hp = math.min(Run.stats.maxHp, Run.hp + Data.player.levelHeal)
    Run.player:refreshShield(Run.stats.maxHp)
    FX.add(
      "¡Nivel " .. Run.playerLevel .. "!",
      Run.player.x,
      Run.player.y - 26,
      { 1.00, 0.90, 0.35 }
    )
  end
end

function Run:useAbility(slot, aim)
  return Abilities.cast(Run, slot, aim)
end

function Run:onAbilityLocked()
  Run:notify("Habilidades selladas", { 0.55, 0.72, 1.00 })
end

function Run:addAbilityLock(seconds)
  Run.abilityLockTimer = math.max(Run.abilityLockTimer or 0, seconds or 0)
end

function Run:applyPlayerEffect(effect, data)
  data = data or {}
  if effect == "slow" then
    Run.player:applySlow(data.duration or 1.5, data.factor or 0.45)
    Run:notify("Lodo: ralentizado", { 0.45, 0.80, 0.40 })
  elseif effect == "mana_drain" then
    local drain = Run.manaMax * (data.manaDrain or 0.12)
    Run.mana = math.max(0, Run.mana - drain)
    Run:addAbilityLock(data.lock or 2)
    Run:notify("Reloj: maná drenado", { 0.55, 0.72, 1.00 })
  end
end

function Run:notify(text, color)
  if Run.player then
    FX.add(text, Run.player.x, Run.player.y - 34, color or { 1.00, 0.88, 0.45 })
  end
end

function Run:toggleBackpack()
  if Run.overlay == "backpack" then
    Run.overlay = nil
  else
    Run.overlay = "backpack"
    local count = #(Run.inventory or {})
    if count == 0 then
      Run.selectedInventory = 1
    elseif Run.selectedInventory > count then
      Run.selectedInventory = count
    end
  end
  Run:clearInput()
end

function Run:openShop()
  if Run.overlay == "shop" then
    Run.overlay = nil
    Run:clearInput()
    return
  end
  if not Hud.shopUnlocked(Run) then
    Run:notify("Tienda: alcanza el nivel 15 y el piso 10", { 1.00, 0.55, 0.40 })
    return
  end
  Run.overlay = "shop"
  Run.shopTab = "buy"
  Run:clearInput()
end

function Run:clearInput()
  if Run.joystick then
    Run.joystick:cancel()
  end
  if Run.buttons then
    Run.buttons:clear()
  end
  if Run.aim then
    Run.aim:cancel()
  end
  Camera.cancelDrag()
end

function Run:cleanup()
  local n = 0
  for i = 1, #Run.enemies do
    local enemy = Run.enemies[i]
    if not enemy.dead then
      n = n + 1
      Run.enemies[n] = enemy
    end
  end
  for i = n + 1, #Run.enemies do
    Run.enemies[i] = nil
  end

  n = 0
  for i = 1, #Run.projectiles do
    local projectile = Run.projectiles[i]
    if not projectile.dead then
      n = n + 1
      Run.projectiles[n] = projectile
    end
  end
  for i = n + 1, #Run.projectiles do
    Run.projectiles[i] = nil
  end

  n = 0
  for i = 1, #Run.itemDrops do
    local item = Run.itemDrops[i]
    if not item.dead then
      n = n + 1
      Run.itemDrops[n] = item
    end
  end
  for i = n + 1, #Run.itemDrops do
    Run.itemDrops[i] = nil
  end

  n = 0
  for i = 1, #Run.hazards do
    local hazard = Run.hazards[i]
    if not hazard.dead then
      n = n + 1
      Run.hazards[n] = hazard
    end
  end
  for i = n + 1, #Run.hazards do
    Run.hazards[i] = nil
  end

  n = 0
  for i = 1, #Run.pets do
    local pet = Run.pets[i]
    if not pet.dead then
      n = n + 1
      Run.pets[n] = pet
    end
  end
  for i = n + 1, #Run.pets do
    Run.pets[i] = nil
  end

  if Run.boss and Run.boss.dead then
    Run.boss = nil
  end

  Run.enemyCount = #Run.enemies
end

function Run:checkLevel(dt)
  if Run.over then return end

  if Run.exitOpen then
    local d2 = Util.dist2(
      Run.player.x,
      Run.player.y,
      Run.exitX,
      Run.exitY
    )
    if d2 < Data.player.exitRadius * Data.player.exitRadius then
      Run:nextLevel()
    end
    return
  end

  if Run.enemyCount == 0 then
    Run.exitTimer = Run.exitTimer + dt
    if Run.exitTimer > Data.player.exitDelay then
      Run.exitOpen = true
      FX.add(
        "¡Salida abierta!",
        Run.exitX,
        Run.exitY - 26,
        { 0.40, 1.00, 0.60 }
      )
    end
  else
    Run.exitTimer = 0
  end
end

function Run:nextLevel()
  local reached = Run.depth + 1
  Save.recordLevel(reached)
  for _, dungeon in ipairs(Data.dungeons) do
    if reached >= dungeon.unlockLevel then
      Save.unlock(dungeon.id)
    end
  end
  Save.save()

  Run.depth = reached
  Run.hp = math.min(
    Run.stats.maxHp,
    Run.hp + math.floor(Run.stats.maxHp * Data.player.nextLevelHealPercent)
  )
  local unlockMessages = Run:commitUnlockNotices()
  Run.overlay = nil
  Run:enterLevel()
  FX.add(
    "Piso " .. Run.depth,
    Run.player.x,
    Run.player.y - 26,
    { 0.50, 1.00, 0.70 }
  )
  for index, message in ipairs(unlockMessages) do
    FX.add(
      message,
      Run.player.x,
      Run.player.y - 44 - index * 16,
      { 1.00, 0.86, 0.35 }
    )
  end
end

function Run:gameOver(reason)
  if Run.over then return end
  Run.over = true
  Run.paused = false
  Run.overlay = nil

  Save.recordLevel(Run.depth)
  Save.save()

  local character = Data.characters[Run.characterId]
  local ability = Data.abilities[Run.abilitySlot1]
  Run.gameOverInfo = {
    level = Run.depth,
    playerLevel = Run.playerLevel,
    kills = Run.kills,
    coins = Save.data.coins,
    dungeon = Run.def.name,
    dungeonId = Run.def.id,
    character = character.name,
    characterId = Run.characterId,
    ability = ability and ability.name or "Sin habilidad",
    abilityId = Run.abilitySlot1,
    reason = reason or "death",
    timeLeft = Run.timeLeft,
    snapshot = Run.floorSnapshot,
  }

  State.switch("gameover", Run.gameOverInfo)
end

function Run.update(dt)
  if Run.over then return end

  if Run.paused then
    return
  end

  Run:updateMana(dt)
  Run.abilityLockTimer = math.max(0, (Run.abilityLockTimer or 0) - dt)
  Run.inventoryFullTimer = math.max(0, (Run.inventoryFullTimer or 0) - dt)
  Run.timeLeft = math.max(0, (Run.timeLeft or Data.floor.timeLimit) - dt)
  if Run.timeLeft <= 0 then
    Run:gameOver("timeout")
    return
  end

  Rhythm.update(dt)
  Abilities.update(Run, dt)
  Run.turboTimer = math.max(0, Run.turboTimer - dt)

  if Run.shadow then
    Run.shadow:update(dt, Run)
    if Run.shadow.dead then
      Run.shadow = nil
    end
  end

  Input.pollKeyboard()
  local dx, dy = Input.consumeMove()
  local joystick = Run.joystick
  if joystick and joystick.active then
    dx = joystick.dx
    dy = joystick.dy
  end

  Run.player:update(dt, dx, dy, Run)
  Camera.follow(Run.player.x, Run.player.y)
  Camera.update(dt)
  Run.player.invuln = math.max(0, Run.player.invuln - dt)
  Run.player.shieldTimer = math.max(0, Run.player.shieldTimer - dt)

  for i = 1, 4 do
    if Input.consumeAbility(i) then
      Run:useAbility(i)
    end
  end

  for _, enemy in ipairs(Run.enemies) do
    if not enemy.dead then
      enemy:update(dt, Run)
    end
  end

  for _, projectile in ipairs(Run.projectiles) do
    if not projectile.dead then
      projectile:update(dt, Run)
    end
  end

  Run:updateFeatures(dt)
  for _, hazard in ipairs(Run.hazards) do
    if not hazard.dead then
      hazard:update(dt, Run)
    end
  end
  Run:updateItemDrops(dt)
  Run:updatePets(dt)
  Run:updateTornado(dt)
  Run:cleanup()
  FX.update(dt)
  Run:checkLevel(dt)

  if Run.over and State.name == "run" then
    State.switch("gameover", Run.gameOverInfo)
  end
end

function Run.draw()
  -- El exterior de la mazmorra se muestra siempre como oscuridad.
  love.graphics.setColor(0.02, 0.025, 0.035)
  love.graphics.rectangle("fill", 0, 0, 960, 540)

  Camera.push()
  Run.dungeon:draw(Camera)
  Run.dungeon:drawExit(Run.exitX, Run.exitY, Run.exitOpen)
  for _, valve in ipairs(Run.valves) do
    valve:draw()
  end
  for _, chest in ipairs(Run.chests) do
    chest:draw()
  end
  for _, item in ipairs(Run.itemDrops) do
    item:draw()
  end
  for _, hazard in ipairs(Run.hazards) do
    hazard:draw()
  end
  Abilities.drawAim(Run)

  if Run.shadow then
    Run.shadow:draw()
  end

  for _, enemy in ipairs(Run.enemies) do
    enemy:draw()
  end
  for _, pet in ipairs(Run.pets) do
    pet:draw()
  end
  for _, projectile in ipairs(Run.projectiles) do
    projectile:draw()
  end

  Run:drawTornado()
  Run.player:draw(Run)
  FX.drawWorld()
  Camera.pop()

  Hud.draw(Run)

  if Run.touchUI then
    Run.buttons:draw(Run)
    Run.joystick:draw()
  end

  -- Los textos flotantes viven en coordenadas del mundo, pero van sobre el HUD.
  Camera.push()
  FX.drawToasts()
  Camera.pop()

  if Run.overlay == "backpack" then
    Backpack.draw(Run)
  elseif Run.overlay == "shop" then
    Shop.draw(Run)
  end

  if Run.paused then
    Hud.drawPause(Run)
  end
end

function Run.drawDebug()
  Hud.drawDebug(Run)
end

function Run.keypressed(key, isrepeat)
  if key == "escape" and Run.overlay then
    Run.overlay = nil
    return
  end

  if key == "p" then
    Run.paused = not Run.paused
    if Run.paused then
      Run.overlay = nil
      Run:clearInput()
    end
    return
  end

  if key == "m" and not isrepeat then
    Rhythm.toggleMute()
    return
  end

  if isrepeat then return end

  if key == "b" then
    Run:toggleBackpack()
    return
  end

  if key == "v" then
    Run:openShop()
    return
  end

  if Run.paused then
    if key == "space" or key == "return" then
      Run.paused = false
    end
    return
  end

  if Run.overlay == "backpack" then
    local number = tonumber(key)
    if number and number >= 1 and number <= Data.inventory.maxSlots then
      Run.selectedInventory = number
      return
    end
    if key == "q" then
      Run:equipInventoryAbility(Run.selectedInventory, 1)
      return
    elseif key == "w" then
      Run:equipInventoryAbility(Run.selectedInventory, 2)
      return
    elseif key == "x" then
      Run:removeInventoryAt(Run.selectedInventory)
      return
    end
    return
  elseif Run.overlay then
    return
  end

  if key == "r" then
    Input.triggerAbility(1)
  elseif key == "f" then
    Input.triggerAbility(2)
  elseif key == "e" then
    Input.triggerAbility(3)
  elseif key == "t" then
    Input.triggerAbility(4)
  end
end

function Run:pressedAt(pointerId, x, y)
  if x < 0 or x > 960 or y < 0 or y > 540 then
    return
  end

  if Hud.hitPause(x, y) then
    Run.paused = not Run.paused
    if Run.paused then
      Run.overlay = nil
      Run:clearInput()
    end
    return
  end

  if Hud.hitBackpack(x, y) then
    Run:toggleBackpack()
    return
  end

  if Hud.hitShop(x, y) then
    Run:openShop()
    return
  end

  if Run.paused then
    Run.paused = false
    return
  end

  if Run.overlay == "backpack" then
    Backpack.pressed(Run, x, y)
    return
  elseif Run.overlay == "shop" then
    Shop.pressed(Run, x, y)
    return
  elseif Run.overlay then
    return
  end

  if Camera.beginDrag(pointerId, x, y) then
    return
  end

  if Run.joystick:press(pointerId, x, y) then
    return
  end

  if Run.touchUI then
    local button = Run.buttons:press(pointerId, x, y)
    if button then
      local abilityId = Run:abilityIdForSlot(button.slot)
      if button.slot == 1 or button.slot == 2 then
        if abilityId and not Run.aim.active then
          Run.aim:begin(pointerId, button.slot, abilityId, x, y)
        end
      else
        Input.triggerAbility(button.slot)
      end
      return
    end
  end
end

function Run:movedAt(pointerId, x, y)
  if Run.overlay then return end
  if Camera.moveDrag(pointerId, x, y) then return end
  if Run.aim:move(pointerId, x, y) then return end
  Run.joystick:move(pointerId, x, y)
end

function Run:releasedAt(pointerId, x, y)
  if Run.overlay then return end
  Camera.endDrag(pointerId)

  if Run.aim.active and Run.aim.pointerId == pointerId then
    Run.aim:move(pointerId, x, y)
    local state = Run.aim:release(pointerId)
    if state then
      Run:useAbility(state.slot, state)
    end
  end

  Run.joystick:release(pointerId)
  Run.buttons:release(pointerId)
end

function Run.mousepressed(x, y, button)
  if button ~= 1 then return end
  Run:pressedAt("mouse", x, y)
end

function Run.mousemoved(x, y)
  Run:movedAt("mouse", x, y)
end

function Run.mousereleased(x, y, button)
  if button ~= 1 then return end
  Run:releasedAt("mouse", x, y)
end

function Run.touchpressed(id, x, y)
  Run:pressedAt(id, x, y)
end

function Run.touchmoved(id, x, y)
  Run:movedAt(id, x, y)
end

function Run.touchreleased(id, x, y)
  Run:releasedAt(id, x, y)
end

function Run.focus(focused)
  if not focused and not Run.over then
    Run.paused = true
    Run.overlay = nil
    Run:clearInput()
  end
end

return Run
