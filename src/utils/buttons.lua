-- buttons.lua: cuatro acciones táctiles; A1/A2 dependen del equipamiento.
local Data = require("src.run.data")
local Fonts = require("src.utils.fonts")

local Buttons = {}
Buttons.__index = Buttons

function Buttons.new()
  local self = setmetatable({}, Buttons)
  self.active = {}
  self.items = {
    { slot = 1, keyLabel = "R", x = 620, y = 318, r = 42 },
    { slot = 2, keyLabel = "F", x = 852, y = 318, r = 42 },
    { slot = 3, keyLabel = "E", x = 736, y = 382, r = 42 },
    { slot = 4, keyLabel = "T", x = 736, y = 238, r = 42 },
  }
  return self
end

function Buttons:press(pointerId, x, y)
  for _, button in ipairs(self.items) do
    local dx = x - button.x
    local dy = y - button.y
    if dx * dx + dy * dy <= button.r * button.r then
      self.active[pointerId] = button
      return button
    end
  end
  return nil
end

function Buttons:release(pointerId)
  self.active[pointerId] = nil
end

function Buttons:clear()
  self.active = {}
end

function Buttons:draw(run)
  for _, button in ipairs(self.items) do
    local abilityId = run:abilityIdForSlot(button.slot)
    local def = abilityId and Data.abilities[abilityId]
    if def then
      local cooldownKey = run:cooldownKeyForSlot(button.slot)
      local cooldown = run.cooldowns[cooldownKey] or 0
      local maxCooldown = def.cooldown
      local locked = (run.abilityLockTimer or 0) > 0
      local ready = cooldown <= 0 and not locked

      local pressed = false
      for _, activeButton in pairs(self.active) do
        if activeButton == button then
          pressed = true
          break
        end
      end

      love.graphics.setColor(0, 0, 0, 0.35)
      love.graphics.circle("fill", button.x, button.y + 3, button.r + 2)

      love.graphics.setColor(0.08, 0.10, 0.13, 0.92)
      love.graphics.circle("fill", button.x, button.y, button.r)

      if cooldown > 0 and maxCooldown > 0 then
        local ratio = math.min(1, cooldown / maxCooldown)
        love.graphics.setColor(0.10, 0.12, 0.15, 0.88)
        love.graphics.arc(
          "fill",
          "pie",
          button.x,
          button.y,
          button.r,
          -math.pi * 0.5,
          -math.pi * 0.5 + ratio * math.pi * 2
        )
      end

      if pressed then
        love.graphics.setColor(0.55, 0.95, 1.00)
      elseif locked then
        love.graphics.setColor(0.45, 0.60, 1.00)
      elseif ready then
        love.graphics.setColor(0.35, 0.85, 0.95)
      else
        love.graphics.setColor(0.30, 0.40, 0.45)
      end
      love.graphics.setLineWidth(2)
      love.graphics.circle("line", button.x, button.y, button.r)
      love.graphics.setLineWidth(1)

      love.graphics.setFont(Fonts.button)
      if ready then
        love.graphics.setColor(1, 1, 1)
      else
        love.graphics.setColor(0.60, 0.70, 0.75)
      end
      love.graphics.printf(
        def.short,
        button.x - button.r,
        button.y - 9,
        button.r * 2,
        "center"
      )

      love.graphics.setFont(Fonts.small)
      love.graphics.setColor(0.80, 0.86, 0.92)
      love.graphics.printf(
        button.keyLabel,
        button.x - button.r,
        button.y - button.r + 2,
        button.r * 2,
        "center"
      )
      love.graphics.setColor(0.65, 0.72, 0.80)
      love.graphics.printf(
        def.name,
        button.x - button.r - 18,
        button.y + button.r + 4,
        button.r * 2 + 36,
        "center"
      )
    end
  end
end

return Buttons
