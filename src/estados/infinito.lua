-- infinito.lua: selección de personaje y mazmorra para el modo Infinito.
local Data = require("src.run.data")
local Save = require("src.run.save")
local Fonts = require("src.utils.fonts")
local Util = require("src.utils.util")
local Screen = require("src.utils.screen")
local TextCache = require("src.utils.textcache")
local State = require("src.estados")
local Portraits = require("src.utils.portraits")

local Infinito = {
  panel = { x = 0, y = 0, w = 0, h = 0 },
  characterRects = {},
  dungeonRects = {},
  rects = {},
  characterId = "amado",
  dungeonId = "cripta",
  message = nil,
  messageTimer = 0,
}

local shortDescription = {
  amado = "Precisión y marca",
  mar = "Golpe y dash",
  amileth = "Cadena y escudo",
}

local function unlockText(dungeon)
  if dungeon.storyUnlock then
    return TextCache.format(
      "inf-tower-unlock",
      "Completa la historia con los tres personajes (%d/%d).",
      Save.storyCompletionCount(),
      #Data.characterOrder
    )
  end
  if not Save.isDungeonUnlocked(dungeon.id) then
    return TextCache.format(
      "inf-unlock",
      "Alcanza el piso %d en Infinito.",
      dungeon.unlockLevel or 1
    )
  end
  return TextCache.format(
    "inf-bpm",
    "Desbloqueada · %s · BPM %d",
    dungeon.song.name,
    dungeon.song.bpm
  )
end

function Infinito.say(text)
  Infinito.message = text
  Infinito.messageTimer = 2.6
end

function Infinito.layout()
  local width = math.min(Screen.width - 60, 900)
  local height = math.min(Screen.height - 30, 500)
  local x = (Screen.width - width) * 0.5
  local y = (Screen.height - height) * 0.5
  Infinito.panel = { x = x, y = y, w = width, h = height }

  local listX = x + 32
  local listY = y + 104
  local listW = math.floor(width * 0.34)
  local characterH = 66
  local characterGap = 8
  Infinito.characterRects = {}
  for index, id in ipairs(Data.characterOrder) do
    Infinito.characterRects[#Infinito.characterRects + 1] = {
      x = listX,
      y = listY + (index - 1) * (characterH + characterGap),
      w = listW,
      h = characterH,
      id = id,
    }
  end

  local dungeonX = listX + listW + 28
  local dungeonW = x + width - 32 - dungeonX
  local dungeonH = 48
  local dungeonGap = 8
  Infinito.dungeonRects = {}
  for index, dungeon in ipairs(Data.dungeons) do
    Infinito.dungeonRects[#Infinito.dungeonRects + 1] = {
      x = dungeonX,
      y = listY + (index - 1) * (dungeonH + dungeonGap),
      w = dungeonW,
      h = dungeonH,
      def = dungeon,
    }
  end

  Infinito.rects.start = {
    x = listX,
    y = y + height - 66,
    w = listW,
    h = 44,
  }
  Infinito.rects.back = {
    x = x + width - 196,
    y = y + height - 66,
    w = 164,
    h = 42,
  }
end

function Infinito.enter()
  Infinito.message = nil
  Infinito.messageTimer = 0
  if not Save.isCharacterUnlocked(Infinito.characterId) then
    Infinito.characterId = "amado"
  end
  if not Save.isDungeonUnlocked(Infinito.dungeonId) then
    Infinito.dungeonId = "cripta"
  end
  Infinito.layout()
end

function Infinito.update(dt)
  if Infinito.messageTimer > 0 then
    Infinito.messageTimer = math.max(0, Infinito.messageTimer - dt)
    if Infinito.messageTimer == 0 then
      Infinito.message = nil
    end
  end
end

local function selectCharacter(id)
  if not Data.characters[id] then return end
  if not Save.isCharacterUnlocked(id) then
    Infinito.say(
      "Encuentra el ítem de " .. Data.characters[id].name .. " en un cofre oculto."
    )
    return
  end
  Infinito.characterId = id
end

local function selectDungeon(id)
  local dungeon = Data.dungeonById[id]
  if not dungeon then return end
  Infinito.dungeonId = id
  if not Save.isDungeonUnlocked(id) then
    Infinito.say(unlockText(dungeon))
  end
end

local function start()
  local dungeon = Data.dungeonById[Infinito.dungeonId]
  if not dungeon then return end
  if not Save.isCharacterUnlocked(Infinito.characterId) then
    Infinito.say("Ese personaje todavía está bloqueado.")
    return
  end
  if not Save.isDungeonUnlocked(dungeon.id) then
    Infinito.say(unlockText(dungeon))
    return
  end
  State.switch("run", dungeon.id, Infinito.characterId, nil, { mode = "free" })
end

function Infinito.keypressed(key, isrepeat)
  if isrepeat then return end
  if key == "escape" or key == "backspace" then
    State.switch("menu")
  elseif key == "return" or key == "space" then
    start()
  elseif key == "a" or key == "1" then
    selectCharacter(Data.characterOrder[1])
  elseif key == "s" or key == "2" then
    selectCharacter(Data.characterOrder[2])
  elseif key == "d" or key == "3" then
    selectCharacter(Data.characterOrder[3])
  elseif key == "q" then
    selectDungeon(Data.dungeons[1].id)
  elseif key == "w" then
    selectDungeon(Data.dungeons[2].id)
  elseif key == "e" then
    selectDungeon(Data.dungeons[3].id)
  elseif key == "r" then
    selectDungeon(Data.dungeons[4].id)
  end
end

function Infinito.pressed(x, y)
  Infinito.layout()
  for _, rect in ipairs(Infinito.characterRects) do
    if Util.inside(x, y, rect) then
      selectCharacter(rect.id)
      return
    end
  end
  for _, rect in ipairs(Infinito.dungeonRects) do
    if Util.inside(x, y, rect) then
      selectDungeon(rect.def.id)
      return
    end
  end
  if Util.inside(x, y, Infinito.rects.start) then
    start()
    return
  end
  if Util.inside(x, y, Infinito.rects.back) then
    State.switch("menu")
  end
end

function Infinito.mousepressed(x, y, button)
  if button == 1 then Infinito.pressed(x, y) end
end

function Infinito.touchpressed(id, x, y)
  Infinito.pressed(x, y)
end

function Infinito.mousemoved(x, y) end
function Infinito.mousereleased(x, y) end
function Infinito.touchmoved(id, x, y) end
function Infinito.touchreleased(id, x, y) end
function Infinito.focus(focused) end

local function drawCard(rect, selected, accent, enabled)
  love.graphics.setColor(
    selected and 0.14 or 0.08,
    selected and 0.20 or 0.11,
    selected and 0.24 or 0.15,
    0.97
  )
  love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 8, 8)
  love.graphics.setColor(
    enabled and accent[1] or 0.32,
    enabled and accent[2] or 0.36,
    enabled and accent[3] or 0.40
  )
  love.graphics.setLineWidth(selected and 3 or 2)
  love.graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, 8, 8)
  love.graphics.setLineWidth(1)
end

function Infinito.draw()
  Infinito.layout()
  local panel = Infinito.panel
  local px, py = panel.x, panel.y

  love.graphics.setColor(0.04, 0.05, 0.07)
  love.graphics.rectangle("fill", 0, 0, Screen.width, Screen.height)
  love.graphics.setColor(0.05, 0.09, 0.09)
  love.graphics.circle("fill", 30, Screen.height - 20, 150)
  love.graphics.circle("fill", Screen.width - 20, 30, 180)

  love.graphics.setColor(0.05, 0.07, 0.09, 0.98)
  love.graphics.rectangle("fill", px, py, panel.w, panel.h, 12, 12)
  love.graphics.setColor(0.25, 0.50, 0.40)
  love.graphics.rectangle("line", px, py, panel.w, panel.h, 12, 12)

  love.graphics.setFont(Fonts.title)
  love.graphics.setColor(0.55, 1.00, 0.78)
  love.graphics.printf("MODO INFINITO", px, py + 14, panel.w, "center")

  love.graphics.setFont(Fonts.small)
  love.graphics.setColor(0.65, 0.74, 0.78)
  love.graphics.printf(
    "Sobrevive piso tras piso. La Torre aparece cuando las tres historias terminan.",
    px,
    py + 50,
    panel.w,
    "center"
  )

  love.graphics.setFont(Fonts.button)
  love.graphics.setColor(0.56, 0.90, 0.72)
  love.graphics.print("Personaje", px + 32, py + 78)
  love.graphics.print("Mazmorra", px + panel.w * 0.34 + 60, py + 78)

  for _, rect in ipairs(Infinito.characterRects) do
    local def = Data.characters[rect.id]
    local unlocked = Save.isCharacterUnlocked(rect.id)
    drawCard(rect, Infinito.characterId == rect.id, def.color, unlocked)
    Portraits.character(def, rect.x + 38, rect.y + 32, 0.42)

    love.graphics.setFont(Fonts.button)
    love.graphics.setColor(unlocked and 1 or 0.55, unlocked and 1 or 0.60, unlocked and 1 or 0.65)
    love.graphics.print(def.name, rect.x + 76, rect.y + 10)
    love.graphics.setFont(Fonts.small)
    love.graphics.setColor(0.70, 0.76, 0.82)
    if unlocked then
      love.graphics.print(shortDescription[rect.id] or def.desc, rect.x + 76, rect.y + 32)
      if Save.isStoryCompleted(rect.id) then
        love.graphics.setColor(0.48, 0.92, 0.66)
        love.graphics.print("Historia completada", rect.x + 76, rect.y + 47)
      end
    else
      love.graphics.print("Bloqueado · búscalo en un cofre oculto", rect.x + 76, rect.y + 34)
    end
  end

  for _, rect in ipairs(Infinito.dungeonRects) do
    local def = rect.def
    local unlocked = Save.isDungeonUnlocked(def.id)
    drawCard(rect, Infinito.dungeonId == def.id, { 0.42, 0.88, 0.70 }, unlocked)

    local boss = Data.enemyTypes[def.boss]
    if boss then
      Portraits.enemy(boss, rect.x + 28, rect.y + rect.h * 0.5, 13, false)
    end

    love.graphics.setFont(Fonts.button)
    love.graphics.setColor(unlocked and 1 or 0.58, unlocked and 1 or 0.62, unlocked and 1 or 0.68)
    love.graphics.print(def.name, rect.x + 54, rect.y + 5)
    love.graphics.setFont(Fonts.small)
    love.graphics.setColor(0.68, 0.75, 0.80)
    love.graphics.print(unlockText(def), rect.x + 54, rect.y + 26)
  end

  local startRect = Infinito.rects.start
  love.graphics.setColor(0.10, 0.24, 0.18, 0.98)
  love.graphics.rectangle("fill", startRect.x, startRect.y, startRect.w, startRect.h, 8, 8)
  love.graphics.setColor(0.50, 1.00, 0.72)
  love.graphics.rectangle("line", startRect.x, startRect.y, startRect.w, startRect.h, 8, 8)
  love.graphics.setFont(Fonts.button)
  love.graphics.setColor(1, 1, 1)
  love.graphics.printf("COMENZAR", startRect.x, startRect.y + 13, startRect.w, "center")

  local backRect = Infinito.rects.back
  love.graphics.setColor(0.10, 0.13, 0.18, 0.98)
  love.graphics.rectangle("fill", backRect.x, backRect.y, backRect.w, backRect.h, 8, 8)
  love.graphics.setColor(0.55, 0.72, 0.82)
  love.graphics.rectangle("line", backRect.x, backRect.y, backRect.w, backRect.h, 8, 8)
  love.graphics.setFont(Fonts.button)
  love.graphics.setColor(0.88, 0.92, 0.96)
  love.graphics.printf("VOLVER", backRect.x, backRect.y + 12, backRect.w, "center")

  if Infinito.message and Infinito.messageTimer > 0 then
    love.graphics.setFont(Fonts.body)
    love.graphics.setColor(1.00, 0.88, 0.48)
    love.graphics.printf(
      Infinito.message,
      px + 20,
      py + panel.h - 100,
      panel.w - 40,
      "center"
    )
  end

  love.graphics.setFont(Fonts.small)
  love.graphics.setColor(0.55, 0.60, 0.68)
  love.graphics.printf(
    "Teclado: A/S/D personaje · Q/W/E/R mazmorra · Enter comenzar · Esc volver",
    0,
    py + panel.h - 20,
    Screen.width,
    "center"
  )
end

return Infinito
