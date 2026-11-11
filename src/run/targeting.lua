-- targeting.lua: selección del enemigo más cercano que se pueda alcanzar.
local Util = require("src.utils.util")

local Targeting = {}

function Targeting.nearestVisible(px, py, enemies, maxDistance, dungeon, requireLineOfSight)
  local best = nil
  local bestD2 = (maxDistance or 9999) * (maxDistance or 9999)

  for _, enemy in ipairs(enemies) do
    if not enemy.dead then
      local d2 = Util.dist2(px, py, enemy.x, enemy.y)
      if d2 < bestD2 then
        local visible = true
        if requireLineOfSight then
          visible = dungeon:lineOfSight(px, py, enemy.x, enemy.y)
        end
        if visible then
          best = enemy
          bestD2 = d2
        end
      end
    end
  end

  return best
end

-- Siguiente enemigo de una cadena, evitando los ya golpeados.
function Targeting.nearestChain(px, py, enemies, hitSet, maxDistance, dungeon, requireLineOfSight)
  local best = nil
  local bestD2 = (maxDistance or 9999) * (maxDistance or 9999)

  for _, enemy in ipairs(enemies) do
    if not enemy.dead and not (hitSet and hitSet[enemy]) then
      local d2 = Util.dist2(px, py, enemy.x, enemy.y)
      if d2 < bestD2 then
        local visible = true
        if requireLineOfSight then
          visible = dungeon:lineOfSight(px, py, enemy.x, enemy.y)
        end
        if visible then
          best = enemy
          bestD2 = d2
        end
      end
    end
  end

  return best
end

return Targeting
