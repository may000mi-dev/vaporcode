-- backpack_view.lua: dibujo y geometría de la mochila (activos + guardados).
-- La lógica de toques vive en backpack.lua para mantener ambos bajo ~300 líneas.
local Data = require("src.run.data")
local Fonts = require("src.utils.fonts")
local Util = require("src.utils.util")
local TextCache = require("src.utils.textcache")
local Screen = require("src.utils.screen")
local Themes = require("src.data.themes")

local Backpack = {}

Backpack.panel = { x = 178, y = 68, w = 604, h = 404 }
Backpack.closeButton = { x = 738, y = 78, w = 32, h = 32 }
Backpack.cancelButton = { x = 682, y = 306, w = 76, h = 26 }

local COLUMNS = 5
local slotW, slotGap = 104, 9
local activeY, activeH = 126, 52
local storageY, storageH, storageGap = 200, 30, 5
local actionsY, actionH = 354, 40
local pendingY = 300

-- Centra el panel y recoloca sus elementos según el tamaño visible.
function Backpack.layout()
  local panel = Backpack.panel
  panel.x = (Screen.width - panel.w) * 0.5
  panel.y = (Screen.height - panel.h) * 0.5

  local close = Backpack.closeButton
  close.x = panel.x + panel.w - 44
  close.y = panel.y + 10

  local cancel = Backpack.cancelButton
  cancel.x = panel.x + panel.w - 100
  cancel.y = panel.y + 238

  activeY = panel.y + 58
  storageY = panel.y + 132
  actionsY = panel.y + 286
  pendingY = panel.y + 232
end

-- Claves fijas: una clave concatenada por frame alocaría tanto como el string.
local activeIndexKeys, activeLabelKeys = {}, {}
for i = 1, 5 do
  activeIndexKeys[i] = "bp-i" .. i
  activeLabelKeys[i] = "bp-l" .. i
end
local storageIndexKeys, storageLabelKeys = {}, {}
for i = 1, 15 do
  storageIndexKeys[i] = "bp-s-i" .. i
  storageLabelKeys[i] = "bp-s-l" .. i
end

local function slotX(column)
  return Backpack.panel.x + 24 + (column - 1) * (slotW + slotGap)
end

function Backpack.activeRect(index)
  return {
    x = slotX(((index - 1) % COLUMNS) + 1),
    y = activeY,
    w = slotW,
    h = activeH,
  }
end

function Backpack.storageRect(index)
  local row = math.floor((index - 1) / COLUMNS)
  return {
    x = slotX(((index - 1) % COLUMNS) + 1),
    y = storageY + row * (storageH + storageGap),
    w = slotW,
    h = storageH,
  }
end

function Backpack.actionRect(index)
  local width, gap = 131, 10
  return {
    x = Backpack.panel.x + 24 + (index - 1) * (width + gap),
    y = actionsY,
    w = width,
    h = actionH,
  }
end

local function drawBorder(rect, color, width)
  love.graphics.setColor(color[1], color[2], color[3])
  love.graphics.setLineWidth(width)
  love.graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, 8, 8)
  love.graphics.setLineWidth(1)
end

local function drawActionButton(rect, label, enabled, color, theme)
  local background = enabled and theme.button or theme.panelAlt
  love.graphics.setColor(background[1], background[2], background[3], 0.98)
  love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 7, 7)
  if enabled and color then
    love.graphics.setColor(color[1], color[2], color[3])
  elseif enabled then
    love.graphics.setColor(theme.accent[1], theme.accent[2], theme.accent[3])
  else
    love.graphics.setColor(theme.border[1], theme.border[2], theme.border[3])
  end
  love.graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, 7, 7)
  love.graphics.setFont(Fonts.body)
  local text = enabled and theme.text or theme.dim
  love.graphics.setColor(text[1], text[2], text[3])
  love.graphics.printf(label, rect.x, rect.y + 11, rect.w, "center")
end

local function drawActiveSlot(run, index, pending, theme)
  local rect = Backpack.activeRect(index)
  local slot = run.inventory[index]
  local selected = run.selectionSection == "active" and run.selectedInventory == index

  love.graphics.setColor(theme.panelAlt[1], theme.panelAlt[2], theme.panelAlt[3], 0.98)
  love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 8, 8)

  if pending then
    local pulse = 0.55 + 0.45 * math.abs(math.sin(love.timer.getTime() * 4))
    drawBorder(rect, {
      theme.secondary[1] * pulse,
      theme.secondary[2] * pulse,
      theme.secondary[3] * pulse,
    }, 2)
  elseif selected then
    drawBorder(rect, theme.secondary, 3)
  else
    drawBorder(rect, theme.border, 1)
  end

  love.graphics.setFont(Fonts.small)
  love.graphics.setColor(theme.muted[1], theme.muted[2], theme.muted[3])
  love.graphics.print(TextCache.format(activeIndexKeys[index], "i%d", index), rect.x + 7, rect.y + 4)

  if slot then
    local def = Data.items[slot.itemId]
    local color = def.color
    love.graphics.setColor(color[1], color[2], color[3], 0.20)
    love.graphics.circle("fill", rect.x + 18, rect.y + 27, 16)
    love.graphics.setColor(color[1], color[2], color[3])
    love.graphics.circle("fill", rect.x + 18, rect.y + 27, 10)
    love.graphics.setFont(Fonts.button)
    love.graphics.setColor(theme.text[1], theme.text[2], theme.text[3])
    local amount = slot.amount or 1
    love.graphics.print(
      TextCache.format(activeLabelKeys[index], amount > 1 and "%sx%d" or "%s", def.short, amount),
      rect.x + 34,
      rect.y + 8
    )
    love.graphics.setFont(Fonts.small)
    love.graphics.setColor(theme.muted[1], theme.muted[2], theme.muted[3])
    love.graphics.printf(def.name, rect.x + 6, rect.y + 33, rect.w - 12, "center")
  else
    love.graphics.setFont(Fonts.small)
    love.graphics.setColor(theme.dim[1], theme.dim[2], theme.dim[3])
    love.graphics.printf("vacío", rect.x, rect.y + 20, rect.w, "center")
  end
end

local function drawStorageSlot(run, index, theme)
  local rect = Backpack.storageRect(index)
  local slot = run.storage[index]
  local selected = run.selectionSection == "inactive" and run.selectedStorage == index

  love.graphics.setColor(theme.panelAlt[1], theme.panelAlt[2], theme.panelAlt[3], 0.98)
  love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 6, 6)
  if selected then
    drawBorder(rect, theme.secondary, 2)
  else
    drawBorder(rect, theme.border, 1)
  end

  if slot then
    local def = Data.items[slot.itemId]
    local color = def.color
    love.graphics.setColor(color[1], color[2], color[3])
    love.graphics.circle("fill", rect.x + 15, rect.y + rect.h * 0.5, 7)
    love.graphics.setFont(Fonts.small)
    love.graphics.setColor(theme.text[1], theme.text[2], theme.text[3])
    local amount = slot.amount or 1
    love.graphics.print(
      TextCache.format(storageLabelKeys[index], amount > 1 and "%sx%d" or "%s", def.short, amount),
      rect.x + 27,
      rect.y + 8
    )
  else
    love.graphics.setFont(Fonts.small)
    love.graphics.setColor(theme.dim[1], theme.dim[2], theme.dim[3])
    love.graphics.print(TextCache.format(storageIndexKeys[index], "%d", index), rect.x + 6, rect.y + 8)
  end
end

local function drawDetail(run, slot, def, theme)
  local panel = Backpack.panel
  love.graphics.setFont(Fonts.body)
  if not def then
    love.graphics.setColor(theme.muted[1], theme.muted[2], theme.muted[3])
    love.graphics.printf(
      "Mochila vacía. Los ítems aparecen al derrotar enemigos o abrir cofres.",
      panel.x + 24,
      panel.y + 242,
      panel.w - 48,
      "center"
    )
    return
  end

  local section = run.selectionSection
  love.graphics.setColor(def.color[1], def.color[2], def.color[3])
  local amount = slot.amount or 1
  love.graphics.print(
    TextCache.format("bp-detail", amount > 1 and "%s x%d" or "%s", def.name, amount),
    panel.x + 24,
    panel.y + 238
  )
  love.graphics.setFont(Fonts.small)
  love.graphics.setColor(theme.muted[1], theme.muted[2], theme.muted[3])
  love.graphics.printf(def.desc or "", panel.x + 24, panel.y + 258, panel.w - 48, "left")

  local primaryLabel, primaryEnabled = "Activar", false
  local a1Enabled, a2Enabled = false, false
  if section == "active" then
    primaryLabel = "Guardar"
    primaryEnabled = #run.storage < Data.inventory.maxInactive
  elseif def.kind == "ability" then
    a1Enabled, a2Enabled = true, true
  else
    primaryEnabled = true
  end

  drawActionButton(Backpack.actionRect(1), primaryLabel, primaryEnabled, def.color, theme)
  drawActionButton(Backpack.actionRect(2), "A1 (R)", a1Enabled, def.color, theme)
  drawActionButton(Backpack.actionRect(3), "A2 (F)", a2Enabled, def.color, theme)
  drawActionButton(Backpack.actionRect(4), "Tirar", true, { 0.95, 0.45, 0.35 }, theme)
end

local function drawPending(run, theme)
  local panel = Backpack.panel
  local slot = run.storage[run.pendingStorageIndex]
  local def = slot and Data.items[slot.itemId]
  local name = def and def.name or "el ítem"

  love.graphics.setColor(theme.buttonSelected[1], theme.buttonSelected[2], theme.buttonSelected[3], 0.98)
  love.graphics.rectangle("fill", panel.x + 16, pendingY, panel.w - 32, 42, 8, 8)
  love.graphics.setColor(theme.secondary[1], theme.secondary[2], theme.secondary[3])
  love.graphics.rectangle("line", panel.x + 16, pendingY, panel.w - 32, 42, 8, 8)

  love.graphics.setFont(Fonts.small)
  love.graphics.setColor(theme.text[1], theme.text[2], theme.text[3])
  love.graphics.printf(
    TextCache.format(
      "bp-pending",
      "Elige un ACTIVO para guardarlo y activar %s. Se intercambian.",
      name
    ),
    panel.x + 24,
    pendingY + 7,
    panel.w - 48 - 92,
    "left"
  )

  local cancel = Backpack.cancelButton
  love.graphics.setColor(theme.button[1], theme.button[2], theme.button[3], 0.98)
  love.graphics.rectangle("fill", cancel.x, cancel.y, cancel.w, cancel.h, 6, 6)
  love.graphics.setColor(theme.secondary[1], theme.secondary[2], theme.secondary[3])
  love.graphics.rectangle("line", cancel.x, cancel.y, cancel.w, cancel.h, 6, 6)
  love.graphics.setFont(Fonts.small)
  love.graphics.setColor(theme.text[1], theme.text[2], theme.text[3])
  love.graphics.printf("Cancelar", cancel.x, cancel.y + 6, cancel.w, "center")
end

function Backpack.draw(run)
  Backpack.layout()
  local theme = Themes.current()
  local panel = Backpack.panel
  love.graphics.setColor(0, 0, 0, 0.48)
  love.graphics.rectangle("fill", 0, 0, Screen.width, Screen.height)

  love.graphics.setColor(theme.panel[1], theme.panel[2], theme.panel[3], 0.98)
  love.graphics.rectangle("fill", panel.x, panel.y, panel.w, panel.h, 12, 12)
  love.graphics.setColor(theme.border[1], theme.border[2], theme.border[3])
  love.graphics.rectangle("line", panel.x, panel.y, panel.w, panel.h, 12, 12)

  love.graphics.setFont(Fonts.button)
  love.graphics.setColor(theme.accent[1], theme.accent[2], theme.accent[3])
  love.graphics.print("MOCHILA", panel.x + 24, panel.y + 18)
  love.graphics.setFont(Fonts.small)
  love.graphics.setColor(theme.muted[1], theme.muted[2], theme.muted[3])
  love.graphics.print("El juego sigue activo · 5 activos + 15 guardados", panel.x + 150, panel.y + 22)

  local close = Backpack.closeButton
  love.graphics.setColor(theme.button[1], theme.button[2], theme.button[3], 0.98)
  love.graphics.rectangle("fill", close.x, close.y, close.w, close.h, 6, 6)
  love.graphics.setColor(theme.border[1], theme.border[2], theme.border[3])
  love.graphics.rectangle("line", close.x, close.y, close.w, close.h, 6, 6)
  love.graphics.setFont(Fonts.button)
  love.graphics.setColor(theme.text[1], theme.text[2], theme.text[3])
  love.graphics.printf("X", close.x, close.y + 6, close.w, "center")

  love.graphics.setFont(Fonts.small)
  love.graphics.setColor(theme.muted[1], theme.muted[2], theme.muted[3])
  love.graphics.print("ACTIVOS · aplican ahora", panel.x + 24, panel.y + 40)
  love.graphics.print("GUARDADOS · consulta y alquimia", panel.x + 24, panel.y + 116)

  local pending = run.pendingStorageIndex ~= nil
  for index = 1, Data.inventory.maxActive do
    drawActiveSlot(run, index, pending, theme)
  end
  for index = 1, Data.inventory.maxInactive do
    drawStorageSlot(run, index, theme)
  end

  if pending then
    drawPending(run, theme)
  else
    local _, _, slot, def = run:selectedSlot()
    drawDetail(run, slot, def, theme)
  end

  love.graphics.setFont(Fonts.small)
  love.graphics.setColor(theme.dim[1], theme.dim[2], theme.dim[3])
  love.graphics.printf(
    "Toca un espacio · Tab cambia zona · Enter activa/guarda · Q/W asignan · X tira · B cierra",
    panel.x + 24,
    panel.y + panel.h - 28,
    panel.w - 48,
    "center"
  )
end

return Backpack
