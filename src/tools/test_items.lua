-- test_items.lua: botín, pasivas, desbloqueos y mascotas de V5.
package.path = "./?.lua;" .. package.path

local randomValue = 0.5
love = {
  math = {
    random = function(a, b)
      if a and b then return a end
      return randomValue
    end,
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

local Data = require("src.run.data")
local Save = require("src.run.save")
local ItemDrop = require("src.run.item_drop")
local Pet = require("src.run.pet")
local Enemy = require("src.run.enemy")
local Rhythm = require("src.run.rhythm")
local Hud = require("src.run.hud")
local Shop = require("src.run.shop")
local Run = require("src.run.run")

Save.load()
assert(Save.isCharacterUnlocked("amado"), "Amado debe estar disponible")
assert(not Save.isCharacterUnlocked("mar"), "Mar debe empezar bloqueada")
assert(Save.unlockCharacter("mar"), "Mar debe desbloquearse una vez")
assert(not Save.unlockCharacter("mar"), "no debe repetirse el desbloqueo")

local picked = false
local fakePlayer = { x = 0, y = 0, radius = 16 }
local dropRun = {
  player = fakePlayer,
  pickupItem = function(self, item)
    picked = true
    return true
  end,
}

local poison = ItemDrop.new("poison", 1000, 0, 1)
poison:update(1, dropRun)
assert(math.abs(poison.life - 6) < 0.001, "el ítem debe durar siete segundos")
poison:update(7, dropRun)
assert(poison.dead and not picked, "el ítem temporal debe desaparecer")

local unlockItem = ItemDrop.new("amileth_unlock", 1000, 0, 1)
unlockItem:update(100, dropRun)
assert(not unlockItem.dead, "el ítem de personaje no debe caducar")

Run.player = fakePlayer
Run.pets = {}
Run.inventory = {}
Run.passiveStacks = {}
assert(Run:addItemToInventory("poison", 2) == "ok", "debe aceptar una pasiva x2")
assert(Run.passiveStacks.poison == 2, "la pasiva debe reflejarse en el inventario")
assert(#Run.inventory == 1 and Run.inventory[1].amount == 2, "cada copia ocupa un espacio")
assert(Run:addItemToInventory("poison", 5) == "ok", "debe topar cada copia en cinco")
assert(#Run.inventory == 2, "las copias iguales no se fusionan solas")
assert(Run:addItemToInventory("poison", 1) == "duplicate", "no debe pasar del máximo total")

Run.inventory = {}
Run.passiveStacks = {}
assert(Run:addItemToInventory("poison", 1) == "ok", "la primera copia debe entrar")
assert(Run:addItemToInventory("poison", 1) == "ok", "la segunda copia debe entrar")
Save.data.coins = 10
local pair = Run:alchemyCandidates()[1]
assert(pair and pair.cost == 10, "dos x1 deben poder combinarse por diez monedas")
assert(Run:combineAlchemy(pair), "la alquimia debe combinar el par")
assert(#Run.inventory == 1 and Run.inventory[1].amount == 2, "el resultado debe ser un solo x2")
assert(Save.data.coins == 0, "la alquimia debe cobrar monedas")

Run.playerLevel = 14
Run.depth = 10
assert(not Hud.shopUnlocked(Run), "la tienda requiere nivel 15")
Run.playerLevel = 15
Run.depth = 9
assert(not Hud.shopUnlocked(Run), "la tienda requiere piso 10")
Run.depth = 10
assert(Hud.shopUnlocked(Run), "nivel 15 y piso 10 deben abrir la tienda")

Run.inventory = {}
Run.passiveStacks = {}
Run.shopTab = "buy"
Save.data.coins = 500
Shop.pressed(Run, 150, 140)
assert(#Run.inventory == 1 and Save.data.coins == 475, "comprar veneno debe cobrar 25")
Shop.pressed(Run, 320, 100)
assert(Run.shopTab == "alchemy", "la pestaña de alquimia debe activarse")
Shop.pressed(Run, 806, 66)
assert(Run.overlay == nil, "la X debe cerrar la tienda")

Save.data.coins = 0
assert(Run:buyItem("poison") == "coins", "sin monedas no debe comprar")

Run.inventory = {}
Run.abilitySlot1 = nil
Run.abilitySlot2 = nil
assert(Run:addItemToInventory("light_arrow_skill", 1) == "ok", "la habilidad debe entrar a la mochila")
assert(Run:equipInventoryAbility(1, 1), "la habilidad debe asignarse a A1")
assert(Run.abilitySlot1 == "light_arrow", "A1 debe quedar equipada")
assert(#Run.inventory == 0, "asignar consume el ítem de habilidad")
assert(Run:addItemToInventory("light_arrow_skill", 1) == "ok", "puede caer otra copia")
assert(Run:equipInventoryAbility(1, 2), "la copia debe asignarse a A2")
assert(Run.abilitySlot1 == "light_arrow" and Run.abilitySlot2 == "light_arrow", "A1 y A2 pueden repetir")

Run.inventory = {}
for _, id in ipairs({ "poison", "vampire", "fairy", "gunpowder", "drum" }) do
  assert(Run:addItemToInventory(id, 1) == "ok", "debe llenarse el inventario")
end
assert(Run:addItemToInventory("flute", 1) == "full", "el sexto ítem debe bloquearse")
Run:removeInventoryAt(1)
assert(Run.passiveStacks.poison == nil, "tirar una pasiva debe recalcular efectos")

Run.inventory = {}
Run.pets = {}
assert(Run:addItemToInventory("dog", 1) == "ok", "la mascota debe ocupar un espacio")
assert(#Run.pets == 1, "la mascota debe activarse")
Run:removeInventoryAt(1)
assert(#Run.pets == 0 or Run.pets[1].dead, "tirar la mascota debe retirarla")

Run.stats = { damage = 10, maxHp = 100, speed = 150 }
Run.hp = 50
Run.mana = 50
Run.manaMax = 100
Run.coinsEarned = 0
Run.enemies = {}
Run.fluteReady = false
Run.passiveStacks = { vampire = 1, fairy = 1 }
Run:onBasicDamage({ x = 0, y = 0 }, 100)
assert(math.abs(Run.hp - 60) < 0.001, "vampiro debe curar 10% con sinergia")
assert(math.abs(Run.mana - 60) < 0.001, "hada debe restaurar 10% con sinergia")

local function fakeEnemy(x, y, hp)
  local enemy = {
    x = x,
    y = y,
    radius = 10,
    hp = hp or 100,
    dead = false,
  }
  function enemy:takeDamage(amount, run, source)
    self.hp = self.hp - amount
    self.lastSource = source
    if self.hp <= 0 then self.dead = true end
    return amount
  end
  function enemy:applyStun(duration)
    self.stun = duration
  end
  function enemy:applySlow(duration, factor)
    self.slow = duration
    self.slowFactor = factor
  end
  return enemy
end

Run.dungeon = {
  moveCircle = function(_, x, y, dx, dy)
    return x + dx, y + dy
  end,
  lineOfSight = function()
    return false
  end,
  destructible = {},
  tileCenter = function(_, tx, ty)
    return tx * 36, ty * 36
  end,
}

local powderTarget = fakeEnemy(0, 0)
local powderOther = fakeEnemy(10, 0)
Run.enemies = { powderTarget, powderOther }
Run.passiveStacks = { gunpowder = 1 }
randomValue = 0
Run:onBasicDamage(powderTarget, 10)
assert(powderTarget.hp < 100 and powderOther.hp < 100, "pólvora debe dañar en área")
assert(powderOther.stun == Data.items.gunpowder.stun, "pólvora debe aturdir")
assert(powderOther.lastSource == "gunpowder", "la explosión no debe repetir pasivas")

local tornadoTarget = fakeEnemy(0, 0)
Run.enemies = { tornadoTarget }
Run.passiveStacks = {}
Run.fluteReady = true
Run:onBasicDamage(tornadoTarget, 1)
assert(Run.tornado and not Run.fluteReady, "flauta debe invocar el tornado")
Run:updateTornado(0.5)
assert(math.abs(tornadoTarget.hp - 85) < 0.001, "el tornado debe dañar cada tick")
assert(tornadoTarget.lastSource == "ability", "el tornado no es ataque básico")

Run.passiveStacks = { poison = 2 }
local poisoned = Enemy.new("automaton", 1000, 0, 100, 10, 5)
Run:onEnemyDamaged(poisoned, 10, "basic")
assert(poisoned.poisonTimer > 0, "veneno debe aplicarse al dañar")
local beforePoison = poisoned.hp
poisoned:update(0.5, {
  player = fakePlayer,
  shadow = nil,
  enemies = { poisoned },
  dungeon = {
    lineOfSight = function()
      return false
    end,
    moveCircle = function(_, x, y)
      return x, y
    end,
  },
  onEnemyDamaged = function() end,
  onEnemyKilled = function() end,
})
assert(poisoned.hp < beforePoison, "el veneno debe hacer daño con el tiempo")

Rhythm.enter({ bpm = 104 })
Rhythm.justBeat = true
local petRun = {
  player = fakePlayer,
  stats = { damage = 10 },
  enemies = { fakeEnemy(50, 0) },
  itemDrops = {},
  dungeon = Run.dungeon,
  pickupItem = function()
    return true
  end,
}

local dog = Pet.new("dog", 0, 0)
dog:update(0.016, petRun)
assert(petRun.enemies[1].hp < 100, "el perro debe morder al ritmo")
assert(petRun.enemies[1].stun and petRun.enemies[1].stun > 0, "el perro debe aturdir")
assert(dog.attackCooldown > 0, "el perro debe esperar dos beats")

local dragon = Pet.new("dragon", 0, 0)
local dragonTarget = fakeEnemy(50, 0)
petRun.enemies = { dragonTarget }
Rhythm.justBeat = true
dragon:update(0.016, petRun)
assert(dragonTarget.hp == 100, "el dragón no debe atacar sin provocación")
dragon:takeDamage(1, petRun)
Rhythm.justBeat = true
dragon:update(0.016, petRun)
assert(dragonTarget.hp < 100, "el dragón debe responder en cono")

local hamster = Pet.new("hamster", 0, 0)
local collected = nil
petRun.enemies = {}
petRun.itemDrops = { ItemDrop.new("poison", 5, 0, 1) }
petRun.pickupItem = function(_, item)
  collected = item
  return true
end
hamster:update(0.016, petRun)
assert(collected and collected.itemId == "poison", "el hámster debe recoger ítems")

Save.data.characters.amileth = false
Run.itemDrops = {}
Run.unlockNotices = {}
Run.player = fakePlayer
Run.coinsEarned = 0
randomValue = 0
assert(
  not Run:maybeDropCharacter({ source = "floor", x = 0, y = 0 }),
  "los cofres normales no dan personajes"
)
assert(Run:maybeDropCharacter({ source = "wall", x = 0, y = 0 }), "el cofre oculto debe dar personaje")
local characterItem = Run.itemDrops[1]
assert(characterItem.itemId == "amileth_unlock", "debe caer el personaje bloqueado")
Run:pickupItem(characterItem)
assert(Save.isCharacterUnlocked("amileth"), "recoger el ítem debe desbloquear")
assert(Run.unlockNotices.amileth == nil, "recoger debe quitar el aviso pendiente")

print("OK botín, pasivas, desbloqueos y mascotas")
