-- shop.lua: tienda y alquimia; no pausa la partida.
local Data = require("src.run.data")
local Save = require("src.run.save")
local Fonts = require("src.utils.fonts")
local Util = require("src.utils.util")

local Shop = {}

Shop.panel = { x = 120, y = 44, w = 720, h = 456 }
Shop.closeButton = { x = 794, y = 54, w = 32, h = 32 }
Shop.tabBuy = { x = 146, y = 92, w = 150, h = 34 }
Shop.tabAlchemy = { x = 306, y = 92, w = 150, h = 34 }

local rowW, rowH, rowGap = 328, 38, 6
local listY = 136

local function buyRowRect(index)
  local column = (index - 1) % 2
  local row = math.floor((index - 1) / 2)
  return {
    x = Shop.panel.x + 26 + column * (rowW + 14),
    y = listY + row * (rowH + rowGap),
    w = rowW,
    h = rowH,
  }
end

local function alchemyRowRect(index)
  return {
    x = Shop.panel.x + 26,
    y = listY + (index - 1) * (rowH + rowGap),
    w = Shop.panel.w - 52,
    h = rowH,
  }
end

local function drawPanel()
  local panel = Shop.panel
  love.graphics.setColor(0, 0, 0, 0.50)
  love.graphics.rectangle("fill", 0, 0, 960, 540)
  love.graphics.setColor(0.055, 0.070, 0.085, 0.98)
  love.graphics.rectangle("fill", panel.x, panel.y, panel.w, panel.h, 12, 12)
  love.graphics.setColor(0.78, 0.60, 0.24)
  love.graphics.rectangle("line", panel.x, panel.y, panel.w, panel.h, 12, 12)
end

local function drawTab(rect, label, active)
  love.graphics.setColor(active and 0.18 or 0.09, active and 0.24 or 0.12, active and 0.22 or 0.14, 0.98)
  love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 7, 7)
  love.graphics.setColor(active and 1.00 or 0.36, active and 0.82 or 0.44, active and 0.32 or 0.50)
  love.graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, 7, 7)
  love.graphics.setFont(Fonts.body)
  love.graphics.setColor(active and 1 or 0.62, active and 1 or 0.68, active and 1 or 0.74)
  love.graphics.printf(label, rect.x, rect.y + 8, rect.w, "center")
end

local function drawBuyList(run)
  for index, itemId in ipairs(Data.shop.items) do
    local rect = buyRowRect(index)
    local def = Data.items[itemId]
    local price = Data.shop.prices[itemId] or 0
    local affordable = Save.data.coins >= price

    love.graphics.setColor(0.09, 0.115, 0.135, 0.98)
    love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 6, 6)
    love.graphics.setColor(affordable and 0.28 or 0.18, affordable and 0.40 or 0.22, affordable and 0.36 or 0.24)
    love.graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, 6, 6)

    love.graphics.setColor(def.color[1], def.color[2], def.color[3])
    love.graphics.circle("fill", rect.x + 18, rect.y + rect.h * 0.5, 10)
    love.graphics.setFont(Fonts.small)
    love.graphics.setColor(0.90, 0.94, 0.98)
    love.graphics.print(def.name, rect.x + 36, rect.y + 4)
    love.graphics.setColor(0.58, 0.66, 0.74)
    love.graphics.print(def.short, rect.x + 36, rect.y + 20)

    love.graphics.setFont(Fonts.body)
    love.graphics.setColor(affordable and 1.00 or 0.65, affordable and 0.86 or 0.40, affordable and 0.35 or 0.32)
    love.graphics.printf(price .. " monedas", rect.x + rect.w - 130, rect.y + 9, 120, "right")
  end
end

local function drawAlchemy(run)
  local candidates = run:alchemyCandidates()
  if #candidates == 0 then
    love.graphics.setFont(Fonts.body)
    love.graphics.setColor(0.68, 0.76, 0.84)
    love.graphics.printf(
      "Necesitas dos ítems pasivos iguales y del mismo nivel. Cada combinación sube x1 hasta x5.",
      Shop.panel.x + 40,
      190,
      Shop.panel.w - 80,
      "center"
    )
    return
  end

  for index, candidate in ipairs(candidates) do
    if index > 7 then break end
    local rect = alchemyRowRect(index)
    local def = Data.items[candidate.itemId]
    local affordable = Save.data.coins >= candidate.cost

    love.graphics.setColor(0.09, 0.115, 0.135, 0.98)
    love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 6, 6)
    love.graphics.setColor(affordable and 0.30 or 0.20, affordable and 0.42 or 0.24, affordable and 0.36 or 0.26)
    love.graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, 6, 6)

    love.graphics.setColor(def.color[1], def.color[2], def.color[3])
    love.graphics.circle("fill", rect.x + 20, rect.y + rect.h * 0.5, 11)
    love.graphics.setFont(Fonts.body)
    love.graphics.setColor(0.92, 0.95, 1.00)
    love.graphics.print(
      def.name .. " x" .. candidate.amount .. " + " .. def.name .. " x" .. candidate.amount
        .. "  ->  " .. def.name .. " x" .. candidate.result,
      rect.x + 40,
      rect.y + 9
    )

    love.graphics.setColor(affordable and 1.00 or 0.65, affordable and 0.86 or 0.40, affordable and 0.35 or 0.32)
    love.graphics.printf(candidate.cost .. " monedas", rect.x + rect.w - 126, rect.y + 9, 112, "right")
  end
end

function Shop.draw(run)
  drawPanel()

  love.graphics.setFont(Fonts.button)
  love.graphics.setColor(1.00, 0.84, 0.40)
  love.graphics.print("TIENDA DE ENGRANAJES", Shop.panel.x + 26, Shop.panel.y + 18)
  love.graphics.setFont(Fonts.small)
  love.graphics.setColor(0.68, 0.74, 0.80)
  love.graphics.print("Activo · Nv.15 / piso 10", Shop.panel.x + 260, Shop.panel.y + 23)
  love.graphics.setColor(1.00, 0.86, 0.35)
  love.graphics.printf("Monedas " .. Save.data.coins, Shop.panel.x + 490, Shop.panel.y + 23, 160, "right")

  local close = Shop.closeButton
  love.graphics.setColor(0.10, 0.13, 0.16, 0.98)
  love.graphics.rectangle("fill", close.x, close.y, close.w, close.h, 6, 6)
  love.graphics.setColor(0.55, 0.70, 0.78)
  love.graphics.rectangle("line", close.x, close.y, close.w, close.h, 6, 6)
  love.graphics.setFont(Fonts.button)
  love.graphics.printf("X", close.x, close.y + 6, close.w, "center")

  drawTab(Shop.tabBuy, "Comprar", run.shopTab ~= "alchemy")
  drawTab(Shop.tabAlchemy, "Alquimia", run.shopTab == "alchemy")

  if run.shopTab == "alchemy" then
    drawAlchemy(run)
  else
    drawBuyList(run)
  end

  love.graphics.setFont(Fonts.small)
  love.graphics.setColor(0.52, 0.60, 0.68)
  love.graphics.printf(
    "Toca un artículo para comprar · Alquimia combina dos ítems iguales · V/escape cierra",
    Shop.panel.x + 26,
    Shop.panel.y + Shop.panel.h - 26,
    Shop.panel.w - 52,
    "center"
  )
end

function Shop.pressed(run, x, y)
  if Util.inside(x, y, Shop.closeButton) then
    run.overlay = nil
    return true
  end
  if Util.inside(x, y, Shop.tabBuy) then
    run.shopTab = "buy"
    return true
  elseif Util.inside(x, y, Shop.tabAlchemy) then
    run.shopTab = "alchemy"
    return true
  end

  if run.shopTab == "alchemy" then
    local candidates = run:alchemyCandidates()
    for index, candidate in ipairs(candidates) do
      if index > 7 then break end
      if Util.inside(x, y, alchemyRowRect(index)) then
        run:combineAlchemy(candidate)
        return true
      end
    end
  else
    for index, itemId in ipairs(Data.shop.items) do
      if Util.inside(x, y, buyRowRect(index)) then
        local status = run:buyItem(itemId)
        if status == "coins" then
          run:notify("Monedas insuficientes", { 1.00, 0.45, 0.35 })
        elseif status == "full" then
          run:notify("Mochila llena", { 1.00, 0.45, 0.35 })
        elseif status == "duplicate" then
          run:notify("Ya tienes ese ítem", { 1.00, 0.70, 0.35 })
        end
        return true
      end
    end
  end

  return Util.inside(x, y, Shop.panel)
end

return Shop
