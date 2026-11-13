-- story_ui.lua: escenas narrativas ligeras sobre la run, sin assets externos.
local Data = require("src.run.data")
local Fonts = require("src.utils.fonts")
local Screen = require("src.utils.screen")
local TextCache = require("src.utils.textcache")

local StoryUI = {}

local function finish(run)
  local callback = run.storySceneDone
  run.overlay = nil
  run.storyScene = nil
  run.storySceneIndex = nil
  run.storySceneDone = nil
  if callback then
    callback(run)
  end
end

function StoryUI.start(run, sceneId, onDone)
  local scene = Data.story.scenes[sceneId]
  if not scene then
    if onDone then onDone(run) end
    return false
  end

  run.overlay = "story"
  run.storyScene = scene
  run.storySceneIndex = 1
  run.storySceneDone = onDone
  if run.clearInput then
    run:clearInput()
  end
  return true
end

function StoryUI.update(run, dt)
  -- Las escenas no consumen tiempo de juego; se reserva el update para
  -- futuras transiciones visuales sin tocar el temporizador del piso.
end

function StoryUI.advance(run)
  local scene = run.storyScene
  if not scene then return end

  local index = run.storySceneIndex or 1
  if index < #scene.lines then
    run.storySceneIndex = index + 1
    return
  end
  finish(run)
end

function StoryUI.keypressed(run, key, isrepeat)
  if isrepeat then return end
  if key == "return" or key == "space" then
    StoryUI.advance(run)
  elseif key == "escape" then
    finish(run)
  end
end

function StoryUI.pressed(run, x, y)
  StoryUI.advance(run)
end

function StoryUI.draw(run)
  local scene = run.storyScene
  if not scene then return end

  local index = run.storySceneIndex or 1
  local line = scene.lines[index]
  if not line then return end

  local width = math.min(Screen.width - 80, 840)
  local height = math.min(Screen.height - 80, 330)
  local x = (Screen.width - width) * 0.5
  local y = (Screen.height - height) * 0.5

  love.graphics.setColor(0, 0, 0, 0.78)
  love.graphics.rectangle("fill", 0, 0, Screen.width, Screen.height)

  love.graphics.setColor(0.07, 0.06, 0.12, 0.99)
  love.graphics.rectangle("fill", x, y, width, height, 12, 12)
  love.graphics.setColor(0.58, 0.40, 0.95)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", x, y, width, height, 12, 12)
  love.graphics.setLineWidth(1)

  love.graphics.setFont(Fonts.small)
  love.graphics.setColor(0.72, 0.62, 1.00)
  love.graphics.print("HISTORIA", x + 28, y + 20)

  love.graphics.setFont(Fonts.title)
  love.graphics.setColor(0.90, 0.84, 1.00)
  love.graphics.printf(scene.title or "", x + 28, y + 44, width - 56, "center")

  love.graphics.setFont(Fonts.body)
  local color = line.color or { 1.00, 0.78, 0.42 }
  love.graphics.setColor(color[1], color[2], color[3])
  love.graphics.printf(line.speaker or "", x + 48, y + 98, width - 96, "center")

  love.graphics.setColor(0.90, 0.91, 0.97)
  love.graphics.printf(line.text or "", x + 64, y + 130, width - 128, "center")

  love.graphics.setFont(Fonts.small)
  love.graphics.setColor(0.58, 0.64, 0.74)
  love.graphics.printf(
    TextCache.format("story-progress", "%d / %d", index, #scene.lines),
    x + 28,
    y + height - 42,
    width - 56,
    "center"
  )
  love.graphics.printf(
    "Toca o pulsa Enter para continuar · Esc omite la escena",
    x + 28,
    y + height - 24,
    width - 56,
    "center"
  )
end

return StoryUI
