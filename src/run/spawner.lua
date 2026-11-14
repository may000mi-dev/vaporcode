-- spawner.lua: creación de enemigos, proyectiles, cofres, sombras y mascotas.
-- Las funciones reciben run como primer argumento y run.lua las monta
-- como métodos, así el resto del juego sigue llamando run:metodo(...).
local Data = require("src.run.data")
local Save = require("src.run.save")
local Enemy = require("src.run.enemy")
local Hazard = require("src.run.hazard")
local Projectile = require("src.run.projectile")
local Threat = require("src.run.threat")
local Compases = require("src.run.compases")
local BossMemories = require("src.run.boss_memories")
local Elites = require("src.run.elite")
local Chest = require("src.run.chest")
local Shadow = require("src.run.shadow")
local Pet = require("src.run.pet")
local FX = require("src.run.fx")

local Spawner = {}

function Spawner.isClericTank(kind)
  for _, tankKind in ipairs(Data.clericEscort.tanks) do
    if tankKind == kind then return true end
  end
  return false
end

-- Devuelve el tanque vivo más cercano, no solo el primero de la lista.
function Spawner.clericEscort(run, x, y)
  local best, bestD2 = nil, math.huge
  for _, enemy in ipairs(run.enemies or {}) do
    if not enemy.dead and Spawner.isClericTank(enemy.kind) then
      local d2 = 0
      if x and y then
        local dx = enemy.x - x
        local dy = enemy.y - y
        d2 = dx * dx + dy * dy
      end
      if d2 < bestD2 then
        best, bestD2 = enemy, d2
      end
    end
  end
  return best
end

-- Punto de aparición a menos de 120 px del tanque, sin atravesar paredes.
function Spawner.clericEscortPoint(run, tank, def)
  local cfg = Data.clericEscort
  local random = run.dungeon.rng
  for _ = 1, cfg.attempts do
    local angle = random:random() * math.pi * 2
    local distance = cfg.minDistance
      + random:random() * (cfg.maxDistance - cfg.minDistance)
    local x, y = run.dungeon:nearestWalkable(
      tank.x + math.cos(angle) * distance,
      tank.y + math.sin(angle) * distance,
      def.radius,
      cfg.maxDistance
    )
    if x then
      local dx = x - tank.x
      local dy = y - tank.y
      if dx * dx + dy * dy <= cfg.maxDistance * cfg.maxDistance then
        return x, y
      end
    end
  end

  local x, y = run.dungeon:nearestWalkable(
    tank.x + tank.radius + def.radius + 8,
    tank.y,
    def.radius,
    cfg.maxDistance
  )
  return x or tank.x, y or tank.y
end

function Spawner.createEnemy(run, kind, x, y, options)
  options = options or {}
  local def = Data.enemyTypes[kind]
  if not def then return nil end

  local hpScale = 1 + (run.depth - 1) * run.def.hpScale
  local damageScale = 1 + (run.depth - 1) * run.def.damageScale
  local hp = options.hp or math.floor(def.hp * hpScale)
  local damage = (options.damage or math.floor(def.damage * damageScale))
    * Compases.enemyDamageMultiplier(run)

  -- Un Clérigo siempre nace junto a un tanque; si no existe, se crea la
  -- escolta antes para que nunca quede solo ni únicamente con Clérigos.
  if kind == "clerigo" and not options.noEscort then
    local tank = Spawner.clericEscort(run, x, y)
    if not tank then
      local tankKind = Data.clericEscort.fallbackTank
      local tankDef = Data.enemyTypes[tankKind]
      local tx, ty = run.dungeon:nearestWalkable(x, y, tankDef.radius, 120)
      tank = Spawner.createEnemy(run, tankKind, tx or x, ty or y, {
        noElite = true,
        noEscort = true,
      })
    end
    if tank then
      x, y = Spawner.clericEscortPoint(run, tank, def)
    end
  end

  local affixes = Elites.roll(run, def, options)
  local enemy = Enemy.new(kind, x, y, hp, damage, def.xp, {
    elite = options.elite,
    affixes = affixes,
    attackCooldownMultiplier = Compases.enemyCooldownMultiplier(run),
    immuneToStun = options.immuneToStun,
  })
  run.enemies[#run.enemies + 1] = enemy
  if not run.sandbox then
    Save.discoverEnemy(kind)
  end
  return enemy
end

function Spawner.spawnEnemies(run)
  if run.sandbox then
    run.threat = nil
    run.enemyCount = 0
    return
  end

  local function rollBoss()
    if run.depth % Data.bossEvery == 0 then
      return run.def.boss or "guardian"
    elseif run.def.boss
      and run.dungeon.rng:random() < (Data.spawn.guardianChance or 0.12)
    then
      -- El antiguo Guardián de la Caldera aparece como jefe opcional en
      -- pisos que no tienen un jefe fijo.
      return "guardian"
    end
    return nil
  end

  local function spawnBoss(bossKind)
    if not bossKind then return end

    local bossDef = Data.enemyTypes[bossKind]
    local bx, by = run.dungeon:randomFloorPoint(
      run.spawnX,
      run.spawnY,
      Data.spawn.bossMinDistance,
      bossDef.radius
    )
    if not bx then
      bx, by = run.dungeon:randomFloorPoint(
        run.spawnX,
        run.spawnY,
        Data.spawn.bossFallbackDistance,
        bossDef.radius
      )
    end
    if not bx then
      bx, by = run.dungeon:randomFloorPoint(nil, nil, 0, bossDef.radius)
    end

    if bx then
      local boss = run:createEnemy(bossKind, bx, by, {
        noElite = true,
      })
      run.boss = boss
      BossMemories.attach(run, boss)
    end
  end

  if Threat.enabled(run) then
    -- El jefe ocupa su lugar antes de la horda para respetar el tope de 18.
    spawnBoss(rollBoss())
    Threat.startFloor(run)
  else
    run.threat = nil
    local count = run.def.spawnBase
      + math.floor((run.depth - 1) * Data.spawn.perDepth)
    count = math.min(count, Data.spawn.maxEnemies)

    local pool = run.def.enemies
    for _ = 1, count do
      local kind = pool[run.dungeon.rng:random(1, #pool)]
      local def = Data.enemyTypes[kind]
      local x, y = run.dungeon:randomFloorPoint(
        run.spawnX,
        run.spawnY,
        Data.spawn.minDistance,
        def.radius
      )

      if x then
        run:createEnemy(kind, x, y)
      end
    end

    -- El Modo Historia conserva el orden original: horda y luego jefe.
    spawnBoss(rollBoss())
  end

  run.enemyCount = #run.enemies
end

function Spawner.spawnHazard(run, kind, x, y, options)
  local hazard = Hazard.new(kind, x, y, options)
  run.hazards[#run.hazards + 1] = hazard
  return hazard
end

function Spawner.spawnProjectile(run, x, y, angle, damage, hostile, options)
  local speed = options and options.speed
    or (hostile and Data.projectile.hostileSpeed or Data.projectile.friendlySpeed)
  run.projectiles[#run.projectiles + 1] = Projectile.new(
    x,
    y,
    angle,
    speed,
    damage,
    not hostile,
    options
  )
end

function Spawner.spawnShadow(run, x, y)
  run.shadow = Shadow.new(x, y, Data.abilities.shadow_swap)
end

function Spawner.spawnChest(run, x, y, source)
  local lootIndex = love.math.random(1, 997)
  run.chests[#run.chests + 1] = Chest.new(x, y, lootIndex, source)
  FX.ring(x, y, 22, Data.chest.color)
end

function Spawner.addPet(run, kind, x, y)
  if run:ownsPet(kind) then return false end
  local pet = Pet.new(kind, x, y)
  if not pet then return false end
  pet:placeNear(run.player, #run.pets + 1, run.dungeon)
  run.pets[#run.pets + 1] = pet
  return true
end

return Spawner
