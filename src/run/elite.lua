-- elite.lua: selección de élites y afijos según el piso.
-- En Modo Historia se conserva la tirada original de un solo afijo; en
-- Infinito la probabilidad y la cantidad de afijos escalan con la profundidad.
local Data = require("src.run.data")

local Elites = {}

local function config()
  return Data.elite
end

local function random(rng, limit)
  if limit then
    return rng:random(limit)
  end
  return rng:random()
end

function Elites.chanceAt(depth)
  local points = config().chanceByDepth
  local level = math.max(1, depth or 1)
  local previous = points[1]
  if level <= previous.depth then
    return previous.chance
  end

  for index = 2, #points do
    local point = points[index]
    if level <= point.depth then
      local span = point.depth - previous.depth
      local offset = level - previous.depth
      return previous.chance
        + (point.chance - previous.chance) * (offset / span)
    end
    previous = point
  end
  return points[#points].chance
end

function Elites.twoAffixChance(depth)
  local level = math.max(1, depth or 1)
  for _, range in ipairs(config().affixCountByDepth) do
    if level <= range.maxDepth then
      return range.twoAffixChance
    end
  end
  return 0
end

function Elites.affixCount(depth, rng)
  local chance = Elites.twoAffixChance(depth)
  if chance > 0 and rng:random() < chance then
    return 2
  end
  return 1
end

local function shuffledAffixes(rng)
  local affixes = {}
  for index, id in ipairs(config().affixes) do
    affixes[index] = id
  end
  for index = #affixes, 2, -1 do
    local swap = random(rng, index)
    affixes[index], affixes[swap] = affixes[swap], affixes[index]
  end
  return affixes
end

local function pickUnique(rng, count)
  local available = shuffledAffixes(rng)
  local result = {}
  for index = 1, math.min(count, #available) do
    result[index] = available[index]
  end
  return result
end

-- Devuelve una lista de afijos. La lista vacía significa enemigo normal.
function Elites.roll(run, def, options)
  options = options or {}
  if options.affixes then
    return options.affixes
  end
  if options.elite then
    return { options.elite }
  end
  if options.affix then
    return { options.affix }
  end
  if options.noElite or def.noElite or def.boss then
    return {}
  end

  local rng = run.dungeon.rng
  if run.mode ~= "free" then
    if rng:random() < config().chance then
      local roll = rng:random(1, 3)
      return { roll == 1 and "volatile" or (roll == 2 and "armored" or "spectral") }
    end
    return {}
  end

  local forced = options.forceElite == true
  if not forced and rng:random() >= Elites.chanceAt(run.depth) then
    return {}
  end

  local count = options.forceTwoAffixes
    and 2
    or (forced and 1 or Elites.affixCount(run.depth, rng))
  return pickUnique(rng, count)
end

return Elites
