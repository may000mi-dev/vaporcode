-- save.lua: progreso persistente en JSON versionado dentro de love.filesystem.
local Data = require("src.run.data")
local Json = require("src.utils.json")

local Save = {}
local FILE = "save.json"
local TEMP_FILE = "save.json.tmp"
local VERSION = 4

local function clamp01(value)
  value = tonumber(value)
  if not value then return nil end
  return math.max(0, math.min(1, value))
end

-- Lee y valida un archivo. Devuelve la tabla decodificada o nil si falta,
-- está incompleto o no es JSON válido.
local function readSave(name)
  if not love.filesystem.getInfo(name) then return nil end
  local content = love.filesystem.read(name)
  if not content then return nil end

  local ok, data = pcall(Json.decode, content)
  if not ok or type(data) ~= "table" then return nil end
  return data
end

local function writeSave(name, content)
  local ok, written = pcall(love.filesystem.write, name, content)
  return ok and written and true or false
end

local function defaultStory()
  return {
    active = false,
    completed = false,
    chapterId = nil,
    depth = 1,
    characterId = "amado",
    checkpoint = nil,
  }
end

local function defaults()
  return {
    version = VERSION,
    coins = 0,
    bestLevel = 0,
    upgrades = { damage = 0, maxHp = 0, speed = 0 },
    unlocked = { cripta = true, forja = false, catedral = false },
    characters = { amado = true, mar = false, amileth = false },
    settings = { musicVolume = 0.6, effectsVolume = 0.8 },
    story = defaultStory(),
  }
end

local function validCheckpoint(checkpoint)
  if type(checkpoint) ~= "table" or type(checkpoint.stats) ~= "table" then
    return false
  end
  local stats = checkpoint.stats
  return type(checkpoint.seed) == "number"
    and type(checkpoint.dungeonId) == "string"
    and type(checkpoint.playerLevel) == "number"
    and type(checkpoint.hp) == "number"
    and type(checkpoint.xp) == "number"
    and type(checkpoint.xpToNext) == "number"
    and type(checkpoint.mana) == "number"
    and type(checkpoint.manaMax) == "number"
    and type(checkpoint.timeLeft) == "number"
    and type(stats.damage) == "number"
    and type(stats.maxHp) == "number"
    and type(stats.speed) == "number"
    and type(stats.attackRate) == "number"
end

local function normalizeStory(data)
  local out = defaultStory()
  if type(data) ~= "table" then return out end

  out.completed = data.completed and true or false
  local chapter = type(data.chapterId) == "string"
    and Data.story.chapterById[data.chapterId]
    or nil
  if not chapter then return out end

  out.chapterId = chapter.id
  local depth = math.floor(tonumber(data.depth) or chapter.startDepth)
  out.depth = math.max(chapter.startDepth, math.min(depth, chapter.endDepth))
  if Data.characters[data.characterId] then
    out.characterId = data.characterId
  end

  if data.active and validCheckpoint(data.checkpoint) then
    local checkpoint = data.checkpoint
    local cpDepth = math.floor(tonumber(checkpoint.depth) or out.depth)
    if cpDepth >= chapter.startDepth and cpDepth <= chapter.endDepth then
      checkpoint.depth = cpDepth
      checkpoint.dungeonId = chapter.dungeonId
      checkpoint.mode = "story"
      checkpoint.storyChapterId = chapter.id
      if not Data.characters[checkpoint.characterId] then
        checkpoint.characterId = "amado"
      end
      out.active = true
      out.depth = cpDepth
      out.characterId = checkpoint.characterId
      out.checkpoint = checkpoint
    end
  end
  return out
end

local function normalize(data)
  local out = defaults()
  if type(data) ~= "table" then return out end

  out.version = VERSION
  out.coins = math.max(0, math.floor(tonumber(data.coins) or 0))
  out.bestLevel = math.max(0, math.floor(tonumber(data.bestLevel) or 0))

  if type(data.upgrades) == "table" then
    for id, definition in pairs(Data.upgrades) do
      local level = math.floor(tonumber(data.upgrades[id]) or 0)
      out.upgrades[id] = math.max(0, math.min(level, definition.maxLevel))
    end
  end

  if type(data.unlocked) == "table" then
    for id, value in pairs(data.unlocked) do
      if type(id) == "string" then
        out.unlocked[id] = value and true or false
      end
    end
  end
  out.unlocked.cripta = true

  if type(data.characters) == "table" then
    for id in pairs(Data.characters) do
      out.characters[id] = data.characters[id] and true or false
    end
  end
  out.characters.amado = true

  if type(data.settings) == "table" then
    out.settings.musicVolume = clamp01(data.settings.musicVolume)
      or out.settings.musicVolume
    out.settings.effectsVolume = clamp01(data.settings.effectsVolume)
      or out.settings.effectsVolume
  end

  out.story = normalizeStory(data.story)
  return out
end

function Save.load()
  Save.data = defaults()

  local data = readSave(FILE)
  local fromTemp = false
  if not data then
    data = readSave(TEMP_FILE)
    fromTemp = data ~= nil
  end
  if not data then return end

  Save.data = normalize(data)
  if fromTemp then
    -- El principal quedó incompleto: se reescribe desde la copia temporal.
    Save.save()
  end
end

function Save.save()
  if type(Save.data) ~= "table" then return false end

  Save.data.version = VERSION
  local ok, content = pcall(Json.encode, Save.data)
  if not ok or type(content) ~= "string" then return false end

  -- Escribir primero la copia temporal protege contra Android matando el
  -- proceso a mitad de la escritura principal: la próxima carga recupera
  -- el progreso desde aquí. La copia se conserva como respaldo.
  if not writeSave(TEMP_FILE, content) then return false end
  if not writeSave(FILE, content) then return false end
  return true
end

-- Borra el progreso persistente y deja una partida limpia con ajustes por
-- defecto. Se escribe de inmediato para que el borrado sea definitivo.
-- Los ajustes de audio viven en el guardado para sobrevivir entre sesiones.
function Save.reset()
  if love and love.filesystem and love.filesystem.remove then
    pcall(love.filesystem.remove, FILE)
    pcall(love.filesystem.remove, TEMP_FILE)
  end
  Save.data = defaults()
  Save.save()
  return Save.data
end

function Save.hasStoryCheckpoint()
  local story = Save.data and Save.data.story
  return story ~= nil
    and story.active == true
    and type(story.checkpoint) == "table"
end

function Save.setStoryCheckpoint(chapterId, snapshot)
  if type(Save.data) ~= "table" or not validCheckpoint(snapshot) then
    return false
  end
  local chapter = Data.story.chapterById[chapterId]
  if not chapter then return false end
  local depth = math.floor(tonumber(snapshot.depth) or 0)
  if depth < chapter.startDepth or depth > chapter.endDepth then
    return false
  end

  local story = Save.data.story
  story.active = true
  story.completed = false
  story.chapterId = chapterId
  story.depth = math.max(
    chapter.startDepth,
    math.min(math.floor(tonumber(snapshot.depth) or chapter.startDepth), chapter.endDepth)
  )
  if Data.characters[snapshot.characterId] then
    story.characterId = snapshot.characterId
  end
  snapshot.mode = "story"
  snapshot.storyChapterId = chapterId
  story.checkpoint = snapshot
  Save.save()
  return true
end

function Save.completeStory()
  local story = Save.data and Save.data.story
  if not story then return false end
  story.active = false
  story.completed = true
  story.checkpoint = nil
  Save.save()
  return true
end

function Save.resetStory()
  if type(Save.data) ~= "table" then return false end
  Save.data.story = defaultStory()
  Save.save()
  return true
end

function Save.setVolumes(musicVolume, effectsVolume)
  if type(Save.data) ~= "table" then return end
  local settings = Save.data.settings
  settings.musicVolume = clamp01(musicVolume) or settings.musicVolume
  settings.effectsVolume = clamp01(effectsVolume) or settings.effectsVolume
  Save.save()
end

function Save.unlock(id)
  if not Save.data.unlocked[id] then
    Save.data.unlocked[id] = true
    Save.save()
  end
end

function Save.isCharacterUnlocked(id)
  return Save.data.characters[id] == true
end

function Save.unlockCharacter(id)
  if not Data.characters[id] then return false end
  if Save.data.characters[id] then return false end
  Save.data.characters[id] = true
  Save.save()
  return true
end

function Save.recordLevel(level)
  if level > Save.data.bestLevel then
    Save.data.bestLevel = level
  end
end

function Save.upgradeCost(id)
  local def = Data.upgrades[id]
  local level = Save.data.upgrades[id] or 0
  return math.floor(def.baseCost * (Data.economy.costGrowth ^ level))
end

function Save.canBuy(id)
  local def = Data.upgrades[id]
  local level = Save.data.upgrades[id] or 0
  if level >= def.maxLevel then return false end
  return Save.data.coins >= Save.upgradeCost(id)
end

function Save.buy(id)
  if not Save.canBuy(id) then return false end
  Save.data.coins = Save.data.coins - Save.upgradeCost(id)
  Save.data.upgrades[id] = Save.data.upgrades[id] + 1
  Save.save()
  return true
end

function Save.stat(id)
  local def = Data.upgrades[id]
  local level = Save.data.upgrades[id] or 0
  return def.base + def.step * level
end

return Save
