-- antidote.lua: enemigos que castigan builds dominantes en Modo Infinito.
-- La generación y el aura solo existen con run.mode == "free"; Historia y la
-- sala de pruebas quedan fuera aunque compartan los mismos tipos base.
local Data = require("src.run.data")
local Util = require("src.utils.util")

local Antidote = {}

local function config()
  return Data.antidote
end

local function isPetKind(kind)
  for _, petKind in ipairs(config().petKinds) do
    if petKind == kind then return true end
  end
  return false
end

function Antidote.enabled(run)
  return run ~= nil
    and run.mode == "free"
    and not run.sandbox
    and (run.depth or 1) >= config().minDepth
end

function Antidote.chanceAt(depth)
  local chance = 0
  for _, entry in ipairs(config().chanceByDepth) do
    if (depth or 1) >= entry.depth then
      chance = entry.chance
    else
      break
    end
  end
  return chance
end

function Antidote.activePets(run)
  local pets = {}
  for _, pet in ipairs(run and run.pets or {}) do
    if not pet.dead and isPetKind(pet.kind) then
      pets[#pets + 1] = pet
    end
  end
  return pets
end

-- Pesos deliberadamente simples: la build dominante sube su contraparte, pero
-- nunca excluye por completo a los otros antídotos.
function Antidote.buildWeights(run)
  local weights = {}
  for _, kind in ipairs(config().types) do
    weights[kind] = 1
  end

  local stacks = run and run.passiveStacks or {}
  local sustain = (stacks.vampire or 0) + (stacks.fairy or 0)
  weights.purificador = weights.purificador + sustain * 4

  local pets = Antidote.activePets(run)
  weights.devorador = weights.devorador + #pets * 5

  local burst = (stacks.poison or 0) + (stacks.gunpowder or 0)
  weights.espejo = weights.espejo + burst * 3
  local damage = run and run.stats and run.stats.damage or 0
  if damage >= 10 then
    weights.espejo = weights.espejo + 2
  end

  local maxHp = run and run.stats and run.stats.maxHp or 0
  if maxHp >= 160 or (run and (run.playerLevel or 1) >= 10) then
    weights.asediador = weights.asediador + 4
  end

  return weights
end

function Antidote.chooseKind(run)
  local rng = run and run.dungeon and run.dungeon.rng
  if not rng then return nil end

  local weights = Antidote.buildWeights(run)
  local total = 0
  for _, kind in ipairs(config().types) do
    total = total + (weights[kind] or 0)
  end
  if total <= 0 then return nil end

  local roll = rng:random() * total
  for _, kind in ipairs(config().types) do
    roll = roll - (weights[kind] or 0)
    if roll < 0 then return kind end
  end
  return config().types[#config().types]
end

-- Devuelve nil si la tirada falla; el llamador decide si cabe en el presupuesto.
function Antidote.choose(run)
  if not Antidote.enabled(run) then return nil end
  local rng = run.dungeon and run.dungeon.rng
  if not rng then return nil end
  if rng:random() >= Antidote.chanceAt(run.depth) then return nil end
  return Antidote.chooseKind(run)
end

function Antidote.suppressed(run)
  if not Antidote.enabled(run) then return false end
  local player = run.player
  if not player then return false end

  local reach = config().healingAuraRadius + (player.radius or 0)
  local reach2 = reach * reach
  for _, enemy in ipairs(run.enemies or {}) do
    if not enemy.dead and enemy.kind == "purificador" then
      if Util.dist2(player.x, player.y, enemy.x, enemy.y) <= reach2 then
        return true
      end
    end
  end
  return false
end

function Antidote.healingMultiplier(run)
  if Antidote.suppressed(run) then
    return 1 - config().healingReduction
  end
  return 1
end

return Antidote
