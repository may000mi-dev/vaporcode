-- floor.lua: instantánea del estado al iniciar un piso para reintentos exactos.
local Floor = {}

local function copyMap(source)
  local out = {}
  if type(source) == "table" then
    for key, value in pairs(source) do
      out[key] = value
    end
  end
  return out
end

local function copyInventory(source)
  local out = {}
  for index, slot in ipairs(source or {}) do
    out[index] = {
      itemId = slot.itemId,
      amount = slot.amount or 1,
    }
  end
  return out
end

function Floor.capture(run)
  local snapshot = {
    seed = run.seed,
    depth = run.depth,
    dungeonId = run.def and run.def.id,
    characterId = run.characterId,
    abilitySlot1 = run.abilitySlot1,
    abilitySlot2 = run.abilitySlot2,
    abilitySlot3 = run.abilitySlot3,
    abilitySlot4 = run.abilitySlot4,
    playerLevel = run.playerLevel,
    hp = run.hp,
    xp = run.xp,
    xpToNext = run.xpToNext,
    kills = run.kills,
    coinsEarned = run.coinsEarned,
    stats = copyMap(run.stats),
    cooldowns = copyMap(run.cooldowns),
    turboTimer = run.turboTimer,
    mana = run.mana,
    manaMax = run.manaMax,
    manaIdleTimer = run.manaIdleTimer,
    timeLeft = run.timeLeft,
    passiveStacks = copyMap(run.passiveStacks),
    inventory = copyInventory(run.inventory),
    pets = {},
    fluteReady = run.fluteReady,
  }

  for _, pet in ipairs(run.pets or {}) do
    if not pet.dead then
      snapshot.pets[#snapshot.pets + 1] = pet:snapshot()
    end
  end

  return snapshot
end

function Floor.restore(run, snapshot)
  if type(snapshot) ~= "table" then return false end

  run.seed = snapshot.seed
  run.depth = snapshot.depth
  run.characterId = snapshot.characterId
  run.abilitySlot1 = snapshot.abilitySlot1
  run.abilitySlot2 = snapshot.abilitySlot2
  run.abilitySlot3 = snapshot.abilitySlot3 or "shield"
  run.abilitySlot4 = snapshot.abilitySlot4 or "turbo"
  run.playerLevel = snapshot.playerLevel
  run.hp = snapshot.hp
  run.xp = snapshot.xp
  run.xpToNext = snapshot.xpToNext
  run.kills = snapshot.kills
  run.coinsEarned = snapshot.coinsEarned
  run.stats = copyMap(snapshot.stats)
  run.cooldowns = copyMap(snapshot.cooldowns)
  run.turboTimer = snapshot.turboTimer
  run.mana = snapshot.mana
  run.manaMax = snapshot.manaMax
  run.manaIdleTimer = snapshot.manaIdleTimer
  run.timeLeft = snapshot.timeLeft
  run.passiveStacks = copyMap(snapshot.passiveStacks)
  run.inventory = copyInventory(snapshot.inventory)
  run.pets = {}
  run.petSnapshot = snapshot.pets or {}
  run.fluteReady = snapshot.fluteReady and true or false
  return true
end

return Floor
