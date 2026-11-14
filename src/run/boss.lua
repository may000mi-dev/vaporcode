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
  if def.bossKind == "organ" then
    enemy.armTimer = def.armFirstDelay or 2.2
    enemy.armState = nil
    enemy.armWindupTimer = 0
    enemy.armPullTimer = 0
    enemy.armAttachedPlayer = nil
    enemy.healerTimer = def.healerFirstDelay or 5.0
  elseif def.bossKind == "chrono" then
    enemy.echoTimer = def.echoFirstDelay or 2.5
    enemy.rewindUsed = false
  end
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

local function spawnBrokenAutomata(run, origin)
  local cfg = Data.brokenAutomata
  local def = Data.enemyTypes.broken_automaton
  if not cfg or not def then return end

  local total = love.math.random(cfg.minCount, cfg.maxCount)
  local start = love.math.random() * math.pi * 2
  for i = 1, total do
    local angle = start + (i - 1) * (math.pi * 2 / total)
    local distance = (origin.radius or 0) + def.radius + 10
    local x, y = run.dungeon:moveCircle(
      origin.x,
      origin.y,
      math.cos(angle) * distance,
      math.sin(angle) * distance,
      def.radius
    )
    local automaton = run:createEnemy("broken_automaton", x, y, { noElite = true })
    if automaton then
      FX.ring(x, y, def.radius + 5, def.color)
    end
  end
  FX.add("¡Autómatas rotos!", origin.x, origin.y - 28, def.color)
end

local function maybeSpawnBrokenAutomata(enemy, run, origin)
  local cfg = Data.brokenAutomata
  if not cfg then return end
  local ratio = enemy.maxHp > 0 and enemy.hp / enemy.maxHp or 1
  if ratio >= cfg.hpThreshold then return end
  if love.math.random() >= cfg.chance then return end
  spawnBrokenAutomata(run, origin)
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
  local minion = run:createEnemy(kind, x, y, { noElite = true })
  FX.ring(x, y, def.radius + 6, def.color)
  if minion then
    maybeSpawnBrokenAutomata(enemy, run, minion)
  end
  return minion
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

local function chronoBlink(enemy, run, target)
  local blinkX, blinkY = findBlinkPoint(enemy, run, target)
  if not blinkX then return false end

  FX.ring(enemy.x, enemy.y, enemy.radius + 8, enemy.def.color)
  enemy.x, enemy.y = blinkX, blinkY
  FX.ring(enemy.x, enemy.y, enemy.radius + 10, enemy.def.color)
  enemy.lostTimer = 0
  enemy.stuckTimer = 0
  return true
end

local function spawnChronoEcho(enemy, run)
  local def = enemy.def
  local player = run.player
  run:spawnHazard("echo", player.x, player.y, {
    radius = def.echoRadius or 64,
    delay = def.echoDelay or 0.65,
    damage = enemy.damage * (def.echoDamageScale or 0.8),
    interval = 1,
    color = def.echoColor,
  })
  FX.ring(player.x, player.y, def.echoRadius or 64, def.echoColor)
end

local function startChronoPhase(enemy, run, ctx)
  local def = enemy.def
  enemy.invulnTimer = def.phaseDuration or 1.6
  enemy.coneTimer = 0.35
  spawnChronoEcho(enemy, run)
  chronoBlink(enemy, run, ctx.target or run.player)
  FX.add("¡Desfase temporal!", enemy.x, enemy.y - 42, def.color)
  if run.shake then run:shake(5, 0.25) end
end

local function startChronoRewind(enemy, run, ctx)
  local def = enemy.def
  enemy.rewindUsed = true
  enemy.invulnTimer = def.rewindInvuln or 1.0
  enemy.coneTimer = 0.6
  enemy.hp = math.min(enemy.maxHp, enemy.hp + enemy.maxHp * (def.rewindHeal or 0.10))
  chronoBlink(enemy, run, ctx.target or run.player)
  FX.add("¡Rebobinando!", enemy.x, enemy.y - 42, def.echoColor or def.color)
  if run.shake then run:shake(7, 0.35) end
end

local function updateChrono(enemy, dt, run, ctx)
  local def = enemy.def
  enemy.invulnTimer = math.max(0, (enemy.invulnTimer or 0) - dt)
  if enemy.invulnTimer > 0 then return end

  local ratio = enemy.maxHp > 0 and enemy.hp / enemy.maxHp or 0
  local threshold = def.phaseThresholds and def.phaseThresholds[enemy.bossPhase]
  if threshold and ratio <= threshold then
    enemy.bossPhase = enemy.bossPhase + 1
    startChronoPhase(enemy, run, ctx)
    return
  end

  if not enemy.rewindUsed and ratio <= (def.rewindThreshold or 0.50) then
    startChronoRewind(enemy, run, ctx)
    return
  end

  enemy.coneTimer = math.max(0, enemy.coneTimer - dt)
  enemy.auraTimer = math.max(0, (enemy.auraTimer or 0) - dt)
  enemy.echoTimer = math.max(0, (enemy.echoTimer or 0) - dt)

  if enemy.echoTimer <= 0 then
    enemy.echoTimer = def.echoInterval or 4.2
    spawnChronoEcho(enemy, run)
  end

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
    if not chronoBlink(enemy, run, target) then
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

local function nearestWalkablePoint(run, x, y, radius)
  if run.dungeon.nearestWalkable then
    local nx, ny = run.dungeon:nearestWalkable(
      x,
      y,
      radius,
      math.max(120, radius * 6)
    )
    if nx then return nx, ny end
  end
  return x, y
end

local function organSummonPool(enemy)
  if enemy.summonPool then return enemy.summonPool end

  local pool = {}
  for _, kind in ipairs(Data.bestiaryOrder) do
    local def = Data.enemyTypes[kind]
    if def and not def.boss then
      pool[#pool + 1] = kind
    end
  end
  enemy.summonPool = pool
  return pool
end

local function organSummonCount(run)
  local count = 0
  for _, enemy in ipairs(run.enemies) do
    if not enemy.dead and enemy.summonedByOrgan then
      count = count + 1
    end
  end
  return count
end

local function summonRandomAround(enemy, run)
  if organSummonCount(run) >= (enemy.def.summonTotalCap or 8) then return end

  local pool = organSummonPool(enemy)
  if #pool == 0 then return end

  local start = love.math.random(1, #pool)
  for offset = 0, #pool - 1 do
    local kind = pool[((start - 1 + offset) % #pool) + 1]
    if countKind(run, kind) < (enemy.def.summonCap or 2) then
      local minion = summonAround(enemy, run, kind)
      if minion then
        minion.summonedByOrgan = true
        return minion
      end
    end
  end
end

local function summonHealerAround(enemy, run)
  if countKind(run, "clerigo") >= (enemy.def.healerCap or 2) then return end
  local minion = summonAround(enemy, run, "clerigo")
  if minion then
    minion.summonedByOrgan = true
  end
end

local function updateOrganZones(enemy, dt, run)
  local def = enemy.def
  enemy.zoneTimer = (enemy.zoneTimer or def.zoneInterval) - dt
  if enemy.zoneTimer > 0 then return end

  -- Igual que la Forja, las zonas apuntan al jugador aunque no haya visión.
  local tx, ty = run.player.x, run.player.y

  enemy.zoneTimer = def.zoneInterval
  for i = 1, def.zoneCount do
    local angle = (math.pi * 2 / def.zoneCount) * (i - 1)
      + love.math.random() * 0.5
    local offset = i == 1 and 0 or def.zoneRadius * 1.15
    run:spawnHazard("zone", tx + math.cos(angle) * offset, ty + math.sin(angle) * offset, {
      radius = def.zoneRadius,
      delay = def.zoneDelay,
      life = def.zoneDuration,
      damage = def.zoneDamage,
      interval = 0.5,
      color = { 0.78, 0.46, 1.00 },
    })
  end
end

local function updateOrganArmState(enemy, dt, run)
  if enemy.armState == "windup" then
    local player = run.player
    -- El brazo persigue la posición actual: no usa lastSeen ni línea de visión.
    enemy.armAngle = Util.atan2(player.y - enemy.y, player.x - enemy.x)
    enemy.armWindupTimer = enemy.armWindupTimer - dt
    if enemy.armWindupTimer <= 0 then
      local def = enemy.def
      local distance = Util.dist(enemy.x, enemy.y, player.x, player.y)
      local angle = enemy.armAngle
      local close = def.armCloseDistance or (enemy.radius + player.radius + 18)
      local reach = (def.armRange or def.zoneRange or 380) + player.radius

      if distance <= reach then
        -- Si ya está dentro, el tirón lo retiene en el sitio unos instantes.
        local pullDistance = math.min(close, distance)
        local tx = enemy.x + math.cos(angle) * pullDistance
        local ty = enemy.y + math.sin(angle) * pullDistance
        tx, ty = nearestWalkablePoint(run, tx, ty, player.radius)
        player:startPull(tx, ty, def.armPullDuration or 0.40)
        enemy.armState = "pull"
        enemy.armPullTimer = def.armPullDuration or 0.40
        enemy.armAttachedPlayer = player
        FX.add("¡Enganchado!", player.x, player.y - 30, { 0.88, 0.62, 1.00 })
        FX.ring(player.x, player.y, player.radius + 8, { 0.88, 0.62, 1.00 })
        if run.shake then run:shake(4, 0.18) end
      else
        enemy.armState = nil
        enemy.armAttachedPlayer = nil
      end
      enemy.armTimer = def.armInterval or 4.8
    end
    return true
  end

  if enemy.armState == "pull" then
    enemy.armPullTimer = enemy.armPullTimer - dt
    if enemy.armPullTimer <= 0 then
      enemy.armState = nil
      enemy.armAttachedPlayer = nil
    end
    return true
  end
  return false
end

local function tryStartOrganArm(enemy, run)
  if enemy.armState or enemy.armTimer > 0 then return false end

  -- Siempre apunta al jugador actual, aunque esté oculto tras un muro.
  local player = run.player
  enemy.armState = "windup"
  enemy.armWindupTimer = enemy.def.armWindup or 0.55
  enemy.armAngle = Util.atan2(player.y - enemy.y, player.x - enemy.x)
  enemy.armAttachedPlayer = nil
  FX.add(
    "¡Brazo del compás!",
    enemy.x,
    enemy.y - enemy.radius - 16,
    { 0.88, 0.62, 1.00 }
  )
  return true
end

local function startOrganPhase(enemy, run)
  enemy.invulnTimer = enemy.def.phaseDuration
  enemy.armState = nil
  enemy.armAttachedPlayer = nil
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
  local def = enemy.def
  enemy.invulnTimer = math.max(0, enemy.invulnTimer - dt)
  enemy.armTimer = math.max(0, (enemy.armTimer or 0) - dt)
  local armBusy = updateOrganArmState(enemy, dt, run)

  enemy.summonTimer = enemy.summonTimer - dt
  if enemy.summonTimer <= 0 then
    enemy.summonTimer = def.summonInterval
    summonRandomAround(enemy, run)
  end

  enemy.healerTimer = math.max(0, (enemy.healerTimer or 0) - dt)
  local bossRatio = enemy.maxHp > 0 and enemy.hp / enemy.maxHp or 0
  local playerRatio = run.stats.maxHp > 0 and run.hp / run.stats.maxHp or 0
  local winning = bossRatio <= (def.healerBossHp or 0.70)
    and playerRatio >= bossRatio + (def.healerLead or 0.20)
  if enemy.healerTimer <= 0 and winning then
    summonHealerAround(enemy, run)
    enemy.healerTimer = def.healerInterval or 7.0
  end

  if enemy.invulnTimer <= 0 then
    if ctx.distance > (def.zoneRange or 380) then
      updateOrganZones(enemy, dt, run)
      if ctx.canSee then
        moveToward(enemy, dt, run, ctx.dx, ctx.dy, ctx.distance, 0.85)
      elseif not armBusy then
        enemy:updateSearch(dt, run)
      end
    else
      -- Dentro del alcance de las zonas el brazo es el ataque por defecto:
      -- así no hay descanso detrás de muros ni en distancias cortas.
      if not armBusy then
        tryStartOrganArm(enemy, run)
      end
      if not ctx.canSee and not enemy.armState then
        enemy:updateSearch(dt, run)
      end
    end
  end

  local threshold = def.phaseThresholds[enemy.bossPhase]
  if threshold and bossRatio <= threshold and enemy.invulnTimer <= 0 then
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

    if enemy.armState == "windup" then
      local reach = enemy.def.armRange or enemy.def.zoneRange or 380
      local ex = enemy.x + math.cos(enemy.armAngle) * reach
      local ey = enemy.y + math.sin(enemy.armAngle) * reach
      local pulse = 0.22 + 0.18 * math.sin(t * 14)
      love.graphics.setColor(0.88, 0.62, 1.00, pulse)
      love.graphics.setLineWidth(7)
      love.graphics.line(enemy.x, enemy.y, ex, ey)
      love.graphics.setColor(0.96, 0.86, 1.00, 0.90)
      love.graphics.setLineWidth(2)
      love.graphics.line(enemy.x, enemy.y, ex, ey)
      love.graphics.circle("line", ex, ey, 8)
      love.graphics.setLineWidth(1)
    elseif enemy.armState == "pull" and enemy.armAttachedPlayer then
      local player = enemy.armAttachedPlayer
      love.graphics.setColor(0.88, 0.62, 1.00, 0.35)
      love.graphics.setLineWidth(8)
      love.graphics.line(enemy.x, enemy.y, player.x, player.y)
      love.graphics.setColor(0.96, 0.86, 1.00, 0.95)
      love.graphics.setLineWidth(3)
      love.graphics.line(enemy.x, enemy.y, player.x, player.y)
      love.graphics.setColor(0.96, 0.86, 1.00, 0.85)
      love.graphics.circle("line", player.x, player.y, player.radius + 7)
      love.graphics.setLineWidth(1)
    end
  end
end

return Boss
