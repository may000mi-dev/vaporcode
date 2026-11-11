-- backpack.lua: mochila de 5 espacios; el juego sigue corriendo mientras está abierta.
local Data = require("src.run.data")
local Fonts = require("src.utils.fonts")
local Util = require("src.utils.util")

local Backpack = {}

Backpack.panel = { x = 178, y = 68, w = 604, h = 404 }
Backpack.closeButton = { x = 738, y = 78, w = 32, h = 32 }

local slotW, slotH, slotGap = 104, 82, 10
local slotY = 132

function Backpack.slotRect(index)
  local panel = Backpack.panel
  local x = panel.x + 24 + (index - 1) * (slotW + slotGap)
  return { x = x, y = slotY, w = slotW, h = slotH }
end

local function actionRect(index)
  local panel = Backpack.panel
  local width = 150
  local gap = 16
  local total = width * 3 + gap * 2
  local startX = panel.x + (panel.w - total) * 0.5
  return {
    x = startX + (index - 1) * (width + gap),
    y = 356,
    w = width,
    h = 42,
  }
end

local function drawAction(rect, label, enabled, color)
  if enabled then
    love.graphics.setColor(0.12, 0.19, 0.23, 0.98)
  else
    love.graphics.setColor(0.09, 0.11, 0.13, 0.95)
  end
  love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 7, 7)
  if enabled and color then
    love.graphics.setColor(color[1], color[2], color[3])
  else
    love.graphics.setColor(0.28, 0.36, 0.42)
  end
  love.graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, 7, 7)
  love.graphics.setFont(Fonts.body)
  love.graphics.setColor(enabled and 1 or 0.48, enabled and 1 or 0.52, enabled and 1 or 0.58)
  love.graphics.printf(label, rect.x, rect.y + 11, rect.w, "center")
end

function Backpack.draw(run)
  local panel = Backpack.panel
  love.graphics.setColor(0, 0, 0, 0.48)
  love.graphics.rectangle("fill", 0, 0, 960, 540)

  love.graphics.setColor(0.055, 0.075, 0.095, 0.98)
  love.graphics.rectangle("fill", panel.x, panel.y, panel.w, panel.h, 12, 12)
  love.graphics.setColor(0.30, 0.52, 0.60)
  love.graphics.rectangle("line", panel.x, panel.y, panel.w, panel.h, 12, 12)

  love.graphics.setFont(Fonts.button)
  love.graphics.setColor(0.62, 0.92, 1.00)
  love.graphics.print("MOCHILA", panel.x + 24, panel.y + 18)
  love.graphics.setFont(Fonts.small)
  love.graphics.setColor(0.58, 0.68, 0.76)
  love.graphics.print("El juego sigue activo · máximo 5 ítems", panel.x + 150, panel.y + 22)

  local close = Backpack.closeButton
  love.graphics.setColor(0.10, 0.13, 0.16, 0.98)
  love.graphics.rectangle("fill", close.x, close.y, close.w, close.h, 6, 6)
  love.graphics.setColor(0.55, 0.70, 0.78)
  love.graphics.rectangle("line", close.x, close.y, close.w, close.h, 6, 6)
  love.graphics.setFont(Fonts.button)
  love.graphics.printf("X", close.x, close.y + 6, close.w, "center")

  for index = 1, Data.inventory.maxSlots do
    local rect = Backpack.slotRect(index)
    local slot = run.inventory[index]
    local selected = run.selectedInventory == index

    love.graphics.setColor(0.045, 0.060, 0.075, 0.98)
    love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 8, 8)
    if selected then
      love.graphics.setColor(1.00, 0.82, 0.32)
      love.graphics.setLineWidth(3)
    else
      love.graphics.setColor(0.20, 0.28, 0.34)
      love.graphics.setLineWidth(1)
    end
    love.graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, 8, 8)
    love.graphics.setLineWidth(1)

    love.graphics.setFont(Fonts.small)
    love.graphics.setColor(0.44, 0.52, 0.60)
    love.graphics.print("i" .. index, rect.x + 7, rect.y + 5)

    if slot then
      local def = Data.items[slot.itemId]
      local color = def.color
      love.graphics.setColor(color[1], color[2], color[3], 0.20)
      love.graphics.circle("fill", rect.x + rect.w * 0.5, rect.y + 35, 22)
      love.graphics.setColor(color[1], color[2], color[3])
      love.graphics.circle("fill", rect.x + rect.w * 0.5, rect.y + 35, 14)
      love.graphics.setFont(Fonts.button)
      love.graphics.setColor(1, 1, 1)
      local label = def.short
      if slot.amount and slot.amount > 1 then
        label = label .. "x" .. slot.amount
      end
      love.graphics.printf(label, rect.x, rect.y + 27, rect.w, "center")
      love.graphics.setFont(Fonts.small)
      love.graphics.setColor(0.72, 0.78, 0.84)
      love.graphics.printf(def.name, rect.x + 4, rect.y + 58, rect.w - 8, "center")
    else
      love.graphics.setFont(Fonts.small)
      love.graphics.setColor(0.30, 0.36, 0.42)
      love.graphics.printf("vacío", rect.x, rect.y + 38, rect.w, "center")
    end
  end

  local slot = run.inventory[run.selectedInventory]
  local def = slot and Data.items[slot.itemId]
  love.graphics.setFont(Fonts.body)
  if def then
    love.graphics.setColor(def.color[1], def.color[2], def.color[3])
    love.graphics.print(
      def.name .. (slot.amount and slot.amount > 1 and (" x" .. slot.amount) or ""),
      panel.x + 24,
      234
    )
    love.graphics.setFont(Fonts.small)
    love.graphics.setColor(0.72, 0.79, 0.86)
    love.graphics.printf(def.desc or "", panel.x + 24, 258, panel.w - 48, "left")

    local a1 = actionRect(1)
    local a2 = actionRect(2)
    local discard = actionRect(3)
    local canEquip = def.kind == "ability"
    drawAction(a1, "Asignar a A1 (R)", canEquip, def.color)
    drawAction(a2, "Asignar a A2 (F)", canEquip, def.color)
    drawAction(discard, "Tirar ítem", true, { 0.95, 0.45, 0.35 })
  else
    love.graphics.setColor(0.60, 0.68, 0.76)
    love.graphics.printf(
      "Mochila vacía. Los ítems aparecen al derrotar enemigos o abrir cofres.",
      panel.x + 24,
      244,
      panel.w - 48,
      "center"
    )
  end

  love.graphics.setFont(Fonts.small)
  love.graphics.setColor(0.52, 0.60, 0.68)
  love.graphics.printf(
    "Toca un espacio para seleccionarlo · B cierra · 1-5 selecciona · Q/W asigna · X tira",
    panel.x + 24,
    panel.y + panel.h - 28,
    panel.w - 48,
    "center"
  )
end

function Backpack.pressed(run, x, y)
  if Util.inside(x, y, Backpack.closeButton) then
    run.overlay = nil
    return true
  end

  for index = 1, Data.inventory.maxSlots do
    if Util.inside(x, y, Backpack.slotRect(index)) then
      run.selectedInventory = index
      return true
    end
  end

  local slot = run.inventory[run.selectedInventory]
  local def = slot and Data.items[slot.itemId]
  if def then
    local a1 = actionRect(1)
    local a2 = actionRect(2)
    local discard = actionRect(3)
    if def.kind == "ability" and Util.inside(x, y, a1) then
      run:equipInventoryAbility(run.selectedInventory, 1)
      return true
    elseif def.kind == "ability" and Util.inside(x, y, a2) then
      run:equipInventoryAbility(run.selectedInventory, 2)
      return true
    elseif Util.inside(x, y, discard) then
      run:removeInventoryAt(run.selectedInventory)
      return true
    end
  end

  return Util.inside(x, y, Backpack.panel)
end

return Backpack
