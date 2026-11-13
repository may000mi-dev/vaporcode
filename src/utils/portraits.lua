-- portraits.lua: retratos procedurales ligeros para personajes y bestiario.
-- No usan imágenes externas: solo formas de love.graphics para mantener el
-- paquete pequeño y el arranque rápido en Android.

local Portraits = {}

local function outline(color, alpha)
  love.graphics.setColor(color[1], color[2], color[3], alpha or 0.90)
  love.graphics.setLineWidth(2)
end

function Portraits.character(def, x, y, scale)
  scale = scale or 1
  local color = def.color
  local bodyW = 46 * scale
  local bodyH = 62 * scale
  local headR = 23 * scale

  love.graphics.setColor(0, 0, 0, 0.30)
  love.graphics.circle("fill", x, y + bodyH * 0.76, bodyW * 0.66)

  love.graphics.setColor(color[1] * 0.30, color[2] * 0.30, color[3] * 0.30, 0.95)
  love.graphics.rectangle(
    "fill",
    x - bodyW * 0.5,
    y + headR * 0.55,
    bodyW,
    bodyH,
    9 * scale,
    9 * scale
  )

  love.graphics.setColor(color[1], color[2], color[3], 0.95)
  love.graphics.rectangle(
    "fill",
    x - bodyW * 0.38,
    y + headR * 0.75,
    bodyW * 0.76,
    bodyH * 0.62,
    7 * scale,
    7 * scale
  )

  love.graphics.circle("fill", x, y, headR)
  love.graphics.setColor(0.10, 0.10, 0.13, 0.95)
  love.graphics.circle("fill", x - headR * 0.34, y - headR * 0.08, 2.6 * scale)
  love.graphics.circle("fill", x + headR * 0.34, y - headR * 0.08, 2.6 * scale)

  outline(color, 1)
  if def.id == "amado" then
    love.graphics.circle("line", x - headR * 0.34, y - headR * 0.08, 6 * scale)
    love.graphics.circle("line", x + headR * 0.34, y - headR * 0.08, 6 * scale)
    love.graphics.line(x - headR, y + headR * 0.55, x + headR, y + headR * 0.55)
    love.graphics.setColor(0.35, 0.75, 0.85, 0.95)
    love.graphics.rectangle(
      "fill",
      x - bodyW * 0.58,
      y + headR * 0.72,
      bodyW * 1.16,
      7 * scale,
      3 * scale,
      3 * scale
    )
  elseif def.id == "mar" then
    love.graphics.line(x - headR * 1.55, y + headR * 1.8, x - headR * 1.05, y + headR * 0.6)
    love.graphics.line(x + headR * 1.55, y + headR * 1.8, x + headR * 1.05, y + headR * 0.6)
    love.graphics.setColor(0.95, 0.70, 0.72, 0.95)
    love.graphics.rectangle(
      "fill",
      x - bodyW * 0.58,
      y + headR * 0.88,
      bodyW * 1.16,
      6 * scale,
      3 * scale,
      3 * scale
    )
  elseif def.id == "amileth" then
    love.graphics.setColor(0.98, 0.92, 0.58, 0.95)
    love.graphics.rectangle(
      "fill",
      x - bodyW * 0.48,
      y + headR * 1.15,
      bodyW * 0.96,
      bodyH * 0.50,
      4 * scale,
      4 * scale
    )
    love.graphics.setColor(0.32, 0.25, 0.18, 0.95)
    love.graphics.line(x, y + headR * 1.15, x, y + headR * 1.15 + bodyH * 0.50)
    love.graphics.setColor(0.98, 0.92, 0.58, 0.95)
    love.graphics.polygon(
      "fill",
      x,
      y - headR * 1.55,
      x + headR * 0.22,
      y - headR * 1.05,
      x + headR * 0.78,
      y - headR * 1.00,
      x + headR * 0.34,
      y - headR * 0.64,
      x + headR * 0.46,
      y - headR * 0.10,
      x,
      y - headR * 0.36,
      x - headR * 0.46,
      y - headR * 0.10,
      x - headR * 0.34,
      y - headR * 0.64,
      x - headR * 0.78,
      y - headR * 1.00,
      x - headR * 0.22,
      y - headR * 1.05
    )
  end
  love.graphics.setLineWidth(1)
end

function Portraits.enemy(def, x, y, radius, boss)
  radius = radius or 24
  local color = def.color or { 0.70, 0.70, 0.75 }
  local role = def.role
  local kind = def.bossKind

  love.graphics.setColor(0, 0, 0, 0.32)
  love.graphics.circle("fill", x, y + radius * 0.16, radius * 1.05)

  love.graphics.setColor(color[1], color[2], color[3], 0.96)
  love.graphics.circle("fill", x, y, radius)
  love.graphics.setColor(color[1] * 0.42, color[2] * 0.42, color[3] * 0.42, 1)
  love.graphics.circle("line", x, y, radius)
  love.graphics.setColor(0.08, 0.09, 0.12, 0.96)
  love.graphics.circle("fill", x, y, radius * 0.38)

  love.graphics.setColor(0.95, 0.94, 0.88, 0.92)
  if role == "turret" then
    love.graphics.rectangle(
      "fill",
      x - radius * 0.42,
      y - radius * 0.16,
      radius * 0.84,
      radius * 0.32,
      2,
      2
    )
    love.graphics.line(x, y - radius * 0.75, x, y + radius * 0.75)
  elseif role == "summoner" then
    love.graphics.circle("line", x, y, radius * 0.62)
    love.graphics.circle("fill", x - radius * 0.85, y - radius * 0.48, radius * 0.16)
    love.graphics.circle("fill", x + radius * 0.88, y + radius * 0.20, radius * 0.16)
  elseif role == "trapper" then
    love.graphics.polygon(
      "line",
      x,
      y - radius * 0.62,
      x + radius * 0.62,
      y + radius * 0.46,
      x - radius * 0.62,
      y + radius * 0.46
    )
    love.graphics.circle("fill", x, y + radius * 0.10, radius * 0.13)
  elseif role == "healer" then
    love.graphics.rectangle(
      "fill",
      x - radius * 0.12,
      y - radius * 0.58,
      radius * 0.24,
      radius * 1.16
    )
    love.graphics.rectangle(
      "fill",
      x - radius * 0.58,
      y - radius * 0.12,
      radius * 1.16,
      radius * 0.24
    )
  elseif role == "mana_hunter" or kind == "chrono" then
    love.graphics.circle("line", x, y, radius * 0.66)
    love.graphics.line(x, y, x, y - radius * 0.48)
    love.graphics.line(x, y, x + radius * 0.38, y + radius * 0.20)
  elseif role == "mortar" then
    love.graphics.circle("line", x, y, radius * 0.70)
    love.graphics.line(x - radius * 0.45, y + radius * 0.42, x + radius * 0.45, y - radius * 0.52)
  elseif role == "blight" then
    love.graphics.circle("fill", x - radius * 0.30, y - radius * 0.16, radius * 0.18)
    love.graphics.circle("fill", x + radius * 0.26, y + radius * 0.22, radius * 0.18)
    love.graphics.circle("fill", x + radius * 0.18, y - radius * 0.38, radius * 0.13)
  elseif kind == "organ" then
    love.graphics.setLineWidth(2)
    for i = 0, 3 do
      local angle = i * math.pi * 0.5
      love.graphics.line(
        x + math.cos(angle) * radius * 0.48,
        y + math.sin(angle) * radius * 0.48,
        x + math.cos(angle) * radius * 1.08,
        y + math.sin(angle) * radius * 1.08
      )
    end
    love.graphics.setLineWidth(1)
  else
    love.graphics.circle("fill", x, y, radius * 0.50)
    love.graphics.setColor(0.08, 0.09, 0.12, 0.96)
    love.graphics.circle("fill", x - radius * 0.20, y - radius * 0.08, radius * 0.09)
    love.graphics.circle("fill", x + radius * 0.20, y - radius * 0.08, radius * 0.09)
  end

  if boss then
    love.graphics.setColor(color[1], color[2], color[3], 0.90)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", x, y, radius + 7)
    love.graphics.setLineWidth(1)
  end
end

return Portraits
