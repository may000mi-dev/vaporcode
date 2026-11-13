-- boss.lua: mecánicas de los jefes por mazmorra.
local Data = require("src.run.data")
local Util = require("src.utils.util")
local FX = require("src.run.fx")

local Boss = {}

function Boss.init(enemy)
  local def = enemy.def
  enemy.bossPhase = 1
  enemy.invulnTimer = 0
  enemy.summonTimer = def.firstSummonDelay or 2
  enemy.zoneTimer = def.zoneInterval or 2.4
  enemy.coneTimer = def.coneInterval or 5.0
  enemy.auraTimer = 0
  enemy.lostTimer = 0
  enemy.stuckTimer = 0
end

local function moveToward(enemy, dt, run, dx, dy, distance, scale)
  if distance <= 0.001 then return end
  local speed = enemy:movementSpeed() * (scale or 1)
  enemy.x, enemy.y = run.dungeon:moveCircle(
    enemy.x,
    enemy.y,
    (dx / distance) * speed * dt,
    (dy / distance) * speed * dt,
    enemy.radius
  )
end

local function countKind(run, kind)
  local count = 0
  for _, enemy in ipairs(run.enemies) do
    if not enemy.dead and enemy.kind == kind then
      count = count + 1
    end
  end
  return count
end

local function summonAround(enemy, run, kind)
  local def = Data.enemyTypes[kind]
  if not def then return end
  if countKind(run, kind) >= (enemy.def.summonCap or 4) then return end
  local angle = love.math.random() * math.pi * 2
  local distance = enemy.radius + def.radius + 12
  local x, y = run.dungeon:moveCircle(
    enemy.x,
    enemy.y,
    math.cos(angle) * distance,
    math.sin(angle) * distance,
    def.radius
  )
  run:createEnemy(kind, x, y, { noElite = true })
  FX.ring(x, y, def.radius + 6, def.color)
end

local function startPatriarchPhase(enemy, run)
  enemy.invulnTimer = enemy.def.phaseDuration
  local count = enemy.def.beamCount
  for i = 0, count - 1 do
    run:spawnHazard("beam", enemy.x, enemy.y, {
      angle = (math.pi * 2 / count) * i + enemy.bossPhase * 0.25,
      rotation = enemy.def.beamRotation,
      length = enemy.def.beamLength,
      width = enemy.def.beamWidth,
      damage = enemy.def.beamDamage,
      life = enemy.def.phaseDuration,
      interval = Data.hazards.beamTick,
      color = { 0.88, 0.78, 0.48 },
    })
  end
  FX.add("¡Jaula de cadenas!", enemy.x, enemy.y - 42, { 1.00, 0.82, 0.36 })
  if run.shake then run:shake(7, 0.35) end
end

local function updatePatriarch(enemy, dt, run, ctx)
  enemy.invulnTimer = math.max(0, enemy.invulnTimer - dt)
  enemy.summonTimer = enemy.summonTimer - dt
  if enemy.summonTimer <= 0 then
    enemy.summonTimer = enemy.def.summonInterval
    summonAround(enemy, run, enemy.def.summonKind)
  end

  if enemy.invulnTimer <= 0 then
    if ctx.canSee then
      moveToward(enemy, dt, run, ctx.dx, ctx.dy, ctx.distance, 1)
    else
      enemy:updateSearch(dt, run)
    end
  end

  local ratio = enemy.maxHp > 0 and enemy.hp / enemy.maxHp or 0
  local threshold = enemy.def.phaseThresholds[enemy.bossPhase]
  if threshold and ratio <= threshold and enemy.invulnTimer <= 0 then
    enemy.bossPhase = enemy.bossPhase + 1
    startPatriarchPhase(enemy, run)
  end
end

local function updateForge(enemy, dt, run)
  enemy.zoneTimer = enemy.zoneTimer - dt
  if enemy.zoneTimer <= 0 then
    enemy.zoneTimer = enemy.def.zoneInterval
    local player = run.player
    for i = 1, enemy.def.zoneCount do
      local angle = (math.pi * 2 / enemy.def.zoneCount) * (i - 1)
        + love.math.random() * 0.5
      local offset = i == 1 and 0 or enemy.def.zoneRadius * 1.15
      local x = player.x + math.cos(angle) * offset
      local y = player.y + math.sin(angle) * offset
      run:spawnHazard("zone", x, y, {
        radius = enemy.def.zoneRadius,
        delay = enemy.def.zoneDelay,
        life = enemy.def.zoneDuration,
        damage = enemy.def.zoneDamage,
        interval = 0.5,
        color = { 1.00, 0.24, 0.14 },
      })
    end
  end

  enemy.summonTimer = enemy.summonTimer - dt
  if enemy.summonTimer <= 0 then
    enemy.summonTimer = enemy.def.summonInterval
    summonAround(enemy, run, enemy.def.summonKind)
  end
end

local function angleDifference(a, b)
  local d = (a - b + math.pi) % (math.pi * 2) - math.pi
  return math.abs(d)
end

local function findBlinkPoint(enemy, run, target)
  local def = enemy.def
  local minDistance = def.blinkMinDistance or 72
  local maxDistance = def.blinkMaxDistance or 132
  local start = love.math.random() * math.pi * 2

  for i = 0, 15 do
    local angle = start + i * (math.pi * 2 / 16)
    local distance = minDistance + (maxDistance - minDistance) * (i % 2)
    local x = target.x + math.cos(angle) * distance
    local y = target.y + math.sin(angle) * distance
    local blocked = run.dungeon.circleCollides
      and run.dungeon:circleCollides(x, y, enemy.radius)
    if not blocked and run.dungeon:lineOfSight(x, y, target.x, target.y) then
      return x, y
    end
  end
end

local function updateChrono(enemy, dt, run, ctx)
  local def = enemy.def
  enemy.coneTimer = math.max(0, enemy.coneTimer - dt)
  enemy.auraTimer = math.max(0, (enemy.auraTimer or 0) - dt)

  if enemy.auraTimer <= 0 then
    enemy.auraTimer = def.auraInterval or 0.7
    local reach = (def.auraRadius or 120) + run.player.radius
    if Util.dist2(enemy.x, enemy.y, run.player.x, run.player.y) <= reach * reach
      and run.dungeon:lineOfSight(enemy.x, enemy.y, run.player.x, run.player.y)
    then
      run.player:takeDamage(enemy.damage * (def.auraDamageScale or 0.12), run)
    end
  end

  local beforeX, beforeY = enemy.x, enemy.y
  if ctx.canSee then
    enemy.lostTimer = 0
    moveToward(enemy, dt, run, ctx.dx, ctx.dy, ctx.distance, 1)
  else
    enemy.lostTimer = (enemy.lostTimer or 0) + dt
    enemy:updateSearch(dt, run)
  end

  local target = ctx.target or run.player
  local step = enemy:movementSpeed() * dt
  local moved = Util.dist(beforeX, beforeY, enemy.x, enemy.y)
  local closeEnough = ctx.distance <= enemy.radius + target.radius + 12
  if not closeEnough and step > 0.001 and moved < step * 0.2 then
    enemy.stuckTimer = (enemy.stuckTimer or 0) + dt
  else
    enemy.stuckTimer = 0
  end

  local lostTooLong = not ctx.canSee
    and (enemy.lostTimer or 0) >= (def.blinkDelay or 1.1)
  local blockedTooLong = (enemy.stuckTimer or 0) >= (def.blinkStuckTime or 0.35)
  local canBlink = ctx.distance <= Data.enemyAI.sightRange
    and (ctx.canSee or enemy.lastSeenX ~= nil)
    and (lostTooLong or blockedTooLong)
  if canBlink then
    local blinkX, blinkY = findBlinkPoint(enemy, run, target)
    if blinkX then
      FX.ring(enemy.x, enemy.y, enemy.radius + 8, def.color)
      enemy.x, enemy.y = blinkX, blinkY
      FX.ring(enemy.x, enemy.y, enemy.radius + 10, def.color)
      enemy.lostTimer = 0
      enemy.stuckTimer = 0
    else
      enemy.lostTimer = (def.blinkDelay or 1.1) * 0.5
      enemy.stuckTimer = 0
    end
  end

  if enemy.coneTimer <= 0 then
    enemy.coneTimer = def.coneInterval
    if ctx.canSee and ctx.distance <= def.coneRange then
      local angle = Util.atan2(ctx.dy, ctx.dx)
      run:spawnHazard("cone", enemy.x, enemy.y, {
        angle = angle,
        halfAngle = def.coneHalfAngle,
        length = def.coneRange,
        life = 0.38,
        damage = 0,
      })
      local playerAngle = Util.atan2(
        run.player.y - enemy.y,
        run.player.x - enemy.x
      )
      if ctx.distance <= def.coneRange
        and angleDifference(playerAngle, angle) <= def.coneHalfAngle
      then
        run.player:freeze(def.coneLock)
        run.player:takeDamage(enemy.damage * def.coneDamageScale, run)
        FX.add("¡Tiempo congelado!", run.player.x, run.player.y - 28, { 0.55, 0.72, 1.00 })
      end
    end
  end
end

local function updateGuardian(enemy, dt, run, ctx)
  if ctx.canSee then
    moveToward(enemy, dt, run, ctx.dx, ctx.dy, ctx.distance, 1)
    enemy.bossTimer = enemy.bossTimer - dt
    if enemy.bossTimer <= 0 then
      enemy.bossTimer = Data.enemyAI.bossShootInterval
      for i = 0, Data.enemyAI.bossProjectileCount - 1 do
        run:spawnProjectile(
          enemy.x,
          enemy.y,
          enemy.phase + i * (math.pi * 2 / Data.enemyAI.bossProjectileCount),
          enemy.damage * Data.enemyAI.bossDamageScale,
          true
        )
      end
      if run.shake then run:shake(5, 0.30) end
    end
  else
    enemy:updateSearch(dt, run)
  end
end

local function startOrganPhase(enemy, run)
  enemy.invulnTimer = enemy.def.phaseDuration
  local count = enemy.def.beamCount
  for i = 0, count - 1 do
    run:spawnHazard("beam", enemy.x, enemy.y, {
      angle = (math.pi * 2 / count) * i + enemy.bossPhase * 0.35,
      rotation = enemy.def.beamRotation,
      length = enemy.def.beamLength,
      width = enemy.def.beamWidth,
      damage = enemy.def.beamDamage,
      life = enemy.def.phaseDuration,
      interval = Data.hazards.beamTick,
      color = { 0.78, 0.46, 1.00 },
    })
  end
  FX.add("¡Compás del fin!", enemy.x, enemy.y - 48, { 0.88, 0.62, 1.00 })
  if run.shake then run:shake(8, 0.40) end
end

local function updateOrgan(enemy, dt, run, ctx)
  enemy.invulnTimer = math.max(0, enemy.invulnTimer - dt)
  enemy.summonTimer = enemy.summonTimer - dt
  if enemy.summonTimer <= 0 then
    enemy.summonTimer = enemy.def.summonInterval
    summonAround(enemy, run, enemy.def.summonKind)
  end

  if enemy.invulnTimer <= 0 and ctx.canSee then
    if ctx.distance > (enemy.def.keepDistance or 0) then
      moveToward(enemy, dt, run, ctx.dx, ctx.dy, ctx.distance, 0.85)
    end
  elseif enemy.invulnTimer <= 0 then
    enemy:updateSearch(dt, run)
  end

  local ratio = enemy.maxHp > 0 and enemy.hp / enemy.maxHp or 0
  local threshold = enemy.def.phaseThresholds[enemy.bossPhase]
  if threshold and ratio <= threshold and enemy.invulnTimer <= 0 then
    enemy.bossPhase = enemy.bossPhase + 1
    startOrganPhase(enemy, run)
  end
end

function Boss.update(enemy, dt, run, ctx)
  local kind = enemy.def.bossKind or "guardian"
  if kind == "patriarch" then
    updatePatriarch(enemy, dt, run, ctx)
  elseif kind == "forge" then
    updateForge(enemy, dt, run)
  elseif kind == "chrono" then
    updateChrono(enemy, dt, run, ctx)
  elseif kind == "organ" then
    updateOrgan(enemy, dt, run, ctx)
  else
    updateGuardian(enemy, dt, run, ctx)
  end
end

function Boss.drawOverlay(enemy)
  if enemy.invulnTimer and enemy.invulnTimer > 0 then
    local t = love.timer.getTime()
    love.graphics.setColor(0.92, 0.84, 0.58, 0.85)
    love.graphics.setLineWidth(2)
    for i = 0, 5 do
      local a = t * 1.6 + i * (math.pi * 2 / 6)
      love.graphics.circle(
        "line",
        enemy.x + math.cos(a) * 7,
        enemy.y + math.sin(a) * 7,
        enemy.radius + 9
      )
    end
    love.graphics.setLineWidth(1)
  end

  if enemy.def.bossKind == "chrono" then
    local t = love.timer.getTime()
    local auraRadius = enemy.def.auraRadius or 120
    local pulse = 0.06 + 0.025 * math.sin(t * 4)
    love.graphics.setColor(0.42, 0.62, 1.00, pulse)
    love.graphics.circle("fill", enemy.x, enemy.y, auraRadius)
    love.graphics.setColor(0.62, 0.78, 1.00, 0.55)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", enemy.x, enemy.y, auraRadius)
    love.graphics.setColor(0.72, 0.86, 1.00, 0.75)
    love.graphics.circle("line", enemy.x, enemy.y, enemy.radius + 5)
    love.graphics.line(
      enemy.x,
      enemy.y,
      enemy.x + math.cos(t) * (enemy.radius + 4),
      enemy.y + math.sin(t) * (enemy.radius + 4)
    )
    love.graphics.setLineWidth(1)
  elseif enemy.def.bossKind == "forge" then
    love.graphics.setColor(1.00, 0.35, 0.16, 0.35)
    love.graphics.circle("fill", enemy.x, enemy.y, enemy.radius + 10)
  elseif enemy.def.bossKind == "organ" then
    local t = love.timer.getTime()
    love.graphics.setColor(0.62, 0.32, 0.95, 0.30)
    love.graphics.circle("fill", enemy.x, enemy.y, enemy.radius + 14)
    love.graphics.setColor(0.86, 0.62, 1.00, 0.80)
    love.graphics.circle("line", enemy.x, enemy.y, enemy.radius + 7)
    for i = 0, 3 do
      local a = t * 1.2 + i * (math.pi * 0.5)
      love.graphics.line(
        enemy.x + math.cos(a) * (enemy.radius + 5),
        enemy.y + math.sin(a) * (enemy.radius + 5),
        enemy.x + math.cos(a) * (enemy.radius + 16),
        enemy.y + math.sin(a) * (enemy.radius + 16)
      )
    end
  end
end

return Boss
