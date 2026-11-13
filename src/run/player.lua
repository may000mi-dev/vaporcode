-- player.lua: personaje controlado por el jugador y ataque automático.
local Data = require("src.run.data")
local Util = require("src.utils.util")

local Player = {}
Player.__index = Player

function Player.new(x, y, characterId)
  local self = setmetatable({}, Player)
  self.x = x
  self.y = y
  self.characterId = Data.characters[characterId] and characterId or "amado"
  self.character = Data.characters[self.characterId]
  self.radius = Data.player.radius
  self.facingX = 1
  self.facingY = 0
  self.moveX = 0
  self.moveY = 0
  self.moving = false
  self.attackTimer = 0.3
  self.spinTimer = 0
  self.shieldTimer = 0
  self.invuln = 0
  self.shield = 0
  self.shieldMax = 0
  self.shieldDelay = 0
  self.slowTimer = 0
  self.slowFactor = 1
  self.timeLockTimer = 0
  return self
end

function Player:applySlow(duration, factor)
  self.slowTimer = math.max(self.slowTimer or 0, duration or 0)
  self.slowFactor = math.min(self.slowFactor or 1, factor or 1)
end

function Player:freeze(duration)
  self.timeLockTimer = math.max(self.timeLockTimer or 0, duration or 0)
end

function Player:setupShield(maxHp)
  local percent = self.character.shieldPercent
  if not percent then return end
  self.shieldMax = maxHp * percent
  self.shield = self.shieldMax
  self.shieldDelay = 0
end

function Player:refreshShield(maxHp)
  local percent = self.character.shieldPercent
  if not percent then return end

  local ratio = 1
  if self.shieldMax > 0 then
    ratio = self.shield / self.shieldMax
  end
  self.shieldMax = maxHp * percent
  self.shield = self.shieldMax * ratio
end

function Player:updateShield(dt)
  local def = self.character
  if not def.shieldPercent or self.shieldMax <= 0 then return end

  if self.shieldDelay > 0 then
    self.shieldDelay = math.max(0, self.shieldDelay - dt)
    return
  end

  local repair = self.shieldMax * (def.shieldRepairRate or 0) * dt
  self.shield = math.min(self.shieldMax, self.shield + repair)
end

function Player:meleeRange(level)
  local def = self.character
  local progress = Util.clamp(
    (level - 1) / (def.meleeLevelSpan or 9),
    0,
    1
  )
  local factor = def.meleeRangeMinFactor
    + (def.meleeRangeMaxFactor - def.meleeRangeMinFactor) * progress
  return self.radius * factor
end

function Player:moveDirection()
  if self.moving then
    return self.moveX, self.moveY
  end
  return self.facingX, self.facingY
end

function Player:tryAttack(run, attackRate)
  local basic = self.character.basic

  if basic == "melee" then
    local range = self:meleeRange(run.playerLevel)
    local target = run:nearestEnemy(range, true)
    if not target then return false end

    self.attackTimer = 1 / attackRate
    local angle = Util.atan2(target.y - self.y, target.x - self.x)
    self.facingX = math.cos(angle)
    self.facingY = math.sin(angle)
    run:meleeSpin(self, range, run.stats.damage)
    return true
  end

  local range = self.character.attackRange or Data.player.attackRange
  local target = run:nearestEnemy(range, true)
  if not target then return false end

  self.attackTimer = 1 / attackRate
  local angle = Util.atan2(target.y - self.y, target.x - self.x)
  self.facingX = math.cos(angle)
  self.facingY = math.sin(angle)

  if basic == "chain" then
    run:spawnProjectile(self.x, self.y, angle, run.stats.damage, false, {
      kind = "chain",
      chain = self.character.chain,
    })
  else
    run:spawnProjectile(self.x, self.y, angle, run.stats.damage, false, {
      kind = "spark",
      mark = true,
    })
  end
  return true
end

function Player:update(dt, dx, dy, run)
  self.slowTimer = math.max(0, (self.slowTimer or 0) - dt)
  self.timeLockTimer = math.max(0, (self.timeLockTimer or 0) - dt)
  if self.slowTimer <= 0 then
    self.slowFactor = 1
  end
  if self.timeLockTimer > 0 then
    dx, dy = 0, 0
  end

  local mag = math.sqrt(dx * dx + dy * dy)
  if mag > 1 then
    dx = dx / mag
    dy = dy / mag
    mag = 1
  end

  self.moving = mag > 0.01
  self.moveX = dx
  self.moveY = dy

  if self.moving then
    self.facingX = dx / mag
    self.facingY = dy / mag
  end

  local speed = run.stats.speed * (self.character.speedMultiplier or 1)
  if self.slowTimer > 0 then
    speed = speed * self.slowFactor
  end
  local attackRate = run.stats.attackRate
  if run.turboTimer > 0 then
    speed = speed * Data.abilities.turbo.speedMultiplier
    attackRate = attackRate * Data.abilities.turbo.attackRateMultiplier
  end

  self.x, self.y = run.dungeon:moveCircle(
    self.x,
    self.y,
    dx * speed * dt,
    dy * speed * dt,
    self.radius
  )

  self:updateShield(dt)

  self.spinTimer = math.max(0, self.spinTimer - dt)
  self.attackTimer = self.attackTimer - dt
  if self.attackTimer <= 0 and self.timeLockTimer <= 0 then
    -- Si no hay objetivo visible se reintenta en el siguiente frame.
    if not self:tryAttack(run, attackRate) then
      self.attackTimer = 0
    end
  end
end

function Player:takeDamage(amount, run)
  if run.over then return false end
  if run.sandbox and run.sandboxInvuln then return false end
  if self.invuln > 0 then return false end
  if self.shieldTimer > 0 then return false end

  self.shieldDelay = self.character.shieldRepairDelay or 0

  if self.shield > 0 then
    local absorbed = math.min(self.shield, amount)
    self.shield = self.shield - absorbed
    amount = amount - absorbed
  end

  if amount > 0 then
    run.hp = run.hp - amount
    if run.shake then run:shake(3, 0.16) end
  end

  self.invuln = Data.player.invulnTime
  if run.hp <= 0 then
    run.hp = 0
    run:gameOver()
  end
  return true
end

function Player:draw(run)
  local color = self.character.color

  love.graphics.setColor(0, 0, 0, 0.35)
  love.graphics.circle("fill", self.x, self.y + 3, self.radius + 2)

  love.graphics.setColor(color[1], color[2], color[3])
  love.graphics.circle("fill", self.x, self.y, self.radius)
  love.graphics.setColor(color[1] * 0.30, color[2] * 0.30, color[3] * 0.30)
  love.graphics.circle("line", self.x, self.y, self.radius)

  love.graphics.setColor(1, 1, 1)
  love.graphics.circle("fill", self.x + self.facingX * 8, self.y + self.facingY * 8, 4)

  if self.spinTimer > 0 then
    local t = love.timer.getTime()
    love.graphics.setColor(color[1], color[2], color[3], self.spinTimer * 4)
    love.graphics.setLineWidth(3)
    for i = 0, 2 do
      love.graphics.arc(
        "line",
        self.x,
        self.y,
        self.radius * 1.8,
        t * 18 + i * (math.pi * 2 / 3),
        t * 18 + i * (math.pi * 2 / 3) + 0.8
      )
    end
    love.graphics.setLineWidth(1)
  end

  if self.shieldTimer > 0 then
    love.graphics.setColor(0.95, 0.80, 0.30)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", self.x, self.y, self.radius + 9)
    love.graphics.setLineWidth(1)
  end

  if self.slowTimer > 0 then
    love.graphics.setColor(0.36, 0.82, 0.45, 0.85)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", self.x, self.y, self.radius + 5)
    love.graphics.setLineWidth(1)
  end

  if self.timeLockTimer > 0 then
    local t = love.timer.getTime()
    love.graphics.setColor(0.55, 0.72, 1.00, 0.95)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", self.x, self.y, self.radius + 8)
    love.graphics.line(self.x, self.y, self.x, self.y - self.radius - 10)
    love.graphics.line(
      self.x,
      self.y,
      self.x + math.cos(t * 8) * (self.radius + 7),
      self.y + math.sin(t * 8) * (self.radius + 7)
    )
    love.graphics.setLineWidth(1)
  end

  if self.shield > 0.05 then
    local t = love.timer.getTime()
    local colors = {
      { 1.00, 0.28, 0.35 },
      { 1.00, 0.68, 0.20 },
      { 1.00, 0.94, 0.28 },
      { 0.30, 0.92, 0.48 },
      { 0.34, 0.68, 1.00 },
      { 0.82, 0.42, 1.00 },
    }
    local alpha = 0.45 + 0.35 * (self.shield / self.shieldMax)
    love.graphics.setLineWidth(3)
    for i, color in ipairs(colors) do
      local a1 = t * 1.8 + (i - 1) * (math.pi * 2 / #colors)
      love.graphics.setColor(color[1], color[2], color[3], alpha)
      love.graphics.arc(
        "line",
        "open",
        self.x,
        self.y,
        self.radius + 8,
        a1,
        a1 + 0.55
      )
    end
    love.graphics.setLineWidth(1)
  end

  if run and run.turboTimer > 0 then
    love.graphics.setColor(0.45, 1.00, 0.55, 0.75)
    love.graphics.circle("line", self.x, self.y, self.radius + 13)
  end
end

return Player
