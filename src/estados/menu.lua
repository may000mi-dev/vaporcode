-- menu.lua: selección de personaje, habilidad, mazmorra y mejoras.
local Data = require("src.run.data")
local Save = require("src.run.save")
local Fonts = require("src.utils.fonts")
local Util = require("src.utils.util")
local State = require("src.estados")

local Menu = {
  dungeonRects = {},
  upgradeRects = {},
  characterRects = {},
  characterId = "amado",
  selectedDungeonId = "cripta",
  message = nil,
  messageTimer = 0,
}

local function drawButton(rect, label, sub, enabled, selected, accent)
  if selected then
    love.graphics.setColor(0.16, 0.22, 0.24, 0.98)
  elseif enabled then
    love.graphics.setColor(0.13, 0.20, 0.25, 0.95)
  else
    love.graphics.setColor(0.09, 0.11, 0.13, 0.95)
  end
  love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 8, 8)

  if selected then
    love.graphics.setColor(1.00, 0.82, 0.32)
  elseif enabled and accent then
    love.graphics.setColor(accent[1], accent[2], accent[3])
  elseif enabled then
    love.graphics.setColor(0.45, 0.80, 0.85)
  else
    love.graphics.setColor(0.25, 0.35, 0.40)
  end
  love.graphics.setLineWidth(selected and 3 or 2)
  love.graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, 8, 8)
  love.graphics.setLineWidth(1)

  love.graphics.setFont(Fonts.button)
  if enabled then
    love.graphics.setColor(1, 1, 1)
  else
    love.graphics.setColor(0.55, 0.60, 0.65)
  end
  love.graphics.print(label, rect.x + 14, rect.y + 6)

  love.graphics.setFont(Fonts.small)
  love.graphics.setColor(0.70, 0.76, 0.82)
  love.graphics.print(sub, rect.x + 14, rect.y + rect.h - 20)
end

local function tryStart(def)
  if not Save.isCharacterUnlocked(Menu.characterId) then
    Menu.characterId = "amado"
  end
  Menu.selectedDungeonId = def.id
  if not Save.data.unlocked[def.id] then
    Menu.say(
      "Necesitas alcanzar el piso "
        .. def.unlockLevel
        .. " para desbloquear "
        .. def.name
        .. "."
    )
    return
  end
  State.switch("run", def.id, Menu.characterId)
end

local function buy(id)
  local def = Data.upgrades[id]
  if Save.buy(id) then
    Menu.say(def.label .. " mejorada a nivel " .. Save.data.upgrades[id] .. ".")
    return
  end

  if Save.data.upgrades[id] >= def.maxLevel then
    Menu.say(def.label .. " ya está al máximo.")
  else
    Menu.say("Monedas insuficientes para " .. def.label .. ".")
  end
end

local function selectCharacter(id)
  if not Data.characters[id] then return end
  if not Save.isCharacterUnlocked(id) then
    Menu.say("Encuentra el ítem de " .. Data.characters[id].name .. " en un cofre oculto.")
    return
  end
  Menu.characterId = id
end

function Menu.say(text)
  Menu.message = text
  Menu.messageTimer = 2.4
end

function Menu.enter()
  Menu.message = nil
  Menu.messageTimer = 0

  if not Data.characters[Menu.characterId]
    or not Save.isCharacterUnlocked(Menu.characterId) then
    Menu.characterId = "amado"
  end
  Menu.characterRects = {}
  local y = 132
  for _, id in ipairs(Data.characterOrder) do
    Menu.characterRects[#Menu.characterRects + 1] = {
      x = 48,
      y = y,
      w = 404,
      h = 50,
      id = id,
    }
    y = y + 56
  end

  Menu.dungeonRects = {}
  y = 326
  for _, dungeon in ipairs(Data.dungeons) do
    Menu.dungeonRects[#Menu.dungeonRects + 1] = {
      x = 48,
      y = y,
      w = 404,
      h = 46,
      def = dungeon,
    }
    y = y + 54
  end

  Menu.upgradeRects = {}
  y = 154
  for _, id in ipairs(Data.upgradeOrder) do
    Menu.upgradeRects[#Menu.upgradeRects + 1] = {
      x = 508,
      y = y,
      w = 404,
      h = 50,
      id = id,
    }
    y = y + 58
  end
end

function Menu.update(dt)
  if Menu.messageTimer > 0 then
    Menu.messageTimer = math.max(0, Menu.messageTimer - dt)
    if Menu.messageTimer == 0 then
      Menu.message = nil
    end
  end
end

function Menu.keypressed(key, isrepeat)
  if isrepeat then return end

  if key == "1" then
    tryStart(Data.dungeons[1])
  elseif key == "2" then
    tryStart(Data.dungeons[2])
  elseif key == "3" then
    tryStart(Data.dungeons[3])
  elseif key == "a" then
    selectCharacter(Data.characterOrder[1])
  elseif key == "s" then
    selectCharacter(Data.characterOrder[2])
  elseif key == "d" then
    selectCharacter(Data.characterOrder[3])
  elseif key == "q" then
    buy("damage")
  elseif key == "w" then
    buy("maxHp")
  elseif key == "e" then
    buy("speed")
  elseif key == "return" or key == "space" then
    tryStart(Data.dungeonById[Menu.selectedDungeonId] or Data.dungeons[1])
  end
end

function Menu.mousepressed(x, y, button)
  if button ~= 1 then return end

  for _, rect in ipairs(Menu.characterRects) do
    if Util.inside(x, y, rect) then
      selectCharacter(rect.id)
      return
    end
  end

  for _, rect in ipairs(Menu.dungeonRects) do
    if Util.inside(x, y, rect) then
      tryStart(rect.def)
      return
    end
  end

  for _, rect in ipairs(Menu.upgradeRects) do
    if Util.inside(x, y, rect) then
      buy(rect.id)
      return
    end
  end
end

function Menu.touchpressed(id, x, y)
  Menu.mousepressed(x, y, 1)
end

function Menu.mousemoved(x, y) end
function Menu.mousereleased(x, y) end
function Menu.touchmoved(id, x, y) end
function Menu.touchreleased(id, x, y) end
function Menu.focus(focused) end

function Menu.draw()
  love.graphics.setColor(0.04, 0.05, 0.07)
  love.graphics.rectangle("fill", 0, 0, 960, 540)

  love.graphics.setColor(0.06, 0.08, 0.11)
  love.graphics.circle("fill", 20, 520, 130)
  love.graphics.circle("fill", 950, 20, 150)

  love.graphics.setFont(Fonts.title)
  love.graphics.setColor(0.55, 0.90, 1.00)
  love.graphics.printf("ROGUELIKE STEAMPUNK MUSICAL", 0, 16, 960, "center")

  love.graphics.setFont(Fonts.subtitle)
  love.graphics.setColor(0.72, 0.78, 0.85)
  love.graphics.printf("May000mi · Prototipo LÖVE 11.5 · V5", 0, 54, 960, "center")

  love.graphics.setFont(Fonts.small)
  love.graphics.setColor(0.55, 0.85, 0.95)
  love.graphics.print("Récord: piso " .. Save.data.bestLevel, 24, 18)

  love.graphics.setColor(1.00, 0.85, 0.35)
  love.graphics.printf("Monedas: " .. Save.data.coins, 620, 18, 316, "right")

  love.graphics.setColor(0.07, 0.09, 0.12, 0.95)
  love.graphics.rectangle("fill", 28, 96, 444, 420, 10, 10)
  love.graphics.rectangle("fill", 488, 96, 444, 420, 10, 10)
  love.graphics.setColor(0.18, 0.22, 0.28)
  love.graphics.rectangle("line", 28, 96, 444, 420, 10, 10)
  love.graphics.rectangle("line", 488, 96, 444, 420, 10, 10)

  love.graphics.setFont(Fonts.button)
  love.graphics.setColor(0.60, 0.90, 1.00)
  love.graphics.print("Personaje", 48, 108)
  love.graphics.print("Mazmorras", 48, 302)
  love.graphics.print("Mejoras permanentes", 508, 108)

  for _, rect in ipairs(Menu.characterRects) do
    local def = Data.characters[rect.id]
    local unlocked = Save.isCharacterUnlocked(rect.id)
    local sub = def.desc
    if not unlocked then
      sub = "Bloqueado · búscalo en un cofre oculto"
    end
    drawButton(
      rect,
      def.name,
      sub,
      unlocked,
      Menu.characterId == rect.id,
      def.color
    )
  end

  for _, rect in ipairs(Menu.dungeonRects) do
    local def = rect.def
    local unlocked = Save.data.unlocked[def.id]
    local sub
    if unlocked then
      sub = "Desbloqueada · BPM " .. def.song.bpm
    else
      sub = "Bloqueada · alcanza el piso " .. def.unlockLevel
    end
    drawButton(rect, def.name, sub, unlocked, Menu.selectedDungeonId == def.id)
  end

  for _, rect in ipairs(Menu.upgradeRects) do
    local def = Data.upgrades[rect.id]
    local level = Save.data.upgrades[rect.id]
    local sub
    if level >= def.maxLevel then
      sub = "Nivel máximo · " .. def.desc
    else
      sub = string.format(
        "Nv.%d · Costo %d · %s",
        level,
        Save.upgradeCost(rect.id),
        def.desc
      )
    end
    drawButton(rect, def.label, sub, Save.canBuy(rect.id), false)
  end

  love.graphics.setFont(Fonts.small)
  love.graphics.setColor(0.60, 0.70, 0.78)
  love.graphics.printf(
    "A1/A2 se encuentran como ítems y se asignan desde la mochila. Escudo y Turbo siempre están activos.",
    508,
    356,
    404,
    "center"
  )

  if Menu.message and Menu.messageTimer > 0 then
    love.graphics.setFont(Fonts.body)
    love.graphics.setColor(1.00, 0.90, 0.50)
    love.graphics.printf(Menu.message, 0, 496, 960, "center")
  end

  love.graphics.setFont(Fonts.small)
  love.graphics.setColor(0.55, 0.60, 0.68)
  love.graphics.printf(
    "Toca personaje y mazmorra. Teclado: 1-3 mazmorra · A/S/D personaje · Q/W/E mejoras · Enter inicia",
    0,
    522,
    960,
    "center"
  )
end

return Menu
