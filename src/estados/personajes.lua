-- personajes.lua: ficha y mejoras con selección global sincronizada.
local Data = require("src.run.data")
local Save = require("src.run.save")
local Fonts = require("src.utils.fonts")
local Util = require("src.utils.util")
local Screen = require("src.utils.screen")
local State = require("src.estados")
local Portraits = require("src.utils.portraits")
local TextCache = require("src.utils.textcache")
local Themes = require("src.data.themes")
local Audio = require("src.utils.audio")
local CharacterSelect = require("src.ui.character_select")

local Personajes = {
  panel = { x = 0, y = 0, w = 0, h = 0 },
  upgradeRects = {},
  rects = {},
  message = nil,
  messageTimer = 0,
  selector = nil,
}

local shortDescription = {
  amado = "Precisión y marca",
  mar = "Golpe y dash",
  amileth = "Cadena y escudo",
}

function Personajes.say(text)
  Personajes.message = text
  Personajes.messageTimer = 2.8
end

function Personajes.layout()
  local width = math.min(Screen.width - 40, 920)
  local height = math.min(Screen.height - 20, 520)
  local x = (Screen.width - width) * 0.5
  local y = (Screen.height - height) * 0.5
  Personajes.panel = { x = x, y = y, w = width, h = height }
  Personajes.selectorPanel = { x = x, y = y, w = width, cardY = 68, cardH = 48, screenW = Screen.width, screenH = Screen.height }
  if Personajes.selector then Personajes.selector:layout(Personajes.selectorPanel) end

  Personajes.upgradeRects = {}
  for index, id in ipairs(Data.upgradeOrder) do
    Personajes.upgradeRects[#Personajes.upgradeRects + 1] = {
      x = x + width - 214,
      y = y + 286 + (index - 1) * 54,
      w = 174, h = 42, id = id,
    }
  end
  Personajes.rects.back = { x = x + width - 180, y = y + height - 54, w = 148, h = 38 }
end

function Personajes.enter(characterId)
  Personajes.message = nil
  Personajes.messageTimer = 0
  if characterId and Data.characters[characterId] then
    Save.setSelectedCharacter(characterId)
  end
  Personajes.selector = CharacterSelect.new({ getZone = function() return "menu" end })
  Personajes.layout()
  Audio.playZone("menu", Save.getSelectedCharacter())
end

function Personajes.update(dt)
  if Personajes.messageTimer > 0 then
    Personajes.messageTimer = math.max(0, Personajes.messageTimer - dt)
    if Personajes.messageTimer == 0 then Personajes.message = nil end
  end
end

local function selected()
  return Data.characters[Save.getSelectedCharacter()]
end

local function upgrade(id)
  local def = Data.upgrades[id]
  local character = selected()
  if not character then return end
  if not Save.isCharacterUnlocked(character.id) then
    Personajes.say("Desbloquea a " .. character.name .. " para mejorar su resonancia.")
    return
  end
  local progress = Save.progressFor(character.id)
  local level = progress.upgrades[id] or 0
  if level >= def.maxLevel then
    Personajes.say(def.label .. " ya está al máximo.")
    return
  end
  if progress.resonance <= 0 then
    Personajes.say("Necesitas una resonancia de " .. character.name .. ".")
    return
  end
  if Save.useResonance(character.id, id) then
    Personajes.say(TextCache.format("personajes-upgrade",
      "%s de %s subió a nivel %d.", def.label, character.name, level + 1))
  end
end

function Personajes.keypressed(key, isrepeat)
  if Personajes.selector and Personajes.selector:keypressed(key) then return end
  if isrepeat then return end
  if key == "escape" or key == "backspace" then State.switch("menu")
  elseif key == "q" or key == "1" then upgrade(Data.upgradeOrder[1])
  elseif key == "w" or key == "2" then upgrade(Data.upgradeOrder[2])
  elseif key == "e" or key == "3" then upgrade(Data.upgradeOrder[3]) end
end

function Personajes.pressed(x, y)
  Personajes.layout()
  if Personajes.selector and Personajes.selector:pressed(x, y) then return end
  if Personajes.selector and Personajes.selector.confirm then return end
  for _, rect in ipairs(Personajes.upgradeRects) do
    if Util.inside(x, y, rect) then upgrade(rect.id); return end
  end
  if Util.inside(x, y, Personajes.rects.back) then State.switch("menu") end
end

function Personajes.mousepressed(x, y, button) if button == 1 then Personajes.pressed(x, y) end end
function Personajes.touchpressed(id, x, y) Personajes.pressed(x, y) end
function Personajes.mousemoved() end
function Personajes.mousereleased() end
function Personajes.touchmoved() end
function Personajes.touchreleased() end
function Personajes.focus(focused) if focused then Audio.resumeMusic() end end

local function drawUpgradeRow(rect, id, characterId, unlocked, theme)
  local def = Data.upgrades[id]
  local level = Save.upgradeLevel(id, characterId)
  local maxed = level >= def.maxLevel
  local progress = Save.progressFor(characterId)
  love.graphics.setFont(Fonts.body)
  love.graphics.setColor(theme.text[1], theme.text[2], theme.text[3])
  love.graphics.print(def.label, rect.x - 292, rect.y + 4)
  love.graphics.setFont(Fonts.small)
  love.graphics.setColor(theme.muted[1], theme.muted[2], theme.muted[3])
  love.graphics.print(TextCache.format("personajes-level", "Nv.%d/%d · %s", level, def.maxLevel, def.desc),
    rect.x - 292, rect.y + 23)

  local enabled = unlocked and not maxed and progress.resonance > 0
  love.graphics.setColor(theme.button[1], theme.button[2], theme.button[3], 0.98)
  love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 7, 7)
  love.graphics.setColor(enabled and theme.accent[1] or theme.border[1], enabled and theme.accent[2] or theme.border[2], enabled and theme.accent[3] or theme.border[3])
  love.graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, 7, 7)
  love.graphics.setFont(Fonts.small)
  love.graphics.setColor(theme.text[1], theme.text[2], theme.text[3], enabled and 1 or 0.6)
  love.graphics.printf(
    unlocked and (maxed and "MÁXIMO" or (enabled and "MEJORAR" or "SIN RESONANCIA")) or "BLOQUEADO",
    rect.x, rect.y + 14, rect.w, "center")
end

function Personajes.draw()
  Personajes.layout()
  local theme = Themes.current()
  local panel = Personajes.panel
  local px, py = panel.x, panel.y
  local character = selected()
  if not character then return end
  local ctheme = Themes.get(character.id)
  local unlocked = Save.isCharacterUnlocked(character.id)
  local progress = Save.progressFor(character.id)

  love.graphics.setColor(theme.bg[1], theme.bg[2], theme.bg[3])
  love.graphics.rectangle("fill", 0, 0, Screen.width, Screen.height)
  love.graphics.setColor(ctheme.accent[1], ctheme.accent[2], ctheme.accent[3], 0.05)
  love.graphics.circle("fill", 30, Screen.height - 20, 150)

  love.graphics.setColor(theme.panel[1], theme.panel[2], theme.panel[3], 0.98)
  love.graphics.rectangle("fill", px, py, panel.w, panel.h, 12, 12)
  love.graphics.setColor(theme.border[1], theme.border[2], theme.border[3])
  love.graphics.rectangle("line", px, py, panel.w, panel.h, 12, 12)

  love.graphics.setFont(Fonts.title)
  love.graphics.setColor(theme.accent[1], theme.accent[2], theme.accent[3])
  love.graphics.printf("PERSONAJES", px, py + 12, panel.w, "center")
  love.graphics.setFont(Fonts.small)
  love.graphics.setColor(theme.muted[1], theme.muted[2], theme.muted[3])
  love.graphics.printf("Tarjetas globales · selección sincronizada con menú y pruebas",
    px, py + 46, panel.w, "center")

  local selectorPanel = {
    x = px, y = py, w = panel.w, cardY = 68, cardH = 48,
    screenW = Screen.width, screenH = Screen.height,
  }
  if Personajes.selector then Personajes.selector:draw(selectorPanel) end

  local portrait = { x = px + 32, y = py + 138, w = 248, h = 320 }
  love.graphics.setColor(theme.button[1], theme.button[2], theme.button[3], 0.98)
  love.graphics.rectangle("fill", portrait.x, portrait.y, portrait.w, portrait.h, 10, 10)
  love.graphics.setColor(ctheme.accent[1], ctheme.accent[2], ctheme.accent[3], 0.65)
  love.graphics.rectangle("line", portrait.x, portrait.y, portrait.w, portrait.h, 10, 10)
  if unlocked and Portraits and Portraits.character then
    Portraits.character(character, portrait.x + portrait.w * 0.5, portrait.y + 110, 1.3)
  end
  love.graphics.setFont(Fonts.title)
  love.graphics.setColor(ctheme.accent[1], ctheme.accent[2], ctheme.accent[3])
  love.graphics.printf(character.name, portrait.x, portrait.y + 226, portrait.w, "center")
  love.graphics.setFont(Fonts.small)
  love.graphics.setColor(theme.muted[1], theme.muted[2], theme.muted[3])
  love.graphics.printf(shortDescription[character.id] or character.desc, portrait.x + 12, portrait.y + 260, portrait.w - 24, "center")
  love.graphics.setFont(Fonts.body)
  love.graphics.setColor(theme.text[1], theme.text[2], theme.text[3])
  love.graphics.printf(character.desc, portrait.x + 16, portrait.y + 278, portrait.w - 32, "center")

  local infoX = px + 310
  local infoY = py + 138
  love.graphics.setFont(Fonts.button)
  love.graphics.setColor(theme.accent[1], theme.accent[2], theme.accent[3])
  love.graphics.print("Estadísticas base", infoX, infoY)
  local stats = {
    { "Daño", Save.stat("damage", character.id) },
    { "Vida máxima", Save.stat("maxHp", character.id) },
    { "Velocidad", Save.stat("speed", character.id) },
  }
  for index, stat in ipairs(stats) do
    love.graphics.setFont(Fonts.body)
    love.graphics.setColor(theme.text[1], theme.text[2], theme.text[3])
    love.graphics.print(stat[1], infoX, infoY + 28 + (index - 1) * 24)
    love.graphics.setColor(theme.secondary[1], theme.secondary[2], theme.secondary[3])
    love.graphics.printf(tostring(stat[2]), infoX + 130, infoY + 28 + (index - 1) * 24, 90, "right")
  end
  love.graphics.setColor(theme.text[1], theme.text[2], theme.text[3])
  love.graphics.print(TextCache.format("personajes-story", "Historia: %s",
    Save.isStoryCompleted(character.id) and "completada" or "pendiente"), infoX + 250, infoY + 28)
  love.graphics.setColor(theme.accent[1], theme.accent[2], theme.accent[3])
  love.graphics.print(TextCache.format("personajes-resonance", "Resonancia de %s: %d",
    character.name, progress.resonance), infoX + 250, infoY + 56)

  love.graphics.setFont(Fonts.button)
  love.graphics.setColor(theme.secondary[1], theme.secondary[2], theme.secondary[3])
  love.graphics.print("Mejoras permanentes", infoX, infoY + 122)
  love.graphics.setFont(Fonts.small)
  love.graphics.setColor(theme.muted[1], theme.muted[2], theme.muted[3])
  love.graphics.printf("Cada jefe derrotado deja una resonancia de este personaje.",
    infoX, infoY + 146, panel.w - 340, "left")

  for _, rect in ipairs(Personajes.upgradeRects) do
    drawUpgradeRow(rect, rect.id, character.id, unlocked, theme)
  end

  local back = Personajes.rects.back
  love.graphics.setColor(theme.button[1], theme.button[2], theme.button[3], 0.98)
  love.graphics.rectangle("fill", back.x, back.y, back.w, back.h, 8, 8)
  love.graphics.setColor(theme.border[1], theme.border[2], theme.border[3])
  love.graphics.rectangle("line", back.x, back.y, back.w, back.h, 8, 8)
  love.graphics.setFont(Fonts.button)
  love.graphics.setColor(theme.text[1], theme.text[2], theme.text[3])
  love.graphics.printf("VOLVER", back.x, back.y + 10, back.w, "center")

  if Personajes.message and Personajes.messageTimer > 0 then
    love.graphics.setFont(Fonts.body)
    love.graphics.setColor(theme.secondary[1], theme.secondary[2], theme.secondary[3])
    love.graphics.printf(Personajes.message, px + 20, py + panel.h - 74, panel.w - 40, "center")
  end

  love.graphics.setFont(Fonts.small)
  love.graphics.setColor(theme.dim[1], theme.dim[2], theme.dim[3])
  love.graphics.printf("Q/W/E mejorar · Esc volver", 0, py + panel.h - 18, Screen.width, "center")

  if Personajes.selector then Personajes.selector:drawConfirm(selectorPanel) end
end

return Personajes
