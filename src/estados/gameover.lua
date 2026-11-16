-- gameover.lua: resumen de la partida y opciones de reintento.
local Fonts = require("src.utils.fonts")
local Save = require("src.run.save")
local State = require("src.estados")
local Util = require("src.utils.util")
local TextCache = require("src.utils.textcache")
local Screen = require("src.utils.screen")
local Themes = require("src.data.themes")

local Gameover = {
  info = nil,
  panel = { x = 200, y = 100, w = 560, h = 350 },
  rects = {
    retry = { x = 500, y = 386, w = 180, h = 54 },
    menu = { x = 280, y = 386, w = 180, h = 54 },
  },
}

-- Centra el panel de derrota en el área visible actual.
function Gameover.layout()
  local panel = Gameover.panel
  panel.x = (Screen.width - panel.w) * 0.5
  panel.y = (Screen.height - panel.h) * 0.5

  Gameover.rects.menu.x = panel.x + 80
  Gameover.rects.menu.y = panel.y + 286
  Gameover.rects.retry.x = panel.x + 300
  Gameover.rects.retry.y = panel.y + 286
end

local function retry()
  if Gameover.info.snapshot then
    State.switch("run", Gameover.info.snapshot)
    return
  end

  if Gameover.info.mode == "story" then
    State.switch(
      "run",
      Gameover.info.dungeonId or "cripta",
      Gameover.info.characterId,
      nil,
      { resume = true }
    )
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
  Gameover.layout()
  if Util.inside(x, y, Gameover.rects.retry) then
    retry()
  elseif Util.inside(x, y, Gameover.rects.menu) then
    State.switch("menu")
  end
end

local function drawButton(rect, label, accent, theme)
  love.graphics.setColor(theme.button[1], theme.button[2], theme.button[3], 0.95)
  love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 8, 8)

  love.graphics.setColor(accent[1], accent[2], accent[3])
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, 8, 8)
  love.graphics.setLineWidth(1)

  love.graphics.setFont(Fonts.button)
  love.graphics.setColor(theme.text[1], theme.text[2], theme.text[3])
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
  Gameover.layout()
  local theme = Themes.current()
  local info = Gameover.info
  local panel = Gameover.panel
  local px, py = panel.x, panel.y

  love.graphics.setColor(0, 0, 0, 0.72)
  love.graphics.rectangle("fill", 0, 0, Screen.width, Screen.height)

  love.graphics.setColor(theme.panel[1], theme.panel[2], theme.panel[3], 0.98)
  love.graphics.rectangle("fill", px, py, panel.w, panel.h, 12, 12)
  love.graphics.setColor(theme.border[1], theme.border[2], theme.border[3])
  love.graphics.rectangle("line", px, py, panel.w, panel.h, 12, 12)

  local timeout = info.reason == "timeout"
  local critical = info.reason == "boss_enrage"
  local story = info.mode == "story"
  local title
  if critical then
    title = "SOBRECARGA CRÍTICA"
  elseif story then
    title = timeout and "EL NÚCLEO CEDE" or "LA MELODÍA SE CORTA"
  else
    title = timeout and "TIEMPO AGOTADO" or "DERROTA"
  end

  love.graphics.setFont(Fonts.title)
  love.graphics.setColor(theme.accent[1], theme.accent[2], theme.accent[3])
  love.graphics.printf(title, px, py + 30, panel.w, "center")

  love.graphics.setFont(Fonts.body)
  love.graphics.setColor(theme.text[1], theme.text[2], theme.text[3])
  if critical then
    love.graphics.printf(
      "La memoria del jefe desbordó los 3 minutos. La sala colapsó.",
      px + 40,
      py + 78,
      480,
      "center"
    )
  elseif timeout then
    love.graphics.printf(
      story and "El núcleo se desestabilizó. Mar y Amileth siguen esperando."
        or "No eliminaste a todos los enemigos a tiempo.",
      px + 40,
      py + 78,
      480,
      "center"
    )
  elseif story then
    love.graphics.printf(
      "La sustancia negra te alcanzó. El siguiente compás aún es tuyo.",
      px + 40,
      py + 78,
      480,
      "center"
    )
  end
  love.graphics.printf(TextCache.format("go-dungeon", "Mazmorra: %s", info.dungeon), px + 40, py + 104, 480, "center")
  love.graphics.printf(
    TextCache.format(
      "go-character",
      "Personaje: %s · %s",
      info.character or "Amado",
      info.ability or "Resonancia"
    ),
    px + 40,
    py + 132,
    480,
    "center"
  )
  love.graphics.printf(
    TextCache.format("go-floor", "Piso alcanzado: %d · Nv.%d", info.level, info.playerLevel or 1),
    px + 40,
    py + 160,
    480,
    "center"
  )
  love.graphics.printf(TextCache.format("go-kills", "Enemigos derrotados: %d", info.kills), px + 40, py + 188, 480, "center")
  love.graphics.printf(TextCache.format("go-coins", "Monedas totales: %d", info.coins), px + 40, py + 216, 480, "center")

  love.graphics.setFont(Fonts.small)
  love.graphics.setColor(theme.muted[1], theme.muted[2], theme.muted[3])
  if info.snapshot then
    love.graphics.printf(
      story and "Reintentar recupera el checkpoint de este piso."
        or "Reintentar restaura el inicio exacto de este piso.",
      px + 40,
      py + 248,
      480,
      "center"
    )
  else
    love.graphics.printf(
      "Las monedas y las mejoras permanentes se conservan.",
      px + 40,
      py + 248,
      480,
      "center"
    )
  end

  drawButton(Gameover.rects.menu, "MENÚ", theme.accent, theme)
  drawButton(
    Gameover.rects.retry,
    story and "REINTENTAR PISO" or "REINTENTAR",
    theme.secondary,
    theme
  )

  love.graphics.setFont(Fonts.small)
  love.graphics.setColor(theme.dim[1], theme.dim[2], theme.dim[3])
  love.graphics.printf("Enter reintentar · Esc menú", 0, Screen.height - 70, Screen.width, "center")
end

Gameover.layout()

return Gameover
