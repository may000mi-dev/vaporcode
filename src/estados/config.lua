-- config.lua: audio, tema/personaje global, sala de pruebas y borrado de datos.
local Audio = require("src.utils.audio")
local Fonts = require("src.utils.fonts")
local Rhythm = require("src.run.rhythm")
local Save = require("src.run.save")
local Screen = require("src.utils.screen")
local State = require("src.estados")
local Util = require("src.utils.util")
local Themes = require("src.data.themes")
local CharacterSelect = require("src.ui.character_select")

local Config = {
  rects = {},
  confirmReset = false,
  resetTimer = 0,
  message = nil,
  messageTimer = 0,
  selector = nil,
}

function Config.layout()
  local width = math.min(Screen.width - 50, 820)
  local height = math.min(Screen.height - 20, 520)
  local x = (Screen.width - width) * 0.5
  local y = (Screen.height - height) * 0.5
  Config.panel = { x = x, y = y, w = width, h = height }
  Config.selectorPanel = { x = x, y = y, w = width, cardY = 70, cardH = 48, screenW = Screen.width, screenH = Screen.height }
  if Config.selector then Config.selector:layout(Config.selectorPanel) end

  local buttonW, buttonH = 52, 38
  local right = x + width - 40 - buttonW
  Config.rects.musicMinus = { x = right - 108, y = y + 152, w = buttonW, h = buttonH }
  Config.rects.musicPlus = { x = right, y = y + 152, w = buttonW, h = buttonH }
  Config.rects.effectsMinus = { x = right - 108, y = y + 196, w = buttonW, h = buttonH }
  Config.rects.effectsPlus = { x = right, y = y + 196, w = buttonW, h = buttonH }

  Config.rects.sandbox = { x = x + 40, y = y + 306, w = 340, h = 46 }
  Config.rects.reset = { x = x + 40, y = y + 402, w = 300, h = 44 }
  Config.rects.back = { x = x + width - 220, y = y + height - 54, w = 180, h = 38 }
end

function Config.say(text)
  Config.message = text
  Config.messageTimer = 2.8
end

local function setVolume(kind, value)
  value = math.max(0, math.min(1, value))
  if kind == "music" then
    Audio.setMusicVolume(value)
  else
    Audio.setEffectsVolume(value)
  end
  local settings = Save.data.settings
  settings.musicVolume = Audio.musicVolume
  settings.effectsVolume = Audio.effectsVolume
  Save.setVolumes(Audio.musicVolume, Audio.effectsVolume)
  if kind == "effects" then Rhythm.playPreview() end
end

local function adjustVolume(kind, delta)
  local current = kind == "music" and Audio.musicVolume or Audio.effectsVolume
  local step = math.floor(current * 10 + 0.5) + delta
  setVolume(kind, step / 10)
end

local function resetData()
  if not Config.confirmReset then
    Config.confirmReset = true
    Config.resetTimer = 4
    Config.say("Toca BORRAR DATOS otra vez para confirmar")
    return
  end
  Save.reset()
  Audio.setMusicVolume(Save.data.settings.musicVolume)
  Audio.setEffectsVolume(Save.data.settings.effectsVolume)
  Audio.playZone("config", Save.getSelectedCharacter())
  Config.confirmReset = false
  Config.resetTimer = 0
  Config.say("Datos borrados. El progreso volvió a cero.")
end

function Config.enter()
  Config.confirmReset = false
  Config.resetTimer = 0
  Config.message = nil
  Config.messageTimer = 0
  Config.selector = CharacterSelect.new({
    getZone = function() return "config" end,
  })
  Config.layout()
  Audio.playZone("config", Save.getSelectedCharacter())
end

function Config.leave() end

function Config.update(dt)
  if Config.resetTimer > 0 then
    Config.resetTimer = math.max(0, Config.resetTimer - dt)
    if Config.resetTimer == 0 then Config.confirmReset = false end
  end
  if Config.messageTimer > 0 then
    Config.messageTimer = math.max(0, Config.messageTimer - dt)
    if Config.messageTimer == 0 then Config.message = nil end
  end
end

function Config.keypressed(key, isrepeat)
  if Config.selector and Config.selector:keypressed(key) then return end
  if isrepeat then return end
  if key == "escape" or key == "backspace" then
    State.switch("menu")
  elseif key == "left" then
    adjustVolume("music", -1)
  elseif key == "right" then
    adjustVolume("music", 1)
  elseif key == "down" then
    adjustVolume("effects", -1)
  elseif key == "up" then
    adjustVolume("effects", 1)
  elseif key == "return" or key == "space" then
    State.switch("run", "sandbox", Save.getSelectedCharacter())
  end
end

function Config.pressed(x, y)
  Config.layout()
  if Config.selector and Config.selector:pressed(x, y) then return end
  if Config.selector and Config.selector.confirm then return end
  if Util.inside(x, y, Config.rects.musicMinus) then adjustVolume("music", -1)
  elseif Util.inside(x, y, Config.rects.musicPlus) then adjustVolume("music", 1)
  elseif Util.inside(x, y, Config.rects.effectsMinus) then adjustVolume("effects", -1)
  elseif Util.inside(x, y, Config.rects.effectsPlus) then adjustVolume("effects", 1)
  elseif Util.inside(x, y, Config.rects.sandbox) then
    State.switch("run", "sandbox", Save.getSelectedCharacter())
  elseif Util.inside(x, y, Config.rects.reset) then resetData()
  elseif Util.inside(x, y, Config.rects.back) then State.switch("menu") end
end

function Config.mousepressed(x, y, button)
  if button == 1 then Config.pressed(x, y) end
end
function Config.touchpressed(id, x, y) Config.pressed(x, y) end
function Config.mousemoved(x, y) end
function Config.mousereleased(x, y) end
function Config.touchmoved(id, x, y) end
function Config.touchreleased(id, x, y) end
function Config.focus(focused)
  if focused then Audio.resumeMusic() else Audio.pauseMusic() end
end

local function drawButton(rect, label, accent, selected, theme)
  local bg = selected and theme.buttonSelected or theme.button
  love.graphics.setColor(bg[1], bg[2], bg[3], 0.98)
  love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 8, 8)
  love.graphics.setColor(accent[1], accent[2], accent[3])
  love.graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, 8, 8)
  love.graphics.setFont(Fonts.button)
  love.graphics.setColor(theme.text[1], theme.text[2], theme.text[3])
  love.graphics.printf(label, rect.x, rect.y + 10, rect.w, "center")
end

local function drawVolumeRow(y, label, value, minusRect, plusRect, theme)
  love.graphics.setFont(Fonts.body)
  love.graphics.setColor(theme.text[1], theme.text[2], theme.text[3])
  love.graphics.print(label, Config.panel.x + 40, y + 8)
  local accent = value <= 0 and {0.85,0.35,0.30} or (value < 0.35 and theme.secondary or theme.accent)
  love.graphics.setColor(accent[1], accent[2], accent[3])
  love.graphics.printf(string.format("%d%%", math.floor(value * 100 + 0.5)),
    Config.panel.x + 360, y + 8, 200, "center")
  drawButton(minusRect, "-", accent, false, theme)
  drawButton(plusRect, "+", accent, false, theme)
end

function Config.draw()
  Config.layout()
  local theme = Themes.current()
  local panel = Config.panel

  love.graphics.setColor(theme.bg[1], theme.bg[2], theme.bg[3])
  love.graphics.rectangle("fill", 0, 0, Screen.width, Screen.height)
  love.graphics.setColor(theme.accent[1], theme.accent[2], theme.accent[3], 0.05)
  love.graphics.circle("fill", 30, Screen.height - 20, 150)
  love.graphics.circle("fill", Screen.width - 20, 30, 180)

  love.graphics.setColor(theme.panel[1], theme.panel[2], theme.panel[3], 0.98)
  love.graphics.rectangle("fill", panel.x, panel.y, panel.w, panel.h, 12, 12)
  love.graphics.setColor(theme.border[1], theme.border[2], theme.border[3])
  love.graphics.rectangle("line", panel.x, panel.y, panel.w, panel.h, 12, 12)

  love.graphics.setFont(Fonts.title)
  love.graphics.setColor(theme.accent[1], theme.accent[2], theme.accent[3])
  love.graphics.printf("CONFIGURACIÓN Y PRUEBAS", panel.x, panel.y + 12, panel.w, "center")

  love.graphics.setFont(Fonts.small)
  love.graphics.setColor(theme.muted[1], theme.muted[2], theme.muted[3])
  love.graphics.printf("Personaje global · tema y música sincronizados en tiempo real",
    panel.x, panel.y + 46, panel.w, "center")

  local selectorPanel = {
    x = panel.x, y = panel.y, w = panel.w,
    cardY = 70, cardH = 48,
    screenW = Screen.width, screenH = Screen.height,
  }
  if Config.selector then Config.selector:draw(selectorPanel) end

  love.graphics.setFont(Fonts.button)
  love.graphics.setColor(theme.accent[1], theme.accent[2], theme.accent[3])
  love.graphics.print("Audio", panel.x + 40, panel.y + 130)

  drawVolumeRow(panel.y + 152, "Música", Audio.musicVolume, Config.rects.musicMinus, Config.rects.musicPlus, theme)
  drawVolumeRow(panel.y + 196, "Efectos", Audio.effectsVolume, Config.rects.effectsMinus, Config.rects.effectsPlus, theme)

  love.graphics.setColor(theme.border[1], theme.border[2], theme.border[3], 0.5)
  love.graphics.rectangle("fill", panel.x + 40, panel.y + 246, panel.w - 80, 1)

  love.graphics.setFont(Fonts.button)
  love.graphics.setColor(theme.secondary[1], theme.secondary[2], theme.secondary[3])
  love.graphics.print("Sala de pruebas", panel.x + 40, panel.y + 258)
  love.graphics.setFont(Fonts.small)
  love.graphics.setColor(theme.muted[1], theme.muted[2], theme.muted[3])
  love.graphics.printf(
    "Invoca enemigos y prueba ítems sin guardar monedas, desbloqueos ni récords.",
    panel.x + 40, panel.y + 282, panel.w - 80, "left")
  drawButton(Config.rects.sandbox, "ENTRAR A PROBAR", theme.accent, false, theme)

  love.graphics.setColor(theme.border[1], theme.border[2], theme.border[3], 0.5)
  love.graphics.rectangle("fill", panel.x + 40, panel.y + 366, panel.w - 80, 1)

  love.graphics.setFont(Fonts.button)
  love.graphics.setColor(0.95, 0.55, 0.42)
  love.graphics.print("Datos", panel.x + 40, panel.y + 376)
  drawButton(Config.rects.reset,
    Config.confirmReset and "CONFIRMAR BORRADO" or "BORRAR DATOS",
    Config.confirmReset and {1.00,0.35,0.30} or {0.90,0.55,0.40},
    Config.confirmReset, theme)

  love.graphics.setFont(Fonts.small)
  love.graphics.setColor(theme.muted[1], theme.muted[2], theme.muted[3])
  love.graphics.printf("Borra monedas, mejoras, personajes, récords y ajustes.\nNo se puede deshacer.",
    panel.x + 360, panel.y + 402, panel.w - 400, "left")

  if Config.confirmReset then
    love.graphics.setColor(1.00, 0.55, 0.45)
    love.graphics.printf("Confirmación válida por " .. math.ceil(Config.resetTimer) .. " s",
      panel.x + 40, panel.y + 452, 420, "left")
  elseif Config.message then
    love.graphics.setColor(theme.secondary[1], theme.secondary[2], theme.secondary[3])
    love.graphics.printf(Config.message, panel.x + 40, panel.y + 452, panel.w - 280, "left")
  end

  drawButton(Config.rects.back, "VOLVER", theme.accent, false, theme)

  love.graphics.setFont(Fonts.small)
  love.graphics.setColor(theme.dim[1], theme.dim[2], theme.dim[3])
  love.graphics.printf("Flechas: música ←/→ · efectos ↑/↓ · Enter: probar · Esc: volver",
    panel.x + 40, panel.y + panel.h - 22, panel.w - 280, "left")

  if Config.selector then Config.selector:drawConfirm(selectorPanel) end
end

return Config
