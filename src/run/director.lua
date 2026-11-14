-- director.lua: dificultad adaptativa del Modo Infinito.
-- Mide el piso terminado y decide el modificador del siguiente. Historia y
-- sala de pruebas nunca entran aquí.
local Data = require("src.run.data")

local Director = {}

local function config()
  return Data.director
end

local function clamp(value, low, high)
  if value < low then return low end
  if value > high then return high end
  return value
end

function Director.enabled(run)
  return run ~= nil and run.mode == "free" and not run.sandbox
end

local function makeState(id, cfg)
  if id == "high" then
    return {
      state = "high",
      threatMultiplier = cfg.highThreatMultiplier,
      extraElites = cfg.highExtraElites,
      message = cfg.messages.high,
      color = cfg.colors.high,
    }
  elseif id == "low" then
    return {
      state = "low",
      threatMultiplier = cfg.lowThreatMultiplier,
      extraElites = 0,
      message = cfg.messages.low,
      color = cfg.colors.low,
    }
  end
  return {
    state = "standard",
    threatMultiplier = 1,
    extraElites = 0,
    message = cfg.messages.standard,
    color = cfg.colors.standard,
  }
end

function Director.evaluate(metrics)
  local cfg = config()
  if not metrics then
    return makeState("standard", cfg)
  end

  local floorTime = metrics.floorTime or 0
  local damageTaken = metrics.damageTaken or 0
  local hpRatio = metrics.endHpRatio or 0

  local high = floorTime < cfg.highTime
    and (damageTaken == 0 or hpRatio >= cfg.highHpRatio)
  local low = hpRatio < cfg.lowHpRatio or floorTime > cfg.lowTime
  local id = high and "high" or (low and "low" or "standard")
  return makeState(id, cfg)
end

-- Conserva el modificador activo al reintentar; solo lo reemplaza cuando hay
-- una evaluación nueva para el piso que va a comenzar.
function Director.beginFloor(run)
  if not Director.enabled(run) then
    run.director = nil
    return nil
  end

  local cfg = config()
  local previous = run.director
  local active = (previous and previous.next)
    or (previous and previous.active)
    or makeState("standard", cfg)
  local notify = active.state ~= "standard"

  run.director = {
    active = active,
    next = nil,
    elapsed = 0,
    damageTaken = 0,
    completed = false,
    last = previous and previous.last or nil,
    notice = notify and active.message or nil,
    noticeTimer = notify and cfg.noticeDuration or 0,
  }
  return active
end

function Director.update(run, dt)
  local state = run and run.director
  if not state or not Director.enabled(run) then
    return
  end

  if (state.noticeTimer or 0) > 0 then
    state.noticeTimer = math.max(0, state.noticeTimer - dt)
  end

  if not state.completed and not run.exitOpen then
    state.elapsed = state.elapsed + dt
  end
end

function Director.onPlayerDamaged(run, amount)
  local state = run and run.director
  if not state or not Director.enabled(run) or state.completed then
    return
  end
  if amount and amount > 0 then
    state.damageTaken = state.damageTaken + amount
  end
end

function Director.completeFloor(run)
  if not Director.enabled(run) then
    return nil
  end
  if not run.director then
    Director.beginFloor(run)
  end

  local state = run.director
  if state.completed then
    return state.next
  end

  local maxHp = run.stats and run.stats.maxHp or 0
  local ratio = 0
  if maxHp > 0 then
    ratio = clamp((run.hp or 0) / maxHp, 0, 1)
  end

  state.last = {
    floorTime = state.elapsed,
    damageTaken = state.damageTaken,
    endHpRatio = ratio,
  }
  state.completed = true
  state.next = Director.evaluate(state.last)
  return state.next
end

function Director.active(run)
  local state = run and run.director
  return state and state.active or nil
end

function Director.lastMetrics(run)
  local state = run and run.director
  return state and state.last or nil
end

function Director.threatMultiplier(run)
  local active = Director.active(run)
  return active and active.threatMultiplier or 1
end

function Director.suppressDoubleAffixes(run)
  local active = Director.active(run)
  return config().suppressDoubleAffixes == true
    and active ~= nil
    and active.state == "low"
end

function Director.extraEliteCount(run)
  local active = Director.active(run)
  return active and active.extraElites or 0
end

function Director.currentNotice(run)
  local state = run and run.director
  if not state
    or not state.notice
    or (state.noticeTimer or 0) <= 0
  then
    return nil
  end
  local active = state.active
  return state.notice, active and active.color or nil
end

return Director
