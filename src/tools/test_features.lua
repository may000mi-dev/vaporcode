-- test_features.lua: válvulas de vapor y apertura de cofres.
package.path = "./?.lua;" .. package.path

love = {
  math = {
    random = function(a, b)
      if a and b then return a end
      return 0.5
    end,
  },
  timer = {
    getTime = function()
      return 0
    end,
  },
}

local Valve = require("src.run.valve")
local Chest = require("src.run.chest")

local player = {
  x = 0,
  y = 0,
  radius = 16,
  hp = 100,
}

function player:takeDamage(amount)
  self.hp = self.hp - amount
  return true
end

local enemy = {
  x = 0,
  y = 0,
  radius = 14,
  hp = 100,
  dead = false,
}

function enemy:takeDamage(amount)
  self.hp = self.hp - amount
end

local opened = 0
local run = {
  player = player,
  enemies = { enemy },
  dungeon = {
    lineOfSight = function()
      return true
    end,
  },
  shake = function() end,
  openChest = function(_, chest)
    opened = opened + 1
    chest.opened = true
  end,
}

local valve = Valve.new(0, 0)
valve:update(0.016, run)
assert(valve.active > 0, "pisar la válvula debe activarla")
assert(not valve:trigger(run), "no debe reactivarse mientras libera vapor")

valve:update(0.02, run)
assert(player.hp == 96, "el vapor debe dañar al jugador")
assert(enemy.hp == 96, "el vapor debe dañar a los enemigos")

player.x = 20
local chest = Chest.new(10, 0, 1)
chest:update(0.016, run)
assert(chest.opened and opened == 1, "el cofre debe abrirse al acercarse")
chest:update(0.016, run)
assert(opened == 1, "el cofre no debe abrirse dos veces")

print("OK válvulas de vapor y cofres")
