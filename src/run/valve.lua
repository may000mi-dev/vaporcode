-- valve.lua: válvula de presión que libera un chorro de vapor al activarse.
local Data = require("src.run.data")
local Util = require("src.utils.util")
local FX = require("src.run.fx")

local Valve = {}
Valve.__index = Valve

function Valve.new(x, y)
  local self = setmetatable({}, Valve)
  self.x = x
  self.y = y
  self.radius = Data.valve.radius
  self.active = 0
  self.cooldown = 0
  self.tickTimer = 0
  self.phase = love.math.random() * math.pi * 2
  return self
end

function Valve:trigger(run)
  local def = Data.valve
  if self.active > 0 or self.cooldown > 0 then return false end

  self.active = def.activeTime
  self.cooldown = def.cooldown
  self.tickTimer = 0
  FX.ring(self.x, self.y, self.radius + 10, def.accent)
  if run.shake then run:shake(2, 0.12) end
  return true
end

function Valve:applyDamage(run)
  local def = Data.valve
  local radius2 = def.jetRadius * def.jetRadius

  for _, enemy in ipairs(run.enemies) do
    if not enemy.dead
      and Util.dist2(self.x, self.y, enemy.x, enemy.y) <= radius2
      and run.dungeon:lineOfSight(self.x, self.y, enemy.x, enemy.y)
    then
      enemy:takeDamage(def.damage, run, "hazard")
    end
  end

  local player = run.player
  if player
    and Util.dist2(self.x, self.y, player.x, player.y) <= radius2
    and run.dungeon:lineOfSight(self.x, self.y, player.x, player.y)
  then
    player:takeDamage(def.damage, run)
  end

  FX.ring(self.x, self.y, def.jetRadius, def.steam)
end

function Valve:update(dt, run)
  local def = Data.valve
  self.cooldown = math.max(0, self.cooldown - dt)

  if self.active > 0 then
    self.active = math.max(0, self.active - dt)
    self.tickTimer = self.tickTimer - dt
    if self.tickTimer <= 0 then
      self.tickTimer = self.tickTimer + def.tickInterval
      self:applyDamage(run)
    end
    return
  end

  if self.cooldown > 0 then return end

  local player = run.player
  if player then
    local reach = def.triggerRadius + player.radius
    if Util.dist2(self.x, self.y, player.x, player.y) <= reach * reach then
      self:trigger(run)
      return
    end
  end

  -- Los enemigos también pueden pisar la válvula y recibir el vapor.
  for _, enemy in ipairs(run.enemies) do
    if not enemy.dead then
      local reach = def.triggerRadius + enemy.radius
      if Util.dist2(self.x, self.y, enemy.x, enemy.y) <= reach * reach then
        self:trigger(run)
        return
      end
    end
  end
end

function Valve:draw()
  local def = Data.valve
  local t = love.timer.getTime()

  if self.active > 0 then
    local alpha = math.min(1, self.active / def.activeTime)
    for i = 1, 8 do
      local angle = self.phase + t * 2.2 + i * (math.pi * 2 / 8)
      local distance = 16 + (i % 3) * 18
      local puff = 7 + (i % 2) * 3
      love.graphics.setColor(
        def.steam[1],
        def.steam[2],
        def.steam[3],
        alpha * 0.20
      )
      love.graphics.circle(
        "fill",
        self.x + math.cos(angle) * distance,
        self.y + math.sin(angle) * distance,
        puff
      )
    end
    love.graphics.setColor(def.steam[1], def.steam[2], def.steam[3], alpha * 0.35)
    love.graphics.circle("line", self.x, self.y, def.jetRadius)
  end

  love.graphics.setColor(0, 0, 0, 0.35)
  love.graphics.circle("fill", self.x, self.y + 2, self.radius + 3)

  love.graphics.setColor(def.color[1], def.color[2], def.color[3])
  love.graphics.circle("fill", self.x, self.y, self.radius)
  love.graphics.setColor(0.16, 0.18, 0.20)
  love.graphics.circle("line", self.x, self.y, self.radius)

  love.graphics.setLineWidth(2)
  for i = 0, 5 do
    local angle = t * 0.8 + i * (math.pi * 2 / 6)
    love.graphics.setColor(0.34, 0.38, 0.42)
    love.graphics.line(
      self.x + math.cos(angle) * (self.radius - 2),
      self.y + math.sin(angle) * (self.radius - 2),
      self.x + math.cos(angle) * (self.radius + 4),
      self.y + math.sin(angle) * (self.radius + 4)
    )
  end
  love.graphics.setLineWidth(1)

  love.graphics.setColor(def.accent[1], def.accent[2], def.accent[3])
  love.graphics.circle("fill", self.x, self.y, self.radius * 0.34)
end

return Valve
