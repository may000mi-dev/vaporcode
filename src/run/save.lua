-- save.lua: progreso persistente en JSON versionado dentro de love.filesystem.
local Data = require("src.run.data")
local Json = require("src.utils.json")

local Save = {}
local FILE = "save.json"
local VERSION = 2

local function defaults()
  return {
    version = VERSION,
    coins = 0,
    bestLevel = 0,
    upgrades = { damage = 0, maxHp = 0, speed = 0 },
    unlocked = { cripta = true, forja = false, catedral = false },
    characters = { amado = true, mar = false, amileth = false },
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
  return out
end

function Save.load()
  Save.data = defaults()
  if not love.filesystem.getInfo(FILE) then return end

  local content = love.filesystem.read(FILE)
  if not content then return end

  local ok, data = pcall(Json.decode, content)
  if ok then
    Save.data = normalize(data)
  end
end

function Save.save()
  Save.data.version = VERSION
  local ok, content = pcall(Json.encode, Save.data)
  if not ok then return false end
  return love.filesystem.write(FILE, content)
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
