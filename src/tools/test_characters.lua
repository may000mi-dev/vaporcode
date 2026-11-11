-- test_characters.lua: marcas de Amado, límite de 3 y pasiva de Mar.
package.path = "./?.lua;" .. package.path

love = {
  math = {
    random = function()
      return 0.5
    end,
  },
}

local Data = require("src.run.data")
local Enemy = require("src.run.enemy")
local Player = require("src.run.player")
local Run = require("src.run.run")

local fakeRun = { onEnemyKilled = function() end }

local e1 = Enemy.new("automaton", 0, 0, 100, 10, 5)
local e2 = Enemy.new("automaton", 0, 0, 100, 10, 5)
local e3 = Enemy.new("automaton", 0, 0, 100, 10, 5)
local e4 = Enemy.new("automaton", 0, 0, 100, 10, 5)
Run.enemies = { e1, e2, e3, e4 }

assert(Run:markEnemy(e1), "debe marcar al primer enemigo")
assert(Run:markEnemy(e2), "debe marcar al segundo enemigo")
assert(Run:markEnemy(e3), "debe marcar al tercer enemigo")
assert(not Run:markEnemy(e4), "no debe pasar de tres marcas")

local before = e1.hp
e1:takeDamage(10, fakeRun)
local expected = before - 10 * (1 + Data.mark.damageBonus)
assert(math.abs(e1.hp - expected) < 0.001, "la marca debe aumentar el daño")
assert(
  math.abs(e1:movementSpeed() - e1.speed * (1 - Data.mark.slow)) < 0.001,
  "la marca debe reducir la velocidad"
)

e1:applyMark(0.4)
Run:markEnemy(e1)
assert(e1.markTimer == Data.mark.duration, "un ataque nuevo debe refrescar la marca")

local player = Player.new(0, 0, "mar")
Run.player = player
Run.characterId = "mar"
Run.dungeon = {
  nearestWalkable = function(_, x, y)
    return x, y
  end,
}

player.moving = false
assert(not Run:marDash(nil, false), "Mar no debe hacer dash estando quieta")

player.moving = true
player.moveX = 1
player.moveY = 0
local startX = player.x
assert(Run:marDash(nil, false), "Mar debe hacer dash al moverse")
assert(player.x > startX, "el dash debe avanzar en la dirección de movimiento")
assert(
  math.abs(player.x - Data.player.radius * Data.characters.mar.dashRadiusFactor) < 0.001,
  "el dash debe recorrer el doble del valor anterior"
)
assert(player.invuln >= Data.characters.mar.dashInvuln, "el dash debe dar invulnerabilidad")
assert(Data.characters.mar.meleeRangeMaxFactor == 14, "el alcance máximo de Mar debe duplicarse")

local shieldRun = {
  hp = 100,
  over = false,
  shake = function() end,
  gameOver = function() end,
}
local amileth = Player.new(0, 0, "amileth")
amileth:setupShield(100)
assert(math.abs(amileth.shieldMax - 10) < 0.001, "el escudo debe ser 10% de la vida")
assert(math.abs(amileth.shield - 10) < 0.001, "el escudo debe iniciar lleno")

assert(amileth:takeDamage(4, shieldRun), "el escudo debe absorber el golpe")
assert(amileth.shield == 6 and shieldRun.hp == 100, "el escudo absorbe antes que la vida")
amileth.invuln = 0
assert(amileth:takeDamage(10, shieldRun), "el excedente debe pasar a la vida")
assert(amileth.shield == 0 and shieldRun.hp == 96, "la vida debe recibir solo el excedente")

amileth:updateShield(5.1)
amileth:updateShield(1)
assert(amileth.shield > 0, "el escudo debe repararse tras cinco segundos sin daño")

Run.mana = 0
Run.manaMax = 100
Run.manaIdleTimer = 0
Run.manaFlash = 0
Run:updateMana(1)
assert(
  math.abs(Run.mana - Data.mana.regen) < 0.001,
  "el maná debe regenerarse lentamente en uso"
)

Run.mana = 0
Run.manaIdleTimer = Data.mana.idleDelay
Run:updateMana(1)
assert(
  math.abs(Run.mana - Data.mana.regen * Data.mana.idleMultiplier) < 0.001,
  "tras cinco segundos el maná debe regenerarse al triple"
)

print("OK personajes, marcas, Mar, escudo y maná")
