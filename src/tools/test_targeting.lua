-- test_targeting.lua: elige al enemigo visible más cercano, no al más cercano a ciegas.
package.path = "./?.lua;" .. package.path

local Targeting = require("src.run.targeting")

local near = { x = 100, y = 0, dead = false }
local far = { x = 300, y = 0, dead = false }

local function dungeonBlocking(x)
  return {
    lineOfSight = function(_, _, _, targetX)
      return targetX ~= x
    end,
  }
end

local target = Targeting.nearestVisible(
  0,
  0,
  { near, far },
  1000,
  dungeonBlocking(near.x),
  true
)
assert(target == far, "debe ignorar al enemigo cercano si hay pared")

target = Targeting.nearestVisible(
  0,
  0,
  { near, far },
  1000,
  dungeonBlocking(near.x),
  false
)
assert(target == near, "sin línea de visión debe elegir al más cercano")

local blocked = { lineOfSight = function() return false end }
assert(
  Targeting.nearestVisible(0, 0, { near, far }, 1000, blocked, true) == nil,
  "no debe haber objetivo si todos están bloqueados"
)

assert(
  Targeting.nearestVisible(0, 0, { near, far }, 50, blocked, false) == nil,
  "no debe apuntar fuera de rango"
)

near.dead = true
assert(
  Targeting.nearestVisible(0, 0, { near, far }, 1000, blocked, false) == far,
  "debe ignorar enemigos muertos"
)

print("OK selección de objetivos")
