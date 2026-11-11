-- test_chain.lua: el proyectil de Amileth salta con 50% de caída por salto.
package.path = "./?.lua;" .. package.path

local Projectile = require("src.run.projectile")

local function makeEnemy(x, hp)
  return {
    x = x,
    y = 0,
    radius = 10,
    hp = hp or 1000,
    dead = false,
    lastHit = 0,
    takeDamage = function(self, amount)
      self.hp = self.hp - amount
      self.lastHit = amount
    end,
  }
end

local first = makeEnemy(40)
local second = makeEnemy(100)
local third = makeEnemy(200)
local run = {
  enemies = { first, second, third },
  dungeon = {
    circleCollides = function()
      return false
    end,
    lineOfSight = function()
      return true
    end,
  },
}

local projectile = Projectile.new(0, 0, 0, 400, 100, true, {
  kind = "chain",
  chain = {
    jumps = 2,
    range = 220,
    falloff = 0.5,
    requireLineOfSight = true,
  },
})
projectile:update(0.1, run)

assert(first.lastHit == 100, "el primer golpe debe ser completo")
assert(second.lastHit == 50, "el primer salto debe aplicar 50%")
assert(third.lastHit == 25, "el segundo salto debe aplicar 25%")

print("OK cadena de Amileth")
