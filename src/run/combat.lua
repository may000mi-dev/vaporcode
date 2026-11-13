-- combat.lua: daño directo, reacciones de pasivas y muerte de enemigos.
-- Las funciones reciben run como primer argumento y run.lua las monta
-- como métodos para conservar la API run:metodo(...).
local Data = require("src.run.data")
local Save = require("src.run.save")
local FX = require("src.run.fx")
local Util = require("src.utils.util")
local Targeting = require("src.run.targeting")

local Combat = {}

function Combat.damagePlayerInRadius(run, x, y, radius, damage)
  local reach = radius + run.player.radius
  if Util.dist2(x, y, run.player.x, run.player.y) <= reach * reach then
    return run.player:takeDamage(damage, run)
  end
  return false
end

function Combat.healEnemiesAround(run, x, y, radius, percent)
  local reach2 = radius * radius
  local healed = 0
  for _, enemy in ipairs(run.enemies) do
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

function Combat.explodeVolatile(run, enemy)
  local radius = Data.elite.volatileRadius
  local damage = math.max(
    enemy.damage * Data.elite.volatileDamageScale,
    enemy.maxHp * 0.35
  )
  if Util.dist2(enemy.x, enemy.y, run.player.x, run.player.y)
    <= (radius + run.player.radius) ^ 2
  then
    run.player:takeDamage(damage, run)
  end
  for _, other in ipairs(run.enemies) do
    if other ~= enemy and not other.dead then
      local reach = radius + other.radius
      if Util.dist2(enemy.x, enemy.y, other.x, other.y) <= reach * reach then
        other:takeDamage(damage, run, "elite")
      end
    end
  end
  FX.ring(enemy.x, enemy.y, radius, { 1.00, 0.55, 0.24 })
  FX.burst(enemy.x, enemy.y, 22, { 1.00, 0.55, 0.24 })
  if run.shake then run:shake(5, 0.26) end
end

function Combat.nearestEnemy(run, maxDistance, requireLineOfSight)
  return Targeting.nearestVisible(
    run.player.x,
    run.player.y,
    run.enemies,
    maxDistance,
    run.dungeon,
    requireLineOfSight
  )
end

function Combat.markEnemy(run, enemy)
  if enemy.dead then return false end

  if enemy.markTimer > 0 then
    enemy:applyMark(Data.mark.duration)
    return true
  end

  local marked = 0
  for _, other in ipairs(run.enemies) do
    if not other.dead and other.markTimer > 0 then
      marked = marked + 1
    end
  end
  if marked >= Data.mark.maxMarks then return false end

  enemy:applyMark(Data.mark.duration)
  return true
end

function Combat.meleeSpin(run, player, range, damage)
  player.spinTimer = 0.25
  local range2 = range * range

  for _, enemy in ipairs(run.enemies) do
    if not enemy.dead then
      if Util.dist2(player.x, player.y, enemy.x, enemy.y) <= range2 then
        if run.dungeon:lineOfSight(player.x, player.y, enemy.x, enemy.y) then
          enemy:takeDamage(damage, run, "basic")
        end
      end
    end
  end

  FX.ring(player.x, player.y, range, Data.characters.mar.color)
end

function Combat.onEnemyKilled(run, enemy)
  run.kills = run.kills + 1

  if not enemy.def.noDrop then
    local coins = Data.economy.coinsBase
      + math.floor(enemy.xp / Data.economy.xpPerCoin)
    run:addCoins(coins)
    run:addXp(enemy.xp)
  end
  local count = enemy.def.boss and 36 or 14
  FX.burst(enemy.x, enemy.y, math.floor(count * 0.35), enemy.def.color)
  if run.player then
    FX.collect(
      enemy.x,
      enemy.y,
      count,
      enemy.def.color,
      run.player.x,
      run.player.y
    )
  end
  if not enemy.def.noDrop then
    FX.add("+" .. enemy.xp .. " XP", enemy.x, enemy.y - 14, { 0.45, 0.90, 1.00 })
    run:maybeDropItem(enemy)
  end
  if enemy.elite == "volatile" then
    run:explodeVolatile(enemy)
  end
  if enemy.def.boss then
    run:shake(8, 0.40)
    FX.add(
      "¡Jefe derrotado!",
      enemy.x,
      enemy.y - 34,
      { 1.00, 0.80, 0.30 }
    )
  end
end

function Combat.onEnemyDamaged(run, enemy, amount, source)
  if amount <= 0 then return end

  local poisonStacks = (run.passiveStacks and run.passiveStacks.poison) or 0
  if poisonStacks > 0 and source ~= "poison" and not enemy.dead then
    local def = Data.items.poison
    local dps = def.dpsBase + (poisonStacks - 1) * def.dpsPerStack
    enemy:applyPoison(dps, def.duration)
  end

  if source == "basic" then
    run:onBasicDamage(enemy, amount)
  end
end

function Combat.onBasicDamage(run, enemy, amount)
  local vampire = (run.passiveStacks and run.passiveStacks.vampire) or 0
  local fairy = (run.passiveStacks and run.passiveStacks.fairy) or 0
  local synergy = vampire > 0 and fairy > 0

  if vampire > 0 then
    local def = Data.items.vampire
    local rate = synergy and def.healSynergy or def.healPerStack
    local heal = amount * math.min(rate * vampire, def.healCap)
    run.hp = math.min(run.stats.maxHp, run.hp + heal)
  end

  if fairy > 0 then
    local def = Data.items.fairy
    local rate = synergy and def.healSynergy or def.healPerStack
    local restore = amount * math.min(rate * fairy, def.healCap)
    run.mana = math.min(run.manaMax, (run.mana or 0) + restore)
  end

  local gunpowder = (run.passiveStacks and run.passiveStacks.gunpowder) or 0
  if gunpowder > 0 and love.math.random() < Data.items.gunpowder.chance then
    run:triggerGunpowder(enemy, gunpowder)
  end

  if run.fluteReady then
    run.fluteReady = false
    run:spawnTornado(enemy.x, enemy.y)
  end
end

function Combat.triggerGunpowder(run, enemy, stacks)
  local def = Data.items.gunpowder
  local damage = run.stats.damage
    * (def.damageBase + (stacks - 1) * def.damagePerStack)
  local radius = def.radiusBase + (stacks - 1) * def.radiusPerStack
  local radius2 = radius * radius

  for _, other in ipairs(run.enemies) do
    if not other.dead then
      local dx = other.x - enemy.x
      local dy = other.y - enemy.y
      local d2 = dx * dx + dy * dy
      if d2 <= radius2 then
        other:takeDamage(damage, run, "gunpowder")
        if not other.dead and other.applyStun then
          other:applyStun(def.stun)
        end
        if not other.dead then
          local distance = math.sqrt(d2)
          local nx, ny = 1, 0
          if distance > 0.001 then
            nx, ny = dx / distance, dy / distance
          end
          other.x, other.y = run.dungeon:moveCircle(
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
  run:shake(4, 0.20)
end

return Combat
