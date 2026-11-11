-- test_floor.lua: la instantánea restaura el estado exacto de inicio de piso.
package.path = "./?.lua;" .. package.path

local Floor = require("src.run.floor")

local run = {
  seed = 12345,
  depth = 3,
  def = { id = "forja" },
  characterId = "amileth",
  abilitySlot1 = "light_arrow",
  abilitySlot2 = "shadow_swap",
  abilitySlot3 = "shield",
  abilitySlot4 = "turbo",
  playerLevel = 4,
  hp = 88,
  xp = 12,
  xpToNext = 68,
  kills = 9,
  coinsEarned = 14,
  stats = { damage = 17, maxHp = 124, speed = 162, attackRate = 2.4 },
  cooldowns = { a1 = 2.5, a2 = 0, shield = 0 },
  turboTimer = 1.25,
  mana = 41,
  manaMax = 100,
  manaIdleTimer = 3,
  timeLeft = 300,
  passiveStacks = { poison = 2, drum = 1 },
  inventory = {
    { itemId = "poison", amount = 2 },
    { itemId = "drum", amount = 1 },
    { itemId = "light_arrow_skill", amount = 1 },
  },
  fluteReady = true,
  pets = {
    {
      dead = false,
      snapshot = function()
        return { kind = "dog", hp = 20, maxHp = 44, attackCooldown = 0.5 }
      end,
    },
  },
}

local snapshot = Floor.capture(run)
assert(snapshot.stats ~= run.stats, "las estadísticas deben copiarse")
assert(snapshot.cooldowns ~= run.cooldowns, "los cooldowns deben copiarse")
assert(snapshot.passiveStacks ~= run.passiveStacks, "las pasivas deben copiarse")
assert(snapshot.inventory ~= run.inventory, "el inventario debe copiarse")
assert(#snapshot.pets == 1, "las mascotas deben capturarse")

run.seed = 0
run.depth = 9
run.hp = 1
run.xp = 0
run.playerLevel = 1
run.mana = 0
run.stats.damage = 1
run.cooldowns.a1 = 0
run.timeLeft = 2
run.passiveStacks.poison = 5
run.inventory = {}
run.fluteReady = false

assert(Floor.restore(run, snapshot), "la instantánea debe restaurarse")
assert(run.seed == 12345 and run.depth == 3, "semilla y piso deben volver al inicio")
assert(run.hp == 88 and run.xp == 12 and run.playerLevel == 4, "el personaje debe restaurarse")
assert(run.mana == 41 and run.manaIdleTimer == 3, "el maná debe restaurarse")
assert(run.stats.damage == 17, "las estadísticas deben restaurarse")
assert(run.cooldowns.a1 == 2.5, "los cooldowns deben restaurarse")
assert(run.timeLeft == 300, "el tiempo del piso debe reiniciarse")
assert(run.passiveStacks.poison == 2, "las pasivas deben restaurarse")
assert(#run.inventory == 3 and run.inventory[1].itemId == "poison", "el inventario debe restaurarse")
assert(run.fluteReady, "la flauta lista debe restaurarse")
assert(#run.petSnapshot == 1 and run.petSnapshot[1].kind == "dog", "las mascotas deben restaurarse")

print("OK instantánea y reintento de piso")
