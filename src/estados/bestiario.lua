-- bestiario.lua: enemigos vistos, retrato procedural y descripción de combate.
local Data = require("src.run.data")
local Save = require("src.run.save")
local Fonts = require("src.utils.fonts")
local Util = require("src.utils.util")
local Screen = require("src.utils.screen")
local State = require("src.estados")
local Portraits = require("src.utils.portraits")
local TextCache = require("src.utils.textcache")

local Bestiario = {
  panel = { x = 0, y = 0, w = 0, h = 0 },
  rects = {},
  cards = {},
  selectedId = nil,
  message = nil,
  messageTimer = 0,
}

local function discoveredCount()
  local count = 0
  for _, id in ipairs(Data.bestiaryOrder) do
    if Save.isEnemyDiscovered(id) then
      count = count + 1
    end
  end
  return count
end

function Bestiario.layout()
  local width = math.min(Screen.width - 60, 900)
  local height = math.min(Screen.height - 30, 500)
  local x = (Screen.width - width) * 0.5
  local y = (Screen.height - height) * 0.5
  Bestiario.panel = { x = x, y = y, w = width, h = height }

  local cols = 3
  local cardW = 154
  local cardH = 48
  local gap = 7
  local gridX = x + 32
  local gridY = y + 84
  Bestiario.cards = {}
  for index, id in ipairs(Data.bestiaryOrder) do
    local col = (index - 1) % cols
    local row = math.floor((index - 1) / cols)
    Bestiario.cards[#Bestiario.cards + 1] = {
      x = gridX + col * (cardW + gap),
      y = gridY + row * (cardH + gap),
      w = cardW,
      h = cardH,
      id = id,
    }
  end

  Bestiario.rects.back = {
    x = x + width - 180,
    y = y + height - 58,
    w = 148,
    h = 40,
  }
end

function Bestiario.enter()
  Bestiario.message = nil
  Bestiario.messageTimer = 0
  if not Bestiario.selectedId or not Data.bestiary[Bestiario.selectedId] then
    Bestiario.selectedId = Data.bestiaryOrder[1]
  end
  Bestiario.layout()
end

function Bestiario.update(dt)
  if Bestiario.messageTimer > 0 then
    Bestiario.messageTimer = math.max(0, Bestiario.messageTimer - dt)
    if Bestiario.messageTimer == 0 then
      Bestiario.message = nil
    end
  end
end

local function navigate(delta)
  local total = #Data.bestiaryOrder
  if total == 0 then return end
  local index = 1
  for i, id in ipairs(Data.bestiaryOrder) do
    if id == Bestiario.selectedId then
      index = i
      break
    end
  end
  index = ((index - 1 + delta) % total) + 1
  Bestiario.selectedId = Data.bestiaryOrder[index]
end

function Bestiario.keypressed(key, isrepeat)
  if isrepeat then return end
  if key == "escape" or key == "backspace" then
    State.switch("menu")
  elseif key == "left" or key == "up" then
    navigate(-1)
  elseif key == "right" or key == "down" then
    navigate(1)
  end
end

function Bestiario.pressed(x, y)
  Bestiario.layout()
  for _, rect in ipairs(Bestiario.cards) do
    if Util.inside(x, y, rect) then
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
  Bestiario.pressed(x, y)
end

function Bestiario.mousemoved(x, y) end
function Bestiario.mousereleased(x, y) end
function Bestiario.touchmoved(id, x, y) end
function Bestiario.touchreleased(id, x, y) end
function Bestiario.focus(focused) end

local function drawCard(rect, id)
  local info = Data.bestiary[id]
  local def = Data.enemyTypes[id]
  local seen = Save.isEnemyDiscovered(id)
  local selected = Bestiario.selectedId == id

  love.graphics.setColor(
    selected and 0.14 or 0.07,
    selected and 0.18 or 0.09,
    selected and 0.22 or 0.12,
    0.98
  )
  love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 7, 7)
  love.graphics.setColor(
    selected and 0.92 or (seen and 0.42 or 0.25),
    selected and 0.72 or (seen and 0.54 or 0.28),
    selected and 0.34 or (seen and 0.34 or 0.32)
  )
  love.graphics.setLineWidth(selected and 3 or 2)
  love.graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, 7, 7)
  love.graphics.setLineWidth(1)

  if seen and def then
    Portraits.enemy(def, rect.x + 22, rect.y + rect.h * 0.5, 13, info.boss)
  else
    love.graphics.setColor(0.18, 0.20, 0.24)
    love.graphics.circle("fill", rect.x + 22, rect.y + rect.h * 0.5, 13)
    love.graphics.setColor(0.30, 0.34, 0.38)
    love.graphics.circle("line", rect.x + 22, rect.y + rect.h * 0.5, 13)
  end

  love.graphics.setFont(Fonts.small)
  love.graphics.setColor(seen and 0.92 or 0.48, seen and 0.94 or 0.50, seen and 0.98 or 0.54)
  love.graphics.print(seen and info.name or "???", rect.x + 42, rect.y + 7)
  if seen then
    love.graphics.setColor(
      info.boss and 0.92 or 0.58,
      info.boss and 0.64 or 0.64,
      info.boss and 0.30 or 0.68
    )
  else
    love.graphics.setColor(0.42, 0.44, 0.50)
  end
  love.graphics.print(
    seen and (info.boss and "JEFE" or "ENEMIGO") or "SIN REGISTRO",
    rect.x + 42,
    rect.y + 27
  )
end

function Bestiario.draw()
  Bestiario.layout()
  local panel = Bestiario.panel
  local px, py = panel.x, panel.y
  local selectedId = Bestiario.selectedId or Data.bestiaryOrder[1]
  local info = Data.bestiary[selectedId]
  local def = Data.enemyTypes[selectedId]
  local seen = Save.isEnemyDiscovered(selectedId)

  love.graphics.setColor(0.04, 0.05, 0.07)
  love.graphics.rectangle("fill", 0, 0, Screen.width, Screen.height)
  love.graphics.setColor(0.08, 0.06, 0.10)
  love.graphics.circle("fill", 30, Screen.height - 20, 150)
  love.graphics.circle("fill", Screen.width - 20, 30, 180)

  love.graphics.setColor(0.05, 0.07, 0.09, 0.98)
  love.graphics.rectangle("fill", px, py, panel.w, panel.h, 12, 12)
  love.graphics.setColor(0.44, 0.34, 0.56)
  love.graphics.rectangle("line", px, py, panel.w, panel.h, 12, 12)

  love.graphics.setFont(Fonts.title)
  love.graphics.setColor(0.92, 0.76, 1.00)
  love.graphics.printf("BESTIARIO", px, py + 14, panel.w, "center")

  love.graphics.setFont(Fonts.small)
  love.graphics.setColor(0.68, 0.68, 0.80)
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

  for _, rect in ipairs(Bestiario.cards) do
    drawCard(rect, rect.id)
  end

  local detailX = px + 534
  local detailY = py + 84
  local detailW = px + panel.w - 32 - detailX
  local detailH = 340
  love.graphics.setColor(0.07, 0.09, 0.13, 0.98)
  love.graphics.rectangle("fill", detailX, detailY, detailW, detailH, 10, 10)
  love.graphics.setColor(
    seen and info.boss and 0.68 or 0.38,
    seen and info.boss and 0.48 or 0.56,
    seen and info.boss and 0.28 or 0.72
  )
  love.graphics.rectangle("line", detailX, detailY, detailW, detailH, 10, 10)

  if seen and def then
    Portraits.enemy(def, detailX + detailW * 0.5, detailY + 84, 54, info.boss)
  else
    love.graphics.setColor(0.17, 0.19, 0.23)
    love.graphics.circle("fill", detailX + detailW * 0.5, detailY + 84, 54)
    love.graphics.setColor(0.30, 0.33, 0.38)
    love.graphics.circle("line", detailX + detailW * 0.5, detailY + 84, 54)
  end

  love.graphics.setFont(Fonts.button)
  love.graphics.setColor(seen and 1 or 0.55, seen and 1 or 0.58, seen and 1 or 0.64)
  love.graphics.printf(
    seen and info.name or "ENEMIGO DESCONOCIDO",
    detailX + 16,
    detailY + 158,
    detailW - 32,
    "center"
  )

  love.graphics.setFont(Fonts.small)
  if seen then
    love.graphics.setColor(
      info.boss and 0.95 or 0.62,
      info.boss and 0.70 or 0.68,
      info.boss and 0.36 or 0.74
    )
  else
    love.graphics.setColor(0.42, 0.44, 0.50)
  end
  love.graphics.printf(
    seen and (info.boss and "JEFE DE MAZMORRA" or "ENEMIGO REGULAR") or "SIN REGISTRO",
    detailX + 16,
    detailY + 184,
    detailW - 32,
    "center"
  )

  love.graphics.setFont(Fonts.body)
  love.graphics.setColor(0.84, 0.87, 0.93)
  love.graphics.printf(
    seen and info.desc or "Aún no registrado. Encuéntralo en una partida para revelar su retrato y sus habilidades.",
    detailX + 22,
    detailY + 216,
    detailW - 44,
    "center"
  )

  local back = Bestiario.rects.back
  love.graphics.setColor(0.10, 0.13, 0.18, 0.98)
  love.graphics.rectangle("fill", back.x, back.y, back.w, back.h, 8, 8)
  love.graphics.setColor(0.55, 0.72, 0.82)
  love.graphics.rectangle("line", back.x, back.y, back.w, back.h, 8, 8)
  love.graphics.setFont(Fonts.button)
  love.graphics.setColor(0.88, 0.92, 0.96)
  love.graphics.printf("VOLVER", back.x, back.y + 11, back.w, "center")

  love.graphics.setFont(Fonts.small)
  love.graphics.setColor(0.55, 0.60, 0.68)
  love.graphics.printf(
    "Toca una ficha · Flechas para recorrer · Esc volver",
    0,
    py + panel.h - 20,
    Screen.width,
    "center"
  )
end

return Bestiario
