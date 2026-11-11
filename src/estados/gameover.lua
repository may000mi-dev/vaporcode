-- gameover.lua: resumen de la partida y opciones de reintento.
local Fonts = require("src.utils.fonts")
local Save = require("src.run.save")
local State = require("src.estados")
local Util = require("src.utils.util")

local Gameover = {
  info = nil,
  rects = {
    retry = { x = 500, y = 386, w = 180, h = 54 },
    menu = { x = 280, y = 386, w = 180, h = 54 },
  },
}

local function retry()
  if Gameover.info.snapshot then
    State.switch("run", Gameover.info.snapshot)
    return
  end

  State.switch(
    "run",
    Gameover.info.dungeonId or "cripta",
    Gameover.info.characterId,
    Gameover.info.abilityId
  )
end

local function chooseAt(x, y)
  if Util.inside(x, y, Gameover.rects.retry) then
    retry()
  elseif Util.inside(x, y, Gameover.rects.menu) then
    State.switch("menu")
  end
end

local function drawButton(rect, label, accent)
  love.graphics.setColor(
    accent[1] * 0.18,
    accent[2] * 0.18,
    accent[3] * 0.18,
    0.95
  )
  love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 8, 8)

  love.graphics.setColor(accent[1], accent[2], accent[3])
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, 8, 8)
  love.graphics.setLineWidth(1)

  love.graphics.setFont(Fonts.button)
  love.graphics.setColor(1, 1, 1)
  love.graphics.printf(label, rect.x, rect.y + 17, rect.w, "center")
end

function Gameover.enter(info)
  Gameover.info = info or {
    level = 1,
    playerLevel = 1,
    kills = 0,
    coins = Save.data.coins,
    dungeon = "Cripta de latón",
    dungeonId = "cripta",
    character = "Amado",
    characterId = "amado",
    ability = "Resonancia",
    abilityId = "resonance",
    reason = "death",
  }
end

function Gameover.keypressed(key, isrepeat)
  if isrepeat then return end

  if key == "return" or key == "space" then
    retry()
  elseif key == "escape" or key == "m" then
    State.switch("menu")
  end
end

function Gameover.mousepressed(x, y, button)
  if button == 1 then
    chooseAt(x, y)
  end
end

function Gameover.touchpressed(id, x, y)
  chooseAt(x, y)
end

function Gameover.mousereleased(x, y) end
function Gameover.mousemoved(x, y) end
function Gameover.touchmoved(id, x, y) end
function Gameover.touchreleased(id, x, y) end
function Gameover.focus(focused) end

function Gameover.draw()
  local info = Gameover.info

  love.graphics.setColor(0, 0, 0, 0.72)
  love.graphics.rectangle("fill", 0, 0, 960, 540)

  love.graphics.setColor(0.07, 0.08, 0.11, 0.98)
  love.graphics.rectangle("fill", 200, 100, 560, 350, 12, 12)
  love.graphics.setColor(0.45, 0.20, 0.20)
  love.graphics.rectangle("line", 200, 100, 560, 350, 12, 12)

  local timeout = info.reason == "timeout"
  love.graphics.setFont(Fonts.title)
  love.graphics.setColor(0.95, 0.40, 0.35)
  love.graphics.printf(timeout and "TIEMPO AGOTADO" or "DERROTA", 200, 130, 560, "center")

  love.graphics.setFont(Fonts.body)
  love.graphics.setColor(0.82, 0.86, 0.92)
  if timeout then
    love.graphics.printf(
      "No eliminaste a todos los enemigos a tiempo.",
      240,
      178,
      480,
      "center"
    )
  end
  love.graphics.printf("Mazmorra: " .. info.dungeon, 240, 204, 480, "center")
  love.graphics.printf(
    "Personaje: " .. (info.character or "Amado")
      .. " · " .. (info.ability or "Resonancia"),
    240,
    232,
    480,
    "center"
  )
  love.graphics.printf(
    "Piso alcanzado: " .. info.level .. " · Nv." .. (info.playerLevel or 1),
    240,
    260,
    480,
    "center"
  )
  love.graphics.printf("Enemigos derrotados: " .. info.kills, 240, 288, 480, "center")
  love.graphics.printf("Monedas totales: " .. info.coins, 240, 316, 480, "center")

  love.graphics.setFont(Fonts.small)
  love.graphics.setColor(0.65, 0.70, 0.78)
  if info.snapshot then
    love.graphics.printf(
      "Reintentar restaura el inicio exacto de este piso.",
      240,
      348,
      480,
      "center"
    )
  else
    love.graphics.printf(
      "Las monedas y las mejoras permanentes se conservan.",
      240,
      348,
      480,
      "center"
    )
  end

  drawButton(Gameover.rects.menu, "MENÚ", { 0.45, 0.70, 0.85 })
  drawButton(Gameover.rects.retry, "REINTENTAR", { 0.90, 0.65, 0.30 })

  love.graphics.setFont(Fonts.small)
  love.graphics.setColor(0.55, 0.60, 0.68)
  love.graphics.printf("Enter reintentar · Esc menú", 0, 470, 960, "center")
end

return Gameover
