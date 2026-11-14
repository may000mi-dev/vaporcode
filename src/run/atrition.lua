-- atrition.lua: desgaste progresivo del Modo Infinito (curación y tiempo).
-- Historia y sala de pruebas conservan los valores base de Balance.
local Data = require("src.run.data")
local Compases = require("src.run.compases")

local Atricion = {}

function Atricion.enabled(run)
  return run ~= nil and run.mode == "free" and not run.sandbox
end

local function config()
  return Data.floor.atrition
end

local function rangeValue(ranges, depth, field, fallback)
  local level = math.max(1, math.floor(depth or 1))
  for _, range in ipairs(ranges) do
    if level <= range.maxDepth then
      return range[field]
    end
  end
  return fallback
end

function Atricion.timeLimit(run, depth)
  if not Atricion.enabled(run) then
    return Data.floor.timeLimit
  end
  return rangeValue(
    config().timeLimitByDepth,
    depth or run.depth,
    "seconds",
    Data.floor.timeLimit
  )
end

function Atricion.floorHealPercent(run, depth)
  if not Atricion.enabled(run) then
    return Data.player.nextLevelHealPercent
  end
  return rangeValue(
    config().healByDepth,
    depth or run.depth,
    "percent",
    0
  )
end

-- Aplica la curación al entrar al piso indicado y conserva el multiplicador
-- de Compases (por ejemplo, Hambruna). Devuelve vida curada y porcentaje base.
function Atricion.applyFloorHeal(run, depth)
  local percent = Atricion.floorHealPercent(run, depth)
  local maxHp = run.stats and run.stats.maxHp or 0
  local multiplier = Compases.playerHealingMultiplier(run)
  local healed = math.floor(maxHp * percent * multiplier)
  if healed > 0 then
    run.hp = math.min(maxHp, (run.hp or 0) + healed)
  end
  return healed, percent
end

function Atricion.formatClock(seconds)
  local total = math.max(0, math.ceil(seconds or 0))
  return string.format("%d:%02d", math.floor(total / 60), total % 60)
end

return Atricion
