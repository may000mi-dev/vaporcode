-- progression.lua: XP, niveles, salida del piso, derrota y desbloqueos.
-- Las funciones reciben run como primer argumento y run.lua las monta
-- como métodos para conservar la API run:metodo(...).
local Data = require("src.run.data")
local Save = require("src.run.save")
local Story = require("src.run.story")
local State = require("src.estados")
local FX = require("src.run.fx")
local Audio = require("src.utils.audio")
local Util = require("src.utils.util")

local Progression = {}

function Progression.xpForLevel(run, level)
  return Data.player.xpBase + (level - 1) * Data.player.xpStep
end

function Progression.addXp(run, amount)
  run.xp = run.xp + amount

  while run.xp >= run.xpToNext do
    run.xp = run.xp - run.xpToNext
    run.playerLevel = run.playerLevel + 1
    run.xpToNext = run:xpForLevel(run.playerLevel)
    run.stats.damage = run.stats.damage + Data.player.levelDamage
    run.stats.maxHp = run.stats.maxHp + Data.player.levelMaxHp
    run.hp = math.min(run.stats.maxHp, run.hp + Data.player.levelHeal)
    run.player:refreshShield(run.stats.maxHp)
    FX.add(
      "¡Nivel " .. run.playerLevel .. "!",
      run.player.x,
      run.player.y - 26,
      { 1.00, 0.90, 0.35 }
    )
  end
end

function Progression.commitUnlockNotices(run)
  local messages = {}
  for _, id in ipairs(Data.characterOrder) do
    if run.unlockNotices[id] then
      Save.unlockCharacter(id)
      messages[#messages + 1] = "¡"
        .. Data.characters[id].name
        .. " desbloqueada!"
      run.unlockNotices[id] = nil
    end
  end
  return messages
end

function Progression.checkLevel(run, dt)
  if run.over then return end
  if run.sandbox then return end

  if run.exitOpen then
    local d2 = Util.dist2(
      run.player.x,
      run.player.y,
      run.exitX,
      run.exitY
    )
    if d2 < Data.player.exitRadius * Data.player.exitRadius then
      run:nextLevel()
    end
    return
  end

  if run.enemyCount == 0 then
    run.exitTimer = run.exitTimer + dt
    if run.exitTimer > Data.player.exitDelay then
      run.exitOpen = true
      FX.add(
        "¡Salida abierta!",
        run.exitX,
        run.exitY - 26,
        { 0.40, 1.00, 0.60 }
      )
    end
  else
    run.exitTimer = 0
  end
end

function Progression.nextLevel(run)
  if run.sandbox then return end
  if Story.isStory(run) then
    return Progression.nextStoryLevel(run)
  end

  local reached = run.depth + 1
  Save.recordLevel(reached)
  for _, dungeon in ipairs(Data.dungeons) do
    if reached >= dungeon.unlockLevel then
      Save.unlock(dungeon.id)
    end
  end
  Save.save()

  run.depth = reached
  run.hp = math.min(
    run.stats.maxHp,
    run.hp + math.floor(run.stats.maxHp * Data.player.nextLevelHealPercent)
  )
  local unlockMessages = run:commitUnlockNotices()
  run.overlay = nil
  run:enterLevel()
  FX.add(
    "Piso " .. run.depth,
    run.player.x,
    run.player.y - 26,
    { 0.50, 1.00, 0.70 }
  )
  for index, message in ipairs(unlockMessages) do
    FX.add(
      message,
      run.player.x,
      run.player.y - 44 - index * 16,
      { 1.00, 0.86, 0.35 }
    )
  end
end

function Progression.nextStoryLevel(run)
  local chapter = run.storyChapter
  if not chapter then return end

  if run.depth < chapter.endDepth then
    local reached = run.depth + 1
    Save.recordLevel(reached)
    for _, dungeon in ipairs(Data.dungeons) do
      if not dungeon.storyOnly and reached >= dungeon.unlockLevel then
        Save.unlock(dungeon.id)
      end
    end
    Save.save()

    run.depth = reached
    run.hp = math.min(
      run.stats.maxHp,
      run.hp + math.floor(run.stats.maxHp * Data.player.nextLevelHealPercent)
    )
    local unlockMessages = run:commitUnlockNotices()
    run.overlay = nil
    run:enterLevel()
    FX.add(
      "Piso " .. run.depth,
      run.player.x,
      run.player.y - 26,
      { 0.50, 1.00, 0.70 }
    )
    for index, message in ipairs(unlockMessages) do
      FX.add(
        message,
        run.player.x,
        run.player.y - 44 - index * 16,
        { 1.00, 0.86, 0.35 }
      )
    end
    return
  end

  Save.recordLevel(run.depth)
  Save.save()
  run:startStoryScene(chapter.outroScene, function()
    if chapter.nextChapter then
      run:advanceStoryChapter()
    else
      run:finishStory()
    end
  end)
end

function Progression.gameOver(run, reason)
  if run.sandbox then
    -- Morir en pruebas no cierra la sesión: restaura vida y limpia el peligro
    -- inmediato para seguir probando el mismo enemigo.
    run.hp = run.stats.maxHp
    if run.player then
      run.player.invuln = 2
    end
    run.projectiles = {}
    run.hazards = {}
    if run.shake then run:shake(4, 0.20) end
    run:notify("Pruebas: vida restaurada", { 0.55, 1.00, 0.70 })
    return
  end

  if run.over then return end
  run.over = true
  run.paused = false
  run.overlay = nil

  Save.recordLevel(run.depth)
  Save.save()

  local character = Data.characters[run.characterId]
  local ability = Data.abilities[run.abilitySlot1]
  run.gameOverInfo = {
    level = run.depth,
    playerLevel = run.playerLevel,
    kills = run.kills,
    coins = Save.data.coins,
    dungeon = run.def.name,
    dungeonId = run.def.id,
    mode = run.mode or "free",
    storyChapterId = run.storyChapterId,
    character = character.name,
    characterId = run.characterId,
    ability = ability and ability.name or "Sin habilidad",
    abilityId = run.abilitySlot1,
    reason = reason or "death",
    timeLeft = run.timeLeft,
    snapshot = run.floorSnapshot,
  }

  Audio.stopMusic()
  State.switch("gameover", run.gameOverInfo)
end

return Progression
