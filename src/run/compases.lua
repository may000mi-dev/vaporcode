-- compases.lua: selección determinista y efectos de los compases del Infinito.
-- La cadena se calcula al entrar al piso usando la semilla de la run; no
-- consume RNG de la mazmorra y por eso un reintento reproduce el mismo piso.
local Data = require("src.run.data")

local Compases = {}

local function config()
  return Data.compases
end

local function makeRng(seed)
  local state = math.floor(math.abs(seed or 1)) % 2147483647
  if state == 0 then state = 1 end
  return function(limit)
    state = (state * 48271) % 2147483647
    return (state % limit) + 1
  end
end

local function shuffle(list, random)
  for i = #list, 2, -1 do
    local j = random(i)
    list[i], list[j] = list[j], list[i]
  end
end

local function isRecent(result, index, id, window)
  local first = math.max(1, index - window + 1)
  for i = first, index - 1 do
    if result[i] == id then
      return true
    end
  end
  return false
end

-- Genera solo los primeros `stage` compases. La ventana activa se recorta
-- después, así el efecto de un piso no cambia si se reintenta.
local function buildSequence(seed, stage)
  local order = {}
  for index, id in ipairs(config().order) do
    order[index] = id
  end

  local random = makeRng(seed)
  local result = {}
  local cursor = #order + 1
  local window = config().maxActive

  for index = 1, stage do
    if cursor > #order then
      shuffle(order, random)
      cursor = 1
    end

    if isRecent(result, index, order[cursor], window) then
      for candidate = cursor + 1, #order do
        if not isRecent(result, index, order[candidate], window) then
          order[cursor], order[candidate] = order[candidate], order[cursor]
          break
        end
      end
    end

    result[index] = order[cursor]
    cursor = cursor + 1
  end
  return result
end

local ROMAN = {
  "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X",
  "XI", "XII", "XIII", "XIV", "XV", "XVI", "XVII", "XVIII", "XIX", "XX",
}

function Compases.roman(number)
  return ROMAN[number] or tostring(number)
end

function Compases.enabled(run)
  return run ~= nil
    and run.mode == "free"
    and not run.sandbox
end

function Compases.stageForDepth(depth)
  return math.floor(math.max(0, depth or 1) / config().cycleFloors)
end

function Compases.sequence(seed, stage)
  return buildSequence(seed, stage)
end

function Compases.refresh(run)
  run.compases = nil
  if not Compases.enabled(run) then
    return nil
  end

  local stage = Compases.stageForDepth(run.depth)
  if stage <= 0 then
    return nil
  end

  local sequence = buildSequence(run.seed or 1, stage)
  local first = math.max(1, stage - config().maxActive + 1)
  local active = {}
  local names = { "Compás " .. Compases.roman(stage) }
  local values = {
    enemyDamageMultiplier = 1,
    enemyCooldownMultiplier = 1,
    threatMultiplier = 1,
    playerHealingMultiplier = 1,
    enemyHealingMultiplier = 1,
    abilityLockBonus = 0,
    echo = false,
  }

  for index = first, stage do
    local id = sequence[index]
    local def = config().types[id]
    if def then
      active[#active + 1] = id
      names[#names + 1] = def.name
      values.enemyDamageMultiplier = values.enemyDamageMultiplier
        * (def.enemyDamageMultiplier or 1)
      values.enemyCooldownMultiplier = values.enemyCooldownMultiplier
        * (def.enemyCooldownMultiplier or 1)
      values.threatMultiplier = values.threatMultiplier
        * (def.threatMultiplier or 1)
      values.playerHealingMultiplier = values.playerHealingMultiplier
        * (def.playerHealingMultiplier or 1)
      values.enemyHealingMultiplier = values.enemyHealingMultiplier
        * (def.enemyHealingMultiplier or 1)
      values.abilityLockBonus = values.abilityLockBonus
        + (def.abilityLockBonus or 0)
      values.echo = values.echo or def.echo == true
    end
  end

  run.compases = {
    stage = stage,
    active = active,
    label = table.concat(names, " · "),
    echoTimer = config().echo.interval,
    enemyDamageMultiplier = values.enemyDamageMultiplier,
    enemyCooldownMultiplier = values.enemyCooldownMultiplier,
    threatMultiplier = values.threatMultiplier,
    playerHealingMultiplier = values.playerHealingMultiplier,
    enemyHealingMultiplier = values.enemyHealingMultiplier,
    abilityLockBonus = values.abilityLockBonus,
    echo = values.echo,
  }
  return run.compases
end

function Compases.has(run, id)
  local state = run and run.compases
  if not state then return false end
  for _, activeId in ipairs(state.active) do
    if activeId == id then return true end
  end
  return false
end

function Compases.value(run, field, fallback)
  local state = run and run.compases
  if not state then return fallback end
  return state[field] or fallback
end

function Compases.enemyDamageMultiplier(run)
  return Compases.value(run, "enemyDamageMultiplier", 1)
end

function Compases.enemyCooldownMultiplier(run)
  return Compases.value(run, "enemyCooldownMultiplier", 1)
end

function Compases.threatMultiplier(run)
  return Compases.value(run, "threatMultiplier", 1)
end

function Compases.playerHealingMultiplier(run)
  return Compases.value(run, "playerHealingMultiplier", 1)
end

function Compases.enemyHealingMultiplier(run)
  return Compases.value(run, "enemyHealingMultiplier", 1)
end

function Compases.abilityLockBonus(run)
  return Compases.value(run, "abilityLockBonus", 0)
end

function Compases.guarantees(run)
  local state = run and run.compases
  local kinds = {}
  if not state then return kinds end

  for _, id in ipairs(state.active) do
    local def = config().types[id]
    if def and def.guaranteedKind then
      kinds[#kinds + 1] = def.guaranteedKind
    end
  end
  return kinds
end

function Compases.hunterAffix(run)
  if Compases.has(run, "hunt") then
    return config().types.hunt.hunterAffix
  end
  return nil
end

function Compases.echoDamage(run)
  local cfg = config().echo
  return cfg.damageBase + math.max(0, (run.depth or 1) - 1) * cfg.damagePerDepth
end

function Compases.update(run, dt)
  local state = run and run.compases
  if not state or not state.echo or not run.player or run.over then
    return
  end

  state.echoTimer = (state.echoTimer or config().echo.interval) - dt
  if state.echoTimer > 0 then return end

  local cfg = config().echo
  state.echoTimer = cfg.interval
  if not run.spawnHazard then return end

  run:spawnHazard("echo", run.player.x, run.player.y, {
    radius = cfg.radius,
    delay = cfg.telegraph,
    damage = Compases.echoDamage(run),
    interval = 1,
    color = cfg.color,
  })
end

return Compases
