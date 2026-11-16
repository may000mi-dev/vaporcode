-- bestiario.lua: enemigos vistos, categorías, scroll y retrato procedural.
local Data = require("src.run.data")
local Save = require("src.run.save")
local Fonts = require("src.utils.fonts")
local Util = require("src.utils.util")
local Screen = require("src.utils.screen")
local State = require("src.estados")
local Portraits = require("src.utils.portraits")
local TextCache = require("src.utils.textcache")
local Themes = require("src.data.themes")
local Audio = require("src.utils.audio")
local CharacterSelect = require("src.ui.character_select")

local Bestiario = {
  panel = { x = 0, y = 0, w = 0, h = 0 },
  rects = {},
  cards = {},
  tabs = {},
  selectedId = nil,
  category = "all",
  filtered = {},
  scroll = 0,
  maxScroll = 0,
  message = nil,
  messageTimer = 0,
  selector = nil,
  drag = nil,
}

local CATEGORY_ORDER = { "all", "melee", "ranged", "summoner", "support", "boss" }
local CATEGORY_LABELS = {
  all = "TODOS",
  melee = "CUERPO",
  ranged = "DISPARAN",
  summoner = "INVOCAN",
  support = "SOPORTE",
  boss = "JEFES",
}

Bestiario.categoryOrder = CATEGORY_ORDER
Bestiario.categoryLabels = CATEGORY_LABELS

local function discoveredCount()
  local count = 0
  for _, id in ipairs(Data.bestiaryOrder) do
    if Save.isEnemyDiscovered(id) then
      count = count + 1
    end
  end
  return count
end

local function hasRole(def, role)
  for _, value in ipairs(def.threatRoles or {}) do
    if value == role then return true end
  end
  return false
end

local function addCategory(categories, category)
  for _, value in ipairs(categories) do
    if value == category then return end
  end
  categories[#categories + 1] = category
end

function Bestiario.categoriesFor(id)
  local info = Data.bestiary[id]
  if info and info.boss then return { "boss" } end

  local def = Data.enemyTypes[id] or {}
  local role = def.role
  local categories = {}

  local shoots = role == "turret" or role == "mortar"
    or hasRole(def, "ranged") or hasRole(def, "area")
    or (
      def.attackRange and def.attackRange > 0
      and (def.projectileSpeed or def.projectileSlowDuration
        or def.mortarRadius or def.manaDrain)
    )
  if shoots then addCategory(categories, "ranged") end

  if role == "summoner" or hasRole(def, "summoner") then
    addCategory(categories, "summoner")
  end

  if role == "healer" or role == "pet_hunter" or hasRole(def, "support")
    or hasRole(def, "control") or hasRole(def, "antidote") then
    addCategory(categories, "support")
  end

  if hasRole(def, "melee") or hasRole(def, "fast") or hasRole(def, "tank") then
    addCategory(categories, "melee")
  end

  if #categories == 0 then addCategory(categories, "melee") end
  return categories
end

function Bestiario.categoryFor(id)
  local categories = Bestiario.categoriesFor(id)
  return categories[1] or "melee"
end

function Bestiario.ensureIndex()
  if Bestiario.index then return end
  local index = {}
  local labels = {}
  for _, category in ipairs(CATEGORY_ORDER) do
    index[category] = {}
  end
  for _, id in ipairs(Data.bestiaryOrder) do
    index.all[#index.all + 1] = id
    for _, category in ipairs(Bestiario.categoriesFor(id)) do
      local list = index[category]
      if list then list[#list + 1] = id end
    end
  end
  for _, category in ipairs(CATEGORY_ORDER) do
    labels[category] = string.format("%s %d", CATEGORY_LABELS[category], #index[category])
  end
  Bestiario.index = index
  Bestiario.tabLabels = labels
end

function Bestiario.filteredFor(category)
  Bestiario.ensureIndex()
  return Bestiario.index[category] or Bestiario.index.melee
end

function Bestiario.syncSelection()
  local list = Bestiario.filtered or {}
  if #list == 0 then return end
  for _, id in ipairs(list) do
    if id == Bestiario.selectedId then return end
  end
  Bestiario.selectedId = list[1]
end

function Bestiario.layout()
  Bestiario.ensureIndex()
  local width = math.min(Screen.width - 60, 900)
  local height = math.min(Screen.height - 30, 500)
  local x = (Screen.width - width) * 0.5
  local y = (Screen.height - height) * 0.5
  Bestiario.panel = { x = x, y = y, w = width, h = height }
  Bestiario.selectorPanel = {
    x = x, y = y, w = width, cardY = 72, cardH = 44,
    screenW = Screen.width, screenH = Screen.height,
  }
  if Bestiario.selector then Bestiario.selector:layout(Bestiario.selectorPanel) end

  if not CATEGORY_LABELS[Bestiario.category] then
    Bestiario.category = "all"
  end

  local leftX = x + 32
  local leftRight = x + 534 - 18
  local leftW = leftRight - leftX
  local tabGap = 5
  local tabW = math.floor((leftW - tabGap * (#CATEGORY_ORDER - 1)) / #CATEGORY_ORDER)
  local tabY = y + 124
  Bestiario.tabs = {}
  for index, category in ipairs(CATEGORY_ORDER) do
    Bestiario.tabs[#Bestiario.tabs + 1] = {
      id = category,
      x = leftX + (index - 1) * (tabW + tabGap),
      y = tabY,
      w = tabW,
      h = 34,
    }
  end

  local gapX = 4
  local gapY = 4
  local cardW = math.floor((leftW - 10 - gapX * 2) / 3)
  local cardH = 38
  local grid = {
    x = leftX,
    y = y + 168,
    w = leftW - 10,
    h = 0,
  }
  grid.h = math.max(cardH, y + height - 72 - grid.y)
  Bestiario.grid = grid
  Bestiario.cols = 3
  Bestiario.cardH = cardH
  Bestiario.gapY = gapY
  Bestiario.rowsVisible = math.max(1, math.floor((grid.h + gapY) / (cardH + gapY)))

  Bestiario.detailRect = {
    x = x + 534,
    y = y + 124,
    w = x + width - 32 - (x + 534),
    h = y + height - 72 - (y + 124),
  }

  Bestiario.rects.back = {
    x = x + width - 180,
    y = y + height - 58,
    w = 148,
    h = 40,
  }

  Bestiario.filtered = Bestiario.filteredFor(Bestiario.category)
  Bestiario.syncSelection()

  local rowCount = math.ceil(#Bestiario.filtered / Bestiario.cols)
  local contentHeight = math.max(0, rowCount * (cardH + gapY) - gapY)
  Bestiario.maxScroll = math.max(0, contentHeight - grid.h)
  Bestiario.scroll = math.max(0, math.min(Bestiario.scroll, Bestiario.maxScroll))

  Bestiario.cards = {}
  for index, id in ipairs(Bestiario.filtered) do
    local row = math.floor((index - 1) / Bestiario.cols)
    local col = (index - 1) % Bestiario.cols
    local cardY = grid.y + row * (cardH + gapY) - Bestiario.scroll
    if cardY + cardH >= grid.y and cardY <= grid.y + grid.h then
      Bestiario.cards[#Bestiario.cards + 1] = {
        x = grid.x + col * (cardW + gapX),
        y = cardY,
        w = cardW,
        h = cardH,
        id = id,
      }
    end
  end
end

function Bestiario.enter()
  Bestiario.message = nil
  Bestiario.messageTimer = 0
  Bestiario.drag = nil
  Bestiario.selector = CharacterSelect.new({ getZone = function() return "menu" end })
  if not Bestiario.selectedId or not Data.bestiary[Bestiario.selectedId] then
    Bestiario.selectedId = Data.bestiaryOrder[1]
  end
  Bestiario.category = "all"
  Bestiario.scroll = 0
  Bestiario.layout()
  Audio.playZone("menu", Save.getSelectedCharacter())
end

function Bestiario.update(dt)
  if Bestiario.messageTimer > 0 then
    Bestiario.messageTimer = math.max(0, Bestiario.messageTimer - dt)
    if Bestiario.messageTimer == 0 then
      Bestiario.message = nil
    end
  end
end

function Bestiario.setScroll(value)
  Bestiario.scroll = math.max(0, math.min(value, Bestiario.maxScroll or 0))
end

function Bestiario.scrollToSelected()
  Bestiario.layout()
  local index = nil
  for i, id in ipairs(Bestiario.filtered) do
    if id == Bestiario.selectedId then
      index = i
      break
    end
  end
  if not index then return end
  local row = math.floor((index - 1) / Bestiario.cols)
  local top = row * (Bestiario.cardH + Bestiario.gapY)
  local bottom = top + Bestiario.cardH
  local scroll = Bestiario.scroll
  if top < scroll then
    scroll = top
  elseif bottom > scroll + Bestiario.grid.h then
    scroll = bottom - Bestiario.grid.h
  end
  Bestiario.setScroll(scroll)
end

function Bestiario.setCategory(category)
  if not CATEGORY_LABELS[category] then return end
  Bestiario.category = category
  Bestiario.scroll = 0
  Bestiario.layout()
  Bestiario.scrollToSelected()
end

function Bestiario.cycleCategory(delta)
  local current = 1
  for index, category in ipairs(CATEGORY_ORDER) do
    if category == Bestiario.category then
      current = index
      break
    end
  end
  local nextIndex = ((current - 1 + delta) % #CATEGORY_ORDER) + 1
  Bestiario.setCategory(CATEGORY_ORDER[nextIndex])
end

local function navigate(delta)
  local list = Bestiario.filteredFor(Bestiario.category)
  if #list == 0 then return end
  local index = 1
  for i, id in ipairs(list) do
    if id == Bestiario.selectedId then
      index = i
      break
    end
  end
  index = ((index - 1 + delta) % #list) + 1
  Bestiario.selectedId = list[index]
  Bestiario.scrollToSelected()
end

function Bestiario.keypressed(key, isrepeat)
  if Bestiario.selector and Bestiario.selector:keypressed(key) then return end
  if isrepeat then return end
  if key == "escape" or key == "backspace" then
    State.switch("menu")
  elseif key == "left" or key == "up" then
    navigate(-1)
  elseif key == "right" or key == "down" then
    navigate(1)
  elseif key == "tab" then
    Bestiario.cycleCategory(1)
  elseif key == "[" then
    Bestiario.cycleCategory(-1)
  elseif key == "]" then
    Bestiario.cycleCategory(1)
  end
end

function Bestiario.pressed(x, y)
  Bestiario.layout()
  if Bestiario.selector and Bestiario.selector:pressed(x, y) then return end
  if Bestiario.selector and Bestiario.selector.confirm then return end
  for _, tab in ipairs(Bestiario.tabs) do
    if Util.inside(x, y, tab) then
      Bestiario.setCategory(tab.id)
      return
    end
  end
  for _, rect in ipairs(Bestiario.cards) do
    if Util.inside(x, y, rect)
      and rect.y >= Bestiario.grid.y
      and rect.y + rect.h <= Bestiario.grid.y + Bestiario.grid.h then
      Bestiario.selectedId = rect.id
      return
    end
  end
  if Util.inside(x, y, Bestiario.rects.back) then
    State.switch("menu")
  end
end

function Bestiario.mousepressed(x, y, button)
  if button == 1 then Bestiario.pressed(x, y) end
end

function Bestiario.touchpressed(id, x, y)
  Bestiario.layout()
  if Bestiario.selector and Bestiario.selector:pressed(x, y) then return end
  if Bestiario.selector and Bestiario.selector.confirm then return end
  if Bestiario.maxScroll > 0 and Util.inside(x, y, Bestiario.grid) then
    Bestiario.drag = {
      id = id,
      y = y,
      scroll = Bestiario.scroll,
      moved = false,
    }
    return
  end
  Bestiario.pressed(x, y)
end

function Bestiario.touchmoved(id, x, y)
  local drag = Bestiario.drag
  if not drag or drag.id ~= id then return end
  local delta = drag.y - y
  if math.abs(delta) > 6 then drag.moved = true end
  Bestiario.setScroll(drag.scroll + delta)
end

function Bestiario.touchreleased(id, x, y)
  local drag = Bestiario.drag
  if not drag or drag.id ~= id then return end
  Bestiario.drag = nil
  if not drag.moved then Bestiario.pressed(x, y) end
end

function Bestiario.wheelmoved(x, y)
  Bestiario.layout()
  Bestiario.setScroll(Bestiario.scroll - (y or 0) * 36)
end

function Bestiario.mousemoved(x, y) end
function Bestiario.mousereleased(x, y) end
function Bestiario.focus(focused) if focused then Audio.resumeMusic() end end

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

local function drawCard(rect, id, theme)
  local info = Data.bestiary[id]
  local def = Data.enemyTypes[id]
  local seen = Save.isEnemyDiscovered(id)
  local selected = Bestiario.selectedId == id
  local background = selected and theme.buttonSelected or theme.panelAlt

  love.graphics.setColor(background[1], background[2], background[3], 0.98)
  love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 7, 7)
  local border = selected and theme.secondary or theme.border
  if not seen then
    border = selected and theme.muted or theme.dim
  end
  love.graphics.setColor(border[1], border[2], border[3])
  love.graphics.setLineWidth(selected and 3 or 2)
  love.graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, 7, 7)
  love.graphics.setLineWidth(1)

  if seen and def then
    Portraits.enemy(def, rect.x + 22, rect.y + rect.h * 0.5, 13, info.boss)
  else
    love.graphics.setColor(theme.dim[1], theme.dim[2], theme.dim[3])
    love.graphics.circle("fill", rect.x + 22, rect.y + rect.h * 0.5, 13)
    love.graphics.setColor(theme.muted[1], theme.muted[2], theme.muted[3])
    love.graphics.circle("line", rect.x + 22, rect.y + rect.h * 0.5, 13)
  end

  love.graphics.setFont(Fonts.small)
  local nameColor = seen and theme.text or theme.dim
  love.graphics.setColor(nameColor[1], nameColor[2], nameColor[3])
  love.graphics.print(seen and info.name or "???", rect.x + 42, rect.y + 7)
  if seen then
    local labelColor = info.boss and theme.secondary or theme.accent
    love.graphics.setColor(labelColor[1], labelColor[2], labelColor[3])
  else
    love.graphics.setColor(theme.dim[1], theme.dim[2], theme.dim[3])
  end
  love.graphics.print(
    seen and (info.boss and "JEFE" or "ENEMIGO") or "SIN REGISTRO",
    rect.x + 42,
    rect.y + 26
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
  love.graphics.printf(
    Bestiario.tabLabels[tab.id] or Bestiario.categoryLabels[tab.id],
    tab.x, tab.y + 10, tab.w, "center"
  )
end

local function drawScrollbar(theme)
  if Bestiario.maxScroll <= 0 then return end
  local grid = Bestiario.grid
  local x = grid.x + grid.w + 3
  local w = 5
  love.graphics.setColor(theme.dim[1], theme.dim[2], theme.dim[3], 0.55)
  love.graphics.rectangle("fill", x, grid.y, w, grid.h, 3, 3)
  local ratio = grid.h / (grid.h + Bestiario.maxScroll)
  local thumbH = math.max(24, grid.h * ratio)
  local thumbY = grid.y + (grid.h - thumbH) * (Bestiario.scroll / Bestiario.maxScroll)
  love.graphics.setColor(theme.accent[1], theme.accent[2], theme.accent[3], 0.85)
  love.graphics.rectangle("fill", x, thumbY, w, thumbH, 3, 3)
end

function Bestiario.draw()
  Bestiario.layout()
  local panel = Bestiario.panel
  local px, py = panel.x, panel.y
  local theme = Themes.current()
  local selectedId = Bestiario.selectedId or Data.bestiaryOrder[1]
  local info = Data.bestiary[selectedId]
  local def = Data.enemyTypes[selectedId]
  local seen = Save.isEnemyDiscovered(selectedId)

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
  love.graphics.printf("BESTIARIO", px, py + 10, panel.w, "center")

  love.graphics.setFont(Fonts.small)
  love.graphics.setColor(theme.muted[1], theme.muted[2], theme.muted[3])
  love.graphics.printf(
    TextCache.format(
      "bestiario-progress",
      "Registrados: %d/%d · aparecen al encontrarlos en una partida",
      discoveredCount(),
      #Data.bestiaryOrder
    ),
    px,
    py + 50,
    panel.w,
    "center"
  )

  if Bestiario.selector then
    Bestiario.selector:draw(Bestiario.selectorPanel)
  end

  for _, tab in ipairs(Bestiario.tabs) do
    drawTab(tab, tab.id == Bestiario.category, theme)
  end

  setListClip(Bestiario.grid)
  for _, rect in ipairs(Bestiario.cards) do
    drawCard(rect, rect.id, theme)
  end
  clearListClip()

  if #Bestiario.cards == 0 then
    love.graphics.setFont(Fonts.body)
    love.graphics.setColor(theme.dim[1], theme.dim[2], theme.dim[3])
    love.graphics.printf(
      "Sin enemigos en esta categoría",
      Bestiario.grid.x,
      Bestiario.grid.y + Bestiario.grid.h * 0.5 - 10,
      Bestiario.grid.w,
      "center"
    )
  end
  drawScrollbar(theme)

  local detailX = Bestiario.detailRect.x
  local detailY = Bestiario.detailRect.y
  local detailW = Bestiario.detailRect.w
  local detailH = Bestiario.detailRect.h
  love.graphics.setColor(theme.panelAlt[1], theme.panelAlt[2], theme.panelAlt[3], 0.98)
  love.graphics.rectangle("fill", detailX, detailY, detailW, detailH, 10, 10)
  local detailBorder = seen and (info.boss and theme.secondary or theme.accent) or theme.border
  love.graphics.setColor(detailBorder[1], detailBorder[2], detailBorder[3])
  love.graphics.rectangle("line", detailX, detailY, detailW, detailH, 10, 10)

  if seen and def then
    Portraits.enemy(def, detailX + detailW * 0.5, detailY + 84, 54, info.boss)
  else
    love.graphics.setColor(theme.dim[1], theme.dim[2], theme.dim[3])
    love.graphics.circle("fill", detailX + detailW * 0.5, detailY + 84, 54)
    love.graphics.setColor(theme.muted[1], theme.muted[2], theme.muted[3])
    love.graphics.circle("line", detailX + detailW * 0.5, detailY + 84, 54)
  end

  love.graphics.setFont(Fonts.button)
  local titleColor = seen and theme.text or theme.dim
  love.graphics.setColor(titleColor[1], titleColor[2], titleColor[3])
  love.graphics.printf(
    seen and info.name or "ENEMIGO DESCONOCIDO",
    detailX + 16,
    detailY + 158,
    detailW - 32,
    "center"
  )

  love.graphics.setFont(Fonts.small)
  if seen then
    local labelColor = info.boss and theme.secondary or theme.accent
    love.graphics.setColor(labelColor[1], labelColor[2], labelColor[3])
  else
    love.graphics.setColor(theme.dim[1], theme.dim[2], theme.dim[3])
  end
  love.graphics.printf(
    seen and (info.boss and "JEFE DE MAZMORRA" or "ENEMIGO REGULAR") or "SIN REGISTRO",
    detailX + 16,
    detailY + 184,
    detailW - 32,
    "center"
  )

  love.graphics.setFont(Fonts.body)
  love.graphics.setColor(theme.text[1], theme.text[2], theme.text[3])
  love.graphics.printf(
    seen and info.desc or "Aún no registrado. Encuéntralo en una partida para revelar su retrato y sus habilidades.",
    detailX + 22,
    detailY + 216,
    detailW - 44,
    "center"
  )

  local back = Bestiario.rects.back
  love.graphics.setColor(theme.button[1], theme.button[2], theme.button[3], 0.98)
  love.graphics.rectangle("fill", back.x, back.y, back.w, back.h, 8, 8)
  love.graphics.setColor(theme.border[1], theme.border[2], theme.border[3])
  love.graphics.rectangle("line", back.x, back.y, back.w, back.h, 8, 8)
  love.graphics.setFont(Fonts.button)
  love.graphics.setColor(theme.text[1], theme.text[2], theme.text[3])
  love.graphics.printf("VOLVER", back.x, back.y + 11, back.w, "center")

  love.graphics.setFont(Fonts.small)
  love.graphics.setColor(theme.dim[1], theme.dim[2], theme.dim[3])
  love.graphics.printf(
    Bestiario.maxScroll > 0
      and "Toca una ficha · Desliza o rueda para recorrer · Tab cambia tipo · Esc volver"
      or "Toca una ficha · Flechas para recorrer · Tab cambia tipo · Esc volver",
    0,
    py + panel.h - 20,
    Screen.width,
    "center"
  )

  if Bestiario.selector then
    Bestiario.selector:drawConfirm(Bestiario.selectorPanel)
  end
end

return Bestiario
