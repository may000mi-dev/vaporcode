-- save.lua: progreso persistente en JSON versionado dentro de love.filesystem.
local Data = require("src.run.data")
local Json = require("src.utils.json")

local Save = {}
local FILE = "save.json"
local TEMP_FILE = "save.json.tmp"
local VERSION = 5

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

local function defaultProgress()
  return {
    upgrades = { damage = 0, maxHp = 0, speed = 0 },
    resonance = 0,
    storyCompleted = false,
  }
end

local function defaults()
  local progress = {}
  for _, id in ipairs(Data.characterOrder) do
    progress[id] = defaultProgress()
  end

  return {
    version = VERSION,
    coins = 0,
    bestLevel = 0,
    unlocked = { cripta = true, forja = false, catedral = false, torre = false },
    characters = { amado = true, mar = false, amileth = false },
    progress = progress,
    bestiary = {},
    settings = { musicVolume = 0.6, effectsVolume = 0.8 },
    story = defaultStory(),
  }
end

local function allStoriesCompleted(progress)
  for _, id in ipairs(Data.characterOrder) do
    local entry = progress and progress[id]
    if not entry or not entry.storyCompleted then
      return false
    end
  end
  return true
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
  if Data.characters[data.characterId] then
    out.characterId = data.characterId
  end

  local chapter = type(data.chapterId) == "string"
    and Data.story.chapterById[data.chapterId]
    or nil
  if not chapter then return out end

  out.chapterId = chapter.id
  local depth = math.floor(tonumber(data.depth) or chapter.startDepth)
  out.depth = math.max(chapter.startDepth, math.min(depth, chapter.endDepth))

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

  -- La versión 4 guardaba un solo nivel de mejora para toda la cuenta. Al
  -- migrar, ese progreso se reparte entre los tres personajes para no quitar
  -- fuerza a quien ya había invertido monedas.
  local legacyUpgrades = type(data.upgrades) == "table" and data.upgrades or nil
  local savedProgress = type(data.progress) == "table" and data.progress or {}

  for _, characterId in ipairs(Data.characterOrder) do
    local source = type(savedProgress[characterId]) == "table"
      and savedProgress[characterId]
      or nil
    local levels = source and type(source.upgrades) == "table"
      and source.upgrades
      or legacyUpgrades

    if type(levels) == "table" then
      for id, definition in pairs(Data.upgrades) do
        local level = math.floor(tonumber(levels[id]) or 0)
        out.progress[characterId].upgrades[id] = math.max(
          0,
          math.min(level, definition.maxLevel)
        )
      end
    end

    if source then
      out.progress[characterId].resonance = math.max(
        0,
        math.floor(tonumber(source.resonance) or 0)
      )
      out.progress[characterId].storyCompleted = source.storyCompleted and true or false
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

  if type(data.bestiary) == "table" then
    for id, seen in pairs(data.bestiary) do
      if type(id) == "string" and seen and Data.bestiary[id] then
        out.bestiary[id] = true
      end
    end
  end

  if type(data.settings) == "table" then
    out.settings.musicVolume = clamp01(data.settings.musicVolume)
      or out.settings.musicVolume
    out.settings.effectsVolume = clamp01(data.settings.effectsVolume)
      or out.settings.effectsVolume
  end

  out.story = normalizeStory(data.story)

  -- El guardado anterior solo tenía un final. Se adjudica al personaje que
  -- completó la campaña y se conserva la compatibilidad con story.completed.
  local completedCharacter = out.story.characterId or "amado"
  if out.story.completed and out.progress[completedCharacter] then
    out.progress[completedCharacter].storyCompleted = true
  end

  out.unlocked.torre = allStoriesCompleted(out.progress)
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

function Save.completeStory(characterId)
  local story = Save.data and Save.data.story
  if not story then return false end

  characterId = characterId or story.characterId or "amado"
  if not Save.data.progress[characterId] then
    characterId = "amado"
  end

  Save.data.progress[characterId].storyCompleted = true
  story.active = false
  story.completed = true
  story.characterId = characterId
  story.checkpoint = nil

  local allCompleted = allStoriesCompleted(Save.data.progress)
  Save.data.unlocked.torre = allCompleted
  Save.save()
  return true, allCompleted
end

function Save.resetStory()
  if type(Save.data) ~= "table" then return false end
  Save.data.story = defaultStory()
  Save.save()
  return true
end

function Save.progressFor(characterId)
  if type(Save.data) ~= "table" then return nil end
  local progress = Save.data.progress[characterId]
  if progress then return progress end
  progress = defaultProgress()
  Save.data.progress[characterId] = progress
  return progress
end

function Save.isStoryCompleted(characterId)
  local progress = Save.progressFor(characterId)
  return progress ~= nil and progress.storyCompleted == true
end

function Save.storyCompletionCount()
  local count = 0
  for _, id in ipairs(Data.characterOrder) do
    if Save.isStoryCompleted(id) then
      count = count + 1
    end
  end
  return count
end

function Save.allStoriesCompleted()
  return allStoriesCompleted(Save.data and Save.data.progress)
end

function Save.addResonance(characterId, amount)
  local progress = Save.progressFor(characterId)
  if not progress then return false end
  amount = math.max(0, math.floor(tonumber(amount) or 0))
  if amount == 0 then return false end
  progress.resonance = progress.resonance + amount
  Save.save()
  return true
end

function Save.upgradeLevel(upgradeId, characterId)
  local progress = Save.progressFor(characterId)
  if not progress or not Data.upgrades[upgradeId] then return 0 end
  return progress.upgrades[upgradeId] or 0
end

function Save.useResonance(characterId, upgradeId)
  local progress = Save.progressFor(characterId)
  local def = Data.upgrades[upgradeId]
  if not progress or not def then return false end
  if progress.resonance <= 0 then return false end
  if (progress.upgrades[upgradeId] or 0) >= def.maxLevel then return false end

  progress.resonance = progress.resonance - 1
  progress.upgrades[upgradeId] = (progress.upgrades[upgradeId] or 0) + 1
  Save.save()
  return true
end

function Save.isDungeonUnlocked(id)
  if id == "torre" then
    return Save.allStoriesCompleted()
  end
  return Save.data.unlocked[id] == true
end

function Save.discoverEnemy(id)
  if type(id) ~= "string" or not Data.enemyTypes[id] then return false end
  if Save.data.bestiary[id] then return false end
  Save.data.bestiary[id] = true
  Save.save()
  return true
end

function Save.isEnemyDiscovered(id)
  return Save.data.bestiary[id] == true
end

function Save.bestiaryCount()
  local count = 0
  for id in pairs(Save.data.bestiary) do
    if Data.bestiary[id] then count = count + 1 end
  end
  return count
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

function Save.stat(id, characterId)
  local def = Data.upgrades[id]
  local level = Save.upgradeLevel(id, characterId)
  return def.base + def.step * level
end

return Save
