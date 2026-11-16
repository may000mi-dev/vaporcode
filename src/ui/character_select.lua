-- character_select.lua: tarjetas globales de personaje con confirmación.
local Data = require("src.run.data")
local Save = require("src.run.save")
local Fonts = require("src.utils.fonts")
local Themes = require("src.data.themes")
local Audio = require("src.utils.audio")
local Portraits = require("src.utils.portraits")
local Util = require("src.utils.util")

local Select = {}

function Select.new(opts)
  opts = opts or {}
  local self = {
    rects = {},
    confirm = nil,
    panel = nil,
    getZone = opts.getZone or function() return "menu" end,
    onChanged = opts.onChanged,
  }
  return setmetatable(self, { __index = Select })
end

function Select:selectedId()
  return Save.getSelectedCharacter and Save.getSelectedCharacter() or "amado"
end

function Select:layout(panel)
  self.panel = panel
  local gap = 10
  local cardW = math.floor((panel.w - 40 - gap * 2) / 3)
  local y = panel.y + panel.cardY
  local h = panel.cardH or 54
  self.rects = {}
  for index, id in ipairs(Data.characterOrder) do
    self.rects[#self.rects + 1] = {
      x = panel.x + 20 + (index - 1) * (cardW + gap),
      y = y,
      w = cardW,
      h = h,
      id = id,
    }
  end

  if self.confirm then
    local sw = panel.screenW or 960
    local sh = panel.screenH or 540
    local w, h2 = 440, 170
    local cx = (sw - w) * 0.5
    local cy = (sh - h2) * 0.5
    self.confirm.modal = { x = cx, y = cy, w = w, h = h2 }
    self.confirm.ok = { x = cx + 28, y = cy + 112, w = 170, h = 40 }
    self.confirm.cancel = { x = cx + w - 198, y = cy + 112, w = 170, h = 40 }
  end
end

function Select:request(id)
  if not Data.characters[id] then return end
  if not Save.isCharacterUnlocked(id) then return end
  if id == self:selectedId() then return end
  self.confirm = { id = id }
end

function Select:apply(id)
  if not Save.isCharacterUnlocked(id) then
    self.confirm = nil
    return
  end
  if not Save.setSelectedCharacter(id) then return end
  Audio.playZone(self.getZone(), id, { crossfade = true })
  self.confirm = nil
  if self.onChanged then self.onChanged(id) end
end

function Select:pressed(x, y)
  if self.confirm then
    if Util.inside(x, y, self.confirm.ok) then
      self:apply(self.confirm.id)
      return true
    elseif Util.inside(x, y, self.confirm.cancel) then
      self.confirm = nil
      return true
    end
    self.confirm = nil
    return true
  end
  for _, rect in ipairs(self.rects) do
    if Util.inside(x, y, rect) then
      self:request(rect.id)
      return true
    end
  end
  return false
end

function Select:keypressed(key)
  if self.confirm then
    if key == "escape" or key == "backspace" or key == "n" then
      self.confirm = nil
      return true
    elseif key == "return" or key == "space" or key == "y" then
      self:apply(self.confirm.id)
      return true
    end
    return true
  end
  return false
end

function Select:draw(panel)
  self:layout(panel)
  local theme = Themes.current()
  local selectedId = self:selectedId()

  for _, rect in ipairs(self.rects) do
    local def = Data.characters[rect.id]
    local unlocked = Save.isCharacterUnlocked(rect.id)
    local selected = unlocked and rect.id == selectedId
    local ctheme = Themes.get(rect.id)
    local accent = unlocked and ctheme.accent or theme.dim
    local background = selected and theme.buttonSelected or (unlocked and theme.panelAlt or theme.panel)
    love.graphics.setColor(background[1], background[2], background[3], 0.98)
    love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 8, 8)
    love.graphics.setColor(accent[1], accent[2], accent[3], selected and 1 or 0.55)
    love.graphics.setLineWidth(selected and 3 or 2)
    love.graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, 8, 8)
    love.graphics.setLineWidth(1)

    if unlocked and Portraits and Portraits.character then
      Portraits.character(def, rect.x + 24, rect.y + rect.h * 0.5, 0.24)
    else
      love.graphics.setColor(theme.bg[1], theme.bg[2], theme.bg[3], 0.85)
      love.graphics.circle("fill", rect.x + 24, rect.y + rect.h * 0.5, 12)
      love.graphics.setColor(theme.dim[1], theme.dim[2], theme.dim[3])
      love.graphics.circle("line", rect.x + 24, rect.y + rect.h * 0.5, 12)
    end
    love.graphics.setFont(Fonts.button)
    local nameColor = unlocked and theme.text or theme.muted
    love.graphics.setColor(nameColor[1], nameColor[2], nameColor[3])
    love.graphics.print(def.name, rect.x + 46, rect.y + 8)
    love.graphics.setFont(Fonts.small)
    love.graphics.setColor(theme.muted[1], theme.muted[2], theme.muted[3])
    local hint
    if selected then
      hint = "Seleccionado"
    elseif unlocked then
      hint = "Tocar para elegir"
    else
      hint = "Bloqueado"
    end
    love.graphics.print(hint, rect.x + 46, rect.y + rect.h - 18)
  end

end

function Select:drawConfirm(panel)
  if not self.confirm then return end
  self:layout(panel)
  local theme = Themes.current()
  local modal = self.confirm.modal
  local name = Data.characters[self.confirm.id].name
  local ctheme = Themes.get(self.confirm.id)
  love.graphics.setColor(0, 0, 0, 0.72)
  love.graphics.rectangle("fill", 0, 0, panel.screenW or 960, panel.screenH or 540)
  love.graphics.setColor(theme.panel[1], theme.panel[2], theme.panel[3], 0.99)
  love.graphics.rectangle("fill", modal.x, modal.y, modal.w, modal.h, 10, 10)
  love.graphics.setColor(ctheme.accent[1], ctheme.accent[2], ctheme.accent[3])
  love.graphics.rectangle("line", modal.x, modal.y, modal.w, modal.h, 10, 10)

  love.graphics.setFont(Fonts.button)
  love.graphics.setColor(theme.text[1], theme.text[2], theme.text[3])
  love.graphics.printf(
    "¿Deseas seleccionar a " .. name .. " para la aventura?",
    modal.x + 20, modal.y + 30, modal.w - 40, "center"
  )
  love.graphics.setFont(Fonts.small)
  love.graphics.setColor(theme.muted[1], theme.muted[2], theme.muted[3])
  love.graphics.printf(
    "La interfaz y la música cambiarán de inmediato.",
    modal.x + 20, modal.y + 74, modal.w - 40, "center"
  )

  local function btn(rect, label, accent)
    love.graphics.setColor(theme.button[1], theme.button[2], theme.button[3], 0.98)
    love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 8, 8)
    love.graphics.setColor(accent[1], accent[2], accent[3])
    love.graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, 8, 8)
    love.graphics.setFont(Fonts.button)
    love.graphics.setColor(theme.text[1], theme.text[2], theme.text[3])
    love.graphics.printf(label, rect.x, rect.y + 11, rect.w, "center")
  end

  btn(self.confirm.ok, "OK", ctheme.accent)
  btn(self.confirm.cancel, "CANCELAR", theme.border)
end

return Select
