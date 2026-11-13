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

local function nearestWall(run, x, y, range)
  local best = nil
  local bestD2 = range * range
  for ty, row in pairs(run.dungeon.destructible or {}) do
    for tx, wall in pairs(row) do
      local wx, wy = run.dungeon:tileCenter(tx, ty)
      local d2 = Util.dist2(x, y, wx, wy)
      if d2 <= bestD2 then
        bestD2 = d2
        best = { x = wx, y = wy, tx = tx, ty = ty, wall = wall }
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
  self.burrowCooldown = 0
  self.burrow = nil
  self.retaliateTimer = 0
  self.regenDelay = 0
  self.hitFlash = 0
  self.invuln = 0
  self.phase = love.math.random() * math.pi * 2
  self.slot = 1
  self.dead = false
  return self
end

function Pet:placeNear(player, slot, dungeon)
  self.slot = slot
  local angle = -1.4 + (slot - 1) * 0.95
  local distance = player.radius + self.radius + 12
  local offsetX = math.cos(angle) * distance
  local offsetY = math.sin(angle) * distance
  if dungeon then
    -- Se desliza contra paredes para no reaparecer dentro de un muro.
    self.x, self.y = dungeon:moveCircle(
      player.x,
      player.y,
      offsetX,
      offsetY,
      self.radius
    )
  else
    self.x = player.x + offsetX
    self.y = player.y + offsetY
  end
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
    local best = nearestWall(run, self.x, self.y, self.def.range)
    if best then
      tx, ty = best.x, best.y
    else
      tx = player.x
      ty = player.y
    end
  end

  return tx, ty
end

function Pet:tryStartBurrow(run)
  if self.burrowCooldown > 0 or not Rhythm.justStrongBeat then return false end

  local wall = nearestWall(run, self.x, self.y, self.def.range)
  if not wall then return false end

  local tile = run.dungeon.tile or 36
  local reach = tile * 0.5 + self.radius + 8
  if Util.dist2(self.x, self.y, wall.x, wall.y) > reach * reach then
    return false
  end
  if love.math.random() >= (self.def.burrowChance or 0.40) then
    return false
  end

  self.burrow = {
    tx = wall.tx,
    ty = wall.ty,
    x = wall.x,
    y = wall.y,
    startBeat = Rhythm.beat,
  }
  self.x, self.y = wall.x, wall.y
  self.facingX, self.facingY = 0, 0
  FX.ring(wall.x, wall.y, self.radius + 6, Data.items.hamster.color)
  return true
end

function Pet:updateBurrow(dt, run)
  local burrow = self.burrow
  local wall = run.dungeon.destructible[burrow.ty]
    and run.dungeon.destructible[burrow.ty][burrow.tx]

  if not wall then
    -- Otra fuente ya abrió la pared: el hámster sale sin gastar la recarga.
    self.burrow = nil
    self.x, self.y = burrow.x, burrow.y
    return
  end

  local beats = self.def.burrowBeats or 4
  if Rhythm.beat - burrow.startBeat < beats then return end

  run:damageWallAt(burrow.tx, burrow.ty, wall.maxHp or wall.hp or 1)
  self.burrow = nil
  self.x, self.y = burrow.x, burrow.y
  self.burrowCooldown = self.def.burrowCooldown or 10
  FX.ring(burrow.x, burrow.y, self.radius + 8, Data.items.hamster.color)
end

function Pet:update(dt, run)
  if self.dead then return end

  self.hitFlash = math.max(0, self.hitFlash - dt * 10)
  self.invuln = math.max(0, self.invuln - dt)
  self.attackCooldown = math.max(0, self.attackCooldown - dt)
  self.burrowCooldown = math.max(0, (self.burrowCooldown or 0) - dt)
  self.regenDelay = math.max(0, self.regenDelay - dt)
  self.retaliateTimer = math.max(0, self.retaliateTimer - dt)

  if self.regenDelay == 0 and self.hp < self.maxHp then
    self.hp = math.min(self.maxHp, self.hp + self.maxHp * self.def.regenRate * dt)
  end

  if self.burrow then
    self:updateBurrow(dt, run)
    return
  end

  local player = run.player
  local leash = Data.petLeash or 360
  if Util.dist2(self.x, self.y, player.x, player.y) > leash * leash then
    -- Una mascota atrapada por paredes vuelve junto al jugador.
    self:placeNear(player, self.slot, run.dungeon)
  end

  if self.kind == "hamster" and self:tryStartBurrow(run) then
    return
  end

  local tx, ty
  if self.kind == "hamster" then
    tx, ty = self:updateHamster(dt, run)
  else
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

  if self.burrow then
    local t = love.timer.getTime()
    local pulse = 0.65 + 0.20 * math.sin(t * 10)
    love.graphics.setColor(color[1], color[2], color[3], pulse)
    love.graphics.circle("fill", self.x, self.y, radius * 0.8)
    love.graphics.setColor(1.00, 0.86, 0.35, 0.85)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", self.x, self.y, radius + 4)
    love.graphics.setLineWidth(1)
    local beats = self.def.burrowBeats or 4
    local remaining = math.max(0, beats - (Rhythm.beat - self.burrow.startBeat))
    for i = 1, beats do
      love.graphics.setColor(1.00, 0.86, 0.35, i <= remaining and 0.95 or 0.25)
      love.graphics.circle("fill", self.x - 12 + i * 6, self.y - radius - 9, 2)
    end
    return
  end

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
