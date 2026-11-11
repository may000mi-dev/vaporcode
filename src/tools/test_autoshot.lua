-- test_autoshot.lua: el auto-disparo exige objetivo con línea de visión.
package.path = "./?.lua;" .. package.path

local Player = require("src.run.player")
local Targeting = require("src.run.targeting")

local function makeRun(visible)
  local run = {
    stats = { speed = 150, attackRate = 1, damage = 10 },
    turboTimer = 0,
    shots = 0,
    enemies = { { x = 100, y = 0, dead = false } },
    dungeon = {
      moveCircle = function(_, x, y, dx, dy)
        return x + dx, y + dy
      end,
      lineOfSight = function()
        return visible
      end,
    },
  }

  function run:nearestEnemy(maxDistance, requireLineOfSight)
    run.los = requireLineOfSight
    return Targeting.nearestVisible(
      self.player.x,
      self.player.y,
      self.enemies,
      maxDistance,
      self.dungeon,
      requireLineOfSight
    )
  end

  function run:spawnProjectile()
    run.shots = run.shots + 1
  end

  return run
end

local player = Player.new(0, 0)

local blockedRun = makeRun(false)
blockedRun.player = player
player.attackTimer = 0
player:update(0.1, 0, 0, blockedRun)
assert(blockedRun.shots == 0, "no debe disparar si hay pared intermedia")
assert(blockedRun.los == true, "debe consultar línea de visión")
assert(player.attackTimer == 0, "debe reintentar en el siguiente frame")

local clearRun = makeRun(true)
clearRun.player = player
player.attackTimer = 0
player:update(0.1, 0, 0, clearRun)
assert(clearRun.shots == 1, "debe disparar con objetivo visible")
assert(clearRun.los == true, "debe consultar línea de visión")
assert(player.attackTimer > 0, "debe respetar el cooldown del ataque")

print("OK auto-disparo con línea de visión")
