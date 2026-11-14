-- test_boss_memories.lua: memorias de jefe, Guardia y Sobrecarga del Infinito.
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
local Elites = require("src.run.elite")
local Enemy = require("src.run.enemy")
local BossMemories = require("src.run.boss_memories")

local function fixedRng(value)
  return {
    random = function(_, a, b)
      if a and b then return a end
      return value
    end,
  }
end

local function fakeRun(mode, depth, active, pool)
  local run = {
    mode = mode or "free",
    sandbox = false,
    depth = depth or 3,
    seed = 7,
    def = { enemies = pool or { "clerigo", "automaton", "sabueso" } },
    player = { x = 10, y = 10, radius = 10 },
    enemies = {},
    mana = 50,
    manaMax = 100,
    manaIdleTimer = 0,
    cooldowns = { a1 = 0, a2 = 0, shield = 0, turbo = 0 },
    abilitySlot1 = "resonance",
    abilitySlot2 = "arrow",
    abilitySlot3 = "shield",
    abilitySlot4 = "turbo",
    created = {},
    hazards = {},
    compases = { active = active or {} },
    dungeon = {
      rng = fixedRng(0.5),
    },
  }
  run.dungeon.moveCircle = function(_, x, y)
    return x, y
  end
  run.dungeon.nearestWalkable = function(_, x, y)
    return x, y
  end
  run.createEnemy = function(self, kind, x, y, options)
    options = options or {}
    local def = Data.enemyTypes[kind]
    local affixes = Elites.roll(self, def, options)
    local enemy = Enemy.new(kind, x, y, nil, nil, nil, { affixes = affixes })
    self.created[#self.created + 1] = { kind = kind, options = options, enemy = enemy }
    self.enemies[#self.enemies + 1] = enemy
    return enemy
  end
  run.notify = function(self, text)
    self.lastNotice = text
  end
  run.spawnHazard = function(self, kind, x, y, options)
    self.hazards[#self.hazards + 1] = {
      kind = kind,
      x = x,
      y = y,
      options = options,
    }
  end
  run.abilityIdForSlot = function(self, slot)
    if slot == 1 then return self.abilitySlot1 end
    if slot == 2 then return self.abilitySlot2 end
    if slot == 4 then return self.abilitySlot4 end
    return self.abilitySlot3
  end
  run.cooldownKeyForSlot = function(_, slot)
    if slot == 1 then return "a1" end
    if slot == 2 then return "a2" end
    if slot == 3 then return "shield" end
    return "turbo"
  end
  run.gameOver = function(self, reason)
    self.over = true
    self.overReason = reason
  end
  return run
end

local function newBoss(kind)
  return Enemy.new(kind or "bone_patriarch", 0, 0, nil, nil, nil, { noElite = true })
end

-- Selección determinista a partir de los compases activos.
local run = fakeRun("free", 6, { "pressure", "echo" })
local boss = newBoss()
run.enemies[1] = boss
BossMemories.attach(run, boss)
assert(#boss.memories == 2, "el jefe debe heredar dos memorias")
assert(boss.memories[1] == "rage" and boss.memories[2] == "echo",
  "Presión y Eco deben convertirse en Furia y Eco")
assert(boss.memoryLabel == "Furia · Eco", "la etiqueta debe listar las memorias")
assert(boss.memoryEnrageTimer == Data.bossMemories.enrageSeconds,
  "todo jefe del Infinito debe tener límite de Sobrecarga")
assert(run.lastNotice and run.lastNotice:find("Furia", 1, true),
  "el inicio del combate debe avisar las memorias")

local duplicateRun = fakeRun("free", 9, { "legion", "hunt", "seal" })
local duplicateBoss = newBoss()
duplicateRun.enemies[1] = duplicateBoss
BossMemories.attach(duplicateRun, duplicateBoss)
assert(#duplicateBoss.memories == 2, "las memorias repetidas deben deduplicarse")
assert(duplicateBoss.memories[1] == "guard" and duplicateBoss.memories[2] == "fortified",
  "Guardia debe aparecer una sola vez")

-- Historia y sala de pruebas quedan intactas.
local story = fakeRun("story", 6, { "pressure", "echo" })
local storyBoss = newBoss()
assert(BossMemories.attach(story, storyBoss) == nil, "Historia no debe recibir memorias")
assert(storyBoss.memoryEnrageTimer == nil, "Historia no debe recibir Sobrecarga")

local sandbox = fakeRun("free", 6, { "pressure" })
sandbox.sandbox = true
local sandboxBoss = newBoss()
assert(BossMemories.attach(sandbox, sandboxBoss) == nil, "la sala de pruebas queda exenta")

-- Los pisos sin jefe solo llevan el límite, no memorias.
local normal = fakeRun("free", 5, { "pressure", "echo" })
local normalBoss = newBoss()
normal.enemies[1] = normalBoss
BossMemories.attach(normal, normalBoss)
assert(normalBoss.memoryEnrageTimer == Data.bossMemories.enrageSeconds,
  "los jefes opcionales también deben tener límite")
assert(normalBoss.memories == nil, "las memorias solo aparecen en pisos de jefe")

-- Furia acelera y multiplica el daño una sola vez.
local rageRun = fakeRun("free", 3, { "pressure" })
local rageBoss = newBoss()
rageRun.enemies[1] = rageBoss
BossMemories.attach(rageRun, rageBoss)
local baseSpeed, baseDamage = rageBoss.speed, rageBoss.damage
BossMemories.update(rageBoss, Data.bossMemories.types.rage.delay - 0.1, rageRun)
assert(not rageBoss.memoryRageActive, "Furia debe esperar su retraso")
BossMemories.update(rageBoss, 0.2, rageRun)
assert(rageBoss.memoryRageActive, "Furia debe activarse al cumplir el retraso")
assert(math.abs(rageBoss.speed - baseSpeed * 1.25) < 0.001, "Furia debe subir la velocidad")
assert(math.abs(rageBoss.damage - baseDamage * 1.25) < 0.001, "Furia debe subir el daño")
assert(math.abs(BossMemories.damageMultiplier(rageBoss) - 1.25) < 0.001,
  "los hazards del jefe deben usar el daño de Furia")
BossMemories.update(rageBoss, 1, rageRun)
assert(math.abs(rageBoss.speed - baseSpeed * 1.25) < 0.001,
  "Furia no debe multiplicarse dos veces")

-- Eco de memoria: hazard telegrafiado con fuente enemiga.
local echoRun = fakeRun("free", 3, { "echo" })
local echoBoss = newBoss()
echoRun.enemies[1] = echoBoss
BossMemories.attach(echoRun, echoBoss)
BossMemories.update(echoBoss, Data.bossMemories.types.echo.interval + 0.1, echoRun)
local echo = echoRun.hazards[1]
assert(echo and echo.kind == "echo", "Eco de memoria debe crear un hazard")
assert(echo.options.delay == Data.bossMemories.types.echo.telegraph
  and echo.options.radius == Data.bossMemories.types.echo.radius,
  "el eco debe telegrafiarse antes de detonar")
assert(echo.options.sourceEnemy == echoBoss, "el eco debe conservar la fuente enemiga")

-- Sifón: maná, una recarga y enfriamiento entre impactos.
local siphonRun = fakeRun("free", 3, { "overload" })
local siphonBoss = newBoss()
siphonRun.enemies[1] = siphonBoss
BossMemories.attach(siphonRun, siphonBoss)
siphonBoss:onPlayerDamaged(20, siphonRun)
assert(siphonRun.mana == 42, "Sifón debe drenar 8 de maná")
assert(siphonRun.cooldowns.a1 == 1, "Sifón debe añadir 1 s a una recarga activa")
siphonBoss:onPlayerDamaged(20, siphonRun)
assert(siphonRun.mana == 42, "Sifón no debe drenar dos veces en el mismo instante")
BossMemories.update(siphonBoss, Data.bossMemories.types.siphon.hitCooldown + 0.05, siphonRun)
siphonBoss:onPlayerDamaged(20, siphonRun)
assert(siphonRun.mana == 34, "Sifón debe volver a drenar tras su enfriamiento")

-- Regeneración: solo cura después de 3 s sin daño y se reinicia al recibir daño.
local regenRun = fakeRun("free", 3, { "famine" })
local regenBoss = newBoss()
regenRun.enemies[1] = regenBoss
BossMemories.attach(regenRun, regenBoss)
regenBoss.maxHp = 100
regenBoss.hp = 50
BossMemories.update(regenBoss, 3.1, regenRun)
assert(math.abs(regenBoss.hp - 53.1) < 0.001, "Regeneración debe curar 1% por segundo")
local beforeHit = regenBoss.hp
regenBoss:takeDamage(10, regenRun, "test")
BossMemories.update(regenBoss, 1, regenRun)
assert(math.abs(regenBoss.hp - (beforeHit - 10)) < 0.001,
  "recibir daño debe reiniciar la espera de Regeneración")

-- Fortificado reduce 30% hasta cruzar el 66% y luego se rompe.
local fortifiedRun = fakeRun("free", 3, { "seal" })
local fortifiedBoss = newBoss()
fortifiedRun.enemies[1] = fortifiedBoss
BossMemories.attach(fortifiedRun, fortifiedBoss)
fortifiedBoss.maxHp = 100
fortifiedBoss.hp = 100
fortifiedBoss:takeDamage(30, fortifiedRun, "test")
assert(math.abs(fortifiedBoss.hp - 79) < 0.001, "Fortificado debe reducir el daño 30%")
assert(fortifiedBoss.memoryFortified, "Fortificado debe seguir activo sobre 66%")
fortifiedBoss:takeDamage(20, fortifiedRun, "test")
assert(math.abs(fortifiedBoss.hp - 65) < 0.001 and not fortifiedBoss.memoryFortified,
  "Fortificado debe romperse al cruzar el umbral")
fortifiedBoss:takeDamage(10, fortifiedRun, "test")
assert(math.abs(fortifiedBoss.hp - 55) < 0.001, "Fortificado roto no debe volver a reducir")

-- Guardia: dos élites del piso, sin Clérigos.
local guardRun = fakeRun("free", 6, { "legion" })
local guardBoss = newBoss()
guardRun.enemies[1] = guardBoss
BossMemories.attach(guardRun, guardBoss)
assert(#guardRun.created == 2, "Guardia debe crear dos escoltas")
for _, entry in ipairs(guardRun.created) do
  assert(entry.kind ~= "clerigo", "Guardia no debe crear Clérigos sueltos")
  assert(entry.options.forceElite == true, "la escolta debe ser élite garantizada")
  assert(#entry.enemy.affixes > 0, "la escolta debe llevar al menos un afijo")
end

-- forceElite ignora la tirada normal de probabilidad.
local forcedRun = fakeRun("free", 1, {})
forcedRun.dungeon.rng = fixedRng(0.99)
local forced = Elites.roll(forcedRun, Data.enemyTypes.automaton, { forceElite = true })
assert(#forced == 1, "forceElite debe garantizar un afijo")
local normalRoll = Elites.roll(forcedRun, Data.enemyTypes.automaton, {})
assert(#normalRoll == 0, "sin forceElite la tirada normal debe poder fallar")

-- Sobrecarga global: a los 180 s la run termina sin importar la vida.
local enrageRun = fakeRun("free", 3, { "pressure" })
local enrageBoss = newBoss()
enrageRun.enemies[1] = enrageBoss
BossMemories.attach(enrageRun, enrageBoss)
local ended = BossMemories.update(enrageBoss, Data.bossMemories.enrageSeconds + 0.1, enrageRun)
assert(ended and enrageRun.over and enrageRun.overReason == "boss_enrage",
  "la Sobrecarga debe cerrar la run con su razón propia")
assert(not BossMemories.update(enrageBoss, 1, enrageRun),
  "la Sobrecarga no debe dispararse dos veces")

print("Tests OK")
