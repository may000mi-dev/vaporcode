-- data.lua: raíz de composición de las definiciones estáticas.
-- El contenido vive por dominio en src/data/; este archivo expone la API
-- plana (Data.enemyTypes, Data.items, ...) que consume todo el juego, así
-- que mover datos entre archivos no rompe llamadas existentes.
local Data = {}

local Abilities = require("src.data.abilities")
local Balance = require("src.data.balance")
local Bosses = require("src.data.bosses")
local Characters = require("src.data.characters")
local Dungeons = require("src.data.dungeons")
local Enemies = require("src.data.enemies")
local Items = require("src.data.items")
local Story = require("src.data.story")
local Upgrades = require("src.data.upgrades")

Data.abilities = Abilities.abilities
Data.mana = Abilities.mana
Data.exchangeable = Abilities.exchangeable
Data.exchangeableSet = Abilities.exchangeableSet

Data.player = Balance.player
Data.economy = Balance.economy
Data.floor = Balance.floor
Data.valve = Balance.valve
Data.destructible = Balance.destructible
Data.chest = Balance.chest
Data.dungeonGen = Balance.dungeonGen
Data.camera = Balance.camera
Data.projectile = Balance.projectile
Data.rhythm = Balance.rhythm
Data.colors = Balance.colors

Data.characters = Characters.characters
Data.characterOrder = Characters.characterOrder
Data.characterItem = Characters.characterItem
Data.mark = Characters.mark

Data.dungeons = Dungeons.dungeons
Data.dungeonById = Dungeons.dungeonById
Data.bossEvery = Dungeons.bossEvery
Data.brokenAutomata = Bosses.brokenAutomata
Data.story = Story

-- Los jefes viven en bosses.lua pero comparten el índice de enemigos
-- (las mazmorras los referencian con la misma clave que a un enemigo).
Data.enemyTypes = {}
for id, def in pairs(Enemies.enemyTypes) do
  Data.enemyTypes[id] = def
end
for id, def in pairs(Bosses.types) do
  Data.enemyTypes[id] = def
end
Data.bestiary = {}
Data.bestiaryOrder = {}
for _, id in ipairs(Enemies.bestiaryOrder) do
  local info = Enemies.bestiary[id]
  if info then
    Data.bestiary[id] = {
      name = info.name,
      desc = info.desc,
      boss = false,
    }
    Data.bestiaryOrder[#Data.bestiaryOrder + 1] = id
  end
end
for _, id in ipairs(Bosses.bestiaryOrder) do
  local info = Bosses.bestiary[id]
  if info then
    Data.bestiary[id] = {
      name = info.name,
      desc = info.desc,
      boss = true,
    }
    Data.bestiaryOrder[#Data.bestiaryOrder + 1] = id
  end
end

Data.elite = Enemies.elite
Data.hazards = Enemies.hazards
Data.enemyAI = Enemies.enemyAI
Data.spawn = Enemies.spawn
Data.threat = Enemies.threat

Data.items = Items.items
Data.itemPool = Items.itemPool
Data.resonanceItem = Items.resonanceItem
Data.itemLifetime = Items.itemLifetime
Data.itemBlinkTime = Items.itemBlinkTime
Data.itemPickupRadius = Items.itemPickupRadius
Data.petLeash = Items.petLeash
Data.inventory = Items.inventory
Data.alchemy = Items.alchemy
Data.shop = Items.shop
Data.drop = Items.drop
Data.pets = Items.pets

Data.upgrades = Upgrades.upgrades
Data.upgradeOrder = Upgrades.upgradeOrder

return Data
