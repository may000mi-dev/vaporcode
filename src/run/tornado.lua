-- tornado.lua: efecto del ítem Flauta de Vapor; daño en área por tics.
-- Exporta spawnTornado/updateTornado/drawTornado: los nombres de la API
-- original de Run, no genéricos, para no chocar con otros métodos.
local Data = require("src.run.data")
local FX = require("src.run.fx")
local Util = require("src.utils.util")

local Tornado = {}

function Tornado.spawnTornado(run, x, y)
  local def = Data.items.flute
  run.tornado = {
    x = x,
    y = y,
    radius = def.radius,
    time = def.duration,
    maxTime = def.duration,
    tick = 0,
    phase = love.math.random() * math.pi * 2,
  }
  FX.ring(x, y, def.radius, def.color)
  FX.add("¡Tornado!", x, y - 34, def.color)
end

function Tornado.updateTornado(run, dt)
  local tornado = run.tornado
  if not tornado then return end

  local def = Data.items.flute
  tornado.time = tornado.time - dt
  tornado.tick = tornado.tick - dt
  if tornado.time <= 0 then
    run.tornado = nil
    return
  end
  if tornado.tick > 0 then return end

  tornado.tick = def.tickInterval
  local damage = run.stats.damage
    * def.damageMultiplier
    * def.tickScale
  local radius2 = tornado.radius * tornado.radius
  for _, enemy in ipairs(run.enemies) do
    if not enemy.dead then
      if Util.dist2(tornado.x, tornado.y, enemy.x, enemy.y) <= radius2 then
        enemy:takeDamage(damage, run, "ability")
        if not enemy.dead and enemy.applySlow then
          enemy:applySlow(def.tickInterval + 0.1, 1 - def.slow)
        end
      end
    end
  end
  FX.ring(tornado.x, tornado.y, tornado.radius, def.color)
end

function Tornado.drawTornado(run)
  local tornado = run.tornado
  if not tornado then return end

  local def = Data.items.flute
  local t = love.timer.getTime()
  local alpha = math.min(1, tornado.time / math.max(0.001, tornado.maxTime))
  love.graphics.setColor(def.color[1], def.color[2], def.color[3], 0.10 * alpha)
  love.graphics.circle("fill", tornado.x, tornado.y, tornado.radius)
  love.graphics.setColor(def.color[1], def.color[2], def.color[3], 0.55 * alpha)
  love.graphics.setLineWidth(3)
  for i = 0, 3 do
    local phase = t * 4 + tornado.phase + i * math.pi * 0.5
    local radius = tornado.radius * (0.35 + i * 0.18)
    love.graphics.arc(
      "line",
      tornado.x,
      tornado.y,
      radius,
      phase,
      phase + 1.4
    )
  end
  love.graphics.setLineWidth(1)
end

return Tornado
