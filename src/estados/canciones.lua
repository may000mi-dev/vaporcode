-- canciones.lua: catálogo musical por personaje con vista previa temporal.
-- Las pistas bloqueadas se muestran como ???; al salir vuelve el tema del menú.
local Data = require("src.run.data")
local Save = require("src.run.save")
local Fonts = require("src.utils.fonts")
local Util = require("src.utils.util")
local Screen = require("src.utils.screen")
local State = require("src.estados")
local TextCache = require("src.utils.textcache")
local Themes = require("src.data.themes")
local Audio = require("src.utils.audio")
local CharacterSelect = require("src.ui.character_select")

local Canciones = {
  panel = { x = 0, y = 0, w = 0, h = 0 },
  selectorPanel = { x = 0, y = 0, w = 0, cardY = 0, cardH = 0 },
  tabs = {},
  rows = {},
  list = { x = 0, y = 0, w = 0, h = 0 },
  rects = {},
  character = "amado",
  selectedIndex = 1,
  scroll = 0,
  maxScroll = 0,
  rowH = 46,
  rowGap = 4,
  previewId = nil,
  drag = nil,
  selector = nil,
}

local CHARACTER_LABELS = {
  amado = "AMADO",
  mar = "MAR",
  amileth = "AMILETH",
}

local function songList()
  return Data.music.byCharacter[Canciones.character] or {}
end

local function isPlayable(songId)
  local def = Data.music.byId[songId]
  if not def then return false end
  return Save.isCharacterUnlocked(def.characterId)
    and Save.isSongDiscovered(def.characterId, songId)
end

local function setScroll(value)
  Canciones.scroll = math.max(0, math.min(value or 0, Canciones.maxScroll or 0))
end

function Canciones.setCharacter(characterId)
  if not Data.music.byCharacter[characterId] then return end
  Canciones.character = characterId
  Canciones.selectedIndex = 1
  Canciones.scroll = 0
  Canciones.layout()
end

function Canciones.layout()
  local width = math.min(Screen.width - 60, 900)
  local height = math.min(Screen.height - 30, 500)
  local x = (Screen.width - width) * 0.5
  local y = (Screen.height - height) * 0.5
  Canciones.panel = { x = x, y = y, w = width, h = height }
  Canciones.selectorPanel = {
    x = x, y = y, w = width, cardY = 72, cardH = 44,
    screenW = Screen.width, screenH = Screen.height,
  }
  if Canciones.selector then Canciones.selector:layout(Canciones.selectorPanel) end

  if not Data.music.byCharacter[Canciones.character] then
    Canciones.character = Save.getSelectedCharacter()
  end

  local tabGap = 6
  local tabW = math.floor((width - 64 - tabGap * 2) / 3)
  Canciones.tabs = {}
  for index, characterId in ipairs(Data.music.characterOrder) do
    Canciones.tabs[#Canciones.tabs + 1] = {
      id = characterId,
      x = x + 32 + (index - 1) * (tabW + tabGap),
      y = y + 124,
      w = tabW,
      h = 34,
    }
  end

  local listY = y + 168
  Canciones.list = {
    x = x + 32,
    y = listY,
    w = width - 64,
    h = math.max(Canciones.rowH, y + height - 70 - listY),
  }

  Canciones.rects.stop = { x = x + 32, y = y + height - 58, w = 148, h = 40 }
  Canciones.rects.back = { x = x + width - 180, y = y + height - 58, w = 148, h = 40 }

  local ids = songList()
  Canciones.selectedIndex = math.max(1, math.min(Canciones.selectedIndex, #ids))
  local step = Canciones.rowH + Canciones.rowGap
  local contentHeight = math.max(0, #ids * step - Canciones.rowGap)
  Canciones.maxScroll = math.max(0, contentHeight - Canciones.list.h)
  setScroll(Canciones.scroll)

  Canciones.rows = {}
  for index, songId in ipairs(ids) do
    local rowY = Canciones.list.y + (index - 1) * step - Canciones.scroll
    if rowY + Canciones.rowH >= Canciones.list.y
      and rowY <= Canciones.list.y + Canciones.list.h then
      Canciones.rows[#Canciones.rows + 1] = {
        x = Canciones.list.x,
        y = rowY,
        w = Canciones.list.w - 8,
        h = Canciones.rowH,
        id = songId,
        index = index,
      }
    end
  end
end

function Canciones.enter()
  Canciones.selector = CharacterSelect.new({ getZone = function() return "menu" end })
  Canciones.character = Save.getSelectedCharacter()
  Canciones.selectedIndex = 1
  Canciones.scroll = 0
  Canciones.previewId = nil
  Canciones.drag = nil
  Canciones.layout()
  Audio.playZone("menu", Save.getSelectedCharacter())
end

function Canciones.leave()
  Canciones.previewId = nil
  Audio.playZone("menu", Save.getSelectedCharacter())
end

function Canciones.update(dt) end

local function playSelected()
  local ids = songList()
  local songId = ids[Canciones.selectedIndex]
  if not songId or not isPlayable(songId) then return false end
  local def = Data.music.byId[songId]
  Audio.playZone(def.zone, def.characterId, { crossfade = true })
  Canciones.previewId = songId
  return true
end

local function stopPreview()
  Canciones.previewId = nil
  Audio.playZone("menu", Save.getSelectedCharacter())
end

local function navigate(delta)
  local ids = songList()
  local count = #ids
  if count == 0 then return end
  Canciones.selectedIndex = ((Canciones.selectedIndex - 1 + delta) % count) + 1
  local step = Canciones.rowH + Canciones.rowGap
  local top = (Canciones.selectedIndex - 1) * step
  local bottom = top + Canciones.rowH
  if top < Canciones.scroll then
    setScroll(top)
  elseif bottom > Canciones.scroll + Canciones.list.h then
    setScroll(bottom - Canciones.list.h)
  end
  Canciones.layout()
end

local function cycleCharacter(delta)
  local current = 1
  for index, characterId in ipairs(Data.music.characterOrder) do
    if characterId == Canciones.character then
      current = index
      break
    end
  end
  local nextIndex = ((current - 1 + delta) % #Data.music.characterOrder) + 1
  Canciones.setCharacter(Data.music.characterOrder[nextIndex])
end

function Canciones.keypressed(key, isrepeat)
  if Canciones.selector and Canciones.selector:keypressed(key) then return end
  if isrepeat then return end
  if key == "escape" or key == "backspace" then
    State.switch("menu")
  elseif key == "left" or key == "[" then
    cycleCharacter(-1)
  elseif key == "right" or key == "]" then
    cycleCharacter(1)
  elseif key == "up" then
    navigate(-1)
  elseif key == "down" then
    navigate(1)
  elseif key == "return" or key == " " then
    playSelected()
  end
end

function Canciones.pressed(x, y)
  Canciones.layout()
  if Canciones.selector and Canciones.selector:pressed(x, y) then return end
  if Canciones.selector and Canciones.selector.confirm then return end
  for _, tab in ipairs(Canciones.tabs) do
    if Util.inside(x, y, tab) then
      Canciones.setCharacter(tab.id)
      return
    end
  end
  for _, row in ipairs(Canciones.rows) do
    if Util.inside(x, y, row)
      and row.y >= Canciones.list.y
      and row.y + row.h <= Canciones.list.y + Canciones.list.h then
      Canciones.selectedIndex = row.index
      playSelected()
      return
    end
  end
  if Util.inside(x, y, Canciones.rects.stop) then
    stopPreview()
    return
  end
  if Util.inside(x, y, Canciones.rects.back) then
    State.switch("menu")
  end
end

function Canciones.mousepressed(x, y, button)
  if button == 1 then Canciones.pressed(x, y) end
end

function Canciones.touchpressed(id, x, y)
  Canciones.layout()
  if Canciones.selector and Canciones.selector:pressed(x, y) then return end
  if Canciones.selector and Canciones.selector.confirm then return end
  if Canciones.maxScroll > 0 and Util.inside(x, y, Canciones.list) then
    Canciones.drag = { id = id, y = y, scroll = Canciones.scroll, moved = false }
    return
  end
  Canciones.pressed(x, y)
end

function Canciones.touchmoved(id, x, y)
  local drag = Canciones.drag
  if not drag or drag.id ~= id then return end
  local delta = drag.y - y
  if math.abs(delta) > 6 then drag.moved = true end
  setScroll(drag.scroll + delta)
end

function Canciones.touchreleased(id, x, y)
  local drag = Canciones.drag
  if not drag or drag.id ~= id then return end
  Canciones.drag = nil
  if not drag.moved then Canciones.pressed(x, y) end
end

function Canciones.wheelmoved(x, y)
  Canciones.layout()
  setScroll(Canciones.scroll - (y or 0) * 32)
end

function Canciones.mousemoved(x, y) end
function Canciones.mousereleased(x, y) end
function Canciones.focus(focused) if focused then Audio.resumeMusic() end end

local function setListClip(rect)
  if not love.graphics.setScissor then return end
  love.graphics.setScissor(
    Screen.ox + rect.x * Screen.scale,
    Screen.oy + rect.y * Screen.scale,
    rect.w * Screen.scale,
    rect.h * Screen.scale
  )
end

local function clearListClip()
  if not love.graphics.setScissor then return end
  love.graphics.setScissor(
    Screen.ox,
    Screen.oy,
    Screen.width * Screen.scale,
    Screen.height * Screen.scale
  )
end

local function drawTab(tab, active, theme)
  local background = active and theme.buttonSelected or theme.button
  local border = active and theme.accent or theme.border
  local text = active and theme.text or theme.muted
  love.graphics.setColor(background[1], background[2], background[3], 0.98)
  love.graphics.rectangle("fill", tab.x, tab.y, tab.w, tab.h, 7, 7)
  love.graphics.setColor(border[1], border[2], border[3])
  love.graphics.rectangle("line", tab.x, tab.y, tab.w, tab.h, 7, 7)
  love.graphics.setFont(Fonts.small)
  love.graphics.setColor(text[1], text[2], text[3])
  love.graphics.printf(CHARACTER_LABELS[tab.id], tab.x, tab.y + 10, tab.w, "center")
end

local function drawRow(row, theme)
  local def = Data.music.byId[row.id]
  local seen = Save.isSongDiscovered(def.characterId, row.id)
    and Save.isCharacterUnlocked(def.characterId)
  local playing = Canciones.previewId == row.id
  local selected = Canciones.selectedIndex == row.index
  local background = playing and theme.buttonSelected
    or selected and theme.panelAlt
    or theme.button
  love.graphics.setColor(background[1], background[2], background[3], 0.97)
  love.graphics.rectangle("fill", row.x, row.y, row.w, row.h, 7, 7)
  local border = playing and theme.secondary or selected and theme.accent or theme.border
  love.graphics.setColor(border[1], border[2], border[3])
  love.graphics.rectangle("line", row.x, row.y, row.w, row.h, 7, 7)

  local iconX = row.x + 18
  local iconY = row.y + row.h * 0.5
  love.graphics.setColor(theme.accent[1], theme.accent[2], theme.accent[3])
  if seen then
    love.graphics.polygon("fill", iconX - 5, iconY - 7, iconX - 5, iconY + 7,
      iconX + 7, iconY)
  else
    love.graphics.circle("line", iconX, iconY, 8)
  end

  love.graphics.setFont(Fonts.small)
  love.graphics.setColor(theme.dim[1], theme.dim[2], theme.dim[3])
  love.graphics.printf(string.format("%02d", row.index), row.x + 36, row.y + 8, 26, "right")
  love.graphics.setFont(Fonts.body)
  local titleColor = seen and theme.text or theme.dim
  love.graphics.setColor(titleColor[1], titleColor[2], titleColor[3])
  love.graphics.print(seen and def.title or "???", row.x + 70, row.y + 5)
  love.graphics.setFont(Fonts.small)
  love.graphics.setColor(theme.muted[1], theme.muted[2], theme.muted[3])
  local status = seen and Data.music.zoneLabels[def.zone] or "SIN DESBLOQUEAR"
  love.graphics.print(status, row.x + 70, row.y + 27)
end

local function drawScrollbar(theme)
  if Canciones.maxScroll <= 0 then return end
  local list = Canciones.list
  local x = list.x + list.w + 2
  love.graphics.setColor(theme.dim[1], theme.dim[2], theme.dim[3], 0.55)
  love.graphics.rectangle("fill", x, list.y, 5, list.h, 3, 3)
  local ratio = list.h / (list.h + Canciones.maxScroll)
  local thumbH = math.max(24, list.h * ratio)
  local thumbY = list.y + (list.h - thumbH) * (Canciones.scroll / Canciones.maxScroll)
  love.graphics.setColor(theme.accent[1], theme.accent[2], theme.accent[3], 0.85)
  love.graphics.rectangle("fill", x, thumbY, 5, thumbH, 3, 3)
end

local function drawFooterButton(rect, label, theme, active)
  local background = active and theme.buttonSelected or theme.button
  love.graphics.setColor(background[1], background[2], background[3], 0.98)
  love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 8, 8)
  love.graphics.setColor(theme.border[1], theme.border[2], theme.border[3])
  love.graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, 8, 8)
  love.graphics.setFont(Fonts.small)
  love.graphics.setColor(theme.text[1], theme.text[2], theme.text[3])
  love.graphics.printf(label, rect.x, rect.y + 12, rect.w, "center")
end

function Canciones.draw()
  Canciones.layout()
  local panel = Canciones.panel
  local px, py = panel.x, panel.y
  local theme = Themes.current()
  local ids = songList()

  love.graphics.setColor(theme.bg[1], theme.bg[2], theme.bg[3])
  love.graphics.rectangle("fill", 0, 0, Screen.width, Screen.height)
  love.graphics.setColor(theme.accent[1], theme.accent[2], theme.accent[3], 0.05)
  love.graphics.circle("fill", 30, Screen.height - 20, 150)

  love.graphics.setColor(theme.panel[1], theme.panel[2], theme.panel[3], 0.98)
  love.graphics.rectangle("fill", px, py, panel.w, panel.h, 12, 12)
  love.graphics.setColor(theme.border[1], theme.border[2], theme.border[3])
  love.graphics.rectangle("line", px, py, panel.w, panel.h, 12, 12)

  love.graphics.setFont(Fonts.title)
  love.graphics.setColor(theme.accent[1], theme.accent[2], theme.accent[3])
  love.graphics.printf("CANCIONES", px, py + 10, panel.w, "center")
  love.graphics.setFont(Fonts.small)
  love.graphics.setColor(theme.muted[1], theme.muted[2], theme.muted[3])
  love.graphics.printf(TextCache.format("canciones-progress",
    "Desbloqueadas: %d/%d · la vista previa termina al salir",
    Save.songCount(Canciones.character), #ids), px, py + 50, panel.w, "center")

  if Canciones.selector then Canciones.selector:draw(Canciones.selectorPanel) end
  for _, tab in ipairs(Canciones.tabs) do
    drawTab(tab, tab.id == Canciones.character, theme)
  end

  setListClip(Canciones.list)
  for _, row in ipairs(Canciones.rows) do
    drawRow(row, theme)
  end
  clearListClip()
  drawScrollbar(theme)

  drawFooterButton(Canciones.rects.stop, "DETENER", theme, false)
  drawFooterButton(Canciones.rects.back, "VOLVER", theme, false)

  if Canciones.selector then Canciones.selector:drawConfirm(Canciones.selectorPanel) end
end

return Canciones
