-- floors.lua: arranque de partida, construcción de piso y reintento exacto.
-- enter/retryFloor se exponen con (run, ...); run.lua los envuelve porque
-- la máquina de estados los invoca por punto: Run.enter(...).
local Data = require("src.run.data")
local Save = require("src.run.save")
local Dungeon = require("src.run.dungeon")
local Player = require("src.run.player")
local Camera = require("src.utils.camera")
local Valve = require("src.run.valve")
local Chest = require("src.run.chest")
local Pet = require("src.run.pet")
local Aim = require("src.run.aim")
local Joystick = require("src.utils.joystick")
local Buttons = require("src.utils.buttons")
local Input = require("src.utils.input")
local Rhythm = require("src.run.rhythm")
local Audio = require("src.utils.audio")
local Sandbox = require("src.run.sandbox")
local Floor = require("src.run.floor")
local Story = require("src.run.story")
local FX = require("src.run.fx")
local Util = require("src.utils.util")

local Floors = {}

function Floors.enter(run, dungeonId, characterId, abilityId, options)
  options = options or {}
  run.def = Data.dungeonById[dungeonId] or Data.dungeons[1]
  run.sandbox = run.def.sandbox == true
  run.mode = options.mode == "story" and "story" or "free"
  run.storyChapterId = nil
  run.storyChapter = nil
  run.storyPendingIntroScene = nil
  if run.mode == "story" then
    local chapter = Data.story.chapterById[options.chapterId]
      or Data.story.chapterById.cripta
    run.storyChapter = chapter
    run.storyChapterId = chapter.id
    run.def = Data.dungeonById[chapter.dungeonId] or run.def
  end

  if characterId
    and Data.characters[characterId]
    and (run.sandbox or Save.isCharacterUnlocked(characterId)) then
    run.characterId = characterId
  else
    run.characterId = "amado"
  end
  run.abilitySlot1 = nil
  run.abilitySlot2 = nil
  run.abilitySlot3 = "shield"
  run.abilitySlot4 = "turbo"
  if abilityId and Data.exchangeableSet[abilityId] then
    run.abilitySlot1 = abilityId
  end

  run.seed = options.seed
    or (os.time() + math.floor(love.timer.getTime() * 1000))
  run.depth = run.mode == "story" and run.storyChapter.startDepth or 1
  run.exitKind = "normal"
  run.playerLevel = 1
  run.kills = 0
  run.coinsEarned = 0
  run.over = false
  run.paused = false
  run.exitOpen = false
  run.exitTimer = 0
  run.cooldowns = {}
  run.turboTimer = 0
  run.manaMax = Data.mana.max
  run.mana = run.manaMax
  run.manaIdleTimer = 0
  run.manaFlash = 0
  run.abilityLockTimer = 0
  run.timeLeft = run.sandbox and 0 or Data.floor.timeLimit
  run.floorSnapshot = nil
  run.shadow = nil
  run.aim = Aim.new()
  run.gameOverInfo = nil
  run.projectiles = {}
  run.valves = {}
  run.chests = {}
  run.itemDrops = {}
  run.hazards = {}
  run.inventory = {}
  run.storage = {}
  -- Estado por partida que no debe sobrevivir a una run anterior. Sin este
  -- reinicio, una mascota o pasiva de la run pasada seguiría activa aunque
  -- su ítem ya no exista en el inventario.
  run.passiveStacks = {}
  run.pets = {}
  run.petSnapshot = nil
  run.fluteReady = false
  run.inventoryFullTimer = 0
  run.tornado = nil
  run.unlockNotices = {}
  run.overlay = nil
  run.storyScene = nil
  run.storySceneIndex = nil
  run.storySceneDone = nil
  run.sandboxInvuln = false
  run.pauseExitConfirm = false
  run.pauseExitTimer = 0
  run.selectedInventory = 1
  run.selectedStorage = 1
  run.selectionSection = "active"
  run.pendingStorageIndex = nil
  run.shopTab = "buy"
  run.touchUI = Util.isMobile()
  run.joystick = Joystick.new()
  run.buttons = Buttons.new()

  local character = Data.characters[run.characterId]
  run.stats = {
    damage = Save.stat("damage"),
    maxHp = Save.stat("maxHp"),
    speed = Save.stat("speed"),
    attackRate = character.attackRate,
  }

  run.hp = run.stats.maxHp
  run.xp = 0
  run.xpToNext = run:xpForLevel(run.playerLevel)

  if run.sandbox then
    Sandbox.reset()
  end

  if run.mode == "story" and options.intro ~= false then
    run.storyPendingIntroScene = run.storyChapter.introScene
  end

  FX.clear()
  Input.reset()
  Rhythm.enter(run.def.song)
  Audio.startMusic(run.def.song.bpm)
  run:enterLevel()
end

function Floors.enterLevel(run)
  -- La semilla de la partida hace reproducibles todos sus pisos.
  local seed = run.seed + run.depth * 7919
  run.dungeon = Dungeon.new({ depth = run.depth }, seed)

  local px, py = run.dungeon:spawnPoint()
  run.player = Player.new(px, py, run.characterId)
  run.player:setupShield(run.stats.maxHp)
  Camera.reset(px, py)
  run.spawnX = px
  run.spawnY = py
  run.exitX, run.exitY = run.dungeon:exitPoint()
  run.exitOpen = false
  run.exitTimer = 0
  run.enemies = {}
  run.projectiles = {}
  run.valves = {}
  run.chests = {}
  run.itemDrops = {}
  run.hazards = {}
  run.tornado = nil
  run.enemyCount = 0
  run.boss = nil
  run.shadow = nil
  run.manaFlash = 0
  run.abilityLockTimer = 0
  if run.aim then
    run.aim:cancel()
  end

  for _, spot in ipairs(run.dungeon.valveSpots) do
    run.valves[#run.valves + 1] = Valve.new(spot.x, spot.y)
  end

  for _, spot in ipairs(run.dungeon.chestSpots) do
    local lootIndex = ((spot.tx * 31 + spot.ty * 17 + run.depth * 13)
      % 997) + 1
    run.chests[#run.chests + 1] = Chest.new(
      spot.x,
      spot.y,
      lootIndex,
      "floor"
    )
  end

  if run.petSnapshot then
    run.pets = {}
    for index, data in ipairs(run.petSnapshot) do
      local pet = Pet.new(data.kind, px, py, data)
      if pet then
        pet:placeNear(run.player, index)
        run.pets[#run.pets + 1] = pet
      end
    end
    run.petSnapshot = nil
  else
    for index, pet in ipairs(run.pets) do
      if not pet.dead then
        pet:placeNear(run.player, index)
      end
    end
  end

  FX.clear()
  run.timeLeft = run.sandbox and 0 or Data.floor.timeLimit
  run:spawnEnemies()
  run.exitKind = Story.exitKind(run)
  run.floorSnapshot = Floor.capture(run)
  if run.mode == "story" then
    run:saveStoryCheckpoint()
    local sceneId = run.storyPendingIntroScene
    run.storyPendingIntroScene = nil
    if sceneId then
      run:startStoryScene(sceneId, nil)
    end
  end
end

function Floors.retryFloor(run, snapshot)
  if not Floor.restore(run, snapshot) then
    Floors.enter(run, "cripta")
    return
  end

  run.def = Data.dungeonById[snapshot.dungeonId] or Data.dungeons[1]
  run.sandbox = run.def.sandbox == true
  run.storyChapter = run.storyChapterId
    and Data.story.chapterById[run.storyChapterId]
    or nil
  if run.mode == "story" and not run.storyChapter then
    run.mode = "free"
    run.storyChapterId = nil
  end
  run.storyPendingIntroScene = nil
  run.storyScene = nil
  run.storySceneIndex = nil
  run.storySceneDone = nil
  run.over = false
  run.paused = false
  run.exitOpen = false
  run.exitTimer = 0
  run.manaFlash = 0
  run.shadow = nil
  run.aim = Aim.new()
  run.gameOverInfo = nil
  run.projectiles = {}
  run.valves = {}
  run.chests = {}
  run.itemDrops = {}
  run.hazards = {}
  run.tornado = nil
  run.unlockNotices = {}
  run.overlay = nil
  run.selectedInventory = 1
  run.selectedStorage = 1
  run.selectionSection = "active"
  run.pendingStorageIndex = nil
  run.shopTab = "buy"
  run.touchUI = Util.isMobile()
  run.joystick = Joystick.new()
  run.buttons = Buttons.new()

  FX.clear()
  Input.reset()
  Rhythm.enter(run.def.song)
  Audio.startMusic(run.def.song.bpm)
  run:enterLevel()
  return true
end

return Floors
