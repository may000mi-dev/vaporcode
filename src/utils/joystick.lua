-- joystick.lua: joystick flotante para la mitad izquierda de la pantalla.
local Util = require("src.utils.util")

local Joystick = {}
Joystick.__index = Joystick

function Joystick.new()
  return setmetatable({
    active = false,
    id = nil,
    baseX = 0,
    baseY = 0,
    knobX = 0,
    knobY = 0,
    dx = 0,
    dy = 0,
    radius = 62,
  }, Joystick)
end

function Joystick:press(id, x, y)
  if not Util.inJoystickZone(x, y) then return false end
  self.active = true
  self.id = id
  self.baseX = x
  self.baseY = y
  self.knobX = x
  self.knobY = y
  self.dx = 0
  self.dy = 0
  return true
end

function Joystick:move(id, x, y)
  if not self.active or self.id ~= id then return end

  local dx = x - self.baseX
  local dy = y - self.baseY
  local distance = math.sqrt(dx * dx + dy * dy)
  if distance > self.radius then
    local scale = self.radius / distance
    dx = dx * scale
    dy = dy * scale
  end

  self.knobX = self.baseX + dx
  self.knobY = self.baseY + dy
  self.dx = dx / self.radius
  self.dy = dy / self.radius
end

function Joystick:release(id)
  if not self.active or self.id ~= id then return end
  self.active = false
  self.id = nil
  self.dx = 0
  self.dy = 0
end

-- Cancela el gesto al pausar o perder el foco para evitar movimientos pegados.
function Joystick:cancel()
  self.active = false
  self.id = nil
  self.dx = 0
  self.dy = 0
end

function Joystick:draw()
  if not self.active then return end

  love.graphics.setColor(0.20, 0.70, 0.80, 0.16)
  love.graphics.circle("fill", self.baseX, self.baseY, self.radius + 8)
  love.graphics.setColor(0.40, 0.90, 1.00, 0.45)
  love.graphics.circle("line", self.baseX, self.baseY, self.radius)
  love.graphics.setColor(0.50, 0.90, 1.00, 0.85)
  love.graphics.circle("fill", self.knobX, self.knobY, 24)
end

return Joystick
