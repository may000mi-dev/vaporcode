-- run.lua: orquestador de la partida: ciclo principal, dibujo e input.
-- La lógica de juego vive en módulos hermanos (spawner, combat, loot, ...)
-- cuyas funciones se montan aquí como métodos para conservar la API
-- Run:metodo(...) que usa el resto del juego y los tests.
local Data = require("src.run.data")
local State = require("src.estados")
local Save = require("src.run.save")
local Rhythm = require("src.run.rhythm")
local Camera = require("src.utils.camera")
local Screen = require("src.utils.screen")
local FX = require("src.run.fx")
local Hud = require("src.run.hud")
local Joystick = require("src.utils.joystick")
local Buttons = require("src.utils.buttons")
local Input = require("src.utils.input")
local Abilities = require("src.run.abilities")
local Backpack = require("src.run.backpack")
local Shop = require("src.run.shop")
local Sandbox = require("src.run.sandbox")
local Audio = require("src.utils.audio")
local Floors = require("src.run.floors")
local StoryUI = require("src.run.story_ui")
local Threat = require("src.run.threat")

local Run = {
  def = nil,
  depth = 1,
  playerLevel = 1,
  hp = 100,
  xp = 0,
  xpToNext = 20,
  kills = 0,
  coinsEarned = 0,
  enemies = {},
  projectiles = {},
  valves = {},
  chests = {},
  itemDrops = {},
  hazards = {},
  passiveStacks = {},
  pets = {},
  petSnapshot = nil,
  tornado = nil,
  fluteReady = false,
  unlockNotices = {},
  player = nil,
  dungeon = nil,
  exitX = 0,
  exitY = 0,
  exitOpen = false,
  exitTimer = 0,
  paused = false,
  over = false,
  sandbox = false,
  mode = "free",
  storyChapterId = nil,
  storyChapter = nil,
  storyPendingIntroScene = nil,
  storyScene = nil,
  storySceneIndex = nil,
  storySceneDone = nil,
  exitKind = "normal",
  sandboxInvuln = false,
  pauseExitConfirm = false,
  pauseExitTimer = 0,
  characterId = "amado",
  abilitySlot1 = nil,
  abilitySlot2 = nil,
  abilitySlot3 = "shield",
  abilitySlot4 = "turbo",
  cooldowns = {},
  inventory = {},
  storage = {},
  inventoryFullTimer = 0,
  overlay = nil,
  selectedInventory = 1,
  selectedStorage = 1,
  selectionSection = "active",
  pendingStorageIndex = nil,
  shopTab = "buy",
  turboTimer = 0,
  mana = Data.mana.max,
  manaMax = Data.mana.max,
  manaIdleTimer = 0,
  manaFlash = 0,
  abilityLockTimer = 0,
  timeLeft = Data.floor.timeLimit,
  floorSnapshot = nil,
  shadow = nil,
  aim = nil,
  joystick = nil,
  buttons = nil,
  touchUI = false,
  stats = {},
  gameOverInfo = nil,
}

-- Sistemas con firma (run, ...). El envoltorio sys() trunca require a un
-- solo valor: Lua 5.4 devuelve (modulo, ruta) y un constructor de tabla
-- colaría la ruta como elemento extra si el require fuera el último.
local function sys(name)
  local module = require(name)
  if type(module) ~= "table" then
    error(name .. " debe devolver una tabla, devolvió " .. type(module))
  end
  return module
end

function Run.enter(dungeonId, characterId, abilityId, options)
  if type(dungeonId) == "table" then
    return Run.retryFloor(dungeonId)
  end

  if type(options) == "table" and options.resume then
    local story = Save.data.story
    local chapter = story and story.chapterId
      and Data.story.chapterById[story.chapterId]
      or nil
    if not story or not story.active or not story.checkpoint or not chapter then
      return Floors.enter(
        Run,
        "cripta",
        characterId,
        nil,
        { mode = "story", chapterId = "cripta" }
      )
    end

    local resumeCharacter = story.characterId or characterId
    local checkpoint = story.checkpoint
    Floors.enter(
      Run,
      chapter.dungeonId,
      resumeCharacter,
      nil,
      { mode = "story", chapterId = chapter.id, intro = false }
    )
    if not Run.retryFloor(checkpoint) then
      Floors.enter(
        Run,
        chapter.dungeonId,
        resumeCharacter,
        nil,
        { mode = "story", chapterId = chapter.id, intro = false }
      )
    end
    return
  end

  return Floors.enter(Run, dungeonId, characterId, abilityId, options)
end

function Run.retryFloor(snapshot)
  return Floors.retryFloor(Run, snapshot)
end

-- enterLevel se monta como método: progresión y el propio floors lo
-- invocan vía run:enterLevel().
Run.enterLevel = Floors.enterLevel

function Run:shake(magnitude, duration)
  Camera.shake(magnitude, duration)
end

function Run:notify(text, color)
  if Run.player then
    FX.add(text, Run.player.x, Run.player.y - 34, color or { 1.00, 0.88, 0.45 })
  end
end

function Run:clearInput()
  if Run.joystick then
    Run.joystick:cancel()
  end
  if Run.buttons then
    Run.buttons:clear()
  end
  if Run.aim then
    Run.aim:cancel()
  end
  Camera.cancelDrag()
end

-- Las monedas de la sala de pruebas no deben tocar el guardado real.
function Run:addCoins(amount)
  amount = math.max(0, math.floor(amount or 0))
  Run.coinsEarned = Run.coinsEarned + amount
  if not Run.sandbox then
    Save.data.coins = Save.data.coins + amount
  end
end

-- Persiste monedas y desbloqueos de la run actual. Android puede matar el
-- proceso en segundo plano sin llamar love.quit; por eso se guarda al pausar.
function Run:autosave()
  if Run.sandbox then return end
  if type(Save.data) == "table" then
    Save.save()
  end
end

function Run:setPaused(value)
  Run.paused = value and true or false
  Run.pauseExitConfirm = false
  Run.pauseExitTimer = 0
  if Run.paused then
    if Run.overlay ~= "story" then
      Run.overlay = nil
    end
    Run:clearInput()
    Audio.pauseMusic()
    Run:autosave()
  else
    Audio.resumeMusic()
  end
end

-- Primer toque arma la confirmación; el segundo sale y conserva monedas y
-- mejoras ya guardadas. El temporizador se descuenta en Run.update.
function Run:requestExitToMenu()
  if not Run.pauseExitConfirm then
    Run.pauseExitConfirm = true
    Run.pauseExitTimer = 3
    return
  end
  Run:exitToMenu()
end

function Run:exitToMenu()
  Run.pauseExitConfirm = false
  Run.pauseExitTimer = 0
  Audio.stopMusic()
  Run:autosave()
  Run:clearInput()
  State.switch("menu")
end

function Run:toggleSandbox()
  if not Run.sandbox or Run.paused then return end
  if Run.overlay == "sandbox" then
    Run.overlay = nil
  else
    Run.overlay = "sandbox"
  end
  Run:clearInput()
end

function Run:updateFeatures(dt)
  for _, valve in ipairs(Run.valves) do
    valve:update(dt, Run)
  end
  if Run.over then return end

  for _, chest in ipairs(Run.chests) do
    chest:update(dt, Run)
  end
end

function Run:updateItemDrops(dt)
  for _, item in ipairs(Run.itemDrops) do
    if not item.dead then
      item:update(dt, Run)
    end
  end
end

function Run:updatePets(dt)
  for _, pet in ipairs(Run.pets) do
    if not pet.dead then
      pet:update(dt, Run)
    end
  end
end

function Run:cleanup()
  local n = 0
  for i = 1, #Run.enemies do
    local enemy = Run.enemies[i]
    if not enemy.dead then
      n = n + 1
      Run.enemies[n] = enemy
    end
  end
  for i = n + 1, #Run.enemies do
    Run.enemies[i] = nil
  end

  n = 0
  for i = 1, #Run.projectiles do
    local projectile = Run.projectiles[i]
    if not projectile.dead then
      n = n + 1
      Run.projectiles[n] = projectile
    end
  end
  for i = n + 1, #Run.projectiles do
    Run.projectiles[i] = nil
  end

  n = 0
  for i = 1, #Run.itemDrops do
    local item = Run.itemDrops[i]
    if not item.dead then
      n = n + 1
      Run.itemDrops[n] = item
    end
  end
  for i = n + 1, #Run.itemDrops do
    Run.itemDrops[i] = nil
  end

  n = 0
  for i = 1, #Run.hazards do
    local hazard = Run.hazards[i]
    if not hazard.dead then
      n = n + 1
      Run.hazards[n] = hazard
    end
  end
  for i = n + 1, #Run.hazards do
    Run.hazards[i] = nil
  end

  n = 0
  for i = 1, #Run.pets do
    local pet = Run.pets[i]
    if not pet.dead then
      n = n + 1
      Run.pets[n] = pet
    end
  end
  for i = n + 1, #Run.pets do
    Run.pets[i] = nil
  end

  if Run.boss and Run.boss.dead then
    Run.boss = nil
  end

  Run.enemyCount = #Run.enemies
end

function Run.update(dt)
  if Run.over then return end

  if (Run.pauseExitTimer or 0) > 0 then
    Run.pauseExitTimer = math.max(0, Run.pauseExitTimer - dt)
    if Run.pauseExitTimer == 0 then
      Run.pauseExitConfirm = false
    end
  end

  if Run.paused then
    return
  end

  if Run.overlay == "sandbox" then
    return
  end

  if Run.overlay == "story" then
    StoryUI.update(Run, dt)
    return
  end

  Run:updateMana(dt)
  Run.abilityLockTimer = math.max(0, (Run.abilityLockTimer or 0) - dt)
  Run.inventoryFullTimer = math.max(0, (Run.inventoryFullTimer or 0) - dt)
  if not Run.sandbox then
    Run.timeLeft = math.max(0, (Run.timeLeft or Data.floor.timeLimit) - dt)
    if Run.timeLeft <= 0 then
      Run:gameOver("timeout")
      return
    end
  end

  Rhythm.update(dt)
  Abilities.update(Run, dt)
  Run.turboTimer = math.max(0, Run.turboTimer - dt)

  if Run.shadow then
    Run.shadow:update(dt, Run)
    if Run.shadow.dead then
      Run.shadow = nil
    end
  end

  Input.pollKeyboard()
  local dx, dy = Input.consumeMove()
  local joystick = Run.joystick
  if joystick and joystick.active then
    dx = joystick.dx
    dy = joystick.dy
  end

  Run.player:update(dt, dx, dy, Run)
  Camera.follow(Run.player.x, Run.player.y)
  Camera.update(dt)
  Run.player.invuln = math.max(0, Run.player.invuln - dt)
  Run.player.shieldTimer = math.max(0, Run.player.shieldTimer - dt)

  for i = 1, 4 do
    if Input.consumeAbility(i) then
      Run:useAbility(i)
    end
  end

  for _, enemy in ipairs(Run.enemies) do
    if not enemy.dead then
      enemy:update(dt, Run)
    end
  end

  for _, projectile in ipairs(Run.projectiles) do
    if not projectile.dead then
      projectile:update(dt, Run)
    end
  end

  Run:updateFeatures(dt)
  for _, hazard in ipairs(Run.hazards) do
    if not hazard.dead then
      hazard:update(dt, Run)
    end
  end
  Run:updateItemDrops(dt)
  Run:updatePets(dt)
  Run:updateTornado(dt)
  Run:cleanup()
  Threat.updateWaves(Run)
  FX.update(dt)
  Run:checkLevel(dt)

  if Run.over and State.name == "run" then
    Audio.stopMusic()
    State.switch("gameover", Run.gameOverInfo)
  end
end

function Run.draw()
  -- El exterior de la mazmorra se muestra siempre como oscuridad.
  love.graphics.setColor(0.02, 0.025, 0.035)
  love.graphics.rectangle("fill", 0, 0, Screen.width, Screen.height)

  Camera.push()
  Run.dungeon:draw(Camera)
  if not Run.sandbox then
    Run.dungeon:drawExit(
      Run.exitX,
      Run.exitY,
      Run.exitOpen,
      Run.exitKind,
      Run.storyChapter and Run.storyChapter.portalColor or nil
    )
  end
  for _, valve in ipairs(Run.valves) do
    valve:draw()
  end
  for _, chest in ipairs(Run.chests) do
    chest:draw()
  end
  for _, item in ipairs(Run.itemDrops) do
    item:draw()
  end
  for _, hazard in ipairs(Run.hazards) do
    hazard:draw()
  end
  Abilities.drawAim(Run)

  if Run.shadow then
    Run.shadow:draw()
  end

  for _, enemy in ipairs(Run.enemies) do
    enemy:draw()
  end
  for _, pet in ipairs(Run.pets) do
    pet:draw()
  end
  for _, projectile in ipairs(Run.projectiles) do
    projectile:draw()
  end

  Run:drawTornado()
  Run.player:draw(Run)
  FX.drawWorld()
  Camera.pop()

  Hud.draw(Run)

  if Run.touchUI then
    Run.buttons:draw(Run)
    Run.joystick:draw()
  end

  -- Los textos flotantes viven en coordenadas del mundo, pero van sobre el HUD.
  Camera.push()
  FX.drawToasts()
  Camera.pop()

  if Run.overlay == "backpack" then
    Backpack.draw(Run)
  elseif Run.overlay == "shop" then
    Shop.draw(Run)
  elseif Run.overlay == "sandbox" then
    Sandbox.draw(Run)
  elseif Run.overlay == "story" then
    StoryUI.draw(Run)
  end

  if Run.paused then
    Hud.drawPause(Run)
  end
end

function Run.drawDebug()
  Hud.drawDebug(Run)
end

function Run.keypressed(key, isrepeat)
  if Run.paused then
    Run:setPaused(false)
    return
  end

  if Run.overlay == "story" then
    StoryUI.keypressed(Run, key, isrepeat)
    return
  end

  if key == "escape" and Run.overlay then
    if Run.pendingStorageIndex then
      Run.pendingStorageIndex = nil
    else
      Run.overlay = nil
    end
    return
  end

  if key == "p" and not isrepeat then
    Run:setPaused(not Run.paused)
    return
  end

  if key == "m" and not isrepeat then
    Rhythm.toggleMute()
    return
  end

  if isrepeat then return end

  if key == "f2" then
    Run:toggleSandbox()
    return
  end

  if Run.paused then
    if key == "escape" then
      Run:requestExitToMenu()
    elseif key == "space" or key == "return" then
      Run:setPaused(false)
    end
    return
  end

  if Run.overlay == "sandbox" then
    return
  end

  if key == "b" then
    Run:toggleBackpack()
    return
  end

  if key == "v" then
    Run:openShop()
    return
  end

  if Run.overlay == "backpack" then
    if Run.pendingStorageIndex then return end
    local number = tonumber(key)
    if number and number >= 1 and number <= Data.inventory.maxActive then
      Run.selectionSection = "active"
      Run.selectedInventory = number
      return
    end
    if key == "tab" then
      Run:cycleSelection(1)
    elseif key == "q" then
      Run:assignSelected(1)
    elseif key == "w" then
      Run:assignSelected(2)
    elseif key == "x" then
      Run:discardSelected()
    elseif key == "return" or key == "space" then
      local status = Run:primarySelected()
      if status == "needs_swap" then
        Run.pendingStorageIndex = Run.selectedStorage
      elseif status == "full" then
        Run:notify("Guardados llenos", { 1.00, 0.45, 0.35 })
      end
    end
    return
  elseif Run.overlay then
    return
  end

  if key == "r" then
    Input.triggerAbility(1)
  elseif key == "f" then
    Input.triggerAbility(2)
  elseif key == "e" then
    Input.triggerAbility(3)
  elseif key == "t" then
    Input.triggerAbility(4)
  end
end

function Run:pressedAt(pointerId, x, y)
  if x < 0 or x > Screen.width or y < 0 or y > Screen.height then
    return
  end

  if Run.paused then
    if Hud.hitExitMenu(x, y) then
      Run:requestExitToMenu()
      return
    end
    Run:setPaused(false)
    return
  end

  if Run.overlay == "story" then
    StoryUI.pressed(Run, x, y)
    return
  end

  -- El panel de pruebas es modal: absorbe el toque antes del HUD para que
  -- los botones que quedan detrás no abran otra capa por accidente.
  if Run.overlay == "sandbox" then
    Sandbox.pressed(Run, x, y)
    return
  end

  if Hud.hitPause(x, y) then
    Run:setPaused(true)
    return
  end

  if Hud.hitBackpack(x, y) then
    Run:toggleBackpack()
    return
  end

  if Hud.hitShop(x, y) then
    Run:openShop()
    return
  end

  if Run.sandbox and Hud.hitSandbox(x, y) then
    Run:toggleSandbox()
    return
  end

  if Run.overlay == "backpack" then
    Backpack.pressed(Run, x, y)
    return
  elseif Run.overlay == "shop" then
    Shop.pressed(Run, x, y)
    return
  elseif Run.overlay then
    return
  end

  if Camera.beginDrag(pointerId, x, y) then
    return
  end

  if Run.joystick:press(pointerId, x, y) then
    return
  end

  if Run.touchUI then
    local button = Run.buttons:press(pointerId, x, y)
    if button then
      local abilityId = Run:abilityIdForSlot(button.slot)
      if button.slot == 1 or button.slot == 2 then
        if abilityId and not Run.aim.active then
          Run.aim:begin(pointerId, button.slot, abilityId, x, y)
        end
      else
        Input.triggerAbility(button.slot)
      end
      return
    end
  end
end

function Run:movedAt(pointerId, x, y)
  if Run.overlay then return end
  if Camera.moveDrag(pointerId, x, y) then return end
  if Run.aim:move(pointerId, x, y) then return end
  Run.joystick:move(pointerId, x, y)
end

function Run:releasedAt(pointerId, x, y)
  if Run.overlay then return end
  Camera.endDrag(pointerId)

  if Run.aim.active and Run.aim.pointerId == pointerId then
    Run.aim:move(pointerId, x, y)
    local state = Run.aim:release(pointerId)
    if state then
      Run:useAbility(state.slot, state)
    end
  end

  Run.joystick:release(pointerId)
  Run.buttons:release(pointerId)
end

function Run.mousepressed(x, y, button)
  if button ~= 1 then return end
  Run:pressedAt("mouse", x, y)
end

function Run.mousemoved(x, y)
  Run:movedAt("mouse", x, y)
end

function Run.mousereleased(x, y, button)
  if button ~= 1 then return end
  Run:releasedAt("mouse", x, y)
end

function Run.touchpressed(id, x, y)
  Run:pressedAt(id, x, y)
end

function Run.touchmoved(id, x, y)
  Run:movedAt(id, x, y)
end

function Run.touchreleased(id, x, y)
  Run:releasedAt(id, x, y)
end

function Run.focus(focused)
  if not focused and not Run.over then
    -- Al ir a segundo plano se pausa y se guarda el progreso alcanzado.
    Run:setPaused(true)
  end
end

-- Instalación al final: los sistemas no pueden pisar campos ni callbacks
-- ya definidos (update, draw, keypressed, ...); una colisión es error
-- inmediato en vez de comportamiento silenciosamente roto.
local systems = {
  sys("src.run.spawner"),
  sys("src.run.combat"),
  sys("src.run.tornado"),
  sys("src.run.walls"),
  sys("src.run.progression"),
  sys("src.run.inventory"),
  sys("src.run.storage"),
  sys("src.run.loot"),
  sys("src.run.slots"),
  sys("src.run.story_flow"),
}

for _, system in ipairs(systems) do
  for name, method in pairs(system) do
    if Run[name] ~= nil then
      error("Run ya define " .. name .. "; el sistema no puede repetirlo")
    end
    Run[name] = method
  end
end

return Run
