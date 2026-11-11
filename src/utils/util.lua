-- util.lua: funciones compartidas y ligeras.
local Util = {}

function Util.clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

function Util.dist2(ax, ay, bx, by)
  local dx = ax - bx
  local dy = ay - by
  return dx * dx + dy * dy
end

function Util.dist(ax, ay, bx, by)
  return math.sqrt(Util.dist2(ax, ay, bx, by))
end

function Util.inside(x, y, rect)
  return x >= rect.x and x < rect.x + rect.w and y >= rect.y and y < rect.y + rect.h
end

-- Zona táctil izquierda para el joystick flotante.
-- Se deja libre el centro para arrastrar la cámara sin conflictos.
function Util.inJoystickZone(x, y)
  return x < 360 and y > 120
end

-- Distancia al cuadrado de un punto contra un segmento y su parámetro t.
function Util.pointSegmentDist2(px, py, ax, ay, bx, by)
  local dx = bx - ax
  local dy = by - ay
  local len2 = dx * dx + dy * dy
  if len2 <= 0.000001 then
    return Util.dist2(px, py, ax, ay), 0
  end
  local t = ((px - ax) * dx + (py - ay) * dy) / len2
  t = Util.clamp(t, 0, 1)
  local qx = ax + dx * t
  local qy = ay + dy * t
  return Util.dist2(px, py, qx, qy), t
end

function Util.isMobile()
  local osName = love.system.getOS()
  return osName == "Android" or osName == "iOS"
end

function Util.round(v)
  return math.floor(v + 0.5)
end

-- Compatibilidad entre LuaJIT (math.atan2) y Lua 5.4 (math.atan con dos args).
function Util.atan2(y, x)
  if math.atan2 then
    return math.atan2(y, x)
  end
  return math.atan(y, x)
end

return Util
