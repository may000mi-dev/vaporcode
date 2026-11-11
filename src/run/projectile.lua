-- projectile.lua: proyectiles, marcas de Amado y cadena de Amileth.
local Data = require("src.run.data")
local Util = require("src.utils.util")
local FX = require("src.run.fx")
local Targeting = require("src.run.targeting")

local Projectile = {}
Projectile.__index = Projectile

function Projectile.new(x, y, angle, speed, damage, friendly, options)
  local self = setmetatable({}, Projectile)
  options = options or {}
  self.x = x
  self.y = y
  self.vx = math.cos(angle) * speed
  self.vy = math.sin(angle) * speed
  self.radius = options.radius or (friendly
    and Data.projectile.friendlyRadius
    or Data.projectile.hostileRadius)
  self.damage = damage
  self.friendly = friendly
  self.life = options.life or (friendly
    and Data.projectile.friendlyLife
    or Data.projectile.hostileLife)
  self.kind = options.kind or "spark"
  self.mark = options.mark or false
  self.chain = options.chain
  self.effect = options.effect
  self.effectData = options.effectData
  self.hitSet = {}
  self.dead = false
  return self
end

function Projectile:chainFrom(enemy, run)
  local chain = self.chain
  local damage = self.damage
  local from = enemy

  for _ = 1, chain.jumps or 0 do
    local target = Targeting.nearestChain(
      from.x,
      from.y,
      run.enemies,
      self.hitSet,
      chain.range,
      run.dungeon,
      chain.requireLineOfSight
    )
    if not target then return end

    damage = damage * (chain.falloff or 0.5)
    self.hitSet[target] = true
    target:takeDamage(damage, run, "basic")
    FX.line(from.x, from.y, target.x, target.y, { 0.98, 0.72, 0.30 })
    from = target
  end
end

function Projectile:hitEnemy(enemy, run)
  self.hitSet[enemy] = true
  enemy:takeDamage(self.damage, run, "basic")

  if self.mark and not enemy.dead and enemy:canBeAffected() then
    run:markEnemy(enemy)
  end

  if self.chain then
    self:chainFrom(enemy, run)
  end
end

function Projectile:update(dt, run)
  self.life = self.life - dt
  if self.life <= 0 then
    self.dead = true
    return
  end

  local nextX = self.x + self.vx * dt
  local nextY = self.y + self.vy * dt

  if self.friendly and run.hitValve and run:hitValve(nextX, nextY, self.radius) then
    self.dead = true
    return
  end

  if run.dungeon:circleCollides(nextX, nextY, self.radius) then
    self.dead = true
    return
  end

  self.x = nextX
  self.y = nextY

  if self.friendly then
    for _, enemy in ipairs(run.enemies) do
      if not enemy.dead then
        local rr = self.radius + enemy.radius
        if Util.dist2(self.x, self.y, enemy.x, enemy.y) <= rr * rr then
          self:hitEnemy(enemy, run)
          self.dead = true
          return
        end
      end
    end
  else
    for _, pet in ipairs(run.pets or {}) do
      if not pet.dead then
        local rr = self.radius + pet.radius
        if Util.dist2(self.x, self.y, pet.x, pet.y) <= rr * rr then
          if pet:takeDamage(self.damage, run) then
            self.dead = true
            return
          end
        end
      end
    end

    local player = run.player
    local rr = self.radius + player.radius
    if Util.dist2(self.x, self.y, player.x, player.y) <= rr * rr then
      local hit = player:takeDamage(self.damage, run)
      if hit and self.effect and run.applyPlayerEffect then
        run:applyPlayerEffect(self.effect, self.effectData)
      end
      self.dead = true
    end
  end
end

function Projectile:draw()
  if self.friendly and self.kind == "chain" then
    local t = love.timer.getTime()
    local colors = {
      { 1.00, 0.28, 0.35 },
      { 1.00, 0.68, 0.20 },
      { 1.00, 0.94, 0.28 },
      { 0.30, 0.92, 0.48 },
      { 0.34, 0.68, 1.00 },
      { 0.82, 0.42, 1.00 },
    }
    love.graphics.setColor(0.40, 0.30, 0.45)
    love.graphics.circle("fill", self.x, self.y, self.radius + 2)
    for i, color in ipairs(colors) do
      local offset = math.sin(t * 12 + i * 0.8) * 2
      love.graphics.setColor(color[1], color[2], color[3], 0.9)
      love.graphics.circle("fill", self.x + offset, self.y, math.max(1, 4 - i * 0.4))
    end
    return
  end

  if self.friendly then
    love.graphics.setColor(0.40, 0.90, 1.00)
    love.graphics.circle("fill", self.x, self.y, self.radius)
    love.graphics.setColor(1, 1, 1, 0.75)
    love.graphics.circle("fill", self.x, self.y, self.radius * 0.45)
  else
    love.graphics.setColor(0.95, 0.45, 0.30)
    love.graphics.circle("fill", self.x, self.y, self.radius)
    love.graphics.setColor(1, 0.85, 0.60, 0.8)
    love.graphics.circle("fill", self.x, self.y, self.radius * 0.45)
  end
end

return Projectile
