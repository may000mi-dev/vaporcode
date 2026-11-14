-- hazard.lua: peligros persistentes del piso (fuego, minas, láseres y zonas).
local Data = require("src.run.data")
local Util = require("src.utils.util")
local FX = require("src.run.fx")

local Hazard = {}
Hazard.__index = Hazard

local function colorFor(kind)
  if kind == "fire" then return { 1.00, 0.42, 0.16 } end
  if kind == "mine" then return { 0.86, 0.70, 0.35 } end
  if kind == "beam" then return { 0.72, 0.52, 1.00 } end
  if kind == "zone" then return { 1.00, 0.28, 0.18 } end
  if kind == "cone" then return { 0.52, 0.72, 1.00 } end
  if kind == "echo" then return { 0.42, 0.62, 1.00 } end
  return { 0.80, 0.80, 0.80 }
end

function Hazard.new(kind, x, y, options)
  options = options or {}
  local self = setmetatable({}, Hazard)
  self.kind = kind
  self.x = x
  self.y = y
  self.radius = options.radius or 38
  self.delay = options.delay or 0
  self.life = options.life or 3
  self.maxLife = self.life
  self.damage = options.damage or 0
  self.interval = options.interval or Data.hazards.fireTick
  self.tickTimer = 0
  self.angle = options.angle or 0
  self.length = options.length or 300
  self.width = options.width or 10
  self.halfAngle = options.halfAngle or 0.4
  self.rotation = options.rotation or 0
  self.color = options.color or colorFor(kind)
  self.target = options.target or "player"
  self.dead = false
  self.armed = self.delay <= 0
  return self
end

function Hazard:applyEffect(run)
  if self.kind == "fire" or self.kind == "zone" or self.kind == "echo" then
    if Util.dist2(self.x, self.y, run.player.x, run.player.y)
      <= (self.radius + run.player.radius) ^ 2
    then
      run.player:takeDamage(self.damage, run)
    end
  elseif self.kind == "beam" then
    local endX = self.x + math.cos(self.angle) * self.length
    local endY = self.y + math.sin(self.angle) * self.length
    local d2 = Util.pointSegmentDist2(
      run.player.x,
      run.player.y,
      self.x,
      self.y,
      endX,
      endY
    )
    if d2 <= (self.width + run.player.radius) ^ 2 then
      run.player:takeDamage(self.damage, run)
    end
  end
end

function Hazard:explodeMine(run)
  self.dead = true
  local reach = Data.hazards.mineExplosionRadius + run.player.radius
  if Util.dist2(self.x, self.y, run.player.x, run.player.y) <= reach * reach then
    run.player:takeDamage(Data.hazards.mineDamage, run)
  end
  for _, enemy in ipairs(run.enemies or {}) do
    if not enemy.dead then
      local rr = Data.hazards.mineExplosionRadius + enemy.radius
      if Util.dist2(self.x, self.y, enemy.x, enemy.y) <= rr * rr then
        enemy:takeDamage(Data.hazards.mineDamage * 0.5, run, "hazard")
      end
    end
  end
  FX.ring(self.x, self.y, Data.hazards.mineExplosionRadius, { 1.00, 0.62, 0.22 })
  FX.burst(self.x, self.y, 12, { 1.00, 0.62, 0.22 })
  if run.shake then run:shake(4, 0.20) end
end

function Hazard:update(dt, run)
  if self.dead then return end

  if self.delay > 0 then
    self.delay = self.delay - dt
    if self.delay <= 0 then
      self.armed = true
      self.tickTimer = 0
    end
    return
  end

  -- El eco detona una sola vez al terminar su telegrafiado.
  if self.kind == "echo" then
    self:applyEffect(run)
    FX.ring(self.x, self.y, self.radius, self.color)
    FX.burst(self.x, self.y, 8, self.color)
    self.dead = true
    return
  end

  self.life = self.life - dt
  if self.life <= 0 then
    -- Las minas estallan al agotar su minuto de vida.
    if self.kind == "mine" then
      self:explodeMine(run)
    else
      self.dead = true
    end
    return
  end

  if self.kind == "beam" then
    self.angle = self.angle + self.rotation * dt
  elseif self.kind == "mine" then
    local trigger = Data.hazards.mineTriggerRadius + run.player.radius
    if Util.dist2(self.x, self.y, run.player.x, run.player.y) <= trigger * trigger then
      self:explodeMine(run)
      return
    end
  end

  self.tickTimer = self.tickTimer - dt
  if self.tickTimer <= 0 then
    self.tickTimer = self.interval
    self:applyEffect(run)
  end
end

function Hazard:draw()
  local color = self.color
  local alpha = 1

  if self.delay > 0 then
    local pulse = 0.42 + 0.22 * math.sin(love.timer.getTime() * 16)
    love.graphics.setColor(color[1], color[2], color[3], pulse)
    love.graphics.setLineWidth(2)
    if self.kind == "beam" then
      local endX = self.x + math.cos(self.angle) * self.length
      local endY = self.y + math.sin(self.angle) * self.length
      love.graphics.line(self.x, self.y, endX, endY)
    else
      love.graphics.circle("line", self.x, self.y, self.radius)
      if self.kind == "echo" then
        local t = love.timer.getTime()
        love.graphics.setColor(color[1], color[2], color[3], 0.38)
        love.graphics.circle("line", self.x, self.y, self.radius * 0.55)
        love.graphics.setColor(color[1], color[2], color[3], 0.72)
        love.graphics.line(self.x, self.y, self.x, self.y - self.radius * 0.42)
        love.graphics.line(
          self.x,
          self.y,
          self.x + math.cos(t * 2.2) * self.radius * 0.32,
          self.y + math.sin(t * 2.2) * self.radius * 0.32
        )
      end
    end
    love.graphics.setLineWidth(1)
    return
  end

  if self.kind == "fire" or self.kind == "zone" then
    alpha = math.min(1, self.life / math.max(0.001, self.maxLife))
    love.graphics.setColor(color[1], color[2], color[3], 0.18 * alpha)
    love.graphics.circle("fill", self.x, self.y, self.radius)
    love.graphics.setColor(color[1], color[2], color[3], 0.65 * alpha)
    love.graphics.setLineWidth(3)
    love.graphics.circle("line", self.x, self.y, self.radius)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1.00, 0.78, 0.28, 0.55 * alpha)
    for i = 0, 2 do
      local a = love.timer.getTime() * 5 + i * (math.pi * 2 / 3)
      love.graphics.circle(
        "fill",
        self.x + math.cos(a) * self.radius * 0.42,
        self.y + math.sin(a) * self.radius * 0.42,
        4
      )
    end
    return
  end

  if self.kind == "mine" then
    love.graphics.setColor(0.10, 0.10, 0.12, 0.95)
    love.graphics.circle("fill", self.x, self.y, 13)
    local blink = 0.55 + 0.45 * math.sin(love.timer.getTime() * 12)
    love.graphics.setColor(color[1], color[2], color[3], blink)
    love.graphics.circle("line", self.x, self.y, 15)
    for i = 0, 3 do
      local a = i * math.pi * 0.5
      love.graphics.line(
        self.x + math.cos(a) * 14,
        self.y + math.sin(a) * 14,
        self.x + math.cos(a) * 19,
        self.y + math.sin(a) * 19
      )
    end
    return
  end

  if self.kind == "beam" then
    alpha = math.min(1, self.life / math.max(0.001, self.maxLife))
    local endX = self.x + math.cos(self.angle) * self.length
    local endY = self.y + math.sin(self.angle) * self.length
    love.graphics.setColor(color[1], color[2], color[3], 0.20 * alpha)
    love.graphics.setLineWidth(self.width * 2)
    love.graphics.line(self.x, self.y, endX, endY)
    love.graphics.setColor(0.92, 0.96, 1.00, 0.92 * alpha)
    love.graphics.setLineWidth(self.width * 0.55)
    love.graphics.line(self.x, self.y, endX, endY)
    love.graphics.setLineWidth(1)
    return
  end

  if self.kind == "cone" then
    alpha = math.min(1, self.life / math.max(0.001, self.maxLife))
    local points = { self.x, self.y }
    local segments = 14
    for i = 0, segments do
      local a = self.angle - self.halfAngle
        + (self.halfAngle * 2) * (i / segments)
      points[#points + 1] = self.x + math.cos(a) * self.length
      points[#points + 1] = self.y + math.sin(a) * self.length
    end
    love.graphics.setColor(color[1], color[2], color[3], 0.22 * alpha)
    love.graphics.polygon("fill", points)
    love.graphics.setColor(color[1], color[2], color[3], 0.72 * alpha)
    love.graphics.polygon("line", points)
  end
end

return Hazard
