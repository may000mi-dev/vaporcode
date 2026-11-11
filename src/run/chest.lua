-- chest.lua: cofre de botín que se abre al acercarse.
local Data = require("src.run.data")
local Util = require("src.utils.util")

local Chest = {}
Chest.__index = Chest

function Chest.new(x, y, lootIndex, source)
  local self = setmetatable({}, Chest)
  self.x = x
  self.y = y
  self.radius = Data.chest.radius
  self.lootIndex = lootIndex or 1
  self.source = source or "floor"
  self.opened = false
  self.phase = love.math.random() * math.pi * 2
  return self
end

function Chest:update(dt, run)
  if self.opened then return end

  local player = run.player
  if not player then return end

  local reach = Data.chest.openRadius + player.radius
  if Util.dist2(self.x, self.y, player.x, player.y) <= reach * reach then
    run:openChest(self)
    self.opened = true
  end
end

function Chest:draw()
  local def = Data.chest
  local t = love.timer.getTime()
  local r = self.radius
  local bob = self.opened and 0 or math.sin(t * 3 + self.phase) * 1.5
  local x = self.x
  local y = self.y + bob

  love.graphics.setColor(0, 0, 0, 0.35)
  love.graphics.circle("fill", x, self.y + 3, r + 4)

  if not self.opened then
    love.graphics.setColor(def.color[1], def.color[2], def.color[3], 0.18)
    love.graphics.circle("fill", x, y, r + 9)
  end

  love.graphics.setColor(def.dark[1], def.dark[2], def.dark[3])
  love.graphics.rectangle("fill", x - r, y - 2, r * 2, r + 7, 3)
  love.graphics.setColor(def.color[1], def.color[2], def.color[3])
  love.graphics.rectangle("fill", x - r + 2, y, r * 2 - 4, r + 3, 2)

  if self.opened then
    love.graphics.setColor(def.dark[1], def.dark[2], def.dark[3])
    love.graphics.rectangle("fill", x - r, y - 10, r * 2, r + 2, 3)
    love.graphics.setColor(def.color[1] * 0.55, def.color[2] * 0.55, def.color[3] * 0.55)
    love.graphics.rectangle("fill", x - r, y - 10, r * 2, 5, 2)
    love.graphics.setColor(0.05, 0.05, 0.06)
    love.graphics.rectangle("fill", x - r + 3, y - 5, r * 2 - 6, 5)
  else
    love.graphics.setColor(def.color[1], def.color[2], def.color[3])
    love.graphics.rectangle("fill", x - r, y - 10, r * 2, 9, 3)
    love.graphics.setColor(def.dark[1], def.dark[2], def.dark[3])
    love.graphics.rectangle("fill", x - r + 2, y - 8, r * 2 - 4, 3, 2)
    love.graphics.setColor(0.95, 0.82, 0.40)
    love.graphics.circle("fill", x, y - 1, 4)
    love.graphics.setColor(0.28, 0.18, 0.08)
    love.graphics.circle("fill", x, y - 1, 2)
  end
end

return Chest
