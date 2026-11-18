-- items.lua: catálogo de ítems vistos en partida, con descripción y filtros.
-- Los objetos aún no vistos quedan como ???; la sala de pruebas no los cuenta.
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

local Items = {
  panel = { x = 0, y = 0, w = 0, h = 0 },
  selectorPanel = { x = 0, y = 0, w = 0, cardY = 0, cardH = 0 },
  tabs = {},
  cards = {},
  filtered = {},
  list = { x = 0, y = 0, w = 0, h = 0 },
  detailRect = { x = 0, y = 0, w = 0, h = 0 },
  rects = {},
  category = "all",
  selectedId = nil,
  scroll = 0,
  maxScroll = 0,
  cardH = 34,
  gapY = 4,
  cols = 3,
  drag = nil,
  selector = nil,
}

local CATEGORY_ORDER = { "all", "passive", "ability", "pet", "character", "resonance" }
local CATEGORY_LABELS = {
  all = "TODOS",
  passive = "PASIVOS",
  ability = "HABILIDADES",
  pet = "MASCOTAS",
  character = "PERSONAJE",
  resonance = "RESONANCIA",
}

local KIND_LABELS = {
  passive = "PASIVO",
  ability = "HABILIDAD",
  pet = "MASCOTA",
  character = "DESBLOQUEO",
  resonance = "RESONANCIA",
}

Items.categoryOrder = CATEGORY_ORDER
Items.categoryLabels = CATEGORY_LABELS

local function buildIndex()
  local index = {}
  for _, category in ipairs(CATEGORY_ORDER) do
    index[category] = {}
  end
  for _, id in ipairs(Data.itemOrder) do
    local def = Data.items[id]
    index.all[#index.all + 1] = id
    if index[def.kind] then
      index[def.kind][#index[def.kind] + 1] = id
    end
  end
  return index
end

local function setScroll(value)
  Items.scroll = math.max(0, math.min(value or 0, Items.maxScroll or 0))
end

function Items.layout()
  local index = buildIndex()
  if not CATEGORY_LABELS[Items.category] then Items.category = "all" end
  Items.filtered = index[Items.category]

  local width = math.min(Screen.width - 60, 900)
  local height = math.min(Screen.height - 30, 500)
  local x = (Screen.width - width) * 0.5
  local y = (Screen.height - height) * 0.5
  Items.panel = { x = x, y = y, w = width, h = height }
  Items.selectorPanel = {
    x = x, y = y, w = width, cardY = 72, cardH = 44,
    screenW = Screen.width, screenH = Screen.height,
  }
  if Items.selector then Items.selector:layout(Items.selectorPanel) end

  local gap = 5
  local tabW = math.floor((width - 64 - gap * (#CATEGORY_ORDER - 1)) / #CATEGORY_ORDER)
  Items.tabs = {}
  for i, category in ipairs(CATEGORY_ORDER) do
    Items.tabs[#Items.tabs + 1] = {
      id = category,
      x = x + 32 + (i - 1) * (tabW + gap),
      y = y + 124,
      w = tabW,
      h = 34,
    }
  end

  local leftX = x + 32
  local leftW = 500
  local step = Items.cardH + Items.gapY
  Items.list = {
    x = leftX,
    y = y + 168,
    w = leftW,
    h = math.max(Items.cardH, y + height - 70 - (y + 168)),
  }
  Items.rowsVisible = math.max(1, math.floor((Items.list.h + Items.gapY) / step))
  Items.detailRect = {
    x = x + 548,
    y = y + 124,
    w = width - 580,
    h = y + height - 72 - (y + 124),
  }
  Items.rects.back = { x = x + width - 180, y = y + height - 58, w = 148, h = 40 }

  local found = false
  for _, id in ipairs(Items.filtered) do
    if id == Items.selectedId then found = true break end
  end
  if not found then
    Items.selectedId = Items.filtered[1] or Data.itemOrder[1]
  end

  local rowCount = math.ceil(#Items.filtered / Items.cols)
  local contentHeight = math.max(0, rowCount * step - Items.gapY)
  Items.maxScroll = math.max(0, contentHeight - Items.list.h)
  setScroll(Items.scroll)

  Items.cards = {}
  local cardW = math.floor((leftW - (Items.cols - 1) * 6) / Items.cols)
  for i, id in ipairs(Items.filtered) do
    local row = math.floor((i - 1) / Items.cols)
    local col = (i - 1) % Items.cols
    local cardY = Items.list.y + row * step - Items.scroll
    if cardY + Items.cardH >= Items.list.y
      and cardY <= Items.list.y + Items.list.h then
      Items.cards[#Items.cards + 1] = {
        x = leftX + col * (cardW + 6),
        y = cardY,
        w = cardW,
        h = Items.cardH,
        id = id,
      }
    end
  end
end

function Items.enter()
  Items.selector = CharacterSelect.new({ getZone = function() return "menu" end })
  Items.category = "all"
  Items.scroll = 0
  Items.selectedId = Data.itemOrder[1]
  Items.drag = nil
  Items.layout()
  Audio.playZone("menu", Save.getSelectedCharacter())
end

function Items.update(dt) end

function Items.setCategory(category)
  if not CATEGORY_LABELS[category] then return end
  Items.category = category
  Items.scroll = 0
  Items.layout()
end

local function cycleCategory(delta)
  local current = 1
  for i, category in ipairs(CATEGORY_ORDER) do
    if category == Items.category then current = i break end
  end
  local nextIndex = ((current - 1 + delta) % #CATEGORY_ORDER) + 1
  Items.setCategory(CATEGORY_ORDER[nextIndex])
end

local function navigate(delta)
  local list = Items.filtered
  if #list == 0 then return end
  local index = 1
  for i, id in ipairs(list) do
    if id == Items.selectedId then index = i break end
  end
  index = ((index - 1 + delta) % #list) + 1
  Items.selectedId = list[index]
  local step = Items.cardH + Items.gapY
  local row = math.floor((index - 1) / Items.cols)
  local top = row * step
  local bottom = top + Items.cardH
  if top < Items.scroll then
    setScroll(top)
  elseif bottom > Items.scroll + Items.list.h then
    setScroll(bottom - Items.list.h)
  end
  Items.layout()
end

function Items.keypressed(key, isrepeat)
  if Items.selector and Items.selector:keypressed(key) then return end
  if isrepeat then return end
  if key == "escape" or key == "backspace" then
    State.switch("menu")
  elseif key == "left" or key == "up" then
    navigate(-1)
  elseif key == "right" or key == "down" then
    navigate(1)
  elseif key == "tab" or key == "]" then
    cycleCategory(1)
  elseif key == "[" then
    cycleCategory(-1)
  end
end

function Items.pressed(x, y)
  Items.layout()
  if Items.selector and Items.selector:pressed(x, y) then return end
  if Items.selector and Items.selector.confirm then return end
  for _, tab in ipairs(Items.tabs) do
    if Util.inside(x, y, tab) then
      Items.setCategory(tab.id)
      return
    end
  end
  for _, card in ipairs(Items.cards) do
    if Util.inside(x, y, card)
      and card.y >= Items.list.y
      and card.y + card.h <= Items.list.y + Items.list.h then
      Items.selectedId = card.id
      return
    end
  end
  if Util.inside(x, y, Items.rects.back) then
    State.switch("menu")
  end
end

function Items.mousepressed(x, y, button)
  if button == 1 then Items.pressed(x, y) end
end

function Items.touchpressed(id, x, y)
  Items.layout()
  if Items.selector and Items.selector:pressed(x, y) then return end
  if Items.selector and Items.selector.confirm then return end
  if Items.maxScroll > 0 and Util.inside(x, y, Items.list) then
    Items.drag = { id = id, y = y, scroll = Items.scroll, moved = false }
    return
  end
  Items.pressed(x, y)
end

function Items.touchmoved(id, x, y)
  local drag = Items.drag
  if not drag or drag.id ~= id then return end
  local delta = drag.y - y
  if math.abs(delta) > 6 then drag.moved = true end
  setScroll(drag.scroll + delta)
end

function Items.touchreleased(id, x, y)
  local drag = Items.drag
  if not drag or drag.id ~= id then return end
  Items.drag = nil
  if not drag.moved then Items.pressed(x, y) end
end

function Items.wheelmoved(x, y)
  Items.layout()
  setScroll(Items.scroll - (y or 0) * 32)
end

function Items.mousemoved(x, y) end
function Items.mousereleased(x, y) end
function Items.focus(focused) if focused then Audio.resumeMusic() end end

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
  love.graphics.printf(CATEGORY_LABELS[tab.id], tab.x, tab.y + 10, tab.w, "center")
end

local function drawCard(card, theme)
  local def = Data.items[card.id]
  local seen = Save.isItemDiscovered(card.id)
  local selected = card.id == Items.selectedId
  local background = selected and theme.buttonSelected or theme.button
  love.graphics.setColor(background[1], background[2], background[3], 0.97)
  love.graphics.rectangle("fill", card.x, card.y, card.w, card.h, 7, 7)
  local border = selected and theme.accent or theme.border
  if not seen then border = selected and theme.muted or theme.dim end
  love.graphics.setColor(border[1], border[2], border[3])
  love.graphics.rectangle("line", card.x, card.y, card.w, card.h, 7, 7)

  love.graphics.setFont(Fonts.small)
  local textColor = seen and theme.text or theme.dim
  love.graphics.setColor(textColor[1], textColor[2], textColor[3])
  love.graphics.printf(seen and def.short or "???", card.x + 4, card.y + 8, card.w - 8, "center")
end

local function drawScrollbar(theme)
  if Items.maxScroll <= 0 then return end
  local list = Items.list
  local x = list.x + list.w + 3
  love.graphics.setColor(theme.dim[1], theme.dim[2], theme.dim[3], 0.55)
  love.graphics.rectangle("fill", x, list.y, 5, list.h, 3, 3)
  local ratio = list.h / (list.h + Items.maxScroll)
  local thumbH = math.max(24, list.h * ratio)
  local thumbY = list.y + (list.h - thumbH) * (Items.scroll / Items.maxScroll)
  love.graphics.setColor(theme.accent[1], theme.accent[2], theme.accent[3], 0.85)
  love.graphics.rectangle("fill", x, thumbY, 5, thumbH, 3, 3)
end

local function drawDetail(theme)
  local rect = Items.detailRect
  local def = Data.items[Items.selectedId]
  local seen = Save.isItemDiscovered(Items.selectedId)
  love.graphics.setColor(theme.panelAlt[1], theme.panelAlt[2], theme.panelAlt[3], 0.97)
  love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 10, 10)
  love.graphics.setColor(theme.border[1], theme.border[2], theme.border[3])
  love.graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, 10, 10)

  local color = seen and def.color or theme.dim
  love.graphics.setColor(color[1], color[2], color[3])
  love.graphics.circle("fill", rect.x + 32, rect.y + 38, 17)
  love.graphics.setColor(theme.bg[1], theme.bg[2], theme.bg[3])
  love.graphics.setFont(Fonts.body)
  love.graphics.printf(seen and def.short or "?", rect.x + 16, rect.y + 25, 32, "center")

  love.graphics.setFont(Fonts.title)
  love.graphics.setColor(seen and theme.text or theme.dim)
  love.graphics.print(seen and def.name or "???", rect.x + 60, rect.y + 18)

  love.graphics.setFont(Fonts.small)
  love.graphics.setColor(theme.secondary[1], theme.secondary[2], theme.secondary[3])
  local kind = seen and KIND_LABELS[def.kind] or "SIN REGISTRO"
  love.graphics.print(kind, rect.x + 60, rect.y + 48)

  love.graphics.setFont(Fonts.body)
  love.graphics.setColor(theme.muted[1], theme.muted[2], theme.muted[3])
  local desc = seen and def.desc or "Recógelo en una partida para registrar su descripción."
  love.graphics.printf(desc, rect.x + 20, rect.y + 88, rect.w - 40, "left")
end

function Items.draw()
  Items.layout()
  local panel = Items.panel
  local px, py = panel.x, panel.y
  local theme = Themes.current()

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
  love.graphics.printf("ÍTEMS", px, py + 10, panel.w, "center")
  love.graphics.setFont(Fonts.small)
  love.graphics.setColor(theme.muted[1], theme.muted[2], theme.muted[3])
  love.graphics.printf(TextCache.format("items-progress",
    "Descubiertos: %d/%d · se registran al aparecer en una partida",
    Save.itemCount(), #Data.itemOrder), px, py + 50, panel.w, "center")

  if Items.selector then Items.selector:draw(Items.selectorPanel) end
  for _, tab in ipairs(Items.tabs) do
    drawTab(tab, tab.id == Items.category, theme)
  end

  setListClip(Items.list)
  for _, card in ipairs(Items.cards) do
    drawCard(card, theme)
  end
  clearListClip()
  drawScrollbar(theme)
  drawDetail(theme)

  local rect = Items.rects.back
  love.graphics.setColor(theme.button[1], theme.button[2], theme.button[3], 0.98)
  love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 8, 8)
  love.graphics.setColor(theme.border[1], theme.border[2], theme.border[3])
  love.graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, 8, 8)
  love.graphics.setFont(Fonts.small)
  love.graphics.setColor(theme.text[1], theme.text[2], theme.text[3])
  love.graphics.printf("VOLVER", rect.x, rect.y + 12, rect.w, "center")

  if Items.selector then Items.selector:drawConfirm(Items.selectorPanel) end
end

return Items
