-- test_compases_elites.lua: compases, afijos de élite y escolta de Clérigos.
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
    getTime = function() return 0 end,
    getFPS = function() return 60 end,
  },
  filesystem = {
    getInfo = function() return nil end,
    write = function() return true end,
  },
  graphics = {
    setColor = function() end,
    circle = function() end,
    arc = function() end,
    line = function() end,
    setLineWidth = function() end,
  },
}

local Data = require("src.run.data")
local Compases = require("src.run.compases")
local Elites = require("src.run.elite")
local Enemy = require("src.run.enemy")
local Threat = require("src.run.threat")
local Spawner = require("src.run.spawner")
local Combat = require("src.run.combat")

local function valueRng(value)
  return {
    random = function(_, a, b)
      if a and b then return a end
      if a then return 1 end
      return value
    end,
  }
end

local function rooms(count)
  local list = {}
  for index = 1, count do list[index] = { index = index } end
  return list
end

local function fakeRun(depth, pool, seed)
  local run = {
    mode = "free",
    sandbox = false,
    depth = depth,
    seed = seed or 1,
    def = { enemies = pool or {}, hpScale = 0, damageScale = 0 },
    player = { x = 0, y = 0, radius = 10 },
    enemies = {},
    enemyCount = 0,
    spawnX = 0,
    spawnY = 0,
    dungeon = {
      rooms = rooms(7),
      rng = rng(seed or 1),
    },
  }
  run.dungeon.randomFloorPoint = function()
    return 100 + #run.enemies * 20, 100
  end
  run.dungeon.nearestWalkable = function(_, x, y)
    return x, y
  end
  run.dungeon.moveCircle = function(_, x, y)
    return x, y
  end
  run.createdOptions = {}
  run.createEnemy = function(self, kind, x, y, options)
    local enemy = { kind = kind, x = x, y = y, dead = false }
    self.createdOptions[#self.createdOptions + 1] = options
    self.enemies[#self.enemies + 1] = enemy
    return enemy
  end
  return run
end

-- Determinismo y ventana activa sin repetir efectos.
for seed = 1, 12 do
  local first = Compases.sequence(seed, 20)
  local second = Compases.sequence(seed, 20)
  assert(#first == 20, "la secuencia debe tener 20 etapas")
  for index = 1, 20 do
    assert(first[index] == second[index], "la secuencia debe ser determinista")
  end
  for index = 3, 20 do
    local window = { first[index - 2], first[index - 1], first[index] }
    assert(window[1] ~= window[2] and window[1] ~= window[3] and window[2] ~= window[3],
      "la ventana de tres compases no debe repetir efectos")
  end
end

local run = fakeRun(3, Data.dungeons[3].enemies, 7)
local state = Compases.refresh(run)
assert(state and state.stage == 1, "el piso 3 debe activar el primer compás")
assert(#state.active == 1, "el primer compás solo debe tener un efecto")
assert(state.label:find("Compás I", 1, true), "la etiqueta debe usar números romanos")

run.depth = 9
state = Compases.refresh(run)
assert(state.stage == 3 and #state.active == 3, "el piso 9 debe mostrar tres compases")
assert(state.label:find("Compás III", 1, true), "la etiqueta debe indicar el tercer compás")

run.mode = "story"
assert(Compases.refresh(run) == nil, "Historia no debe recibir compases")
run.mode = "free"
run.sandbox = true
assert(Compases.refresh(run) == nil, "la sala de pruebas no debe recibir compases")
run.sandbox = false

-- Multiplicadores y Eco.
run.compases = { active = { "legion", "pressure", "famine" }, threatMultiplier = 1.25,
  enemyDamageMultiplier = 1.15, playerHealingMultiplier = 0.60 }
assert(Compases.threatMultiplier(run) == 1.25, "Legión debe subir la amenaza")
assert(Compases.enemyDamageMultiplier(run) == 1.15, "Presión debe subir el daño")
assert(Compases.playerHealingMultiplier(run) == 0.60, "Hambruna debe bajar la curación")
assert(Compases.echoDamage({ depth = 7 }) == 22, "el Eco debe escalar con el piso")

local echoRun = fakeRun(1, {}, 3)
echoRun.compases = { active = { "echo" }, echo = true, echoTimer = 0.01 }
local hazard
echoRun.spawnHazard = function(_, kind, x, y, options)
  hazard = { kind = kind, x = x, y = y, options = options }
end
Compases.update(echoRun, 0.02)
assert(hazard and hazard.kind == "echo", "Eco debe crear un hazard de eco")
assert(hazard.options.delay == 1.5 and hazard.options.radius == 64,
  "el eco debe telegrafiarse antes de detonar")

-- Curvas de élite.
assert(math.abs(Elites.chanceAt(1) - 0.10) < 0.001, "piso 1 debe tener 10%")
assert(math.abs(Elites.chanceAt(5) - 0.20) < 0.001, "piso 5 debe tener 20%")
assert(math.abs(Elites.chanceAt(10) - 0.35) < 0.001, "piso 10 debe tener 35%")
assert(Elites.twoAffixChance(6) == 0, "antes del piso 7 solo hay un afijo")
assert(Elites.twoAffixChance(7) == 0.30, "del piso 7 al 12 hay 30% de dos afijos")
assert(Elites.twoAffixChance(13) == 0.60, "desde el piso 13 hay 60% de dos afijos")

local eliteRun = fakeRun(10, Data.dungeons[3].enemies, 99)
eliteRun.dungeon.rng = valueRng(0)
local affixes = Elites.roll(eliteRun, Data.enemyTypes.automaton, {})
assert(#affixes == 2 and affixes[1] ~= affixes[2], "el piso 10 puede dar dos afijos únicos")
local normalRun = fakeRun(1, Data.dungeons[3].enemies, 99)
normalRun.dungeon.rng = valueRng(0)
assert(#Elites.roll(normalRun, Data.enemyTypes.automaton, {}) == 1,
  "el piso 1 solo debe dar un afijo")

-- Afijos en combate.
local vampire = Enemy.new("automaton", 0, 0, 100, 10, 7, { affixes = { "vampiric" } })
vampire.hp = 50
vampire:onDamageDealt(20, {})
assert(vampire.hp == 54, "Vampírico debe curar 20% del daño infligido")

local guardian = Enemy.new("automaton", 0, 0, 50, 10, 7, { affixes = { "guardian" } })
local target = Enemy.new("automaton", 50, 0, 100, 10, 7)
local auraRun = { enemies = { guardian, target } }
target:takeDamage(100, auraRun, "test")
assert(target.hp == 20, "Guardián debe reducir 20% el daño cercano")

local mirror = Enemy.new("automaton", 0, 0, 100, 10, 7, { affixes = { "mirror" } })
local reflected = 0
local mirrorRun = {
  player = {
    x = 30,
    y = 0,
    takeDamage = function(_, amount)
      reflected = reflected + amount
      return true
    end,
  },
}
mirror:takeDamage(50, mirrorRun, "basic")
assert(math.abs(reflected - 15) < 0.001, "Espejo debe reflejar 30% del daño frontal")

local chronos = Enemy.new("automaton", 0, 0, 100, 10, 7, { affixes = { "chronos" } })
chronos.chronosTimer = 0.01
local slowed = false
local chronoRun = {
  player = {
    radius = 10,
    applySlow = function(_, duration, factor)
      slowed = duration == Data.elite.chronosDuration
        and math.abs(factor - 0.70) < 0.001
    end,
  },
}
chronoRun.player.x = 10
chronoRun.player.y = 0
chronos:updateAffixTimers(0.02, chronoRun)
assert(slowed, "Cronos debe ralentizar 30% dentro de 150 px")

local hunter = Enemy.new("sabueso", 0, 0, 26, 9, 8, {
  affixes = { "vampiric" },
  immuneToStun = true,
})
assert(hunter:applyStun(3) == false, "el cazador de Cacería no debe aturdirse")

local slowBoss = Enemy.new("time_organ", 0, 0, 500, 10, 50, {
  attackCooldownMultiplier = 0.83,
})
local firstSummon = (slowBoss.def.firstSummonDelay or 2) * 0.83
assert(math.abs(slowBoss.summonTimer - firstSummon) < 0.001,
  "Sobrecarga debe acelerar también el primer ataque del jefe")
assert(math.abs(slowBoss:cooldown(10) - 8.3) < 0.001,
  "el intervalo enemigo debe multiplicarse por 0.83")

-- Coro aumenta la curación enemiga.
local healRun = fakeRun(1, {}, 2)
healRun.compases = { active = { "choir" }, enemyHealingMultiplier = 1.25 }
local wounded = { x = 0, y = 0, hp = 50, maxHp = 100, dead = false }
healRun.enemies = { wounded }
Combat.healEnemiesAround(healRun, 0, 0, 100, 0.15)
assert(math.abs(wounded.hp - 68.75) < 0.001, "Coro debe curar 25% más")

-- Garantías de compases y escolta.
local guaranteeRun = fakeRun(10, Data.dungeons[2].enemies, 44)
guaranteeRun.compases = { active = { "hunt", "seal", "choir" }, threatMultiplier = 1 }
local units = { "sabueso", "sabueso" }
local spent = Threat.applyGuarantees(guaranteeRun, units, 40, 2)
assert(spent > 2, "las garantías deben sumar su costo")
for _, kind in ipairs({ "sabueso", "inquisidor", "clerigo" }) do
  local found = false
  for _, own in ipairs(units) do
    if own == kind then found = true end
  end
  assert(found, "la composición debe incluir " .. kind)
end

local escortWaves = {
  { units = { "clerigo", "espectro" }, cost = 6, total = 2 },
  { units = { "clerigo", "clerigo" }, cost = 8, total = 2 },
}
Threat.enforceEscorts(guaranteeRun, escortWaves)
for _, wave in ipairs(escortWaves) do
  local hasCleric, hasTank, tankBeforeCleric = false, false, false
  for _, kind in ipairs(wave.units) do
    if kind == "clerigo" then hasCleric = true end
    if Spawner.isClericTank(kind) then
      hasTank = true
      if not hasCleric then tankBeforeCleric = true end
    end
  end
  assert(not hasCleric or hasTank, "toda oleada con Clérigo debe incluir tanque")
  assert(not hasCleric or tankBeforeCleric, "el tanque debe salir antes del Clérigo")
end

-- startFloor aplica garantías y escolta aunque el pool no tenga tanques.
local floorRun = fakeRun(10, Data.dungeons[2].enemies, 321)
floorRun.compases = { active = { "choir", "hunt", "seal" }, threatMultiplier = 1 }
local floorState = Threat.startFloor(floorRun)
assert(floorState.hunterAffix == "vampiric", "Cacería debe marcar al cazador")
for _, wave in ipairs(floorState.waves) do
  local hasCleric, hasTank = false, false
  for _, kind in ipairs(wave.units) do
    if kind == "clerigo" then hasCleric = true end
    if Spawner.isClericTank(kind) then hasTank = true end
  end
  assert(not hasCleric or hasTank, "la oleada generada debe traer escolta")
end

-- El primer Sabueso de Cacería se crea como élite vampírico inmune.
local hunterSpawnRun = fakeRun(3, Data.dungeons[1].enemies, 8)
hunterSpawnRun.threat = {
  enabled = true,
  complete = false,
  activeWave = 1,
  queue = { "sabueso" },
  queueIndex = 1,
  spawned = 0,
  hunterAffix = "vampiric",
  hunterSpawned = false,
}
Threat.spawnFromQueue(hunterSpawnRun)
local spawnedOptions = hunterSpawnRun.createdOptions[1]
assert(spawnedOptions
  and spawnedOptions.affix == "vampiric"
  and spawnedOptions.forceElite
  and spawnedOptions.immuneToStun,
  "Cacería debe forzar un Sabueso élite inmune")

-- createEnemy crea la escolta si no hay ningún tanque vivo.
local spawnRun = fakeRun(1, {}, 5)
spawnRun.sandbox = true
spawnRun.dungeon.rng = valueRng(0.9)
local cleric = Spawner.createEnemy(spawnRun, "clerigo", 100, 100)
assert(cleric and #spawnRun.enemies == 2, "el Clérigo debe traer un tanque de escolta")
local tank = spawnRun.enemies[1]
assert(Spawner.isClericTank(tank.kind), "la escolta debe ser un tanque")
local dx = cleric.x - tank.x
local dy = cleric.y - tank.y
assert(dx * dx + dy * dy <= 120 * 120, "el Clérigo debe nacer a menos de 120 px")

print("OK compases, élites y escolta de Clérigos")
