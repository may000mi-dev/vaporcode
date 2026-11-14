-- boss_memories.lua: memorias heredadas de los compases y Sobrecarga global.
-- El sistema queda aislado con run.mode == "free": Historia no cambia.
local Data = require("src.run.data")
local FX = require("src.run.fx")

local BossMemories = {}

local function config()
  return Data.bossMemories
end

local function typeData(id)
  return config().types[id]
end

local function contains(list, id)
  for _, value in ipairs(list or {}) do
    if value == id then return true end
  end
  return false
end

function BossMemories.has(enemy, id)
  return enemy ~= nil and contains(enemy.memories, id)
end

function BossMemories.damageMultiplier(enemy)
  return enemy and enemy.memoryDamageMultiplier or 1
end

-- Toma las memorias de los compases activos en orden, sin repetir. La ventana
-- de compases ya es determinista, así que un reintento hereda la misma pelea.
function BossMemories.candidates(run)
  local result = {}
  local state = run and run.compases
  local mapping = config().fromCompas
  for _, compasId in ipairs(state and state.active or {}) do
    local memoryId = mapping[compasId]
    if memoryId and not contains(result, memoryId) then
      result[#result + 1] = memoryId
    end
  end
  if #result == 0 then
    result[1] = "rage"
  end
  return result
end

local function chooseMemories(run)
  local result = {}
  for _, id in ipairs(BossMemories.candidates(run)) do
    if #result >= config().maxMemories then break end
    result[#result + 1] = id
  end
  return result
end

local function spawnGuards(enemy, run)
  if not run.createEnemy or not run.dungeon or not run.def then return end

  local pool = {}
  for _, kind in ipairs(run.def.enemies or {}) do
    local def = Data.enemyTypes[kind]
    if def and not def.boss and kind ~= "clerigo" then
      pool[#pool + 1] = kind
    end
  end
  if #pool == 0 then
    pool[1] = "automaton"
  end

  local rng = run.dungeon.rng
  local start = rng and rng:random() * math.pi * 2 or love.math.random() * math.pi * 2
  local count = config().types.guard.count
  for index = 1, count do
    local kind = rng and pool[rng:random(1, #pool)] or pool[love.math.random(1, #pool)]
    local def = Data.enemyTypes[kind]
    local angle = start + (index - 1) * (math.pi * 2 / count)
    local distance = enemy.radius + def.radius + config().types.guard.distance
    local x, y = run.dungeon:moveCircle(
      enemy.x,
      enemy.y,
      math.cos(angle) * distance,
      math.sin(angle) * distance,
      def.radius
    )
    local guard = run:createEnemy(kind, x, y, {
      forceElite = true,
      noEscort = true,
    })
    if guard then
      guard.bossGuard = true
      FX.ring(guard.x, guard.y, def.radius + 8, config().types.guard.color)
    end
  end
end

local function applyPassives(enemy)
  enemy.memoryRageTimer = typeData("rage").delay
  enemy.memoryRageActive = false
  enemy.memoryDamageMultiplier = 1
  enemy.memoryEchoTimer = typeData("echo").interval
  enemy.memorySiphonCooldown = 0
  enemy.memoryRegenIdleTimer = 0
  enemy.memoryRegenFxTimer = 0
  enemy.memoryFortified = BossMemories.has(enemy, "fortified")
  enemy.memoryFortifiedReduction = typeData("fortified").reduction
  enemy.memoryFortifiedThreshold = typeData("fortified").threshold

  if BossMemories.has(enemy, "siphon") then
    enemy.onPlayerDamaged = BossMemories.onPlayerDamaged
  end
end

function BossMemories.attach(run, enemy)
  if not run or not enemy then return nil end
  if run.mode ~= "free" or run.sandbox then return nil end
  if enemy.memoryAttached then return enemy end
  enemy.memoryAttached = true
  enemy.memoryEnrageTimer = config().enrageSeconds
  enemy.memoryEnrageTotal = config().enrageSeconds
  enemy.memoryEnrageTriggered = false

  -- Todos los jefes del Infinito tienen límite; las memorias solo aparecen en
  -- los pisos de jefe (múltiplos de bossEvery).
  if (run.depth or 1) % Data.bossEvery ~= 0 then
    return enemy
  end

  local memories = chooseMemories(run)
  enemy.memories = memories
  local names = {}
  for index, id in ipairs(memories) do
    names[index] = typeData(id).name
  end
  enemy.memoryLabel = table.concat(names, " · ")
  applyPassives(enemy)

  if BossMemories.has(enemy, "guard") then
    spawnGuards(enemy, run)
  end

  if run.player and run.notify then
    run:notify("Memorias: " .. enemy.memoryLabel, typeData(memories[1]).color)
  end
  return enemy
end

function BossMemories.onPlayerDamaged(enemy, amount, run)
  if enemy.dead or amount <= 0 or not BossMemories.has(enemy, "siphon") then return end
  if (enemy.memorySiphonCooldown or 0) > 0 then return end

  local cfg = typeData("siphon")
  enemy.memorySiphonCooldown = cfg.hitCooldown
  if run.mana then
    run.mana = math.max(0, run.mana - cfg.manaDrain)
    run.manaIdleTimer = 0
  end

  if run.cooldowns
    and run.abilityIdForSlot
    and run.cooldownKeyForSlot
  then
    local available = {}
    for slot = 1, 4 do
      if run:abilityIdForSlot(slot) then
        available[#available + 1] = slot
      end
    end
    if #available > 0 then
      local slot = available[love.math.random(1, #available)]
      local key = run:cooldownKeyForSlot(slot)
      run.cooldowns[key] = (run.cooldowns[key] or 0) + cfg.cooldownPenalty
    end
  end

  local player = run.player
  if player then
    FX.add("Sifón", player.x, player.y - 30, cfg.color)
  end
end

local function updateRage(enemy, dt)
  if not BossMemories.has(enemy, "rage") or enemy.memoryRageActive then return end
  enemy.memoryRageTimer = (enemy.memoryRageTimer or 0) - dt
  if enemy.memoryRageTimer > 0 then return end

  local cfg = typeData("rage")
  enemy.memoryRageTimer = 0
  enemy.memoryRageActive = true
  enemy.speed = enemy.speed * cfg.speedMultiplier
  enemy.damage = enemy.damage * cfg.damageMultiplier
  enemy.memoryDamageMultiplier = cfg.damageMultiplier
  FX.add("¡Furia!", enemy.x, enemy.y - enemy.radius - 24, cfg.color)
  FX.ring(enemy.x, enemy.y, enemy.radius + 12, cfg.color)
end

local function updateEcho(enemy, dt, run)
  if not BossMemories.has(enemy, "echo") then return end
  enemy.memoryEchoTimer = (enemy.memoryEchoTimer or typeData("echo").interval) - dt
  if enemy.memoryEchoTimer > 0 then return end

  local cfg = typeData("echo")
  enemy.memoryEchoTimer = cfg.interval
  if not run.spawnHazard or not run.player then return end

  local damage = cfg.damageBase
    + math.max(0, (run.depth or 1) - 1) * cfg.damagePerDepth
  damage = damage * BossMemories.damageMultiplier(enemy)
  run:spawnHazard("echo", run.player.x, run.player.y, {
    radius = cfg.radius,
    delay = cfg.telegraph,
    damage = damage,
    interval = 1,
    color = cfg.color,
    sourceEnemy = enemy,
  })
  FX.ring(run.player.x, run.player.y, cfg.radius, cfg.color)
end

local function updateRegen(enemy, dt)
  if not BossMemories.has(enemy, "regen") then return end
  local cfg = typeData("regen")
  enemy.memoryRegenIdleTimer = (enemy.memoryRegenIdleTimer or 0) + dt
  if enemy.memoryRegenIdleTimer <= cfg.idle or enemy.hp >= enemy.maxHp then return end

  enemy.hp = math.min(enemy.maxHp, enemy.hp + enemy.maxHp * cfg.percentPerSecond * dt)
  enemy.memoryRegenFxTimer = (enemy.memoryRegenFxTimer or 0) - dt
  if enemy.memoryRegenFxTimer <= 0 then
    enemy.memoryRegenFxTimer = 1
    local heal = math.max(1, math.floor(enemy.maxHp * cfg.percentPerSecond))
    FX.add("+" .. heal .. " vida", enemy.x, enemy.y - enemy.radius - 22, cfg.color)
  end
end

-- Devuelve true cuando la Sobrecarga cierra la run; Boss.update debe cortar.
function BossMemories.update(enemy, dt, run)
  if not enemy.memoryEnrageTimer or enemy.dead or run.over then return false end

  enemy.memoryEnrageTimer = enemy.memoryEnrageTimer - dt
  if enemy.memoryEnrageTimer <= 0 and not enemy.memoryEnrageTriggered then
    enemy.memoryEnrageTriggered = true
    enemy.memoryEnrageTimer = 0
    -- La Sobrecarga ignora escudos, invulnerabilidad y curación: cierra la run.
    run.hp = 0
    if run.player then
      run.player.invuln = 0
    end
    if run.gameOver then
      run:gameOver("boss_enrage")
    end
    return true
  end

  enemy.memorySiphonCooldown = math.max(0, (enemy.memorySiphonCooldown or 0) - dt)
  if not enemy.memories then return false end

  updateRage(enemy, dt)
  updateEcho(enemy, dt, run)
  updateRegen(enemy, dt)
  return false
end

function BossMemories.drawOverlay(enemy)
  if not enemy.memories or #enemy.memories == 0 then return end

  local t = love.timer.getTime()
  if BossMemories.has(enemy, "rage") and enemy.memoryRageActive then
    local pulse = 0.18 + 0.08 * math.sin(t * 7)
    love.graphics.setColor(0.55, 0.02, 0.02, pulse)
    love.graphics.circle("fill", enemy.x, enemy.y, enemy.radius + 10)
  end

  for index, id in ipairs(enemy.memories) do
    local def = typeData(id)
    local alpha = 0.60
    if id == "fortified" and not enemy.memoryFortified then
      alpha = 0.20
    elseif id == "regen" and enemy.memoryRegenIdleTimer <= typeData("regen").idle then
      alpha = 0.30
    end
    love.graphics.setColor(def.color[1], def.color[2], def.color[3], alpha)
    love.graphics.setLineWidth(2)
    love.graphics.circle(
      "line",
      enemy.x,
      enemy.y,
      enemy.radius + 10 + index * 3 + math.sin(t * 5 + index) * 1.5
    )
  end
  love.graphics.setLineWidth(1)

  if BossMemories.has(enemy, "regen")
    and enemy.memoryRegenIdleTimer > typeData("regen").idle
    and enemy.hp < enemy.maxHp
  then
    love.graphics.setColor(0.42, 0.92, 0.42, 0.45)
    love.graphics.circle("line", enemy.x, enemy.y, enemy.radius + 16)
  end
end

return BossMemories
