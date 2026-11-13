-- spawner.lua: creación de enemigos, proyectiles, cofres, sombras y mascotas.
-- Las funciones reciben run como primer argumento y run.lua las monta
-- como métodos, así el resto del juego sigue llamando run:metodo(...).
local Data = require("src.run.data")
local Save = require("src.run.save")
local Enemy = require("src.run.enemy")
local Hazard = require("src.run.hazard")
local Projectile = require("src.run.projectile")
local Chest = require("src.run.chest")
local Shadow = require("src.run.shadow")
local Pet = require("src.run.pet")
local FX = require("src.run.fx")

local Spawner = {}

function Spawner.createEnemy(run, kind, x, y, options)
  options = options or {}
  local def = Data.enemyTypes[kind]
  if not def then return nil end

  local hpScale = 1 + (run.depth - 1) * run.def.hpScale
  local damageScale = 1 + (run.depth - 1) * run.def.damageScale
  local hp = options.hp or math.floor(def.hp * hpScale)
  local damage = options.damage or math.floor(def.damage * damageScale)

  local elite = options.elite
  if not elite and not options.noElite and not def.boss and not def.noElite then
    if run.dungeon.rng:random() < Data.elite.chance then
      local roll = run.dungeon.rng:random(1, 3)
      elite = roll == 1 and "volatile" or (roll == 2 and "armored" or "spectral")
    end
  end

  local enemy = Enemy.new(kind, x, y, hp, damage, def.xp, { elite = elite })
  run.enemies[#run.enemies + 1] = enemy
  if not run.sandbox then
    Save.discoverEnemy(kind)
  end
  return enemy
end

function Spawner.spawnEnemies(run)
  if run.sandbox then
    run.enemyCount = 0
    return
  end

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

  if run.depth % Data.bossEvery == 0 then
    local bossDef = Data.enemyTypes[run.def.boss or "guardian"]
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
      local boss = run:createEnemy(bossDef.id or (run.def.boss or "guardian"), bx, by, {
        noElite = true,
      })
      run.boss = boss
    end
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
