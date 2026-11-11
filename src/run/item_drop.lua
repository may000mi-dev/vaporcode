-- item_drop.lua: ítem en el suelo, temporal salvo los desbloqueos de personaje.
local Data = require("src.run.data")
local Util = require("src.utils.util")
local Fonts = require("src.utils.fonts")

local ItemDrop = {}
ItemDrop.__index = ItemDrop

function ItemDrop.new(itemId, x, y, amount)
  local def = Data.items[itemId]
  if not def then return nil end

  local self = setmetatable({}, ItemDrop)
  self.itemId = itemId
  self.def = def
  self.x = x
  self.y = y
  self.amount = amount or 1
  self.radius = def.kind == "character" and 13 or 9
  self.permanent = def.kind == "character"
  self.life = self.permanent and math.huge or Data.itemLifetime
  self.phase = love.math.random() * math.pi * 2
  self.dead = false
  -- Etiqueta precalculada: la cantidad no cambia tras aparecer en el suelo.
  self.label = def.short
  if self.amount > 1 then
    self.label = def.short .. " x" .. self.amount
  end
  return self
end

function ItemDrop:update(dt, run)
  if self.dead then return end

  if not self.permanent then
    self.life = self.life - dt
    if self.life <= 0 then
      self.dead = true
      return
    end
  end

  local player = run.player
  if not player then return end

  local reach = Data.itemPickupRadius + player.radius + self.radius
  if Util.dist2(self.x, self.y, player.x, player.y) <= reach * reach then
    if run:pickupItem(self) then
      self.dead = true
    end
  end
end

function ItemDrop:alpha()
  if self.permanent or self.life > Data.itemBlinkTime then return 1 end

  local elapsed = Data.itemBlinkTime - self.life
  if math.floor(elapsed * 6) % 2 == 0 then
    return 0.25
  end
  return 1
end

function ItemDrop:draw()
  local def = self.def
  local color = def.color
  local t = love.timer.getTime()
  local alpha = self:alpha()
  local bob = math.sin(t * 3.4 + self.phase) * 2
  local x = self.x
  local y = self.y + bob
  local r = self.radius

  love.graphics.setColor(0, 0, 0, 0.30 * alpha)
  love.graphics.circle("fill", x, self.y + 3, r + 3)

  local ring = r + 6 + math.sin(t * 5 + self.phase) * 2
  love.graphics.setColor(color[1], color[2], color[3], 0.25 * alpha)
  love.graphics.circle("fill", x, y, ring)

  love.graphics.setColor(color[1], color[2], color[3], alpha)
  if def.kind == "pet" then
    love.graphics.circle("fill", x, y, r)
    love.graphics.setColor(0.08, 0.08, 0.10, alpha)
    love.graphics.circle("fill", x - r * 0.35, y - r * 0.15, 1.6)
    love.graphics.circle("fill", x + r * 0.35, y - r * 0.15, 1.6)
    love.graphics.polygon(
      "fill",
      x - r * 0.8,
      y - r * 0.65,
      x - r * 0.5,
      y - r * 1.25,
      x - r * 0.1,
      y - r * 0.7
    )
    love.graphics.polygon(
      "fill",
      x + r * 0.8,
      y - r * 0.65,
      x + r * 0.5,
      y - r * 1.25,
      x + r * 0.1,
      y - r * 0.7
    )
  elseif def.kind == "character" then
    love.graphics.setLineWidth(3)
    love.graphics.circle("line", x, y, r)
    love.graphics.circle("line", x, y, r * 0.55)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.circle("fill", x, y, 3)
  else
    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.rotate(math.pi * 0.25)
    love.graphics.rectangle("fill", -r, -r, r * 2, r * 2, 3, 3)
    love.graphics.pop()
    love.graphics.setColor(0.06, 0.07, 0.08, alpha)
    love.graphics.circle("fill", x, y, 2)
  end

  love.graphics.setFont(Fonts.small)
  love.graphics.setColor(1, 1, 1, alpha)
  love.graphics.printf(self.label, x - 34, y - r - 15, 68, "center")
end

return ItemDrop
