-- abilities.lua: lanzamiento, apuntado y efectos de las habilidades.
local Data = require("src.run.data")
local Util = require("src.utils.util")
local Camera = require("src.utils.camera")
local Rhythm = require("src.run.rhythm")
local FX = require("src.run.fx")
local Shadow = require("src.run.shadow")

local Abilities = {}

local function shake(run, amount, duration)
  if run.shake then
    run:shake(amount, duration)
  end
end

local function dispatch(run, slot)
  if run.abilityIdForSlot then
    return run:abilityIdForSlot(slot)
  end
  if slot == 2 then return run.abilitySlot2 end
  if slot == 3 then return run.abilitySlot3 end
  return run.abilitySlot1
end

function Abilities.range(run, id)
  local def = Data.abilities[id]
  if not def then return nil end

  if id == "resonance" then
    local reach = def.throwRangeBase
      + (run.playerLevel - 1) * def.throwRangePerLevel
    return math.min(reach, def.throwRangeMax)
  end
  return def.range
end

-- Resuelve el punto objetivo en coordenadas del mundo.
function Abilities.aimTarget(run, id, aim)
  local player = run.player
  local range = Abilities.range(run, id)
  local targetX, targetY

  if aim and aim.dragging then
    targetX, targetY = Camera.toWorld(aim.x, aim.y)
  elseif id == "resonance" then
    return player.x, player.y, Util.atan2(player.facingY, player.facingX)
  else
    local target = run:nearestEnemy(Data.player.attackRange, true)
    if target then
      targetX = target.x
      targetY = target.y
    else
      local distance = (range or 160) * 0.7
      targetX = player.x + player.facingX * distance
      targetY = player.y + player.facingY * distance
    end
  end

  if range then
    local dx = targetX - player.x
    local dy = targetY - player.y
    local distance = math.sqrt(dx * dx + dy * dy)
    if distance > range and distance > 0.001 then
      local scale = range / distance
      targetX = player.x + dx * scale
      targetY = player.y + dy * scale
    end
  end

  local angle = Util.atan2(targetY - player.y, targetX - player.x)
  return targetX, targetY, angle
end

local function castResonance(run, def, aim, perfect)
  local player = run.player
  local centerX, centerY = Abilities.aimTarget(run, "resonance", aim)
  local multiplier = perfect and Data.rhythm.perfectMultiplier or 1
  local damage = run.stats.damage * def.damageMultiplier * multiplier
  local radius2 = def.radius * def.radius
  local characterId = run.characterId
  local amount = def.displacement

  for _, enemy in ipairs(run.enemies) do
    if not enemy.dead then
      local dx = enemy.x - centerX
      local dy = enemy.y - centerY
      local d2 = dx * dx + dy * dy
      if d2 <= radius2 then
        enemy:takeDamage(damage, run, "ability")

        if not enemy.dead and (characterId == "mar" or characterId == "amileth") then
          local distance = math.sqrt(d2)
          local nx, ny = player.facingX, player.facingY
          if distance > 0.001 then
            nx = dx / distance
            ny = dy / distance
          end

          if characterId == "mar" then
            -- Mar empuja fuera del radio, no solo una distancia fija.
            local outside = def.radius - distance + enemy.radius + 8
            local push = math.max(amount, outside)
            enemy.x, enemy.y = run.dungeon:moveCircle(
              enemy.x,
              enemy.y,
              nx * push,
              ny * push,
              enemy.radius
            )
          else
            -- Amileth atrae sin pasarse del centro.
            local pull = math.min(distance, amount)
            enemy.x, enemy.y = run.dungeon:moveCircle(
              enemy.x,
              enemy.y,
              -nx * pull,
              -ny * pull,
              enemy.radius
            )
          end
        end
      end
    end
  end

  if run.triggerValvesInRadius then
    run:triggerValvesInRadius(centerX, centerY, def.radius)
  end
  if run.damageWallsInRadius then
    run:damageWallsInRadius(
      centerX,
      centerY,
      def.radius,
      Data.destructible.resonanceDamage
    )
  end

  local color = def.color
  if perfect then
    color = { 1.00, 0.85, 0.35 }
    FX.add("¡Resonancia x2!", centerX, centerY - 26, color)
    FX.burst(centerX, centerY, 24, color)
  else
    FX.burst(centerX, centerY, 14, color)
  end
  FX.ring(centerX, centerY, def.radius, color)
  shake(run, 3, 0.18)
  return true
end

local function castShield(run, def)
  -- Con Tambor se puede refrescar la duración; no se repite la curación.
  local refreshing = run.player.shieldTimer > 0
  run.player.shieldTimer = def.duration
  if not refreshing then
    local heal = math.floor(run.stats.maxHp * def.healPercent)
    run.hp = math.min(run.stats.maxHp, run.hp + heal)
    FX.add("+" .. heal .. " vida", run.player.x, run.player.y - 26, { 0.40, 1.00, 0.50 })
  end
  FX.ring(run.player.x, run.player.y, 46, def.color)
  FX.burst(run.player.x, run.player.y, 12, def.color)
  return true
end

local function castTurbo(run, def)
  run.turboTimer = def.duration
  FX.add(
    "Turbo " .. def.duration .. "s",
    run.player.x,
    run.player.y - 26,
    def.color
  )
  FX.ring(run.player.x, run.player.y, 56, def.color)
  return true
end

local function castLightArrow(run, def, aim)
  local player = run.player
  local _, _, angle = Abilities.aimTarget(run, "light_arrow", aim)
  local dirX, dirY = math.cos(angle), math.sin(angle)
  local distance, hit, hitTx, hitTy = run.dungeon:raycast(
    player.x,
    player.y,
    dirX,
    dirY,
    def.range
  )
  local endX = player.x + dirX * distance
  local endY = player.y + dirY * distance
  local damage = run.stats.damage * def.damageMultiplier

  if run.triggerValvesOnSegment then
    run:triggerValvesOnSegment(
      player.x,
      player.y,
      endX,
      endY,
      def.width
    )
  end
  if hit and hitTx and run.damageWallAt then
    run:damageWallAt(
      hitTx,
      hitTy,
      Data.destructible.lightArrowDamage
    )
  end

  for _, enemy in ipairs(run.enemies) do
    if not enemy.dead then
      local forward = (enemy.x - player.x) * dirX + (enemy.y - player.y) * dirY
      if forward >= 0 and forward <= distance then
        local d2 = Util.pointSegmentDist2(
          enemy.x,
          enemy.y,
          player.x,
          player.y,
          endX,
          endY
        )
        local reach = def.width + enemy.radius
        if d2 <= reach * reach then
          enemy:takeDamage(damage, run, "ability")
        end
      end
    end
  end

  FX.line(player.x, player.y, endX, endY, def.color, 0.28, 10)
  FX.line(player.x, player.y, endX, endY, { 1, 1, 1 }, 0.16, 3)
  FX.ring(endX, endY, 24, def.color)
  shake(run, 2, 0.12)
  return true
end

local function castShadowSwap(run, def, aim)
  local player = run.player
  local targetX, targetY, angle = Abilities.aimTarget(run, "shadow_swap", aim)
  local landingX, landingY = run.dungeon:nearestWalkable(
    targetX,
    targetY,
    player.radius,
    run.dungeon.tile * 2
  )
  if not landingX then return false end

  local oldX, oldY = player.x, player.y
  run:spawnShadow(oldX, oldY)
  player.x = landingX
  player.y = landingY
  player.invuln = math.max(player.invuln, 0.25)

  FX.ring(oldX, oldY, 28, def.color)
  FX.ring(landingX, landingY, 34, def.color)
  FX.burst(oldX, oldY, 12, def.color)
  shake(run, 3, 0.16)
  if run.triggerValvesInRadius then
    run:triggerValvesInRadius(oldX, oldY, def.explosionRadius)
  end

  if run.characterId == "mar" then
    run:marDash(angle, true)
    return true, { skipPassive = true }
  end

  return true
end

local casts = {
  resonance = castResonance,
  shield = castShield,
  turbo = castTurbo,
  light_arrow = castLightArrow,
  shadow_swap = castShadowSwap,
}

function Abilities.cast(run, slot, aim)
  local id = dispatch(run, slot)
  local def = Data.abilities[id]
  if not def then return false end
  if (run.abilityLockTimer or 0) > 0 then
    if run.onAbilityLocked then run:onAbilityLocked() end
    return false
  end
  local cooldownKey = run.cooldownKeyForSlot
    and run:cooldownKeyForSlot(slot)
    or id
  if (run.cooldowns[cooldownKey] or 0) > 0 then return false end

  local perfect = Rhythm.inWindow()
  local drumStacks = 0
  if run.passiveStacks then
    drumStacks = run.passiveStacks.drum or 0
  end
  local drum = drumStacks > 0
  local drumDef = Data.items.drum

  local cost = def.manaCost or 0
  if drum and perfect then
    cost = cost * drumDef.costMultiplier
  end
  if run.mana and run.mana < cost then
    if run.onManaFail then run:onManaFail(def) end
    return false
  end

  local cast = casts[id]
  if not cast then return false end

  local ok, meta = cast(run, def, aim, perfect)
  if ok == false then return false end
  Rhythm.registerHit(perfect)

  if run.mana then
    run.mana = math.max(0, run.mana - cost)
    run.manaIdleTimer = 0
  end

  if drum and perfect then
    run.cooldowns[cooldownKey] = def.cooldown * drumDef.ownCooldownMultiplier
    for otherKey, cooldown in pairs(run.cooldowns) do
      if otherKey ~= cooldownKey and cooldown > 0 then
        run.cooldowns[otherKey] = math.max(
          0,
          cooldown - drumDef.otherCooldownReduction
        )
      end
    end
  else
    run.cooldowns[cooldownKey] = def.cooldown
  end

  if perfect and run.passiveStacks and (run.passiveStacks.flute or 0) > 0 then
    if not run.fluteReady then
      run.fluteReady = true
      FX.add(
        "Flauta lista",
        run.player.x,
        run.player.y - 30,
        Data.items.flute.color
      )
    end
  end

  run:onAbilityActivated(id, aim, meta)
  return true
end

function Abilities.update(run, dt)
  for id, cooldown in pairs(run.cooldowns) do
    if cooldown > 0 then
      run.cooldowns[id] = math.max(0, cooldown - dt)
    end
  end
end

function Abilities.drawAim(run)
  local aim = run.aim
  if not aim or not aim.active then return end

  local id = aim.abilityId
  local def = Data.abilities[id]
  if not def then return end

  local player = run.player
  local targetX, targetY = Abilities.aimTarget(run, id, aim)
  local color = def.color

  love.graphics.setColor(color[1], color[2], color[3], 0.55)
  love.graphics.setLineWidth(2)

  if id == "light_arrow" then
    local angle = Util.atan2(targetY - player.y, targetX - player.x)
    local distance = run.dungeon:raycast(
      player.x,
      player.y,
      math.cos(angle),
      math.sin(angle),
      def.range
    )
    love.graphics.line(
      player.x,
      player.y,
      player.x + math.cos(angle) * distance,
      player.y + math.sin(angle) * distance
    )
  else
    love.graphics.line(player.x, player.y, targetX, targetY)
    if id == "resonance" then
      love.graphics.circle("line", targetX, targetY, def.radius)
    else
      love.graphics.circle("line", targetX, targetY, player.radius + 8)
    end
  end

  love.graphics.setLineWidth(1)
end

return Abilities
