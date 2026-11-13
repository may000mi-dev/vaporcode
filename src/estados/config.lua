-- config.lua: audio, borrado de datos y acceso a la sala de pruebas.
-- Los ajustes se guardan en save.json; la música de esta pantalla es la misma
-- pista procedural del juego para escuchar el volumen mientras se ajusta.
local Audio = require("src.utils.audio")
local Fonts = require("src.utils.fonts")
local Rhythm = require("src.run.rhythm")
local Save = require("src.run.save")
local Screen = require("src.utils.screen")
local State = require("src.estados")
local Util = require("src.utils.util")

local Config = {
  rects = {},
  confirmReset = false,
  resetTimer = 0,
  message = nil,
  messageTimer = 0,
}

local function volumeColor(value)
  if value <= 0.0 then return { 0.85, 0.35, 0.30 } end
  if value < 0.35 then return { 0.95, 0.72, 0.32 } end
  return { 0.45, 0.90, 0.70 }
end

function Config.layout()
  local width = math.min(Screen.width - 80, 780)
  local height = math.min(Screen.height - 40, 480)
  local x = (Screen.width - width) * 0.5
  local y = (Screen.height - height) * 0.5
  Config.panel = { x = x, y = y, w = width, h = height }

  local buttonW, buttonH = 52, 40
  local right = x + width - 40 - buttonW
  Config.rects.musicMinus = { x = right - 108, y = y + 94, w = buttonW, h = buttonH }
  Config.rects.musicPlus = { x = right, y = y + 94, w = buttonW, h = buttonH }
  Config.rects.effectsMinus = { x = right - 108, y = y + 144, w = buttonW, h = buttonH }
  Config.rects.effectsPlus = { x = right, y = y + 144, w = buttonW, h = buttonH }

  Config.rects.sandbox = { x = x + 40, y = y + 254, w = 340, h = 48 }
  Config.rects.reset = { x = x + 40, y = y + 352, w = 300, h = 46 }
  Config.rects.back = { x = x + width - 220, y = y + height - 58, w = 180, h = 40 }
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
  if kind == "music" then
    settings.musicVolume = Audio.musicVolume
  else
    settings.effectsVolume = Audio.effectsVolume
    Rhythm.playPreview()
  end
  Save.setVolumes(Audio.musicVolume, Audio.effectsVolume)
end

local function adjustVolume(kind, delta)
  local current = kind == "music" and Audio.musicVolume or Audio.effectsVolume
  -- Pasos de 10% redondeados para evitar 0.30000000000000004 en pantalla.
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
  Config.confirmReset = false
  Config.resetTimer = 0
  Config.say("Datos borrados. El progreso volvió a cero.")
end

function Config.enter()
  Config.confirmReset = false
  Config.resetTimer = 0
  Config.message = nil
  Config.messageTimer = 0
  Config.layout()
  Audio.startMusic(104)
end

function Config.leave()
  Audio.stopMusic()
end

function Config.update(dt)
  if Config.resetTimer > 0 then
    Config.resetTimer = math.max(0, Config.resetTimer - dt)
    if Config.resetTimer == 0 then
      Config.confirmReset = false
    end
  end
  if Config.messageTimer > 0 then
    Config.messageTimer = math.max(0, Config.messageTimer - dt)
    if Config.messageTimer == 0 then
      Config.message = nil
    end
  end
end

function Config.keypressed(key, isrepeat)
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
    State.switch("run", "sandbox", "amado")
  end
end

function Config.pressed(x, y)
  Config.layout()
  if Util.inside(x, y, Config.rects.musicMinus) then
    adjustVolume("music", -1)
  elseif Util.inside(x, y, Config.rects.musicPlus) then
    adjustVolume("music", 1)
  elseif Util.inside(x, y, Config.rects.effectsMinus) then
    adjustVolume("effects", -1)
  elseif Util.inside(x, y, Config.rects.effectsPlus) then
    adjustVolume("effects", 1)
  elseif Util.inside(x, y, Config.rects.sandbox) then
    State.switch("run", "sandbox", "amado")
  elseif Util.inside(x, y, Config.rects.reset) then
    resetData()
  elseif Util.inside(x, y, Config.rects.back) then
    State.switch("menu")
  end
end

function Config.mousepressed(x, y, button)
  if button == 1 then Config.pressed(x, y) end
end

function Config.touchpressed(id, x, y)
  Config.pressed(x, y)
end

function Config.mousemoved(x, y) end
function Config.mousereleased(x, y) end
function Config.touchmoved(id, x, y) end
function Config.touchreleased(id, x, y) end

function Config.focus(focused)
  if focused then
    Audio.resumeMusic()
  else
    Audio.pauseMusic()
  end
end

local function drawButton(rect, label, accent, selected)
  love.graphics.setColor(
    selected and 0.24 or 0.10,
    selected and 0.14 or 0.16,
    selected and 0.12 or 0.20,
    0.98
  )
  love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 8, 8)
  love.graphics.setColor(accent[1], accent[2], accent[3])
  love.graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, 8, 8)
  love.graphics.setFont(Fonts.button)
  love.graphics.setColor(1, 1, 1)
  love.graphics.printf(label, rect.x, rect.y + 12, rect.w, "center")
end

local function drawVolumeRow(y, label, value, minusRect, plusRect)
  love.graphics.setFont(Fonts.body)
  love.graphics.setColor(0.86, 0.90, 0.95)
  love.graphics.print(label, Config.panel.x + 40, y + 8)

  local color = volumeColor(value)
  love.graphics.setColor(color[1], color[2], color[3])
  love.graphics.printf(
    string.format("%d%%", math.floor(value * 100 + 0.5)),
    Config.panel.x + 360,
    y + 8,
    200,
    "center"
  )

  drawButton(minusRect, "-", color, false)
  drawButton(plusRect, "+", color, false)
end

function Config.draw()
  Config.layout()
  local panel = Config.panel

  love.graphics.setColor(0.04, 0.05, 0.07)
  love.graphics.rectangle("fill", 0, 0, Screen.width, Screen.height)
  love.graphics.setColor(0.06, 0.08, 0.11)
  love.graphics.circle("fill", 30, Screen.height - 20, 150)
  love.graphics.circle("fill", Screen.width - 20, 30, 180)

  love.graphics.setColor(0.05, 0.07, 0.10, 0.98)
  love.graphics.rectangle("fill", panel.x, panel.y, panel.w, panel.h, 12, 12)
  love.graphics.setColor(0.25, 0.45, 0.55)
  love.graphics.rectangle("line", panel.x, panel.y, panel.w, panel.h, 12, 12)

  love.graphics.setFont(Fonts.title)
  love.graphics.setColor(0.55, 0.90, 1.00)
  love.graphics.printf("CONFIGURACIÓN", panel.x, panel.y + 16, panel.w, "center")

  love.graphics.setFont(Fonts.small)
  love.graphics.setColor(0.58, 0.68, 0.76)
  love.graphics.printf(
    "Audio sintetizado en el dispositivo · sin pistas externas",
    panel.x,
    panel.y + 50,
    panel.w,
    "center"
  )

  love.graphics.setFont(Fonts.button)
  love.graphics.setColor(0.70, 0.90, 1.00)
  love.graphics.print("Audio", panel.x + 40, panel.y + 72)

  drawVolumeRow(
    panel.y + 94,
    "Música",
    Audio.musicVolume,
    Config.rects.musicMinus,
    Config.rects.musicPlus
  )
  drawVolumeRow(
    panel.y + 144,
    "Efectos",
    Audio.effectsVolume,
    Config.rects.effectsMinus,
    Config.rects.effectsPlus
  )

  love.graphics.setColor(0.16, 0.22, 0.28)
  love.graphics.rectangle("fill", panel.x + 40, panel.y + 198, panel.w - 80, 1)

  love.graphics.setFont(Fonts.button)
  love.graphics.setColor(0.55, 1.00, 0.72)
  love.graphics.print("Sala de pruebas", panel.x + 40, panel.y + 210)

  love.graphics.setFont(Fonts.small)
  love.graphics.setColor(0.62, 0.72, 0.80)
  love.graphics.printf(
    "Invoca enemigos y prueba ítems sin guardar monedas, desbloqueos ni récords.",
    panel.x + 40,
    panel.y + 232,
    panel.w - 80,
    "left"
  )
  drawButton(Config.rects.sandbox, "ENTRAR A PROBAR", { 0.45, 0.95, 0.65 }, false)

  love.graphics.setColor(0.16, 0.22, 0.28)
  love.graphics.rectangle("fill", panel.x + 40, panel.y + 318, panel.w - 80, 1)

  love.graphics.setFont(Fonts.button)
  love.graphics.setColor(0.95, 0.55, 0.42)
  love.graphics.print("Datos", panel.x + 40, panel.y + 328)

  drawButton(
    Config.rects.reset,
    Config.confirmReset and "CONFIRMAR BORRADO" or "BORRAR DATOS",
    Config.confirmReset and { 1.00, 0.35, 0.30 } or { 0.90, 0.55, 0.40 },
    Config.confirmReset
  )

  love.graphics.setFont(Fonts.small)
  love.graphics.setColor(0.66, 0.72, 0.78)
  love.graphics.printf(
    "Borra monedas, mejoras, personajes, récords y ajustes.\nNo se puede deshacer.",
    panel.x + 360,
    panel.y + 352,
    panel.w - 400,
    "left"
  )

  if Config.confirmReset then
    love.graphics.setColor(1.00, 0.55, 0.45)
    love.graphics.printf(
      "Confirmación válida por " .. math.ceil(Config.resetTimer) .. " s",
      panel.x + 40,
      panel.y + 404,
      420,
      "left"
    )
  elseif Config.message then
    love.graphics.setColor(1.00, 0.88, 0.45)
    love.graphics.printf(
      Config.message,
      panel.x + 40,
      panel.y + 404,
      panel.w - 80,
      "left"
    )
  end

  drawButton(Config.rects.back, "VOLVER", { 0.45, 0.75, 0.90 }, false)

  love.graphics.setFont(Fonts.small)
  love.graphics.setColor(0.55, 0.62, 0.70)
  love.graphics.printf(
    "Flechas: música ←/→ · efectos ↑/↓ · Enter: probar · Esc: volver",
    panel.x + 40,
    panel.y + panel.h - 46,
    panel.w - 280,
    "left"
  )
end

return Config
