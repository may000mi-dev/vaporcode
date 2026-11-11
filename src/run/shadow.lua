-- shadow.lua: señuelo temporal que atrae enemigos y explota al desaparecer.
local Data = require("src.run.data")
local Util = require("src.utils.util")
local FX = require("src.run.fx")

local Shadow = {}
Shadow.__index = Shadow

function Shadow.new(x, y, def)
  return setmetatable({
    x = x,
    y = y,
    radius = 15,
    timer = def.duration,
    maxTimer = def.duration,
    def = def,
    dead = false,
  }, Shadow)
end

function Shadow:explode(run)
  local def = self.def
  local damage = run.stats.damage * def.explosionMultiplier
  local radius2 = def.explosionRadius * def.explosionRadius

  for _, enemy in ipairs(run.enemies) do
    if not enemy.dead then
      if Util.dist2(self.x, self.y, enemy.x, enemy.y) <= radius2 then
        enemy:takeDamage(damage, run, "ability")
      end
    end
  end

  FX.ring(self.x, self.y, def.explosionRadius, def.color)
  FX.burst(self.x, self.y, 28, def.color)
  if run.shake then run:shake(5, 0.25) end
end

function Shadow:update(dt, run)
  self.timer = self.timer - dt
  if self.timer <= 0 then
    self.timer = 0
    self:explode(run)
    self.dead = true
  end
end

function Shadow:draw()
  local def = Data.abilities.shadow_swap
  local pulse = 1 + math.sin(love.timer.getTime() * 8) * 0.08

  love.graphics.setColor(0, 0, 0, 0.45)
  love.graphics.circle("fill", self.x, self.y + 2, self.radius * pulse + 3)

  love.graphics.setColor(def.color[1], def.color[2], def.color[3], 0.60)
  love.graphics.circle("fill", self.x, self.y, self.radius * pulse)
  love.graphics.setColor(0.10, 0.06, 0.16, 0.95)
  love.graphics.circle("fill", self.x, self.y, self.radius * 0.52)

  love.graphics.setColor(0.92, 0.86, 1.00, 0.85)
  love.graphics.circle("line", self.x, self.y, self.radius * pulse + 3)
end

return Shadow
