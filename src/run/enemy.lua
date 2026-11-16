-- enemy.lua: enemigos con roles, memoria de persecución, élites y jefes.
local Data = require("src.run.data")
local Util = require("src.utils.util")
local Boss = require("src.run.boss")
local FX = require("src.run.fx")
local Compases = require("src.run.compases")
local Antidote = require("src.run.antidote")

local Enemy = {}
Enemy.__index = Enemy

local function angleDistance(a, b)
  local delta = (a - b + math.pi) % (math.pi * 2) - math.pi
  return math.abs(delta)
end

function Enemy.new(kind, x, y, hp, damage, xp, options)
  options = options or {}
  local def = Data.enemyTypes[kind]
  local self = setmetatable({}, Enemy)
  self.kind = kind
  self.def = def
  self.x = x
  self.y = y
  self.radius = def.radius
  self.speed = def.speed
  self.hp = hp or def.hp
  self.maxHp = self.hp
  self.damage = damage or def.damage
  self.xp = xp or def.xp
  self.phase = love.math.random() * math.pi * 2
  self.hitFlash = 0
  self.shootTimer = (def.firstAttackDelay or 0)
    * (options.attackCooldownMultiplier or 1)
  self.bossTimer = Data.enemyAI.bossFirstShotDelay
    * (options.attackCooldownMultiplier or 1)
  self.contactTimer = 0
  self.dead = false
  self.markTimer = 0
  self.stunTimer = 0
  self.extraSlowTimer = 0
  self.extraSlowFactor = 1
  self.poisonTimer = 0
  self.poisonDps = 0
  self.invulnTimer = 0
  self.lastSeenX = nil
  self.lastSeenY = nil
  self.searchTimer = 0
  self.searchSide = love.math.random() < 0.5 and -1 or 1
  self.blockedTimer = 0
  self.trapSide = 1

  self.elite = options.elite
  self.affixes = options.affixes
    or (options.elite and { options.elite })
    or {}
  if not self.elite and #self.affixes > 0 then
    self.elite = self.affixes[1]
  end
  self.attackCooldownMultiplier = options.attackCooldownMultiplier or 1
  self.immuneToStun = options.immuneToStun == true
  self.armor = def.armor or 0
  self.mirrorShieldTimer = 0
  self.mirrorShieldCooldownTimer = def.reflectionFirstDelay or 0
  self.mirrorShieldAngle = love.math.random() * math.pi * 2
  self.eliteTimer = love.math.random() * Data.elite.spectralCycle
  self.intangible = false
  self.shield = self:hasAffix("armored") and Data.elite.armoredShield or 0
  self.chronosTimer = self:hasAffix("chronos")
    and love.math.random() * Data.elite.chronosInterval
    or 0
  self.mirrorTimer = self:hasAffix("mirror")
    and Data.elite.mirrorDuration
    or 0
  self.mirrorCooldownTimer = 0
  self.facingX = 1
  self.facingY = 0

  if def.boss then
    Boss.init(self)
  end
  return self
end

function Enemy:hasAffix(id)
  for _, affix in ipairs(self.affixes or {}) do
    if affix == id then return true end
  end
  return false
end

function Enemy:isElite()
  return #(self.affixes or {}) > 0
end

function Enemy:cooldown(base)
  return (base or 0) * (self.attackCooldownMultiplier or 1)
end

function Enemy:canBeAffected()
  if self.dead or self.intangible then return false end
  return (self.shield or 0) <= 0
end

function Enemy:applyMark(duration)
  self.markTimer = duration or Data.mark.duration
end

function Enemy:movementSpeed()
  local speed = self.speed
  if self.extraSlowTimer > 0 then
    speed = speed * self.extraSlowFactor
  end
  if self.markTimer > 0 then
    speed = speed * (1 - Data.mark.slow)
  end
  return speed
end

function Enemy:applyStun(duration)
  -- Los jefes no se aturden: la pólvora y el perro no deben anular su IA.
  if self.def.boss or self.immuneToStun then return false end
  self.stunTimer = math.max(self.stunTimer, duration or 0)
  return true
end

function Enemy:applySlow(duration, factor)
  self.extraSlowTimer = math.max(self.extraSlowTimer, duration or 0)
  self.extraSlowFactor = math.min(self.extraSlowFactor or 1, factor or 1)
end

function Enemy:applyPoison(dps, duration)
  if self.dead then return end
  self.poisonDps = math.max(self.poisonDps or 0, dps or 0)
  self.poisonTimer = math.max(self.poisonTimer or 0, duration or 0)
end

function Enemy:move(dt, run, dx, dy, scale)
  local distance = math.sqrt(dx * dx + dy * dy)
  if distance <= 0.001 then return end
  local speed = self:movementSpeed() * (scale or 1)
  self.facingX = dx / distance
  self.facingY = dy / distance
  self.x, self.y = run.dungeon:moveCircle(
    self.x,
    self.y,
    (dx / distance) * speed * dt,
    (dy / distance) * speed * dt,
    self.radius
  )
end

function Enemy:shoot(run, target, options)
  options = options or {}
  local angle = Util.atan2(target.y - self.y, target.x - self.x)
  if options.angle then angle = options.angle end
  options.sourceEnemy = self
  run:spawnProjectile(
    self.x,
    self.y,
    angle,
    self.damage * (options.damageScale or 1),
    true,
    options
  )
end

local function sweep(enemy, dt, run, dx, dy, speedScale)
  local angle = Util.atan2(dy, dx) + enemy.searchSide * math.pi * 0.5
  enemy:move(dt, run, math.cos(angle), math.sin(angle), speedScale)
  enemy.searchTimer = enemy.searchTimer + dt
  if enemy.searchTimer >= Data.enemyAI.searchDuration then
    -- Si el barrido no revela al jugador, se abandona esa memoria.
    enemy.searchSide = -enemy.searchSide
    enemy.searchTimer = 0
    enemy.blockedTimer = 0
    enemy.lastSeenX = nil
    enemy.lastSeenY = nil
  end
end

function Enemy:updateSearch(dt, run)
  if not self.lastSeenX then return end

  local dx = self.lastSeenX - self.x
  local dy = self.lastSeenY - self.y
  local distance = math.sqrt(dx * dx + dy * dy)
  if distance > Data.enemyAI.memoryDistance then
    local before = distance
    self:move(dt, run, dx, dy, 0.72)
    local after = math.sqrt(
      (self.lastSeenX - self.x) ^ 2 + (self.lastSeenY - self.y) ^ 2
    )
    local expected = self:movementSpeed() * 0.72 * dt * 0.25
    if after > before - expected then
      self.blockedTimer = self.blockedTimer + dt
    else
      self.blockedTimer = 0
    end

    -- Si una pared impide avanzar, bordearla en lugar de empujarla.
    if self.blockedTimer >= 0.18 then
      sweep(self, dt, run, dx, dy, 0.8)
    end
    return
  end

  sweep(self, dt, run, dx, dy, 0.55)
end

function Enemy:updateChaser(dt, run, nx, ny)
  self:move(dt, run, nx, ny, 1)
end

function Enemy:updateRanged(dt, run, target, distance, nx, ny)
  local ai = Data.enemyAI
  local keep = self.def.keepDistance or ai.keepDistance
  if distance < keep then
    self:move(dt, run, -nx, -ny, 1)
  else
    self:move(dt, run, nx, ny, 1)
  end

  self.shootTimer = self.shootTimer - dt
  if distance > ai.shootRange and self.shootTimer <= 0 then
    self.shootTimer = self:cooldown(ai.shootInterval)
    self:shoot(run, target, {
      damageScale = ai.shootDamageScale,
    })
  end
end

function Enemy:updateTurret(dt, run, target, distance)
  local def = self.def
  if distance > (def.attackRange or 500) then return end
  self.shootTimer = self.shootTimer - dt
  if self.shootTimer <= 0 then
    self.shootTimer = self:cooldown(def.attackInterval or 3)
    self:shoot(run, target, {
      damageScale = def.projectileScale or 1,
      speed = def.projectileSpeed,
      radius = def.projectileRadius,
      kind = "heavy",
    })
  end
end

function Enemy:updateMortar(dt, run, target, distance, nx, ny)
  local def = self.def
  if distance < (def.retreatDistance or 145) then
    self:move(dt, run, -nx, -ny, 1)
  elseif distance > (def.keepDistance or 210) + 45 then
    self:move(dt, run, nx, ny, 1)
  end

  self.shootTimer = self.shootTimer - dt
  if self.shootTimer <= 0 then
    self.shootTimer = self:cooldown(def.attackInterval or 3.2)
    run:spawnHazard("fire", target.x, target.y, {
      radius = def.mortarRadius,
      delay = def.mortarDelay,
      life = def.fireDuration,
      damage = def.mortarDamage * Compases.enemyDamageMultiplier(run),
      interval = 0.5,
      color = { 1.00, 0.38, 0.14 },
      sourceEnemy = self,
    })
    FX.ring(target.x, target.y, def.mortarRadius, { 1.00, 0.38, 0.14 })
  end
end

function Enemy:updateHealer(dt, run, distance, nx, ny)
  local def = self.def
  local keep = def.keepDistance or 210
  if distance < (def.retreatDistance or 155) then
    self:move(dt, run, -nx, -ny, 1)
  elseif distance > keep + 50 then
    self:move(dt, run, nx, ny, 1)
  end

  self.shootTimer = self.shootTimer - dt
  if self.shootTimer <= 0 then
    self.shootTimer = self:cooldown(def.attackInterval or 4)
    run:healEnemiesAround(self.x, self.y, def.healRadius, def.healPercent)
  end
end

function Enemy:updateSummoner(dt, run, distance, nx, ny)
  local def = self.def
  if distance < (def.fleeDistance or 190) then
    self:move(dt, run, -nx, -ny, 1)
  elseif distance > 300 then
    self:move(dt, run, nx, ny, 0.6)
  end

  self.shootTimer = self.shootTimer - dt
  if self.shootTimer <= 0 then
    self.shootTimer = self:cooldown(def.attackInterval or 6)
    local count = 0
    for _, enemy in ipairs(run.enemies) do
      if not enemy.dead and enemy.kind == def.summonKind then
        count = count + 1
      end
    end
    if count < (def.summonCap or 4) then
      local angle = love.math.random() * math.pi * 2
      local minion = Data.enemyTypes[def.summonKind]
      local x, y = run.dungeon:moveCircle(
        self.x,
        self.y,
        math.cos(angle) * (self.radius + minion.radius + 8),
        math.sin(angle) * (self.radius + minion.radius + 8),
        minion.radius
      )
      run:createEnemy(def.summonKind, x, y, {
        noElite = true,
        hp = def.summonKind == "broken_automaton" and 1 or nil,
      })
      FX.ring(x, y, minion.radius + 6, minion.color)
    end
  end
end

function Enemy:updateTrapper(dt, run, target, nx, ny)
  local def = self.def
  local angle = Util.atan2(-ny, -nx) + self.trapSide * math.pi * 0.5
  local offsetX = math.cos(angle) * (def.flankDistance or 118)
  local offsetY = math.sin(angle) * (def.flankDistance or 118)
  local tx = target.x + offsetX
  local ty = target.y + offsetY
  self:move(dt, run, tx - self.x, ty - self.y, 1)

  self.shootTimer = self.shootTimer - dt
  if self.shootTimer <= 0 then
    self.shootTimer = self:cooldown(def.attackInterval or 2.6)
    self.trapSide = -self.trapSide
    run:spawnHazard("mine", self.x, self.y, {
      delay = Data.hazards.mineArm,
      life = Data.hazards.mineLife,
      radius = Data.hazards.mineExplosionRadius,
      damage = Data.hazards.mineDamage * Compases.enemyDamageMultiplier(run),
      sourceEnemy = self,
    })
  end
end

function Enemy:updateBlight(dt, run, target, distance, nx, ny)
  local def = self.def
  if distance < 80 then
    self:move(dt, run, -nx, -ny, 0.8)
  elseif distance > 150 then
    self:move(dt, run, nx, ny, 1)
  end

  self.shootTimer = self.shootTimer - dt
  if distance <= (def.attackRange or 300)
    and distance > 60
    and self.shootTimer <= 0
  then
    self.shootTimer = self:cooldown(def.attackInterval or 3.4)
    self:shoot(run, target, {
      damageScale = 0.9,
      speed = 190,
      radius = 7,
      kind = "blight",
      effect = "slow",
      effectData = {
        duration = def.projectileSlowDuration,
        factor = def.projectileSlowFactor,
      },
    })
  end
end

function Enemy:updateManaHunter(dt, run, target, distance, nx, ny)
  local def = self.def
  local keep = def.keepDistance or 230
  if distance < (def.retreatDistance or 170) then
    self:move(dt, run, -nx, -ny, 1)
  elseif distance > keep + 70 then
    self:move(dt, run, nx, ny, 1)
  end

  self.shootTimer = self.shootTimer - dt
  if distance <= (def.attackRange or 470) and self.shootTimer <= 0 then
    self.shootTimer = self:cooldown(def.attackInterval or 3.4)
    self:shoot(run, target, {
      damageScale = 0.85,
      speed = def.projectileSpeed or 235,
      radius = 7,
      kind = "clock",
      effect = "mana_drain",
      effectData = {
        manaDrain = def.manaDrain,
        lock = def.abilityLock,
      },
    })
  end
end

function Enemy:updatePurifier(dt, run, distance, nx, ny)
  local def = self.def
  local keep = def.keepDistance or 120
  if distance > keep + 30 then
    self:move(dt, run, nx, ny, 1)
  elseif distance < (def.retreatDistance or 72) then
    self:move(dt, run, -nx, -ny, 1)
  end
end

function Enemy:updateSiege(dt, run, target, distance, nx, ny)
  -- Inmóvil: solo orienta la barrera hacia el jugador.
  self.facingX = nx
  self.facingY = ny
end

function Enemy:findPetTarget(run)
  if not Antidote.enabled(run) or not run.pets then return nil end

  local best, bestD2 = nil, math.huge
  local range = Data.enemyAI.sightRange
  local range2 = range * range
  for _, pet in ipairs(Antidote.activePets(run)) do
    local d2 = Util.dist2(self.x, self.y, pet.x, pet.y)
    if d2 <= range2
      and (not run.dungeon or not run.dungeon.lineOfSight
        or run.dungeon:lineOfSight(self.x, self.y, pet.x, pet.y))
      and d2 < bestD2
    then
      best, bestD2 = pet, d2
    end
  end
  return best
end

function Enemy:updatePetHunter(dt, run, target, distance, nx, ny)
  self:move(dt, run, nx, ny, 1)
  self.contactTimer = math.max(0, self.contactTimer - dt)
  if distance > self.radius + target.radius + 4 then return end
  if self.contactTimer > 0 then return end

  local def = self.def
  local drain = self.damage * (def.petDrainScale or 0.35)
  if not target:takeDamage(drain, run) then return end

  self.contactTimer = def.petDrainInterval or 0.45
  local heal = drain * (def.petDrainHealPercent or 0.50)
  self.hp = math.min(self.maxHp, self.hp + heal)
  FX.line(self.x, self.y, target.x, target.y, def.color, 0.16, 3)
  FX.add(
    "-" .. math.max(1, math.floor(drain)),
    target.x,
    target.y - target.radius - 8,
    def.color
  )
end

function Enemy:updateRole(dt, run, target, distance, nx, ny)
  local role = self.def.role or (self.def.keepDistance and "ranged" or "chaser")
  if role == "purifier" then
    self:updatePurifier(dt, run, distance, nx, ny)
  elseif role == "siege" then
    self:updateSiege(dt, run, target, distance, nx, ny)
  elseif role == "turret" then
    self:updateTurret(dt, run, target, distance)
  elseif role == "mortar" then
    self:updateMortar(dt, run, target, distance, nx, ny)
  elseif role == "healer" then
    self:updateHealer(dt, run, distance, nx, ny)
  elseif role == "summoner" then
    self:updateSummoner(dt, run, distance, nx, ny)
  elseif role == "trapper" then
    self:updateTrapper(dt, run, target, nx, ny)
  elseif role == "blight" then
    self:updateBlight(dt, run, target, distance, nx, ny)
  elseif role == "mana_hunter" then
    self:updateManaHunter(dt, run, target, distance, nx, ny)
  elseif role == "ranged" then
    self:updateRanged(dt, run, target, distance, nx, ny)
  else
    self:updateChaser(dt, run, nx, ny)
  end
end

function Enemy:updateContact(dt, run, target, distance, nx, ny, canSee, targetingShadow)
  self.contactTimer = math.max(0, self.contactTimer - dt)
  if not canSee or targetingShadow then return end
  if distance >= self.radius + target.radius then return end
  if self.contactTimer > 0 then return end

  local hit = target:takeDamage(
    self.damage * Data.enemyAI.contactDamageScale,
    run,
    self
  )
  if not hit then return end

  self.contactTimer = Data.enemyAI.contactInterval
  if self.def.contactSlow and target.applySlow then
    target:applySlow(
      self.def.contactSlowDuration,
      self.def.contactSlowFactor
    )
  end
  self.x, self.y = run.dungeon:moveCircle(
    self.x,
    self.y,
    -nx * Data.enemyAI.contactKnockback,
    -ny * Data.enemyAI.contactKnockback,
    self.radius
  )
end

function Enemy:hasGuardianAura(run)
  if not run or not run.enemies then return false end
  local radius = Data.elite.guardianRadius
  for _, other in ipairs(run.enemies) do
    if other ~= self and not other.dead and other:hasAffix("guardian") then
      local reach = radius + self.radius
      if Util.dist2(self.x, self.y, other.x, other.y) <= reach * reach then
        return true
      end
    end
  end
  return false
end

function Enemy:updateMirrorShield(dt)
  local def = self.def
  if not def.reflectionActiveTime then return end

  self.mirrorShieldAngle = (self.mirrorShieldAngle
    + dt * (def.reflectionRotation or 2.4)) % (math.pi * 2)

  if self.mirrorShieldTimer > 0 then
    self.mirrorShieldTimer = math.max(0, self.mirrorShieldTimer - dt)
    if self.mirrorShieldTimer == 0 then
      self.mirrorShieldCooldownTimer = def.reflectionCooldown or 4.6
    end
  elseif self.mirrorShieldCooldownTimer > 0 then
    self.mirrorShieldCooldownTimer = math.max(0, self.mirrorShieldCooldownTimer - dt)
    if self.mirrorShieldCooldownTimer == 0 then
      self.mirrorShieldTimer = def.reflectionActiveTime
    end
  end
end

function Enemy:updateAffixTimers(dt, run)
  if self:hasAffix("mirror") then
    if self.mirrorTimer > 0 then
      self.mirrorTimer = math.max(0, self.mirrorTimer - dt)
      if self.mirrorTimer == 0 then
        self.mirrorCooldownTimer = Data.elite.mirrorCooldown
      end
    elseif self.mirrorCooldownTimer > 0 then
      self.mirrorCooldownTimer = math.max(0, self.mirrorCooldownTimer - dt)
      if self.mirrorCooldownTimer == 0 then
        self.mirrorTimer = Data.elite.mirrorDuration
      end
    end
  end

  if self:hasAffix("chronos") and self.stunTimer <= 0 then
    self.chronosTimer = (self.chronosTimer or 0) - dt
    if self.chronosTimer <= 0 then
      self.chronosTimer = Data.elite.chronosInterval
      local player = run and run.player
      local radius = Data.elite.chronosRadius
      if player then
        local reach = radius + player.radius
        if Util.dist2(self.x, self.y, player.x, player.y) <= reach * reach then
          player:applySlow(Data.elite.chronosDuration, 1 - Data.elite.chronosSlow)
        end
      end
      FX.ring(self.x, self.y, radius, { 0.52, 0.72, 1.00 })
    end
  end
end

function Enemy:onDamageDealt(amount, run)
  if amount <= 0 or not self:hasAffix("vampiric") or self.dead then return end
  local heal = amount * Data.elite.vampiricHealPercent
  if self.hp < self.maxHp then
    self.hp = math.min(self.maxHp, self.hp + heal)
    FX.add("+" .. math.floor(heal) .. " vida", self.x, self.y - self.radius - 18, { 0.95, 0.30, 0.32 })
  end
end

function Enemy:shouldReflectAntidote(run, amount, source)
  local def = self.def
  if def.role ~= "mirror_guard" or self.mirrorShieldTimer <= 0 then
    return false
  end
  if amount < (def.reflectionMinDamage or 0) then return false end
  if source == "poison"
    or source == "elite"
    or source == "hazard"
    or source == "pet"
  then
    return false
  end

  local player = run and run.player
  if not player then return false end
  local angle = Util.atan2(player.y - self.y, player.x - self.x)
  local halfArc = (def.reflectionArc or math.pi * 0.7) * 0.5
  return angleDistance(angle, self.mirrorShieldAngle) <= halfArc
end

function Enemy:shouldReflect(run)
  if self.mirrorTimer <= 0 or not run or not run.player then
    return false
  end
  local dx = run.player.x - self.x
  local dy = run.player.y - self.y
  local distance = math.sqrt(dx * dx + dy * dy)
  if distance <= 0.001 then return true end
  local dot = (dx / distance) * (self.facingX or 1)
    + (dy / distance) * (self.facingY or 0)
  return dot >= 0.15
end

function Enemy:update(dt, run)
  self.hitFlash = math.max(0, self.hitFlash - dt * Data.enemyAI.hitFlashDecay)
  self.markTimer = math.max(0, self.markTimer - dt)
  self.stunTimer = math.max(0, self.stunTimer - dt)
  self.extraSlowTimer = math.max(0, self.extraSlowTimer - dt)
  if self.extraSlowTimer == 0 then
    self.extraSlowFactor = 1
  end

  if self:hasAffix("spectral") then
    self.eliteTimer = (self.eliteTimer + dt) % Data.elite.spectralCycle
    self.intangible = self.eliteTimer < Data.elite.spectralDuration
  end

  self:updateAffixTimers(dt, run)
  self:updateMirrorShield(dt)

  if self.poisonTimer > 0 then
    self.poisonTimer = math.max(0, self.poisonTimer - dt)
    if not self.dead and (self.poisonDps or 0) > 0 then
      self:takeDamage(self.poisonDps * dt, run, "poison")
    end
  end
  if self.dead then return end

  if self.stunTimer > 0 then
    self.phase = self.phase + dt * Data.enemyAI.phaseSpeed
    return
  end

  local shadow = run.shadow
  local petTarget
  if not shadow and self.def.role == "pet_hunter" then
    petTarget = self:findPetTarget(run)
  end
  local target = shadow or petTarget or run.player
  local targetingShadow = shadow ~= nil
  local targetingPet = not targetingShadow and petTarget ~= nil
  local dx = target.x - self.x
  local dy = target.y - self.y
  local distance = math.sqrt(dx * dx + dy * dy)
  local nx, ny = 0, 0
  if distance > 0.001 then
    nx = dx / distance
    ny = dy / distance
  end

  local canSee = distance < Data.enemyAI.sightRange
    and run.dungeon:lineOfSight(self.x, self.y, target.x, target.y)

  if canSee then
    self.lastSeenX = target.x
    self.lastSeenY = target.y
    self.searchTimer = 0
  end

  if self.def.boss then
    Boss.update(self, dt, run, {
      target = target,
      canSee = canSee,
      distance = distance,
      dx = dx,
      dy = dy,
      nx = nx,
      ny = ny,
    })
  elseif canSee then
    if targetingPet then
      self:updatePetHunter(dt, run, target, distance, nx, ny)
    else
      self:updateRole(dt, run, target, distance, nx, ny)
    end
  else
    self:updateSearch(dt, run)
  end

  self.phase = self.phase + dt * Data.enemyAI.phaseSpeed
  if not targetingPet then
    self:updateContact(dt, run, target, distance, nx, ny, canSee, targetingShadow)
  end

  if not targetingShadow and not targetingPet and run.pets then
    for _, pet in ipairs(run.pets) do
      if not pet.dead and pet.def.meleeVulnerable then
        local rr = self.radius + pet.radius
        if Util.dist2(self.x, self.y, pet.x, pet.y) <= rr * rr then
          pet:takeDamage(self.damage * dt * 0.8, run)
        end
      end
    end
  end
end

function Enemy:takeDamage(amount, run, source)
  if self.dead then return 0 end
  if (self.invulnTimer or 0) > 0 or self.intangible then return 0 end

  if run and run.enemies and self:hasGuardianAura(run) then
    amount = amount * (1 - Data.elite.guardianDamageReduction)
  end

  if (self.armor or 0) > 0 then
    amount = amount * (1 - self.armor)
  end

  -- Fortificado protege mientras el jefe siga por encima del umbral. La
  -- memoria se rompe al cruzar el porcentaje y no vuelve a activarse.
  if self.memoryFortified
    and self.maxHp > 0
    and self.hp > self.maxHp * (self.memoryFortifiedThreshold or 0)
  then
    amount = amount * (1 - (self.memoryFortifiedReduction or 0))
  end

  local cap = self.def.damageCap
  if cap and amount > cap then
    amount = cap + (amount - cap) * (self.def.damageCapExcessScale or 0.15)
  end

  if (self.shield or 0) > 0 then
    local absorbed = math.min(self.shield, amount)
    self.shield = self.shield - absorbed
    amount = amount - absorbed
    self.hitFlash = 1
    if amount <= 0 then return absorbed end
  end

  if self.markTimer > 0 then
    amount = amount * (1 + Data.mark.damageBonus)
  end

  self.hp = self.hp - amount
  self.hitFlash = 1

  if amount > 0 and self.memoryRegenIdleTimer then
    self.memoryRegenIdleTimer = 0
  end

  if self.memoryFortified
    and self.maxHp > 0
    and self.hp <= self.maxHp * (self.memoryFortifiedThreshold or 0)
  then
    self.memoryFortified = false
    FX.add("Fortificado roto", self.x, self.y - self.radius - 20, { 0.70, 0.80, 0.92 })
  end

  local reflect = nil
  local reflectColor = nil
  if run
    and run.player
    and source ~= "poison"
    and source ~= "elite"
    and source ~= "hazard"
    and source ~= "pet"
    and self:hasAffix("mirror")
    and self:shouldReflect(run)
  then
    reflect = Data.elite.mirrorReflect
    reflectColor = { 0.78, 0.88, 1.00 }
  elseif run
    and run.player
    and self:shouldReflectAntidote(run, amount, source)
  then
    reflect = self.def.reflectionReflect or 0.35
    reflectColor = self.def.color
  end
  if reflect then
    run.player:takeDamage(amount * reflect, run)
    FX.ring(self.x, self.y, self.radius + 10, reflectColor)
  end

  if run and run.onEnemyDamaged then
    run:onEnemyDamaged(self, amount, source or "basic")
  end

  if self.hp <= 0 then
    self.hp = 0
    self.dead = true
    self.markTimer = 0
    self.stunTimer = 0
    self.intangible = false
    if run and run.onEnemyKilled then
      run:onEnemyKilled(self)
    end
  end
  return amount
end

function Enemy:draw()
  local color = self.def.color
  local radius = self.radius
  local alpha = self.intangible and 0.32 or 1

  love.graphics.setColor(0, 0, 0, 0.35)
  love.graphics.circle("fill", self.x, self.y + 2, radius + 2)

  local flash = self.hitFlash or 0
  love.graphics.setColor(
    color[1] + (1 - color[1]) * flash,
    color[2] + (1 - color[2]) * flash,
    color[3] + (1 - color[3]) * flash,
    alpha
  )
  love.graphics.circle("fill", self.x, self.y, radius)

  love.graphics.setColor(color[1] * 0.45, color[2] * 0.45, color[3] * 0.45, alpha)
  love.graphics.circle("line", self.x, self.y, radius)

  love.graphics.setColor(0.10, 0.10, 0.12, alpha)
  love.graphics.circle("fill", self.x, self.y, radius * 0.35)

  if self:isElite() then
    local t = love.timer.getTime()
    local colors = {
      volatile = { 1.00, 0.48, 0.20, 0.85 },
      armored = { 0.56, 0.72, 0.92, 0.85 },
      spectral = { 0.62, 0.86, 1.00, 0.85 },
      vampiric = { 0.90, 0.24, 0.30, 0.85 },
      chronos = { 0.52, 0.72, 1.00, 0.85 },
      guardian = { 0.82, 0.74, 0.36, 0.85 },
      mirror = { 0.90, 0.92, 1.00, 0.85 },
    }
    love.graphics.setLineWidth(2)
    for index, affix in ipairs(self.affixes) do
      local color = colors[affix] or { 0.80, 0.80, 0.80, 0.85 }
      love.graphics.setColor(color[1], color[2], color[3], color[4])
      love.graphics.circle(
        "line",
        self.x,
        self.y,
        radius + 5 + index * 2 + math.sin(t * 6 + index) * 1.5
      )
    end
    love.graphics.setLineWidth(1)
  end

  if self:hasAffix("chronos") then
    love.graphics.setColor(0.52, 0.72, 1.00, 0.22)
    love.graphics.circle("line", self.x, self.y, Data.elite.chronosRadius)
  end

  if self:hasAffix("guardian") then
    love.graphics.setColor(0.82, 0.74, 0.36, 0.20)
    love.graphics.circle("line", self.x, self.y, Data.elite.guardianRadius)
  end

  if self.def.role == "purifier" then
    local t = love.timer.getTime()
    local aura = Data.antidote.healingAuraRadius
    local pulse = 0.55 + 0.20 * math.sin(t * 3.2)
    love.graphics.setColor(0.70, 0.95, 0.55, 0.06)
    love.graphics.circle("fill", self.x, self.y, aura)
    love.graphics.setColor(0.70, 0.95, 0.55, 0.18 * pulse + 0.10)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", self.x, self.y, aura)
    love.graphics.setLineWidth(1)
  end

  if self.def.role == "mirror_guard" and self.mirrorShieldTimer > 0 then
    local halfArc = (self.def.reflectionArc or math.pi * 0.7) * 0.5
    love.graphics.setColor(0.78, 0.90, 1.00, 0.90)
    love.graphics.setLineWidth(4)
    love.graphics.arc(
      "line",
      "open",
      self.x,
      self.y,
      self.radius + 12,
      self.mirrorShieldAngle - halfArc,
      self.mirrorShieldAngle + halfArc
    )
    love.graphics.setLineWidth(1)
  end

  if self.def.role == "siege" then
    local facing = Util.atan2(self.facingY or 0, self.facingX or 1)
    local halfArc = math.pi * 0.32
    love.graphics.setColor(0.95, 0.72, 0.30, 0.85)
    love.graphics.setLineWidth(4)
    love.graphics.arc(
      "line",
      "open",
      self.x,
      self.y,
      self.radius + 11,
      facing - halfArc,
      facing + halfArc
    )
    love.graphics.setLineWidth(1)
  end

  if self.mirrorTimer > 0 then
    local facing = Util.atan2(self.facingY or 0, self.facingX or 1)
    love.graphics.setColor(0.82, 0.90, 1.00, 0.90)
    love.graphics.setLineWidth(3)
    love.graphics.arc("line", "open", self.x, self.y, radius + 12,
      facing - math.pi * 0.5, facing + math.pi * 0.5)
    love.graphics.setLineWidth(1)
  end

  if (self.shield or 0) > 0 then
    love.graphics.setColor(0.56, 0.72, 0.92, 0.9)
    love.graphics.setLineWidth(3)
    love.graphics.circle("line", self.x, self.y, radius + 4)
    love.graphics.setLineWidth(1)
  end

  if self.intangible then
    love.graphics.setColor(0.62, 0.86, 1.00, 0.75)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", self.x, self.y, radius + 8)
    love.graphics.setLineWidth(1)
  end

  if self.markTimer > 0 then
    local markColor = Data.characters.amado.color
    love.graphics.setColor(markColor[1], markColor[2], markColor[3], 0.95)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", self.x, self.y, radius + 5)
    love.graphics.setLineWidth(1)
    love.graphics.circle("fill", self.x, self.y - radius - 7, 3)
  end

  if self.poisonTimer > 0 then
    love.graphics.setColor(0.42, 0.92, 0.42, 0.75)
    love.graphics.circle("line", self.x, self.y, radius + 2)
  end

  if self.stunTimer > 0 then
    love.graphics.setColor(1.00, 0.85, 0.30, 0.95)
    love.graphics.circle("fill", self.x, self.y - radius - 6, 3)
    love.graphics.circle("fill", self.x - 5, self.y - radius - 3, 2)
    love.graphics.circle("fill", self.x + 5, self.y - radius - 3, 2)
  end

  if self.def.boss then
    love.graphics.setColor(0.95, 0.80, 0.30)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", self.x, self.y, radius + 6)
    love.graphics.setLineWidth(1)
    Boss.drawOverlay(self)
  end

  love.graphics.setColor(color[1] * 0.8, color[2] * 0.8, color[3] * 0.8, alpha)
  for i = 0, 2 do
    local a = self.phase + i * (math.pi * 2 / 3)
    love.graphics.line(
      self.x + math.cos(a) * radius * 0.55,
      self.y + math.sin(a) * radius * 0.55,
      self.x + math.cos(a) * radius * 0.90,
      self.y + math.sin(a) * radius * 0.90
    )
  end

  local barWidth = radius * 2
  local ratio = self.maxHp > 0 and self.hp / self.maxHp or 0
  love.graphics.setColor(0.10, 0.10, 0.10, 0.85)
  love.graphics.rectangle("fill", self.x - barWidth * 0.5, self.y - radius - 9, barWidth, 4)
  love.graphics.setColor(0.80, 0.22, 0.22)
  love.graphics.rectangle("fill", self.x - barWidth * 0.5, self.y - radius - 9, barWidth * ratio, 4)
end

return Enemy
