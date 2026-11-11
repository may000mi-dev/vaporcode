-- fx.lua: partículas y textos flotantes, actualizados en un solo recorrido.
local Fonts = require("src.utils.fonts")

local FX = { list = {} }

function FX.clear()
  FX.list = {}
end

function FX.add(text, x, y, color)
  FX.list[#FX.list + 1] = {
    kind = "text",
    text = text,
    x = x,
    y = y,
    vy = -30,
    life = 0.9,
    maxLife = 0.9,
    color = color or { 1.0, 0.90, 0.40 },
  }
end

function FX.ring(x, y, radius, color)
  FX.list[#FX.list + 1] = {
    kind = "ring",
    x = x,
    y = y,
    radius = radius,
    life = 0.35,
    maxLife = 0.35,
    color = color or { 0.50, 0.90, 1.00 },
  }
end

function FX.line(x1, y1, x2, y2, color, life, width)
  local duration = life or 0.24
  FX.list[#FX.list + 1] = {
    kind = "line",
    x1 = x1,
    y1 = y1,
    x2 = x2,
    y2 = y2,
    width = width or 2,
    life = duration,
    maxLife = duration,
    color = color or { 0.50, 0.90, 1.00 },
  }
end

function FX.burst(x, y, count, color)
  for _ = 1, count do
    local angle = love.math.random() * math.pi * 2
    local speed = 50 + love.math.random() * 110
    local life = 0.35 + love.math.random() * 0.35
    FX.list[#FX.list + 1] = {
      kind = "particle",
      x = x,
      y = y,
      vx = math.cos(angle) * speed,
      vy = math.sin(angle) * speed,
      life = life,
      maxLife = life,
      radius = 2 + love.math.random() * 2,
      color = color or { 1.0, 0.70, 0.30 },
    }
  end
end

local atan2 = math.atan2 or math.atan

-- Restos que vuelan hacia el jugador para simular la recolección.
function FX.collect(x, y, count, color, targetX, targetY)
  local base = love.math.random() * math.pi * 2
  if targetX and targetY then
    base = atan2(targetY - y, targetX - x)
  end

  for _ = 1, count do
    local angle = base + (love.math.random() - 0.5) * 0.9
    local speed = 90 + love.math.random() * 110
    local life = 0.45 + love.math.random() * 0.25
    FX.list[#FX.list + 1] = {
      kind = "collect",
      x = x,
      y = y,
      vx = math.cos(angle) * speed,
      vy = math.sin(angle) * speed,
      targetX = targetX,
      targetY = targetY,
      life = life,
      maxLife = life,
      radius = 2 + love.math.random() * 2,
      gear = love.math.random() < 0.5,
      color = color or { 1.0, 0.70, 0.30 },
    }
  end
end

function FX.update(dt)
  local i = 1
  while i <= #FX.list do
    local item = FX.list[i]
    item.life = item.life - dt

    if item.life <= 0 then
      FX.list[i] = FX.list[#FX.list]
      FX.list[#FX.list] = nil
    else
      if item.kind == "text" then
        item.y = item.y + item.vy * dt
      elseif item.kind == "particle" then
        item.x = item.x + item.vx * dt
        item.y = item.y + item.vy * dt
        item.vx = item.vx * 0.94
        item.vy = item.vy * 0.94
      elseif item.kind == "collect" then
        local dx = item.targetX - item.x
        local dy = item.targetY - item.y
        local distance = math.sqrt(dx * dx + dy * dy)
        if distance > 1 then
          local pull = 900 * dt
          item.vx = item.vx + (dx / distance) * pull
          item.vy = item.vy + (dy / distance) * pull
        end
        item.x = item.x + item.vx * dt
        item.y = item.y + item.vy * dt
      end
      i = i + 1
    end
  end
end

function FX.drawWorld()
  for _, item in ipairs(FX.list) do
    if item.kind == "particle" then
      local alpha = math.max(0, item.life / item.maxLife)
      love.graphics.setColor(item.color[1], item.color[2], item.color[3], alpha)
      love.graphics.circle("fill", item.x, item.y, math.max(0.5, item.radius * alpha))
    elseif item.kind == "collect" then
      local alpha = math.max(0, item.life / item.maxLife)
      local radius = math.max(0.5, item.radius * alpha)
      love.graphics.setColor(item.color[1], item.color[2], item.color[3], alpha)
      love.graphics.circle("fill", item.x, item.y, radius)
      if item.gear then
        love.graphics.setColor(1, 1, 1, alpha * 0.65)
        love.graphics.line(item.x - radius, item.y, item.x + radius, item.y)
        love.graphics.line(item.x, item.y - radius, item.x, item.y + radius)
      end
    elseif item.kind == "ring" then
      local progress = 1 - item.life / item.maxLife
      local alpha = math.max(0, item.life / item.maxLife)
      love.graphics.setColor(item.color[1], item.color[2], item.color[3], alpha)
      love.graphics.setLineWidth(3)
      love.graphics.circle("line", item.x, item.y, item.radius * progress)
      love.graphics.setLineWidth(1)
    elseif item.kind == "line" then
      local alpha = math.max(0, item.life / item.maxLife)
      love.graphics.setColor(item.color[1], item.color[2], item.color[3], alpha)
      love.graphics.setLineWidth(item.width)
      love.graphics.line(item.x1, item.y1, item.x2, item.y2)
      love.graphics.setLineWidth(1)
    end
  end
end

function FX.drawToasts()
  love.graphics.setFont(Fonts.small)
  for _, item in ipairs(FX.list) do
    if item.kind == "text" then
      local alpha = math.max(0, item.life / item.maxLife)
      love.graphics.setColor(item.color[1], item.color[2], item.color[3], alpha)
      love.graphics.printf(item.text, item.x - 60, item.y, 120, "center")
    end
  end
end

return FX
