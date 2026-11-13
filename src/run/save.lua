-- save.lua: progreso persistente en JSON versionado dentro de love.filesystem.
local Data = require("src.run.data")
local Json = require("src.utils.json")

local Save = {}
local FILE = "save.json"
local TEMP_FILE = "save.json.tmp"
local VERSION = 3

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

local function defaults()
  return {
    version = VERSION,
    coins = 0,
    bestLevel = 0,
    upgrades = { damage = 0, maxHp = 0, speed = 0 },
    unlocked = { cripta = true, forja = false, catedral = false },
    characters = { amado = true, mar = false, amileth = false },
    settings = { musicVolume = 0.6, effectsVolume = 0.8 },
  }
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
