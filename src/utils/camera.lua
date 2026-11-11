-- camera.lua: cámara centrada con arrastre temporal para explorar.
local Data = require("src.run.data")
local Screen = require("src.utils.screen")
local Util = require("src.utils.util")

local Camera = {
  x = Screen.width * 0.5,
  y = Screen.height * 0.5,
  focusX = Screen.width * 0.5,
  focusY = Screen.height * 0.5,
  offsetX = 0,
  offsetY = 0,
  dragging = false,
  dragId = nil,
  dragStartX = 0,
  dragStartY = 0,
  dragBaseX = 0,
  dragBaseY = 0,
  shakeTime = 0,
  shakeDuration = 0,
  shakeMagnitude = 0,
  shakeX = 0,
  shakeY = 0,
}

local function apply()
  Camera.x = Camera.focusX + Camera.offsetX
  Camera.y = Camera.focusY + Camera.offsetY
end

local function clampOffset()
  local limit = Data.camera.maxOffset
  Camera.offsetX = Util.clamp(Camera.offsetX, -limit, limit)
  Camera.offsetY = Util.clamp(Camera.offsetY, -limit, limit)
end

function Camera.reset(x, y)
  Camera.focusX = x
  Camera.focusY = y
  Camera.offsetX = 0
  Camera.offsetY = 0
  Camera.dragging = false
  Camera.dragId = nil
  Camera.shakeTime = 0
  Camera.shakeDuration = 0
  Camera.shakeMagnitude = 0
  Camera.shakeX = 0
  Camera.shakeY = 0
  apply()
end

function Camera.shake(magnitude, duration)
  if not duration or duration <= 0 then return end
  Camera.shakeMagnitude = math.max(
    Camera.shakeMagnitude or 0,
    magnitude or 4
  )
  Camera.shakeTime = math.max(Camera.shakeTime or 0, duration)
  Camera.shakeDuration = Camera.shakeTime
end

-- El jugador queda al centro salvo mientras se explora con el dedo.
function Camera.follow(x, y)
  Camera.focusX = x
  Camera.focusY = y
  apply()
end

function Camera.update(dt)
  if not Camera.dragging then
    local decay = math.max(0, 1 - Data.camera.returnSpeed * dt)
    Camera.offsetX = Camera.offsetX * decay
    Camera.offsetY = Camera.offsetY * decay
    if math.abs(Camera.offsetX) < 0.5 then Camera.offsetX = 0 end
    if math.abs(Camera.offsetY) < 0.5 then Camera.offsetY = 0 end
  end

  if Camera.shakeTime > 0 then
    Camera.shakeTime = math.max(0, Camera.shakeTime - dt)
    local strength = 0
    if Camera.shakeDuration > 0 then
      strength = Camera.shakeMagnitude * (Camera.shakeTime / Camera.shakeDuration)
    end
    if Camera.shakeTime > 0 and love and love.math then
      Camera.shakeX = (love.math.random() * 2 - 1) * strength
      Camera.shakeY = (love.math.random() * 2 - 1) * strength
    else
      Camera.shakeX = 0
      Camera.shakeY = 0
      if Camera.shakeTime <= 0 then
        Camera.shakeMagnitude = 0
      end
    end
  end

  apply()
end

function Camera.beginDrag(pointerId, x, y)
  if Camera.dragging then return false end

  -- La zona de arrastre se centra en el espacio libre actual (varía con el aspecto).
  local zoneW = Data.camera.dragZone.w
  local zoneH = Data.camera.dragZone.h
  local zoneX = (Screen.width - zoneW) * 0.5
  local zoneY = (Screen.height - zoneH) * 0.5
  if x < zoneX or x > zoneX + zoneW or y < zoneY or y > zoneY + zoneH then
    return false
  end

  Camera.dragging = true
  Camera.dragId = pointerId
  Camera.dragStartX = x
  Camera.dragStartY = y
  Camera.dragBaseX = Camera.offsetX
  Camera.dragBaseY = Camera.offsetY
  return true
end

function Camera.moveDrag(pointerId, x, y)
  if not Camera.dragging or Camera.dragId ~= pointerId then return false end
  Camera.offsetX = Camera.dragBaseX + (x - Camera.dragStartX)
  Camera.offsetY = Camera.dragBaseY + (y - Camera.dragStartY)
  clampOffset()
  apply()
  return true
end

function Camera.endDrag(pointerId)
  if not Camera.dragging or Camera.dragId ~= pointerId then return false end
  Camera.dragging = false
  Camera.dragId = nil
  return true
end

function Camera.cancelDrag()
  Camera.dragging = false
  Camera.dragId = nil
end

function Camera.push()
  love.graphics.push()
  love.graphics.translate(
    Screen.width * 0.5 - Camera.x + Camera.shakeX,
    Screen.height * 0.5 - Camera.y + Camera.shakeY
  )
end

function Camera.pop()
  love.graphics.pop()
end

function Camera.toWorld(x, y)
  return Camera.x + (x - Screen.width * 0.5),
    Camera.y + (y - Screen.height * 0.5)
end

-- Límites visibles del mundo, útiles para no dibujar fuera de pantalla.
function Camera.view()
  local halfW = Screen.width * 0.5
  local halfH = Screen.height * 0.5
  return Camera.x - halfW, Camera.y - halfH, Camera.x + halfW, Camera.y + halfH
end

apply()

return Camera
