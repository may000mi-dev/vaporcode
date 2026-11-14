-- threat.lua: presupuesto de amenaza, roles y oleadas del Modo Infinito.
-- El Modo Historia no entra aquí: sigue usando el spawn plano de spawner.lua.
local Data = require("src.run.data")
local Util = require("src.utils.util")

local Threat = {}

local function config()
  return Data.threat
end

local function aliveCount(run)
  local total = 0
  for _, enemy in ipairs(run.enemies or {}) do
    if not enemy.dead then
      total = total + 1
    end
  end
  return total
end

local function hasRole(def, roles)
  for _, role in ipairs(roles or {}) do
    for _, own in ipairs(def.threatRoles or {}) do
      if own == role then
        return true
      end
    end
  end
  return false
end

local function shuffle(list, rng)
  for i = #list, 2, -1 do
    local j = rng:random(1, i)
    list[i], list[j] = list[j], list[i]
  end
end

function Threat.enabled(run)
  return run ~= nil
    and run.mode == "free"
    and not run.sandbox
    and run.dungeon ~= nil
end

function Threat.pending(run)
  return run.threat ~= nil
    and run.threat.enabled == true
    and run.threat.complete ~= true
end

function Threat.roomCount(run)
  return run.dungeon and #run.dungeon.rooms or 0
end

function Threat.sizeMultiplier(roomCount)
  local cfg = config()
  local count = math.max(1, roomCount or cfg.sizeRoomsBase)
  return Util.clamp(
    count / cfg.sizeRoomsBase,
    cfg.sizeMin,
    cfg.sizeMax
  )
end

-- Acepta una run o un número de piso, para poder probar la fórmula aislada.
function Threat.calculateBudget(runOrDepth, roomCount)
  local cfg = config()
  local depth = 1
  if type(runOrDepth) == "table" then
    depth = runOrDepth.depth or 1
    if roomCount == nil then
      roomCount = Threat.roomCount(runOrDepth)
    end
  elseif type(runOrDepth) == "number" then
    depth = runOrDepth
  end

  local size = Threat.sizeMultiplier(roomCount)
  local raw = cfg.base + math.max(0, depth - 1) * cfg.growth
  return math.max(1, math.floor(raw * size)), size
end

function Threat.cost(kind)
  local def = Data.enemyTypes[kind]
  return def and def.threat or 0
end

local function roleCandidates(pool, roles, maxCost)
  local candidates = {}
  for _, kind in ipairs(pool) do
    local def = Data.enemyTypes[kind]
    local cost = def and def.threat or 0
    if def
      and cost > 0
      and cost <= maxCost
      and hasRole(def, roles)
    then
      candidates[#candidates + 1] = kind
    end
  end
  return candidates
end

local function ensureRole(run, pool, roles, minCost, remaining, units)
  local spent = 0
  while spent < minCost do
    local candidates = roleCandidates(pool, roles, remaining)
    if #candidates == 0 then
      break
    end

    local kind = candidates[run.dungeon.rng:random(1, #candidates)]
    local cost = Threat.cost(kind)
    units[#units + 1] = kind
    remaining = remaining - cost
    spent = spent + cost
  end
  return remaining, spent
end

-- Genera la lista completa del piso. Las garantías se gastan antes del
-- relleno aleatorio para que una mala tirada no deje la sala sin roles.
function Threat.generateComposition(run, budget)
  local cfg = config()
  local pool = run.def and run.def.enemies or {}
  local units = {}
  local remaining = budget

  if (run.depth or 1) >= cfg.rangedDepth then
    remaining = ensureRole(
      run,
      pool,
      cfg.rangedRoles,
      cfg.rangedMinCost,
      remaining,
      units
    )
  end

  if (run.depth or 1) >= cfg.supportDepth then
    remaining = ensureRole(
      run,
      pool,
      cfg.supportRoles,
      cfg.supportMinCost,
      remaining,
      units
    )
  end

  local firstPick = #units == 0
  while remaining > 0 do
    -- La primera unidad no debe consumir todo el presupuesto: así una sala
    -- pequeña conserva material para su segunda oleada.
    local maxCost = remaining
    if firstPick and remaining >= 2 then
      maxCost = math.floor(remaining * 0.5)
    end

    local affordable = {}
    for _, kind in ipairs(pool) do
      local cost = Threat.cost(kind)
      if cost > 0 and cost <= maxCost then
        affordable[#affordable + 1] = kind
      end
    end
    if #affordable == 0 and firstPick and maxCost < remaining then
      for _, kind in ipairs(pool) do
        local cost = Threat.cost(kind)
        if cost > 0 and cost <= remaining then
          affordable[#affordable + 1] = kind
        end
      end
    end
    if #affordable == 0 then
      break
    end

    local kind = affordable[run.dungeon.rng:random(1, #affordable)]
    local cost = Threat.cost(kind)
    units[#units + 1] = kind
    remaining = remaining - cost
    firstPick = false
  end

  return units, budget - remaining, remaining
end

function Threat.waveCount(budget, roomCount)
  local cfg = config()
  local smallRoom = (roomCount or cfg.sizeRoomsBase) < cfg.smallDungeonRooms

  if budget <= cfg.waveLowMax then
    return smallRoom and 2 or 1
  elseif budget <= cfg.waveMidMax then
    return 2
  end
  return 3
end

function Threat.waveRatios(count)
  local cfg = config()
  if count <= 1 then
    return { 1 }
  elseif count == 2 then
    return cfg.waveRatios2
  end
  return cfg.waveRatios3
end

local function waveTargets(totalCost, ratios)
  local targets = {}
  local assigned = 0
  for i = 1, #ratios - 1 do
    targets[i] = math.floor(totalCost * ratios[i])
    assigned = assigned + targets[i]
  end
  targets[#ratios] = math.max(0, totalCost - assigned)
  return targets
end

function Threat.splitWaves(run, units, totalCost, roomCount)
  if #units == 0 then
    return {}
  end

  local count = Threat.waveCount(totalCost, roomCount)
  count = math.min(count, #units)
  count = math.max(1, count)

  local ratios = Threat.waveRatios(count)
  local targets = waveTargets(totalCost, ratios)
  local shuffled = {}
  for i = 1, #units do
    shuffled[i] = units[i]
  end
  shuffle(shuffled, run.dungeon.rng)

  local waves = {}
  local unitIndex = 1
  for waveIndex = 1, count do
    local wave = {
      index = waveIndex,
      units = {},
      cost = 0,
    }
    local last = waveIndex == count
    while unitIndex <= #shuffled
      and (last or wave.cost < targets[waveIndex])
    do
      local kind = shuffled[unitIndex]
      wave.units[#wave.units + 1] = kind
      wave.cost = wave.cost + Threat.cost(kind)
      unitIndex = unitIndex + 1
    end
    waves[waveIndex] = wave
  end

  -- Un objetivo pequeño con unidades caras puede dejar una oleada vacía.
  -- Se mueve una unidad de la oleada más llena sin alterar el total.
  for waveIndex = 1, count do
    if #waves[waveIndex].units == 0 then
      local donor = waves[1]
      for candidate = 2, count do
        if #waves[candidate].units > #donor.units then
          donor = waves[candidate]
        end
      end
      if #donor.units <= 1 then
        break
      end

      local kind = table.remove(donor.units)
      local cost = Threat.cost(kind)
      donor.cost = donor.cost - cost
      waves[waveIndex].units[1] = kind
      waves[waveIndex].cost = cost
    end
  end

  local cfg = config()
  for _, wave in ipairs(waves) do
    wave.total = #wave.units
    wave.killed = 0
    wave.nextAt = math.max(
      1,
      math.ceil(wave.total * cfg.nextWaveKillRatio)
    )
  end

  return waves
end

local function randomSpawnPoint(run, def)
  local cfg = config()
  local x, y = run.dungeon:randomFloorPoint(
    run.player.x,
    run.player.y,
    cfg.spawnMinDistance,
    def.radius
  )
  if x then
    return x, y
  end

  x, y = run.dungeon:randomFloorPoint(
    run.player.x,
    run.player.y,
    cfg.spawnFallbackDistance,
    def.radius
  )
  if x then
    return x, y
  end

  return run.dungeon:randomFloorPoint(nil, nil, 0, def.radius)
end

function Threat.spawnFromQueue(run)
  local state = run.threat
  if not state or state.complete then
    return
  end

  local cap = config().maxActive
  local active = aliveCount(run)
  while state.queueIndex <= #state.queue and active < cap do
    local kind = state.queue[state.queueIndex]
    state.queueIndex = state.queueIndex + 1

    local def = Data.enemyTypes[kind]
    if def then
      local x, y = randomSpawnPoint(run, def)
      if x then
        local enemy = run:createEnemy(kind, x, y)
        if enemy then
          enemy.threatWave = state.activeWave
          state.spawned = state.spawned + 1
          active = active + 1
        end
      end
    end
  end

  run.enemyCount = active
end

function Threat.startFloor(run)
  run.threat = nil
  if not Threat.enabled(run) then
    return nil
  end

  local roomCount = Threat.roomCount(run)
  local budget, size = Threat.calculateBudget(run, roomCount)
  local units, spent = Threat.generateComposition(run, budget)
  local waves = Threat.splitWaves(run, units, spent, roomCount)

  local state = {
    enabled = true,
    complete = #waves == 0,
    budget = budget,
    spent = spent,
    roomCount = roomCount,
    sizeMultiplier = size,
    waves = waves,
    activeWave = 1,
    queue = {},
    queueIndex = 1,
    spawned = 0,
    killsTotal = 0,
  }
  run.threat = state

  if #waves > 0 then
    for _, kind in ipairs(waves[1].units) do
      state.queue[#state.queue + 1] = kind
    end
    Threat.spawnFromQueue(run)
  end

  return state
end

function Threat.updateWaves(run)
  local state = run.threat
  if not state or not state.enabled or state.complete then
    return
  end

  local current = state.waves[state.activeWave]
  while current
    and state.activeWave < #state.waves
    and current.killed >= current.nextAt
  do
    state.activeWave = state.activeWave + 1
    local nextWave = state.waves[state.activeWave]
    for _, kind in ipairs(nextWave.units) do
      state.queue[#state.queue + 1] = kind
    end

    if run.notify then
      run:notify(
        string.format("Oleada %d/%d", state.activeWave, #state.waves),
        { 1.00, 0.76, 0.30 }
      )
    end
    current = state.waves[state.activeWave]
  end

  Threat.spawnFromQueue(run)

  if state.activeWave >= #state.waves
    and state.queueIndex > #state.queue
    and aliveCount(run) == 0
  then
    state.complete = true
  end
end

function Threat.onEnemyKilled(run, enemy)
  local state = run.threat
  if not state or not state.enabled or not enemy.threatWave then
    return
  end

  state.killsTotal = state.killsTotal + 1
  local wave = state.waves[enemy.threatWave]
  if wave then
    wave.killed = wave.killed + 1
  end
end

function Threat.remainingTotal(run)
  local state = run.threat
  if not state or not state.enabled then
    return run.enemyCount or 0
  end

  local total = aliveCount(run)
  local queued = #state.queue - state.queueIndex + 1
  if queued > 0 then
    total = total + queued
  end
  for index = state.activeWave + 1, #state.waves do
    total = total + #state.waves[index].units
  end
  return total
end

return Threat
