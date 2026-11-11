-- aim.lua: estado de apuntado para las habilidades con arrastre.
local Aim = {}
Aim.__index = Aim

local DRAG_THRESHOLD = 18
local DRAG_THRESHOLD2 = DRAG_THRESHOLD * DRAG_THRESHOLD

function Aim.new()
  return setmetatable({
    active = false,
    pointerId = nil,
    slot = 1,
    abilityId = nil,
    startX = 0,
    startY = 0,
    x = 0,
    y = 0,
    dragging = false,
  }, Aim)
end

function Aim:begin(pointerId, slot, abilityId, x, y)
  self.active = true
  self.pointerId = pointerId
  self.slot = slot
  self.abilityId = abilityId
  self.startX = x
  self.startY = y
  self.x = x
  self.y = y
  self.dragging = false
end

function Aim:move(pointerId, x, y)
  if not self.active or self.pointerId ~= pointerId then return false end
  self.x = x
  self.y = y
  local dx = x - self.startX
  local dy = y - self.startY
  self.dragging = dx * dx + dy * dy > DRAG_THRESHOLD2
  return true
end

function Aim:release(pointerId)
  if not self.active or self.pointerId ~= pointerId then return nil end

  local state = {
    slot = self.slot,
    abilityId = self.abilityId,
    startX = self.startX,
    startY = self.startY,
    x = self.x,
    y = self.y,
    dragging = self.dragging,
  }
  self:cancel()
  return state
end

function Aim:cancel()
  self.active = false
  self.pointerId = nil
  self.abilityId = nil
  self.dragging = false
end

return Aim
