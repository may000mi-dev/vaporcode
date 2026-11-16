-- test_antidote.lua: aparición, selección, aura y castigos de los Antídoto.
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
  print = noop,
  circle = noop,
  arc = noop,
  setLineWidth = noop,
}

local Data = require("src.run.data")
local Antidote = require("src.run.antidote")
local Enemy = require("src.run.enemy")
local Pet = require("src.run.pet")
local Threat = require("src.run.threat")
local Combat = require("src.run.combat")

local function fixedRng(value)
  return {
    random = function(_, a, b)
      if a and b then return a end
      if a then return 1 end
      return value
    end,
  }
end

local function scriptedRng(values, fallback)
  local index = 0
  return {
    random = function(_, a, b)
      index = index + 1
      local value = values[index]
      if value == nil then value = fallback or 0 end
      if a and b then
        return math.min(b, math.floor(value * (b - a + 1)) + a)
      elseif a then
        return math.min(a, math.floor(value * a) + 1)
      end
      return value
    end,
  }
end

local function rooms(count)
  local list = {}
  for index = 1, count do
    list[index] = { index = index }
  end
  return list
end

local function fakeRun(mode, depth)
  local run = {
    mode = mode or "free",
    sandbox = false,
    depth = depth or 6,
    player = {
      x = 0,
      y = 0,
      radius = 16,
      damageTaken = 0,
    },
    stats = { damage = 4, maxHp = 100 },
    hp = 50,
    mana = 0,
    manaMax = 100,
    passiveStacks = {},
    pets = {},
    enemies = {},
    playerLevel = 1,
    dungeon = {
      rooms = rooms(7),
      rng = rng(depth or 6),
    },
  }
  run.player.takeDamage = function(self, amount)
    self.damageTaken = self.damageTaken + amount
    return true
  end
  run.dungeon.lineOfSight = function()
    return true
  end
  run.dungeon.moveCircle = function(_, x, y, dx, dy)
    return x + dx, y + dy
  end
  run.dungeon.randomFloorPoint = function()
    return 100, 100
  end
  run.onEnemyDamaged = noop
  run.onEnemyKilled = noop
  run.onPetKilled = noop
  return run
end

local function unitCost(units)
  local total = 0
  for _, kind in ipairs(units) do
    total = total + Threat.cost(kind)
  end
  return total
end

local function countKind(units, kind)
  local count = 0
  for _, id in ipairs(units) do
    if id == kind then count = count + 1 end
  end
  return count
end

-- Aislamiento: Historia, sandbox y pisos tempranos nunca generan Antídoto.
assert(not Antidote.enabled(fakeRun("story", 20)),
  "Historia no debe activar Antídoto")
local sandboxRun = fakeRun("free", 20)
sandboxRun.sandbox = true
assert(not Antidote.enabled(sandboxRun), "sandbox no debe activar Antídoto")
assert(not Antidote.enabled(fakeRun("free", 5)),
  "el piso 5 aún no debe activar Antídoto")
assert(Antidote.enabled(fakeRun("free", 6)), "el piso 6 abre los Antídoto")
assert(Antidote.chanceAt(6) == 0.35, "piso 6 debe tener 35%")
assert(Antidote.chanceAt(16) == 1.00, "piso 16 debe garantizar Antídoto")

local storyRun = fakeRun("story", 12)
storyRun.dungeon.rng = fixedRng(0)
assert(Antidote.choose(storyRun) == nil, "Historia no debe elegir Antídoto")

-- Selección sesgada sin excluir contrapartes.
local healRun = fakeRun("free", 6)
healRun.passiveStacks = { vampire = 1 }
healRun.dungeon.rng = scriptedRng({ 0, 0.10 })
assert(Antidote.choose(healRun) == "purificador",
  "la curación debe priorizar al Purificador")

local petRun = fakeRun("free", 6)
petRun.pets = { Pet.new("dog", 0, 10) }
petRun.dungeon.rng = scriptedRng({ 0, 0.30 })
assert(Antidote.choose(petRun) == "devorador",
  "las mascotas deben priorizar al Devorador")

local burstRun = fakeRun("free", 6)
burstRun.passiveStacks = { poison = 2 }
burstRun.stats.damage = 12
burstRun.dungeon.rng = scriptedRng({ 0, 0.50 })
assert(Antidote.choose(burstRun) == "espejo",
  "el daño alto debe priorizar al Espejo")

local tankRun = fakeRun("free", 6)
tankRun.stats.maxHp = 180
tankRun.dungeon.rng = scriptedRng({ 0, 0.50 })
assert(Antidote.choose(tankRun) == "asediador",
  "la vida alta debe priorizar al Asediador")

-- La tirada de aparición se respeta.
local missRun = fakeRun("free", 6)
missRun.dungeon.rng = fixedRng(0.99)
assert(Antidote.choose(missRun) == nil, "por encima de la probabilidad no debe salir")

-- Generación: máximo una unidad, coste real, solo en free.
local pool = Data.dungeons[3].enemies
local genRun = fakeRun("free", 6)
genRun.def = { enemies = pool }
genRun.dungeon.rng = fixedRng(0)
genRun.createEnemy = noop
local units, spent, remaining = Threat.generateComposition(genRun, 30)
assert(countKind(units, "purificador") == 1,
  "el piso debe contener exactamente un Antídoto")
assert(unitCost(units) == spent, "el costo del Antídoto debe entrar en el gasto")
assert(spent <= 30 and remaining < 4, "el Antídoto debe respetar el presupuesto")

local storyGen = fakeRun("story", 10)
storyGen.def = { enemies = pool }
storyGen.dungeon.rng = fixedRng(0)
local storyUnits = Threat.generateComposition(storyGen, 30)
for _, kind in ipairs(Data.antidote.types) do
  assert(countKind(storyUnits, kind) == 0,
    "Historia no debe generar " .. kind)
end

-- Purificador: aura, HUD lógico y reducción de curación.
local auraRun = fakeRun("free", 6)
auraRun.player.x = 100
local purifier = Enemy.new("purificador", 0, 0)
auraRun.enemies = { purifier }
assert(Antidote.suppressed(auraRun), "el aura debe cubrir al jugador")
assert(Antidote.healingMultiplier(auraRun) == 0.5, "el aura debe reducir 50%")
auraRun.player.x = 200
assert(not Antidote.suppressed(auraRun), "fuera del aura no debe suprimir")

local combatRun = fakeRun("free", 6)
combatRun.enemies = {
  Enemy.new("purificador", combatRun.player.x, combatRun.player.y),
}
combatRun.passiveStacks = { vampire = 1 }
local hpBefore = combatRun.hp
Combat.onBasicDamage(combatRun, { x = 0, y = 0, dead = false }, 100)
assert(math.abs((combatRun.hp - hpBefore) - 4) < 0.001,
  "Vampiro debe curar la mitad dentro del aura")

local fairyRun = fakeRun("free", 6)
fairyRun.enemies = {
  Enemy.new("purificador", fairyRun.player.x, fairyRun.player.y),
}
fairyRun.passiveStacks = { fairy = 1 }
Combat.onBasicDamage(fairyRun, { x = 0, y = 0, dead = false }, 100)
assert(math.abs(fairyRun.mana - 4) < 0.001,
  "Hada debe restaurar la mitad de maná dentro del aura")

-- Devorador: ignora al hámster, persigue mascotas y drena vida.
local petBattle = fakeRun("free", 6)
local hamster = Pet.new("hamster", 0, 5)
local dog = Pet.new("dog", 0, 40)
petBattle.pets = { hamster, dog }
local devourer = Enemy.new("devorador", 0, 0)
assert(devourer:findPetTarget(petBattle) == dog,
  "el Devorador debe ignorar al hámster y elegir otra mascota")
devourer.hp = 50
local petHp = dog.hp
devourer:updatePetHunter(0.1, petBattle, dog, 13, 0, 1)
assert(dog.hp < petHp, "el Devorador debe drenar vida de la mascota")
assert(devourer.hp > 50, "el Devorador debe curarse al drenar")

local armorRun = fakeRun("free", 6)
local armored = Enemy.new("devorador", 0, 0)
armored:takeDamage(20, armorRun, "basic")
assert(math.abs(armored.hp - (armored.maxHp - 16)) < 0.001,
  "la armadura del Devorador debe reducir 20%")

-- Espejo: escudo frontal temporal, reflejo parcial y umbral mínimo.
local mirrorRun = fakeRun("free", 6)
local mirror = Enemy.new("espejo", 0, 0)
mirror.mirrorShieldTimer = 1
mirror.mirrorShieldAngle = 0
mirrorRun.player.x = 30
mirrorRun.player.y = 0
mirror:takeDamage(50, mirrorRun, "basic")
assert(math.abs(mirrorRun.player.damageTaken - 17.5) < 0.001,
  "el Espejo debe reflejar 35% del daño frontal")

local reflectBefore = mirrorRun.player.damageTaken
mirror.mirrorShieldAngle = math.pi
mirror:takeDamage(50, mirrorRun, "basic")
assert(math.abs(mirrorRun.player.damageTaken - reflectBefore) < 0.001,
  "la espalda del Espejo no debe reflejar")

local weakMirror = Enemy.new("espejo", 0, 0)
weakMirror.mirrorShieldTimer = 1
weakMirror.mirrorShieldAngle = 0
weakMirror:takeDamage(5, mirrorRun, "basic")
assert(math.abs(mirrorRun.player.damageTaken - reflectBefore) < 0.001,
  "el daño bajo el mínimo no debe reflejarse")

local timerMirror = Enemy.new("espejo", 0, 0)
timerMirror.mirrorShieldCooldownTimer = 0.01
timerMirror:updateMirrorShield(0.02)
assert(timerMirror.mirrorShieldTimer > 0,
  "el escudo debe activarse al terminar el cooldown")

-- Asediador: inmóvil y tope de daño por golpe.
local siegeRun = fakeRun("free", 6)
local siege = Enemy.new("asediador", 0, 0)
siegeRun.player.x = 50
siege:takeDamage(100, siegeRun, "basic")
assert(math.abs(siege.hp - (siege.maxHp - 28.6)) < 0.001,
  "el Asediador debe limitar el daño por golpe a 16 + 15% del exceso")
local hpAfterHeavy = siege.hp
siege:takeDamage(10, siegeRun, "basic")
assert(math.abs(siege.hp - (hpAfterHeavy - 10)) < 0.001,
  "el tope no debe alterar golpes por debajo del límite")

print("OK Antídoto: aislamiento, selección, aura, mascotas y defensas")
