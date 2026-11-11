-- pet.lua: mascotas que siguen al jugador y actúan al ritmo.
local Data = require("src.run.data")
local Util = require("src.utils.util")
local Rhythm = require("src.run.rhythm")
local FX = require("src.run.fx")

local Pet = {}
Pet.__index = Pet

local function nearestEnemy(run, x, y, range)
  local best = nil
  local bestD2 = range * range
  for _, enemy in ipairs(run.enemies) do
    if not enemy.dead then
      local d2 = Util.dist2(x, y, enemy.x, enemy.y)
      if d2 <= bestD2 then
        bestD2 = d2
        best = enemy
      end
    end
  end
  return best
end

local function nearestItem(run, x, y, range)
  local best = nil
  local bestD2 = range * range
  for _, item in ipairs(run.itemDrops or {}) do
    if not item.dead then
      local d2 = Util.dist2(x, y, item.x, item.y)
      if d2 <= bestD2 then
        bestD2 = d2
        best = item
      end
    end
  end
  return best
end

function Pet.new(kind, x, y, snapshot)
  local def = Data.pets[kind]
  if not def then return nil end

  local self = setmetatable({}, Pet)
  self.kind = kind
  self.def = def
  self.itemId = kind
  self.x = x
  self.y = y
  self.radius = def.radius
  self.maxHp = snapshot and snapshot.maxHp or def.hp
  self.hp = snapshot and math.min(snapshot.hp or self.maxHp, self.maxHp) or self.maxHp
  self.facingX = 1
  self.facingY = 0
  self.attackCooldown = snapshot and snapshot.attackCooldown or 0
  self.retaliateTimer = 0
  self.regenDelay = 0
  self.hitFlash = 0
  self.invuln = 0
  self.phase = love.math.random() * math.pi * 2
  self.slot = 1
  self.dead = false
  return self
end

function Pet:placeNear(player, slot)
  self.slot = slot
  local angle = -1.4 + (slot - 1) * 0.95
  self.x = player.x + math.cos(angle) * (player.radius + self.radius + 12)
  self.y = player.y + math.sin(angle) * (player.radius + self.radius + 12)
end

function Pet:snapshot()
  return {
    kind = self.kind,
    hp = self.hp,
    maxHp = self.maxHp,
    attackCooldown = self.attackCooldown,
  }
end

function Pet:attackDog(run, target)
  local damage = run.stats.damage * self.def.damageMultiplier
  target:takeDamage(damage, run, "pet")
  if not target.dead and target.applyStun then
    target:applyStun(Rhythm.spb)
  end
  self.facingX = self.x < target.x and 1 or -1
  self.invuln = math.max(self.invuln, 0.5)
  FX.line(self.x, self.y, target.x, target.y, Data.items.dog.color)
  FX.ring(target.x, target.y, target.radius + 7, Data.items.dog.color)
end

function Pet:attackCat(run, target)
  local damage = run.stats.damage * self.def.damageMultiplier
  target:takeDamage(damage, run, "pet")
  self.facingX = self.x < target.x and 1 or -1
  FX.line(self.x, self.y, target.x, target.y, Data.items.cat.color, 0.14, 2)
  FX.burst(target.x, target.y, 5, Data.items.cat.color)
end

function Pet:attackDragon(run, target)
  local angle = Util.atan2(target.y - self.y, target.x - self.x)
  self.facingX = math.cos(angle)
  self.facingY = math.sin(angle)
  local damage = run.stats.damage * self.def.damageMultiplier
  local range2 = self.def.range * self.def.range

  for _, enemy in ipairs(run.enemies) do
    if not enemy.dead then
      local dx = enemy.x - self.x
      local dy = enemy.y - self.y
      local d2 = dx * dx + dy * dy
      if d2 <= range2 then
        local distance = math.sqrt(d2)
        local dot = 1
        if distance > 0.001 then
          dot = (dx * self.facingX + dy * self.facingY) / distance
        end
        if dot >= math.cos(self.def.spread) then
          enemy:takeDamage(damage, run, "pet")
        end
      end
    end
  end

  local endX = self.x + self.facingX * self.def.range
  local endY = self.y + self.facingY * self.def.range
  FX.line(self.x, self.y, endX, endY, Data.items.dragon.color, 0.18, 12)
  FX.burst(endX, endY, 10, Data.items.dragon.color)
end

function Pet:tryBeatAttack(run)
  if not Rhythm.justBeat or self.attackCooldown > 0 then return end
  if self.kind == "hamster" then return end

  local target = nearestEnemy(run, self.x, self.y, self.def.range)
  if not target then return end

  if self.kind == "dragon" and self.retaliateTimer <= 0 then
    return
  end

  if self.kind == "dog" then
    self:attackDog(run, target)
  elseif self.kind == "cat" then
    self:attackCat(run, target)
  elseif self.kind == "dragon" then
    self:attackDragon(run, target)
  else
    return
  end

  self.attackCooldown = Rhythm.spb * (self.def.cooldownBeats or 2)
end

function Pet:updateHamster(dt, run)
  local item = nearestItem(run, self.x, self.y, self.def.range)
  local tx, ty
  if item then
    tx, ty = item.x, item.y
    if Util.dist2(self.x, self.y, tx, ty) <= (self.radius + item.radius + 8) ^ 2 then
      if run:pickupItem(item, self) then
        item.dead = true
      end
    end
  else
    local player = run.player
    local best = nil
    local bestD2 = self.def.range * self.def.range
    for ty2, row in pairs(run.dungeon.destructible or {}) do
      for tx2 in pairs(row) do
        local wx, wy = run.dungeon:tileCenter(tx2, ty2)
        local d2 = Util.dist2(self.x, self.y, wx, wy)
        if d2 <= bestD2 then
          bestD2 = d2
          best = { x = wx, y = wy }
        end
      end
    end
    if best then
      tx, ty = best.x, best.y
    else
      tx = player.x
      ty = player.y
    end
  end

  return tx, ty
end

function Pet:update(dt, run)
  if self.dead then return end

  self.hitFlash = math.max(0, self.hitFlash - dt * 10)
  self.invuln = math.max(0, self.invuln - dt)
  self.attackCooldown = math.max(0, self.attackCooldown - dt)
  self.regenDelay = math.max(0, self.regenDelay - dt)
  self.retaliateTimer = math.max(0, self.retaliateTimer - dt)

  if self.regenDelay == 0 and self.hp < self.maxHp then
    self.hp = math.min(self.maxHp, self.hp + self.maxHp * self.def.regenRate * dt)
  end

  local tx, ty
  if self.kind == "hamster" then
    tx, ty = self:updateHamster(dt, run)
  else
    local player = run.player
    local angle = -1.4 + (self.slot - 1) * 0.95
    local distance = player.radius + self.radius + 14
    tx = player.x + math.cos(angle) * distance
    ty = player.y + math.sin(angle) * distance
  end

  local dx, dy = tx - self.x, ty - self.y
  local distance = math.sqrt(dx * dx + dy * dy)
  if distance > 3 then
    local speed = self.def.speed or 160
    local step = math.min(distance, speed * dt)
    self.x, self.y = run.dungeon:moveCircle(
      self.x,
      self.y,
      dx / distance * step,
      dy / distance * step,
      self.radius
    )
    self.facingX = dx / distance
    self.facingY = dy / distance
  end

  self:tryBeatAttack(run)
end

function Pet:takeDamage(amount, run)
  if self.dead or self.invuln > 0 then return false end

  self.hp = self.hp - amount
  self.hitFlash = 1
  self.regenDelay = self.def.regenDelay or 3
  self.invuln = 0.12
  self.retaliateTimer = 4
  if self.hp <= 0 then
    self.hp = 0
    self.dead = true
    if run.onPetKilled then run:onPetKilled(self) end
  end
  return true
end

function Pet:draw()
  local color = Data.items[self.kind].color
  local radius = self.radius
  local flash = self.hitFlash or 0

  love.graphics.setColor(0, 0, 0, 0.30)
  love.graphics.circle("fill", self.x, self.y + 2, radius + 2)

  love.graphics.setColor(
    color[1] + (1 - color[1]) * flash,
    color[2] + (1 - color[2]) * flash,
    color[3] + (1 - color[3]) * flash
  )
  if self.kind == "dragon" then
    love.graphics.polygon(
      "fill",
      self.x,
      self.y - radius,
      self.x + radius,
      self.y + radius * 0.7,
      self.x - radius,
      self.y + radius * 0.7
    )
  else
    love.graphics.circle("fill", self.x, self.y, radius)
  end

  love.graphics.setColor(0.08, 0.08, 0.10)
  love.graphics.circle("fill", self.x - radius * 0.32, self.y - radius * 0.15, 1.6)
  love.graphics.circle("fill", self.x + radius * 0.32, self.y - radius * 0.15, 1.6)

  if self.kind == "dog" or self.kind == "cat" then
    love.graphics.setColor(color[1] * 0.75, color[2] * 0.75, color[3] * 0.75)
    local ear = self.kind == "cat" and 1.5 or 0.9
    love.graphics.polygon(
      "fill",
      self.x - radius * 0.8,
      self.y - radius * 0.55,
      self.x - radius * 0.55,
      self.y - radius * ear,
      self.x - radius * 0.12,
      self.y - radius * 0.60
    )
    love.graphics.polygon(
      "fill",
      self.x + radius * 0.8,
      self.y - radius * 0.55,
      self.x + radius * 0.55,
      self.y - radius * ear,
      self.x + radius * 0.12,
      self.y - radius * 0.60
    )
  elseif self.kind == "hamster" then
    love.graphics.setColor(color[1] * 1.1, color[2] * 1.05, color[3])
    love.graphics.circle("fill", self.x - radius * 0.55, self.y - radius * 0.55, radius * 0.45)
    love.graphics.circle("fill", self.x + radius * 0.55, self.y - radius * 0.55, radius * 0.45)
  elseif self.kind == "dragon" then
    love.graphics.setColor(0.95, 0.75, 0.25)
    love.graphics.circle("fill", self.x, self.y - radius * 0.75, 2)
  end

  if self.hp < self.maxHp then
    local w = radius * 2
    local ratio = self.maxHp > 0 and self.hp / self.maxHp or 0
    love.graphics.setColor(0.08, 0.10, 0.12)
    love.graphics.rectangle("fill", self.x - w * 0.5, self.y - radius - 8, w, 3)
    love.graphics.setColor(0.40, 0.90, 0.45)
    love.graphics.rectangle("fill", self.x - w * 0.5, self.y - radius - 8, w * ratio, 3)
  end
end

return Pet
