-- menu.lua: entrada principal con selección global de personaje y tema dinámico.
local Data = require("src.run.data")
local Save = require("src.run.save")
local Fonts = require("src.utils.fonts")
local Util = require("src.utils.util")
local State = require("src.estados")
local TextCache = require("src.utils.textcache")
local Screen = require("src.utils.screen")
local Themes = require("src.data.themes")
local Audio = require("src.utils.audio")
local CharacterSelect = require("src.ui.character_select")

local Menu = {
  rects = {},
  panel = { x = 0, y = 0, w = 0, h = 0 },
  selector = nil,
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
  local width = math.min(Screen.width - 60, 820)
  local height = math.min(Screen.height - 24, 510)
  local x = (Screen.width - width) * 0.5
  local y = (Screen.height - height) * 0.5
  Menu.panel = { x = x, y = y, w = width, h = height }
  Menu.selectorPanel = { x = x, y = y, w = width, cardY = 62, cardH = 48, screenW = Screen.width, screenH = Screen.height }
  if Menu.selector then Menu.selector:layout(Menu.selectorPanel) end

  local labels = { "story", "infinite", "characters", "bestiary", "config" }
  local buttonX = x + 28
  local buttonY = y + 134
  local buttonW = width - 56
  local buttonH = 50
  local gap = 7
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
  Menu.selector = CharacterSelect.new({
    getZone = function() return "menu" end,
  })
  Menu.layout()
  Audio.playZone("menu", Save.getSelectedCharacter())
end

function Menu.update(dt) end
function Menu.mousemoved(x, y) end
function Menu.mousereleased(x, y) end
function Menu.touchmoved(id, x, y) end
function Menu.touchreleased(id, x, y) end
function Menu.focus(focused)
  if focused then Audio.resumeMusic() end
end

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
  if Menu.selector and Menu.selector:keypressed(key) then return end
  if isrepeat then return end
  if key == "1" or key == "h" then open("story")
  elseif key == "2" or key == "i" then open("infinite")
  elseif key == "3" or key == "p" then open("characters")
  elseif key == "4" or key == "b" then open("bestiary")
  elseif key == "5" or key == "c" then open("config") end
end

function Menu.pressed(x, y)
  Menu.layout()
  local selectorPanel = {
    x = Menu.panel.x, y = Menu.panel.y, w = Menu.panel.w,
    cardY = 62, cardH = 48,
    screenW = Screen.width, screenH = Screen.height,
  }
  if Menu.selector and Menu.selector:pressed(x, y) then return end
  if Menu.selector and Menu.selector.confirm then return end
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

local function drawButton(rect, label, sub, accent, highlighted, theme)
  local bg = highlighted and theme.buttonSelected or theme.button
  love.graphics.setColor(bg[1], bg[2], bg[3], 0.97)
  love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 9, 9)
  love.graphics.setColor(accent[1], accent[2], accent[3])
  love.graphics.setLineWidth(highlighted and 3 or 2)
  love.graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, 9, 9)
  love.graphics.setLineWidth(1)

  love.graphics.setFont(Fonts.button)
  love.graphics.setColor(theme.text[1], theme.text[2], theme.text[3])
  love.graphics.print(label, rect.x + 18, rect.y + 7)
  love.graphics.setFont(Fonts.small)
  love.graphics.setColor(theme.muted[1], theme.muted[2], theme.muted[3])
  love.graphics.print(sub, rect.x + 18, rect.y + rect.h - 19)
end

function Menu.draw()
  Menu.layout()
  local theme = Themes.current()
  local panel = Menu.panel
  local px, py = panel.x, panel.y

  love.graphics.setColor(theme.bg[1], theme.bg[2], theme.bg[3])
  love.graphics.rectangle("fill", 0, 0, Screen.width, Screen.height)
  love.graphics.setColor(theme.accent[1], theme.accent[2], theme.accent[3], 0.06)
  love.graphics.circle("fill", 20, Screen.height - 20, 150)
  love.graphics.circle("fill", Screen.width - 10, 20, 170)

  love.graphics.setFont(Fonts.small)
  love.graphics.setColor(theme.accent[1], theme.accent[2], theme.accent[3])
  love.graphics.print(
    TextCache.format("menu-record", "Récord: piso %d", Save.data.bestLevel),
    24, 14
  )
  love.graphics.setColor(theme.secondary[1], theme.secondary[2], theme.secondary[3])
  love.graphics.printf(
    TextCache.format("menu-coins", "Monedas: %d", Save.data.coins),
    Screen.width - 340, 14, 316, "right"
  )

  love.graphics.setColor(theme.panel[1], theme.panel[2], theme.panel[3], 0.98)
  love.graphics.rectangle("fill", px, py, panel.w, panel.h, 12, 12)
  love.graphics.setColor(theme.border[1], theme.border[2], theme.border[3])
  love.graphics.rectangle("line", px, py, panel.w, panel.h, 12, 12)

  love.graphics.setFont(Fonts.title)
  love.graphics.setColor(theme.accent[1], theme.accent[2], theme.accent[3])
  love.graphics.printf("VaporCode", px, py + 6, panel.w, "center")
  love.graphics.setFont(Fonts.small)
  love.graphics.setColor(theme.muted[1], theme.muted[2], theme.muted[3])
  love.graphics.printf("Selecciona tu personaje para la aventura", px, py + 42, panel.w, "center")

  local selectorPanel = {
    x = px, y = py, w = panel.w,
    cardY = 62, cardH = 48,
    screenW = Screen.width, screenH = Screen.height,
  }
  if Menu.selector then Menu.selector:draw(selectorPanel) end

  local acc = theme.accent
  local sec = theme.secondary
  drawButton(Menu.rects.story, storyLabel(), storySubtitle(), acc, Save.hasStoryCheckpoint(), theme)
  drawButton(Menu.rects.infinite, "MODO INFINITO", infiniteSubtitle(), sec, false, theme)
  drawButton(Menu.rects.characters, "PERSONAJES",
    "Estadísticas, pasivas y mejoras con resonancias", acc, false, theme)
  drawButton(Menu.rects.bestiary, "BESTIARIO",
    TextCache.format("menu-bestiary", "Enemigos registrados: %d/%d",
      Save.bestiaryCount(), #Data.bestiaryOrder), sec, false, theme)
  drawButton(Menu.rects.config, "CONFIGURACIÓN",
    "Audio · borrar datos · sala de pruebas", acc, false, theme)

  love.graphics.setFont(Fonts.small)
  love.graphics.setColor(theme.dim[1], theme.dim[2], theme.dim[3])
  love.graphics.printf(
    "Teclado: H historia · I infinito · P personajes · B bestiario · C configuración",
    0, py + panel.h - 22, Screen.width, "center"
  )

  -- El modal de personaje se dibuja al final para quedar sobre todo el menú.
  if Menu.selector then Menu.selector:drawConfirm(selectorPanel) end
end

return Menu
