-- infinito.lua: selección de mazmorra con personaje global sincronizado.
local Data = require("src.run.data")
local Save = require("src.run.save")
local Fonts = require("src.utils.fonts")
local Util = require("src.utils.util")
local Screen = require("src.utils.screen")
local TextCache = require("src.utils.textcache")
local State = require("src.estados")
local Portraits = require("src.utils.portraits")
local Themes = require("src.data.themes")
local Audio = require("src.utils.audio")
local CharacterSelect = require("src.ui.character_select")

local Infinito = {
  panel = { x = 0, y = 0, w = 0, h = 0 },
  dungeonRects = {},
  rects = {},
  dungeonId = "cripta",
  message = nil,
  messageTimer = 0,
  selector = nil,
}

local function unlockText(dungeon)
  if dungeon.storyUnlock then
    return TextCache.format("inf-tower-unlock",
      "Completa la historia con los tres personajes (%d/%d).",
      Save.storyCompletionCount(), #Data.characterOrder)
  end
  if not Save.isDungeonUnlocked(dungeon.id) then
    return TextCache.format("inf-unlock", "Alcanza el piso %d en Infinito.", dungeon.unlockLevel or 1)
  end
  return TextCache.format("inf-bpm", "Desbloqueada · %s · BPM %d", dungeon.song.name, dungeon.song.bpm)
end

function Infinito.say(text)
  Infinito.message = text
  Infinito.messageTimer = 2.6
end

function Infinito.layout()
  local width = math.min(Screen.width - 50, 880)
  local height = math.min(Screen.height - 20, 510)
  local x = (Screen.width - width) * 0.5
  local y = (Screen.height - height) * 0.5
  Infinito.panel = { x = x, y = y, w = width, h = height }
  Infinito.selectorPanel = { x = x, y = y, w = width, cardY = 68, cardH = 46, screenW = Screen.width, screenH = Screen.height }
  if Infinito.selector then Infinito.selector:layout(Infinito.selectorPanel) end

  local listX = x + 28
  local listY = y + 150
  local dungeonW = width - 56
  local dungeonH = 46
  local dungeonGap = 8
  Infinito.dungeonRects = {}
  for index, dungeon in ipairs(Data.dungeons) do
    Infinito.dungeonRects[#Infinito.dungeonRects + 1] = {
      x = listX, y = listY + (index - 1) * (dungeonH + dungeonGap),
      w = dungeonW, h = dungeonH, def = dungeon,
    }
  end

  Infinito.rects.start = { x = x + 28, y = y + height - 58, w = 260, h = 42 }
  Infinito.rects.back = { x = x + width - 196, y = y + height - 58, w = 164, h = 42 }
end

function Infinito.enter()
  Infinito.message = nil
  Infinito.messageTimer = 0
  if not Save.isDungeonUnlocked(Infinito.dungeonId) then Infinito.dungeonId = "cripta" end
  Infinito.selector = CharacterSelect.new({ getZone = function() return "menu" end })
  Infinito.layout()
  Audio.playZone("menu", Save.getSelectedCharacter())
end

function Infinito.update(dt)
  if Infinito.messageTimer > 0 then
    Infinito.messageTimer = math.max(0, Infinito.messageTimer - dt)
    if Infinito.messageTimer == 0 then Infinito.message = nil end
  end
end

local function selectDungeon(id)
  local dungeon = Data.dungeonById[id]
  if not dungeon then return end
  Infinito.dungeonId = id
  if not Save.isDungeonUnlocked(id) then Infinito.say(unlockText(dungeon)) end
end

local function start()
  local dungeon = Data.dungeonById[Infinito.dungeonId]
  local cid = Save.getSelectedCharacter()
  if not dungeon then return end
  if not Save.isCharacterUnlocked(cid) then
    Infinito.say("Ese personaje todavía está bloqueado.")
    return
  end
  if not Save.isDungeonUnlocked(dungeon.id) then
    Infinito.say(unlockText(dungeon))
    return
  end
  State.switch("run", dungeon.id, cid, nil, { mode = "free" })
end

function Infinito.keypressed(key, isrepeat)
  if Infinito.selector and Infinito.selector:keypressed(key) then return end
  if isrepeat then return end
  if key == "escape" or key == "backspace" then State.switch("menu")
  elseif key == "return" or key == "space" then start()
  elseif key == "1" then selectDungeon(Data.dungeons[1].id)
  elseif key == "2" then selectDungeon(Data.dungeons[2].id)
  elseif key == "3" then selectDungeon(Data.dungeons[3].id)
  elseif key == "4" then selectDungeon(Data.dungeons[4].id) end
end

function Infinito.pressed(x, y)
  Infinito.layout()
  if Infinito.selector and Infinito.selector:pressed(x, y) then return end
  if Infinito.selector and Infinito.selector.confirm then return end
  for _, rect in ipairs(Infinito.dungeonRects) do
    if Util.inside(x, y, rect) then selectDungeon(rect.def.id); return end
  end
  if Util.inside(x, y, Infinito.rects.start) then start(); return end
  if Util.inside(x, y, Infinito.rects.back) then State.switch("menu") end
end

function Infinito.mousepressed(x, y, button) if button == 1 then Infinito.pressed(x, y) end end
function Infinito.touchpressed(id, x, y) Infinito.pressed(x, y) end
function Infinito.mousemoved() end
function Infinito.mousereleased() end
function Infinito.touchmoved() end
function Infinito.touchreleased() end
function Infinito.focus(focused) if focused then Audio.resumeMusic() end end

local function drawCard(rect, selected, unlocked, theme)
  local accent = selected and theme.accent or theme.border
  love.graphics.setColor(
    selected and theme.buttonSelected[1] or theme.button[1],
    selected and theme.buttonSelected[2] or theme.button[2],
    selected and theme.buttonSelected[3] or theme.button[3], 0.97)
  love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 8, 8)
  love.graphics.setColor(unlocked and accent[1] or 0.32, unlocked and accent[2] or 0.36, unlocked and accent[3] or 0.40)
  love.graphics.setLineWidth(selected and 3 or 2)
  love.graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, 8, 8)
  love.graphics.setLineWidth(1)
end

function Infinito.draw()
  Infinito.layout()
  local theme = Themes.current()
  local panel = Infinito.panel
  local px, py = panel.x, panel.y

  love.graphics.setColor(theme.bg[1], theme.bg[2], theme.bg[3])
  love.graphics.rectangle("fill", 0, 0, Screen.width, Screen.height)
  love.graphics.setColor(theme.secondary[1], theme.secondary[2], theme.secondary[3], 0.05)
  love.graphics.circle("fill", 30, Screen.height - 20, 150)

  love.graphics.setColor(theme.panel[1], theme.panel[2], theme.panel[3], 0.98)
  love.graphics.rectangle("fill", px, py, panel.w, panel.h, 12, 12)
  love.graphics.setColor(theme.border[1], theme.border[2], theme.border[3])
  love.graphics.rectangle("line", px, py, panel.w, panel.h, 12, 12)

  love.graphics.setFont(Fonts.title)
  love.graphics.setColor(theme.accent[1], theme.accent[2], theme.accent[3])
  love.graphics.printf("MODO INFINITO", px, py + 12, panel.w, "center")
  love.graphics.setFont(Fonts.small)
  love.graphics.setColor(theme.muted[1], theme.muted[2], theme.muted[3])
  love.graphics.printf("Personaje global activo · elige mazmorra", px, py + 46, panel.w, "center")

  local selectorPanel = {
    x = px, y = py, w = panel.w, cardY = 68, cardH = 46,
    screenW = Screen.width, screenH = Screen.height,
  }
  if Infinito.selector then Infinito.selector:draw(selectorPanel) end

  love.graphics.setFont(Fonts.button)
  love.graphics.setColor(theme.secondary[1], theme.secondary[2], theme.secondary[3])
  love.graphics.print("Mazmorra", px + 28, py + 126)

  for _, rect in ipairs(Infinito.dungeonRects) do
    local def = rect.def
    local unlocked = Save.isDungeonUnlocked(def.id)
    drawCard(rect, Infinito.dungeonId == def.id, unlocked, theme)
    local boss = Data.enemyTypes[def.boss]
    if boss and Portraits and Portraits.enemy then
      Portraits.enemy(boss, rect.x + 26, rect.y + rect.h * 0.5, 13, false)
    end
    love.graphics.setFont(Fonts.button)
    love.graphics.setColor(unlocked and theme.text[1] or theme.dim[1], unlocked and theme.text[2] or theme.dim[2], unlocked and theme.text[3] or theme.dim[3])
    love.graphics.print(def.name, rect.x + 52, rect.y + 4)
    love.graphics.setFont(Fonts.small)
    love.graphics.setColor(theme.muted[1], theme.muted[2], theme.muted[3])
    love.graphics.print(unlockText(def), rect.x + 52, rect.y + 24)
  end

  local startRect = Infinito.rects.start
  love.graphics.setColor(theme.buttonSelected[1], theme.buttonSelected[2], theme.buttonSelected[3], 0.98)
  love.graphics.rectangle("fill", startRect.x, startRect.y, startRect.w, startRect.h, 8, 8)
  love.graphics.setColor(theme.accent[1], theme.accent[2], theme.accent[3])
  love.graphics.rectangle("line", startRect.x, startRect.y, startRect.w, startRect.h, 8, 8)
  love.graphics.setFont(Fonts.button)
  love.graphics.setColor(theme.text[1], theme.text[2], theme.text[3])
  love.graphics.printf("COMENZAR", startRect.x, startRect.y + 12, startRect.w, "center")

  local backRect = Infinito.rects.back
  love.graphics.setColor(theme.button[1], theme.button[2], theme.button[3], 0.98)
  love.graphics.rectangle("fill", backRect.x, backRect.y, backRect.w, backRect.h, 8, 8)
  love.graphics.setColor(theme.border[1], theme.border[2], theme.border[3])
  love.graphics.rectangle("line", backRect.x, backRect.y, backRect.w, backRect.h, 8, 8)
  love.graphics.setFont(Fonts.button)
  love.graphics.setColor(theme.text[1], theme.text[2], theme.text[3])
  love.graphics.printf("VOLVER", backRect.x, backRect.y + 12, backRect.w, "center")

  if Infinito.message and Infinito.messageTimer > 0 then
    love.graphics.setFont(Fonts.body)
    love.graphics.setColor(theme.secondary[1], theme.secondary[2], theme.secondary[3])
    love.graphics.printf(Infinito.message, px + 20, py + panel.h - 90, panel.w - 40, "center")
  end

  love.graphics.setFont(Fonts.small)
  love.graphics.setColor(theme.dim[1], theme.dim[2], theme.dim[3])
  love.graphics.printf("1-4 mazmorra · Enter comenzar · Esc volver", 0, py + panel.h - 16, Screen.width, "center")

  if Infinito.selector then Infinito.selector:drawConfirm(selectorPanel) end
end

return Infinito
