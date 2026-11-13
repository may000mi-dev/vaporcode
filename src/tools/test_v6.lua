-- test_v6.lua: roles de enemigos, élites, hazards y jefes.
package.path = "./?.lua;" .. package.path

local function rng(seed)
  local state = seed or 1
  return {
    random = function(_, a, b)
      state = (state * 1103515245 + 12345) % 2147483648
      local value = state / 2147483648
      if a and b then
        return math.floor(value * (b - a + 1)) + a
      elseif a then
        return math.floor(value * a) + 1
      end
      return value
    end,
  }
end

love = {
  math = {
    random = function(a, b)
      if a and b then return a end
      return 0.5
    end,
    newRandomGenerator = rng,
  },
  timer = {
    getTime = function()
      return 0
    end,
    getFPS = function()
      return 60
    end,
  },
  system = {
    getOS = function()
      return "Linux"
    end,
  },
  filesystem = {
    getInfo = function()
      return nil
    end,
    write = function()
      return true
    end,
  },
}

local function noop() end
love.graphics = {
  setColor = noop,
  rectangle = noop,
  print = noop,
  printf = noop,
  rotate = noop,
  polygon = noop,
  setFont = noop,
  circle = noop,
  line = noop,
  arc = noop,
  setLineWidth = noop,
  push = noop,
  pop = noop,
  translate = noop,
}

local Data = require("src.run.data")
local Player = require("src.run.player")
local Enemy = require("src.run.enemy")
local Hazard = require("src.run.hazard")
local Boss = require("src.run.boss")
local Save = require("src.run.save")
local Run = require("src.run.run")

assert(Data.dungeons[1].boss == "bone_patriarch", "la cripta debe tener su jefe")
assert(Data.dungeons[2].boss == "living_forge", "la forja debe tener su jefe")
assert(Data.dungeons[3].boss == "time_inquisitor", "la catedral debe tener su jefe")
assert(Data.enemyTypes.centinela.role == "turret", "el centinela debe ser torreta")
assert(Data.enemyTypes.artillero.role == "mortar", "el artillero debe usar mortero")
assert(Data.enemyTypes.maquinista.role == "summoner", "el maquinista debe invocar")
assert(Data.enemyTypes.saboteador.role == "trapper", "el saboteador debe poner minas")
assert(Data.enemyTypes.peste.role == "blight", "la peste debe ralentizar")
assert(Data.enemyTypes.clerigo.role == "healer", "el clérigo debe sanar")
assert(Data.enemyTypes.inquisidor.role == "mana_hunter", "el inquisidor debe drenar maná")

Save.load()
Run.enter("cripta", "amado", "resonance")

-- Estados del jugador.
Run.player:applySlow(2, 0.45)
assert(Run.player.slowTimer > 0 and Run.player.slowFactor == 0.45, "slow debe aplicarse")
Run.player:freeze(1)
assert(Run.player.timeLockTimer == 1, "el bloqueo de tiempo debe aplicarse")
Run.player.timeLockTimer = 0
Run.player.slowTimer = 0
Run.player.slowFactor = 1

-- Fuego: daño inmediato al pisar la zona.
Run.player.invuln = 0
Run.hazards = {}
local hpBefore = Run.hp
Run:spawnHazard("fire", Run.player.x, Run.player.y, {
  radius = 40,
  damage = 7,
  life = 2,
  interval = 0.5,
})
Run.hazards[1]:update(0.01, Run)
assert(Run.hp < hpBefore, "el fuego debe dañar al jugador")

-- Rayo: detecta el segmento, no solo el origen.
Run.player.invuln = 0
Run.hazards = {}
hpBefore = Run.hp
Run:spawnHazard("beam", Run.player.x - 100, Run.player.y, {
  angle = 0,
  length = 300,
  width = 8,
  damage = 5,
  life = 2,
  interval = 0.4,
})
Run.hazards[1]:update(0.01, Run)
assert(Run.hp < hpBefore, "el rayo debe dañar a lo largo del segmento")

-- Mina: tarda en armarse y explota al acercarse.
Run.player.invuln = 0
Run.hazards = {}
hpBefore = Run.hp
Run:spawnHazard("mine", Run.player.x, Run.player.y, {
  delay = Data.hazards.mineArm,
  life = 10,
  radius = Data.hazards.mineExplosionRadius,
  damage = Data.hazards.mineDamage,
})
Run.hazards[1]:update(Data.hazards.mineArm + 0.2, Run)
assert(#Run.hazards == 1 and not Run.hazards[1].dead, "la mina no debe explotar antes de armarse")
Run.hazards[1]:update(0.01, Run)
assert(Run.hazards[1].dead and Run.hp < hpBefore, "la mina debe explotar al pisarla")

-- Torreta: dispara un proyectil pesado.
Run.projectiles = {}
local turret = Enemy.new("centinela", 0, 0, 78, 16, 16)
turret.shootTimer = 0
turret:updateTurret(0.01, Run, Run.player, 200)
assert(#Run.projectiles == 1, "el centinela debe disparar")
assert(Run.projectiles[1].radius == 8, "el proyectil del centinela debe ser pesado")

-- Mortero: deja fuego telegrafiado donde está el jugador.
Run.hazards = {}
local mortar = Enemy.new("artillero", 0, 0, 46, 12, 12)
mortar.shootTimer = 0
mortar:updateMortar(0.01, Run, Run.player, 210, 1, 0)
assert(#Run.hazards == 1 and Run.hazards[1].kind == "fire", "el mortero debe crear fuego")
assert(Run.hazards[1].delay > 0, "el mortero debe telegrafiar antes de dañar")

-- Invocador: añade autómatas rotos sin élite.
Run.enemies = { mortar }
local summoner = Enemy.new("maquinista", 0, 0, 54, 10, 15)
Run.enemies[2] = summoner
summoner.shootTimer = 0
summoner:updateSummoner(0.01, Run, 300, 0, 0)
assert(#Run.enemies == 3, "el maquinista debe invocar")
assert(Run.enemies[3].kind == "broken_automaton", "debe invocar autómatas rotos")
assert(not Run.enemies[3].elite, "los invocados no deben ser élite")

-- Sanador: recupera vida de un aliado cercano.
Run.enemies = {}
local healer = Enemy.new("clerigo", 0, 0, 55, 8, 18)
local ally = Enemy.new("automaton", 20, 0, 32, 10, 7)
ally.hp = 10
Run.enemies = { healer, ally }
healer.shootTimer = 0
healer:updateHealer(0.01, Run, 210, 1, 0)
assert(ally.hp > 10, "el clérigo debe sanar a sus aliados")

-- Trampero: coloca una mina.
Run.hazards = {}
local trapper = Enemy.new("saboteador", 0, 0, 38, 10, 14)
trapper.shootTimer = 0
trapper:updateTrapper(0.01, Run, Run.player, 1, 0)
assert(#Run.hazards == 1 and Run.hazards[1].kind == "mine", "el saboteador debe poner minas")

-- Peste: proyectil con ralentización.
Run.projectiles = {}
local blight = Enemy.new("peste", 0, 0, 60, 11, 15)
blight.shootTimer = 0
blight:updateBlight(0.01, Run, Run.player, 150, 1, 0)
assert(#Run.projectiles == 1, "la peste debe disparar lodo")
assert(Run.projectiles[1].effect == "slow", "el lodo debe ralentizar")

-- Inquisidor: proyectil que drena maná y bloquea habilidades.
Run.projectiles = {}
local hunter = Enemy.new("inquisidor", 0, 0, 85, 14, 20)
hunter.shootTimer = 0
hunter:updateManaHunter(0.01, Run, Run.player, 300, 1, 0)
assert(#Run.projectiles == 1, "el inquisidor debe disparar")
assert(Run.projectiles[1].effect == "mana_drain", "el reloj debe drenar maná")

Run.mana = Run.manaMax
Run.abilityLockTimer = 0
Run:applyPlayerEffect("mana_drain", { manaDrain = 0.12, lock = 2 })
assert(Run.mana < Run.manaMax, "el drenaje debe bajar el maná")
assert(Run.abilityLockTimer == 2, "el drenaje debe bloquear habilidades")

-- Élites: escudo, intangibilidad y explosión al morir.
local armored = Enemy.new("automaton", 0, 0, 32, 10, 7, { elite = "armored" })
local absorbed = armored:takeDamage(30, {})
assert(armored.shield == 20 and armored.hp == 32, "el blindado debe absorber con escudo")
assert(absorbed == 30, "el escudo debe reportar el daño absorbido")

local spectral = Enemy.new("automaton", 0, 0, 32, 10, 7, { elite = "spectral" })
spectral.intangible = true
assert(spectral:takeDamage(99, {}) == 0, "el espectral no debe recibir daño intangible")
assert(not spectral:canBeAffected(), "el espectral no debe poder marcarse")

-- Memoria: si una pared bloquea, el enemigo bordea y luego abandona la búsqueda.
local blockedRun = {
  dungeon = {
    moveCircle = function(_, x, y)
      return x, y
    end,
  },
}
local searcher = Enemy.new("automaton", 0, 0, 32, 10, 7)
searcher.lastSeenX = 300
searcher.lastSeenY = 0
searcher:updateSearch(0.1, blockedRun)
searcher:updateSearch(0.1, blockedRun)
assert(searcher.searchTimer > 0, "el barrido debe activarse al quedar bloqueado")
for _ = 1, 30 do
  searcher:updateSearch(0.1, blockedRun)
end
assert(searcher.lastSeenX == nil, "debe abandonar la memoria si no puede rodear")

Run.enemies = {}
Run.player.x, Run.player.y = Run.spawnX, Run.spawnY
Run.player.invuln = 0
local volatile = Enemy.new("automaton", Run.player.x, Run.player.y, 32, 10, 7, { elite = "volatile" })
Run.enemies = { volatile }
hpBefore = Run.hp
volatile:takeDamage(999, Run, "test")
assert(volatile.dead, "el volátil debe morir")
assert(Run.hp < hpBefore, "el volátil debe explotar al morir")

-- Jefe Patriarca: fases invulnerables con rayos.
Run.hazards = {}
Run.enemies = {}
local patriarch = Run:createEnemy("bone_patriarch", 100, 100, { noElite = true })
patriarch.hp = patriarch.maxHp * 0.6
patriarch:update(0.01, Run)
assert(patriarch.invulnTimer > 0, "el patriarca debe volverse invulnerable en fase")
assert(#Run.hazards == patriarch.def.beamCount, "la fase debe crear todos los rayos")
assert(patriarch:takeDamage(50, Run) == 0, "el patriarca no debe recibir daño en fase")

-- Jefe Forja: zonas telegrafiadas e invocaciones.
Run.hazards = {}
Run.enemies = {}
local forge = Run:createEnemy("living_forge", 100, 100, { noElite = true })
forge.zoneTimer = 0
forge:update(0.01, Run)
assert(#Run.hazards == forge.def.zoneCount, "la forja debe crear zonas de fuego")
assert(Run.hazards[1].kind == "zone" and Run.hazards[1].delay > 0, "las zonas deben telegrafiarse")

-- Jefe Inquisidor del Tiempo: aura, inmunidad a aturdimiento y reubicación.
Run.hazards = {}
Run.enemies = {}
local chrono = Run:createEnemy("time_inquisitor", 100, 100, { noElite = true })
assert(chrono.radius == Data.player.radius, "el Inquisidor debe medir lo mismo que el jugador")
assert(Data.enemyTypes.time_inquisitor.hp > 500, "el Inquisidor debe tener más vida")
chrono:applyStun(3)
assert(chrono.stunTimer == 0, "los jefes no deben quedar aturdidos")

Run.player.shield = 0
Run.player.shieldTimer = 0
Run.player.timeLockTimer = 0
Run.player.invuln = 0
Run.hp = Run.stats.maxHp
chrono.x, chrono.y = Run.spawnX, Run.spawnY
Run.player.x, Run.player.y = Run.spawnX, Run.spawnY
chrono.auraTimer = 0
local hpAura = Run.hp
Boss.update(chrono, 0.01, Run, {
  target = Run.player,
  canSee = true,
  distance = 0,
  dx = 0,
  dy = 0,
  nx = 0,
  ny = 0,
})
assert(Run.hp < hpAura, "el aura del Inquisidor debe dañar al jugador cercano")

Run.hazards = {}
Run.player.x = chrono.x + 100
Run.player.y = chrono.y
Run.player.timeLockTimer = 0
Run.player.invuln = 0
chrono.coneTimer = 0
Boss.update(chrono, 0.01, Run, {
  target = Run.player,
  canSee = true,
  distance = 100,
  dx = 100,
  dy = 0,
  nx = 1,
  ny = 0,
})
assert(Run.player.timeLockTimer > 0, "el cono debe congelar al jugador")
assert(#Run.hazards >= 1 and Run.hazards[#Run.hazards].kind == "cone", "el cono debe dibujarse")

-- Si queda bloqueado, el Inquisidor se reubica cerca del jugador.
local originalDungeon = Run.dungeon
Run.dungeon = {
  moveCircle = function(_, x, y)
    return x, y
  end,
  lineOfSight = function()
    return true
  end,
  circleCollides = function()
    return false
  end,
}
chrono.x, chrono.y = Run.spawnX, Run.spawnY
Run.player.x, Run.player.y = chrono.x + 200, chrono.y
chrono.lastSeenX, chrono.lastSeenY = Run.player.x, Run.player.y
chrono.stuckTimer = chrono.def.blinkStuckTime
chrono.lostTimer = 0
local stuckX, stuckY = chrono.x, chrono.y
Boss.update(chrono, 0.01, Run, {
  target = Run.player,
  canSee = true,
  distance = 200,
  dx = 200,
  dy = 0,
  nx = 1,
  ny = 0,
})
assert(
  chrono.x ~= stuckX or chrono.y ~= stuckY,
  "el Inquisidor debe reubicarse cuando queda bloqueado"
)
Run.dungeon = originalDungeon


-- Jefe Órgano: zonas a distancia, brazo a media distancia y clérigos si va perdiendo.
Run.hazards = {}
Run.enemies = {}
Run.projectiles = {}
Run.player.pullTimer = 0
Run.player.shield = 0
Run.player.shieldTimer = 0
Run.player.timeLockTimer = 0
Run.player.invuln = 0
Run.hp = Run.stats.maxHp
local organ = Run:createEnemy("time_organ", Run.spawnX, Run.spawnY, { noElite = true })
Run.enemies = { organ }
organ.zoneTimer = 0
organ.armTimer = 0
organ.summonTimer = 99
organ.healerTimer = 99
Run.player.x, Run.player.y = organ.x + 500, organ.y
Boss.update(organ, 0.01, Run, {
  target = Run.player,
  canSee = true,
  distance = 500,
  dx = 500,
  dy = 0,
  nx = 1,
  ny = 0,
})
assert(#Run.hazards == organ.def.zoneCount, "el Órgano debe crear zonas a distancia")
assert(Run.hazards[1].kind == "zone" and Run.hazards[1].delay > 0, "las zonas deben telegrafiarse")
assert(organ.armState == nil, "el brazo no debe lanzarse a distancia lejana")

-- A media distancia el brazo atraviesa paredes y arrastra al jugador.
Run.hazards = {}
organ.x, organ.y = Run.spawnX, Run.spawnY
Run.player.x, Run.player.y = organ.x + 250, organ.y
organ.invulnTimer = 0
organ.bossPhase = 3
organ.zoneTimer = 99
organ.summonTimer = 99
organ.healerTimer = 99
organ.armTimer = 0
organ.armState = nil
organ.lastSeenX, organ.lastSeenY = Run.player.x, Run.player.y
local armCtx = {
  target = Run.player,
  canSee = false,
  distance = 250,
  dx = 250,
  dy = 0,
  nx = 1,
  ny = 0,
}
Boss.update(organ, 0.01, Run, armCtx)
assert(organ.armState == "windup", "el brazo debe iniciar aunque una pared corte la visión")
Boss.update(organ, organ.def.armWindup + 0.01, Run, armCtx)
assert(organ.armState == "pull", "el brazo debe enganchar al jugador")
assert(Run.player.pullTimer > 0, "el jugador debe quedar arrastrado")
local pullX = Run.player.pullX
assert(pullX and math.abs(pullX - organ.x) <= organ.def.armCloseDistance + 1, "el destino debe quedar cerca del jefe")

local beforePullX = Run.player.x
local realDungeon = Run.dungeon
Run.dungeon = {
  moveCircle = function()
    error("el arrastre no debe usar colisiones")
  end,
}
Run.player:update(0.05, 1, 0, Run)
Run.dungeon = realDungeon
assert(Run.player.x ~= beforePullX, "el arrastre debe mover al jugador sin colisionar")
Run.player.pullTimer = 0
Run.player.pullX, Run.player.pullY = nil, nil
Run.player.pullStartX, Run.player.pullStartY = nil, nil

-- Cerca se conservan los rayos y no se lanzan zonas ni el brazo.
Run.hazards = {}
organ.invulnTimer = 0
organ.armTimer = 0
organ.armState = nil
organ.armAttachedPlayer = nil
organ.armPullTimer = 0
organ.zoneTimer = 0
organ.summonTimer = 99
organ.healerTimer = 99
Run.player.x, Run.player.y = organ.x + 100, organ.y
Boss.update(organ, 0.01, Run, {
  target = Run.player,
  canSee = true,
  distance = 100,
  dx = 100,
  dy = 0,
  nx = 1,
  ny = 0,
})
assert(#Run.hazards == 0 and organ.armState == nil, "de cerca no debe usar zonas ni brazo")

-- Todas las invocaciones regulares, sin jefes de pisos anteriores.
Run.enemies = { organ }
organ.summonTimer = 0
organ.armTimer = 99
organ.healerTimer = 99
Boss.update(organ, 0.01, Run, {
  target = Run.player,
  canSee = true,
  distance = 100,
  dx = 100,
  dy = 0,
  nx = 1,
  ny = 0,
})
assert(#Run.enemies == 2, "el Órgano debe invocar aliados")
assert(Run.enemies[2].summonedByOrgan, "la invocación debe marcarse como del jefe")
local poolSet = {}
for _, kind in ipairs(organ.summonPool) do
  local def = Data.enemyTypes[kind]
  assert(def and not def.boss, "la invocación no puede ser un jefe")
  poolSet[kind] = true
end
assert(poolSet.automaton and poolSet.inquisidor, "deben estar todos los enemigos regulares")
assert(not poolSet.bone_patriarch and not poolSet.time_inquisitor, "no deben aparecer jefes anteriores")

-- Si el jugador va ganando, invoca clérigos que curan al jefe.
Run.enemies = { organ }
organ.hp = math.floor(organ.maxHp * 0.5)
Run.hp = Run.stats.maxHp
organ.bossPhase = 3
organ.invulnTimer = 0
organ.healerTimer = 0
organ.summonTimer = 99
organ.armTimer = 99
Boss.update(organ, 0.01, Run, {
  target = Run.player,
  canSee = true,
  distance = 100,
  dx = 100,
  dy = 0,
  nx = 1,
  ny = 0,
})
assert(#Run.enemies == 2 and Run.enemies[2].kind == "clerigo", "el Órgano debe invocar clérigos")
local organHealer = Run.enemies[2]
organHealer.x, organHealer.y = organ.x + 20, organ.y
organHealer.shootTimer = 0
local organHpBefore = organ.hp
organHealer:updateHealer(0.01, Run, 20, 1, 0)
assert(organ.hp > organHpBefore, "los clérigos deben curar al Órgano")


print("OK V6: roles, élites, hazards y jefes")
