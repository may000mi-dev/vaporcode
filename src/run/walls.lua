-- walls.lua: interacción con el mundo: válvulas de vapor y paredes frágiles.
-- Las funciones reciben run como primer argumento y run.lua las monta
-- como métodos para conservar la API run:metodo(...).
local Data = require("src.run.data")
local FX = require("src.run.fx")
local Util = require("src.utils.util")

local Walls = {}

function Walls.hitValve(run, x, y, radius)
  if not run.valves then return false end

  for _, valve in ipairs(run.valves) do
    local reach = radius + valve.radius
    if Util.dist2(x, y, valve.x, valve.y) <= reach * reach then
      valve:trigger(run)
      return true
    end
  end
  return false
end

function Walls.triggerValvesInRadius(run, x, y, radius)
  if not run.valves then return end

  local reach2 = radius * radius
  for _, valve in ipairs(run.valves) do
    if Util.dist2(x, y, valve.x, valve.y) <= reach2 then
      valve:trigger(run)
    end
  end
end

function Walls.triggerValvesOnSegment(run, x1, y1, x2, y2, width)
  if not run.valves then return end

  for _, valve in ipairs(run.valves) do
    local reach = width + valve.radius
    local d2 = Util.pointSegmentDist2(
      valve.x,
      valve.y,
      x1,
      y1,
      x2,
      y2
    )
    if d2 <= reach * reach then
      valve:trigger(run)
    end
  end
end

function Walls.damageWallAt(run, tx, ty, amount)
  local dungeon = run.dungeon
  if not dungeon:isDestructibleTile(tx, ty) then return false end

  local broken, wall = dungeon:damageWall(tx, ty, amount)
  local x, y = dungeon:tileCenter(tx, ty)
  if not broken then
    FX.burst(x, y, 5, Data.destructible.crack)
    FX.ring(x, y, 12, Data.destructible.crack)
    return false
  end

  run:onWallBroken(tx, ty, wall, x, y)
  return true
end

function Walls.damageWallsInRadius(run, x, y, radius, amount)
  local dungeon = run.dungeon
  local hits = {}
  local reach = radius + dungeon.tile * 0.5
  local reach2 = reach * reach

  for ty, row in pairs(dungeon.destructible) do
    for tx in pairs(row) do
      local wx, wy = dungeon:tileCenter(tx, ty)
      if Util.dist2(x, y, wx, wy) <= reach2 then
        hits[#hits + 1] = { tx = tx, ty = ty }
      end
    end
  end

  local broken = false
  for _, hit in ipairs(hits) do
    if run:damageWallAt(hit.tx, hit.ty, amount) then
      broken = true
    end
  end
  return broken
end

function Walls.onWallBroken(run, tx, ty, wall, x, y)
  local def = Data.destructible
  FX.burst(x, y, 20, def.crack)
  FX.ring(x, y, 28, def.crack)
  FX.add("¡Pared destruida!", x, y - 24, def.crack)
  run:shake(4, 0.20)

  if wall and wall.loot then
    run:spawnChest(x, y, "wall")
  end
end

return Walls
