-- personajes.lua: ficha, pasiva, progreso y mejoras permanentes por personaje.
local Data = require("src.run.data")
local Save = require("src.run.save")
local Fonts = require("src.utils.fonts")
local Util = require("src.utils.util")
local Screen = require("src.utils.screen")
local State = require("src.estados")
local Portraits = require("src.utils.portraits")
local TextCache = require("src.utils.textcache")

local Personajes = {
  panel = { x = 0, y = 0, w = 0, h = 0 },
  characterRects = {},
  upgradeRects = {},
  rects = {},
  characterId = "amado",
  message = nil,
  messageTimer = 0,
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
  local width = math.min(Screen.width - 60, 900)
  local height = math.min(Screen.height - 30, 500)
  local x = (Screen.width - width) * 0.5
  local y = (Screen.height - height) * 0.5
  Personajes.panel = { x = x, y = y, w = width, h = height }

  local gap = 12
  local cardW = math.floor((width - 64 - gap * 2) / 3)
  Personajes.characterRects = {}
  for index, id in ipairs(Data.characterOrder) do
    Personajes.characterRects[#Personajes.characterRects + 1] = {
      x = x + 32 + (index - 1) * (cardW + gap),
      y = y + 78,
      w = cardW,
      h = 58,
      id = id,
    }
  end

  Personajes.upgradeRects = {}
  for index, id in ipairs(Data.upgradeOrder) do
    Personajes.upgradeRects[#Personajes.upgradeRects + 1] = {
      x = x + width - 214,
      y = y + 270 + (index - 1) * 54,
      w = 174,
      h = 42,
      id = id,
    }
  end

  Personajes.rects.back = {
    x = x + width - 180,
    y = y + height - 58,
    w = 148,
    h = 40,
  }
end

function Personajes.enter(characterId)
  Personajes.message = nil
  Personajes.messageTimer = 0
  if characterId and Data.characters[characterId] then
    Personajes.characterId = characterId
  end
  Personajes.layout()
end

function Personajes.update(dt)
  if Personajes.messageTimer > 0 then
    Personajes.messageTimer = math.max(0, Personajes.messageTimer - dt)
    if Personajes.messageTimer == 0 then
      Personajes.message = nil
    end
  end
end

local function selected()
  return Data.characters[Personajes.characterId]
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
    Personajes.say(
      TextCache.format(
        "personajes-upgrade",
        "%s de %s subió a nivel %d.",
        def.label,
        character.name,
        level + 1
      )
    )
  end
end

function Personajes.keypressed(key, isrepeat)
  if isrepeat then return end
  if key == "escape" or key == "backspace" then
    State.switch("menu")
  elseif key == "a" or key == "1" then
    Personajes.characterId = Data.characterOrder[1]
  elseif key == "s" or key == "2" then
    Personajes.characterId = Data.characterOrder[2]
  elseif key == "d" or key == "3" then
    Personajes.characterId = Data.characterOrder[3]
  elseif key == "q" or key == "4" then
    upgrade(Data.upgradeOrder[1])
  elseif key == "w" or key == "5" then
    upgrade(Data.upgradeOrder[2])
  elseif key == "e" or key == "6" then
    upgrade(Data.upgradeOrder[3])
  end
end

function Personajes.pressed(x, y)
  Personajes.layout()
  for _, rect in ipairs(Personajes.characterRects) do
    if Util.inside(x, y, rect) then
      Personajes.characterId = rect.id
      return
    end
  end
  for _, rect in ipairs(Personajes.upgradeRects) do
    if Util.inside(x, y, rect) then
      upgrade(rect.id)
      return
    end
  end
  if Util.inside(x, y, Personajes.rects.back) then
    State.switch("menu")
  end
end

function Personajes.mousepressed(x, y, button)
  if button == 1 then Personajes.pressed(x, y) end
end

function Personajes.touchpressed(id, x, y)
  Personajes.pressed(x, y)
end

function Personajes.mousemoved(x, y) end
function Personajes.mousereleased(x, y) end
function Personajes.touchmoved(id, x, y) end
function Personajes.touchreleased(id, x, y) end
function Personajes.focus(focused) end

local function drawCard(rect, selectedCard, accent, unlocked)
  love.graphics.setColor(
    selectedCard and 0.13 or 0.08,
    selectedCard and 0.19 or 0.10,
    selectedCard and 0.24 or 0.14,
    0.97
  )
  love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 8, 8)
  love.graphics.setColor(
    unlocked and accent[1] or 0.34,
    unlocked and accent[2] or 0.38,
    unlocked and accent[3] or 0.42
  )
  love.graphics.setLineWidth(selectedCard and 3 or 2)
  love.graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, 8, 8)
  love.graphics.setLineWidth(1)
end

local function drawUpgradeRow(rect, id, characterId, unlocked)
  local def = Data.upgrades[id]
  local level = Save.upgradeLevel(id, characterId)
  local maxed = level >= def.maxLevel
  local progress = Save.progressFor(characterId)

  love.graphics.setFont(Fonts.body)
  love.graphics.setColor(0.88, 0.92, 0.96)
  love.graphics.print(def.label, rect.x - 292, rect.y + 4)
  love.graphics.setFont(Fonts.small)
  love.graphics.setColor(0.62, 0.70, 0.78)
  love.graphics.print(
    TextCache.format(
      "personajes-level",
      "Nv.%d/%d · %s",
      level,
      def.maxLevel,
      def.desc
    ),
    rect.x - 292,
    rect.y + 23
  )

  local enabled = unlocked and not maxed and progress.resonance > 0
  love.graphics.setColor(enabled and 0.09 or 0.07, enabled and 0.22 or 0.09, enabled and 0.16 or 0.11, 0.98)
  love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 7, 7)
  love.graphics.setColor(
    maxed and 0.45 or (enabled and 0.48 or 0.32),
    maxed and 0.48 or (enabled and 1.00 or 0.38),
    maxed and 0.50 or (enabled and 0.70 or 0.44)
  )
  love.graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, 7, 7)
  love.graphics.setFont(Fonts.small)
  love.graphics.setColor(enabled and 1 or 0.58, enabled and 1 or 0.62, enabled and 1 or 0.68)
  love.graphics.printf(
    unlocked and (maxed and "MÁXIMO" or (enabled and "MEJORAR" or "SIN RESONANCIA"))
      or "BLOQUEADO",
    rect.x,
    rect.y + 14,
    rect.w,
    "center"
  )
end

function Personajes.draw()
  Personajes.layout()
  local panel = Personajes.panel
  local px, py = panel.x, panel.y
  local character = selected()
  if not character then return end

  local unlocked = Save.isCharacterUnlocked(character.id)
  local progress = Save.progressFor(character.id)

  love.graphics.setColor(0.04, 0.05, 0.07)
  love.graphics.rectangle("fill", 0, 0, Screen.width, Screen.height)
  love.graphics.setColor(0.05, 0.07, 0.12)
  love.graphics.circle("fill", 30, Screen.height - 20, 150)
  love.graphics.circle("fill", Screen.width - 20, 30, 180)

  love.graphics.setColor(0.05, 0.07, 0.10, 0.98)
  love.graphics.rectangle("fill", px, py, panel.w, panel.h, 12, 12)
  love.graphics.setColor(0.28, 0.42, 0.56)
  love.graphics.rectangle("line", px, py, panel.w, panel.h, 12, 12)

  love.graphics.setFont(Fonts.title)
  love.graphics.setColor(0.62, 0.84, 1.00)
  love.graphics.printf("PERSONAJES", px, py + 14, panel.w, "center")

  love.graphics.setFont(Fonts.small)
  love.graphics.setColor(0.63, 0.72, 0.80)
  love.graphics.printf(
    TextCache.format(
      "personajes-tower",
      "Historias completadas: %d/%d · La Torre requiere las tres",
      Save.storyCompletionCount(),
      #Data.characterOrder
    ),
    px,
    py + 50,
    panel.w,
    "center"
  )

  for _, rect in ipairs(Personajes.characterRects) do
    local def = Data.characters[rect.id]
    local isUnlocked = Save.isCharacterUnlocked(rect.id)
    drawCard(rect, Personajes.characterId == rect.id, def.color, isUnlocked)
    Portraits.character(def, rect.x + 30, rect.y + 28, 0.30)
    love.graphics.setFont(Fonts.button)
    love.graphics.setColor(isUnlocked and 1 or 0.55, isUnlocked and 1 or 0.58, isUnlocked and 1 or 0.63)
    love.graphics.print(def.name, rect.x + 58, rect.y + 5)
    love.graphics.setFont(Fonts.small)
    love.graphics.setColor(0.66, 0.72, 0.80)
    love.graphics.print(
      isUnlocked and (shortDescription[rect.id] or "") or "Bloqueado",
      rect.x + 58,
      rect.y + 27
    )
  end

  local portrait = { x = px + 32, y = py + 156, w = 248, h = 292 }
  love.graphics.setColor(0.07, 0.09, 0.13, 0.98)
  love.graphics.rectangle("fill", portrait.x, portrait.y, portrait.w, portrait.h, 10, 10)
  love.graphics.setColor(character.color[1], character.color[2], character.color[3], 0.60)
  love.graphics.rectangle("line", portrait.x, portrait.y, portrait.w, portrait.h, 10, 10)

  if unlocked then
    Portraits.character(character, portrait.x + portrait.w * 0.5, portrait.y + 96, 1.35)
  else
    love.graphics.setFont(Fonts.subtitle)
    love.graphics.setColor(0.52, 0.58, 0.66)
    love.graphics.printf("BLOQUEADO", portrait.x, portrait.y + 110, portrait.w, "center")
  end

  love.graphics.setFont(Fonts.title)
  love.graphics.setColor(character.color[1], character.color[2], character.color[3])
  love.graphics.printf(character.name, portrait.x, portrait.y + 208, portrait.w, "center")

  love.graphics.setFont(Fonts.body)
  love.graphics.setColor(0.84, 0.88, 0.94)
  love.graphics.printf(character.desc, portrait.x + 16, portrait.y + 242, portrait.w - 32, "center")

  local infoX = px + 310
  local infoY = py + 156
  love.graphics.setFont(Fonts.button)
  love.graphics.setColor(0.58, 0.86, 1.00)
  love.graphics.print("Estadísticas base", infoX, infoY)

  local stats = {
    { "Daño", Save.stat("damage", character.id) },
    { "Vida máxima", Save.stat("maxHp", character.id) },
    { "Velocidad", Save.stat("speed", character.id) },
  }
  for index, stat in ipairs(stats) do
    love.graphics.setFont(Fonts.body)
    love.graphics.setColor(0.82, 0.88, 0.94)
    love.graphics.print(stat[1], infoX, infoY + 28 + (index - 1) * 24)
    love.graphics.setColor(1.00, 0.86, 0.42)
    love.graphics.printf(
      tostring(stat[2]),
      infoX + 130,
      infoY + 28 + (index - 1) * 24,
      90,
      "right"
    )
  end

  love.graphics.setFont(Fonts.body)
  love.graphics.setColor(0.82, 0.88, 0.94)
  love.graphics.print(
    TextCache.format(
      "personajes-story",
      "Historia: %s",
      Save.isStoryCompleted(character.id) and "completada" or "pendiente"
    ),
    infoX + 250,
    infoY + 28
  )

  love.graphics.setColor(0.55, 0.92, 1.00)
  love.graphics.print(
    TextCache.format(
      "personajes-resonance",
      "Resonancia de %s: %d",
      character.name,
      progress.resonance
    ),
    infoX + 250,
    infoY + 56
  )

  love.graphics.setFont(Fonts.button)
  love.graphics.setColor(0.96, 0.76, 0.34)
  love.graphics.print("Mejoras permanentes", infoX, infoY + 108)
  love.graphics.setFont(Fonts.small)
  love.graphics.setColor(0.62, 0.69, 0.76)
  love.graphics.printf(
    "Cada jefe derrotado deja una resonancia de este personaje.",
    infoX,
    infoY + 132,
    panel.w - 340,
    "left"
  )

  for _, rect in ipairs(Personajes.upgradeRects) do
    drawUpgradeRow(rect, rect.id, Personajes.characterId, unlocked)
  end

  if not unlocked then
    love.graphics.setFont(Fonts.small)
    love.graphics.setColor(0.92, 0.64, 0.42)
    love.graphics.printf(
      TextCache.format(
        "personajes-locked",
        "Encuentra el ítem de %s en un cofre oculto.",
        character.name
      ),
      infoX,
      infoY + 82,
      panel.w - 340,
      "left"
    )
  end

  local back = Personajes.rects.back
  love.graphics.setColor(0.10, 0.13, 0.18, 0.98)
  love.graphics.rectangle("fill", back.x, back.y, back.w, back.h, 8, 8)
  love.graphics.setColor(0.55, 0.72, 0.82)
  love.graphics.rectangle("line", back.x, back.y, back.w, back.h, 8, 8)
  love.graphics.setFont(Fonts.button)
  love.graphics.setColor(0.88, 0.92, 0.96)
  love.graphics.printf("VOLVER", back.x, back.y + 11, back.w, "center")

  if Personajes.message and Personajes.messageTimer > 0 then
    love.graphics.setFont(Fonts.body)
    love.graphics.setColor(1.00, 0.88, 0.48)
    love.graphics.printf(
      Personajes.message,
      px + 20,
      py + panel.h - 76,
      panel.w - 40,
      "center"
    )
  end

  love.graphics.setFont(Fonts.small)
  love.graphics.setColor(0.55, 0.60, 0.68)
  love.graphics.printf(
    "Teclado: A/S/D personaje · Q/W/E mejorar · Esc volver",
    0,
    py + panel.h - 20,
    Screen.width,
    "center"
  )
end

return Personajes
