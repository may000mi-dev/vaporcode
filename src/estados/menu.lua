-- menu.lua: entrada principal a Historia, Infinito, Personajes y Bestiario.
local Data = require("src.run.data")
local Save = require("src.run.save")
local Fonts = require("src.utils.fonts")
local Util = require("src.utils.util")
local State = require("src.estados")
local TextCache = require("src.utils.textcache")
local Screen = require("src.utils.screen")

local Menu = {
  rects = {},
  panel = { x = 0, y = 0, w = 0, h = 0 },
}

local function unlockedDungeons()
  local count = 0
  for _, dungeon in ipairs(Data.dungeons) do
    if Save.isDungeonUnlocked(dungeon.id) then
      count = count + 1
    end
  end
  return count, #Data.dungeons
end

local function storyLabel()
  if Save.hasStoryCheckpoint() then return "CONTINUAR HISTORIA" end
  return "MODO HISTORIA"
end

local function storySubtitle()
  local story = Save.data.story
  local chapter = story and story.chapterId
    and Data.story.chapterById[story.chapterId]
    or nil
  if Save.hasStoryCheckpoint() and chapter then
    return TextCache.format(
      "menu-story-progress",
      "%s · Piso %d · %s",
      chapter.name,
      story.depth,
      Data.characters[story.characterId].name
    )
  end

  local completed = Save.storyCompletionCount()
  if completed > 0 then
    return TextCache.format(
      "menu-story-completed",
      "%d/%d historias completadas · tres perspectivas",
      completed,
      #Data.characterOrder
    )
  end
  return "Campaña narrativa · elige a Amado, Mar o Amileth"
end

local function infiniteSubtitle()
  local unlocked, total = unlockedDungeons()
  if Save.isDungeonUnlocked("torre") then
    return TextCache.format(
      "menu-infinite-tower",
      "%d/%d mazmorras · la Torre ya está abierta",
      unlocked,
      total
    )
  end
  return TextCache.format(
    "menu-infinite",
    "%d/%d mazmorras desbloqueadas · elige personaje y destino",
    unlocked,
    total
  )
end

function Menu.layout()
  local width = math.min(Screen.width - 80, 760)
  local height = math.min(Screen.height - 40, 470)
  local x = (Screen.width - width) * 0.5
  local y = (Screen.height - height) * 0.5
  Menu.panel = { x = x, y = y, w = width, h = height }

  local labels = { "story", "infinite", "characters", "bestiary", "config" }
  local buttonX = x + 34
  local buttonY = y + 78
  local buttonW = width - 68
  local buttonH = 54
  local gap = 8
  Menu.rects = {}
  for index, id in ipairs(labels) do
    Menu.rects[id] = {
      x = buttonX,
      y = buttonY + (index - 1) * (buttonH + gap),
      w = buttonW,
      h = buttonH,
    }
  end
end

function Menu.enter()
  Menu.layout()
end

function Menu.update(dt) end
function Menu.mousemoved(x, y) end
function Menu.mousereleased(x, y) end
function Menu.touchmoved(id, x, y) end
function Menu.touchreleased(id, x, y) end
function Menu.focus(focused) end

local function open(id)
  if id == "story" then
    State.switch("historia")
  elseif id == "infinite" then
    State.switch("infinito")
  elseif id == "characters" then
    State.switch("personajes")
  elseif id == "bestiary" then
    State.switch("bestiario")
  elseif id == "config" then
    State.switch("config")
  end
end

function Menu.keypressed(key, isrepeat)
  if isrepeat then return end

  if key == "1" or key == "h" then
    open("story")
  elseif key == "2" or key == "i" then
    open("infinite")
  elseif key == "3" or key == "p" then
    open("characters")
  elseif key == "4" or key == "b" then
    open("bestiary")
  elseif key == "5" or key == "c" then
    open("config")
  end
end

function Menu.pressed(x, y)
  Menu.layout()
  for _, id in ipairs({ "story", "infinite", "characters", "bestiary", "config" }) do
    if Util.inside(x, y, Menu.rects[id]) then
      open(id)
      return
    end
  end
end

function Menu.mousepressed(x, y, button)
  if button == 1 then Menu.pressed(x, y) end
end

function Menu.touchpressed(id, x, y)
  Menu.pressed(x, y)
end

local function drawButton(rect, label, sub, accent, highlighted)
  if highlighted then
    love.graphics.setColor(0.12, 0.19, 0.24, 0.98)
  else
    love.graphics.setColor(0.08, 0.10, 0.14, 0.96)
  end
  love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 9, 9)

  love.graphics.setColor(accent[1], accent[2], accent[3])
  love.graphics.setLineWidth(highlighted and 3 or 2)
  love.graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, 9, 9)
  love.graphics.setLineWidth(1)

  love.graphics.setFont(Fonts.button)
  love.graphics.setColor(1, 1, 1)
  love.graphics.print(label, rect.x + 18, rect.y + 8)

  love.graphics.setFont(Fonts.small)
  love.graphics.setColor(0.70, 0.77, 0.84)
  love.graphics.print(sub, rect.x + 18, rect.y + rect.h - 20)
end

function Menu.draw()
  Menu.layout()
  local panel = Menu.panel
  local px, py = panel.x, panel.y

  love.graphics.setColor(0.04, 0.05, 0.07)
  love.graphics.rectangle("fill", 0, 0, Screen.width, Screen.height)
  love.graphics.setColor(0.06, 0.08, 0.11)
  love.graphics.circle("fill", 20, Screen.height - 20, 130)
  love.graphics.circle("fill", Screen.width - 10, 20, 150)

  love.graphics.setFont(Fonts.small)
  love.graphics.setColor(0.55, 0.85, 0.95)
  love.graphics.print(
    TextCache.format("menu-record", "Récord: piso %d", Save.data.bestLevel),
    24,
    18
  )

  love.graphics.setColor(1.00, 0.85, 0.35)
  love.graphics.printf(
    TextCache.format("menu-coins", "Monedas: %d", Save.data.coins),
    Screen.width - 340,
    18,
    316,
    "right"
  )

  love.graphics.setColor(0.05, 0.07, 0.10, 0.98)
  love.graphics.rectangle("fill", px, py, panel.w, panel.h, 12, 12)
  love.graphics.setColor(0.20, 0.33, 0.42)
  love.graphics.rectangle("line", px, py, panel.w, panel.h, 12, 12)

  love.graphics.setFont(Fonts.title)
  love.graphics.setColor(0.55, 0.90, 1.00)
  love.graphics.printf("ROGUELIKE STEAMPUNK MUSICAL", px, py + 8, panel.w, "center")

  love.graphics.setFont(Fonts.small)
  love.graphics.setColor(0.72, 0.78, 0.85)
  love.graphics.printf("May000mi · Prototipo LÖVE 11.5 · V9", px, py + 44, panel.w, "center")

  drawButton(
    Menu.rects.story,
    storyLabel(),
    storySubtitle(),
    { 0.72, 0.52, 1.00 },
    Save.hasStoryCheckpoint()
  )
  drawButton(
    Menu.rects.infinite,
    "MODO INFINITO",
    infiniteSubtitle(),
    { 0.38, 0.88, 0.66 },
    false
  )
  drawButton(
    Menu.rects.characters,
    "PERSONAJES",
    "Estadísticas, pasivas y mejoras con resonancias",
    { 0.42, 0.78, 1.00 },
    false
  )
  drawButton(
    Menu.rects.bestiary,
    "BESTIARIO",
    TextCache.format(
      "menu-bestiary",
      "Enemigos registrados: %d/%d",
      Save.bestiaryCount(),
      #Data.bestiaryOrder
    ),
    { 0.95, 0.68, 0.32 },
    false
  )
  drawButton(
    Menu.rects.config,
    "CONFIGURACIÓN",
    "Audio · borrar datos · sala de pruebas",
    { 0.55, 0.85, 0.95 },
    false
  )

  love.graphics.setFont(Fonts.small)
  love.graphics.setColor(0.55, 0.60, 0.68)
  love.graphics.printf(
    "Teclado: H historia · I infinito · P personajes · B bestiario · C configuración",
    0,
    py + panel.h - 24,
    Screen.width,
    "center"
  )
end

return Menu
