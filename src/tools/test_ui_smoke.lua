-- test_ui_smoke.lua: dibuja las pantallas nuevas con gráficos simulados.
-- No valida píxeles: detecta campos o llamadas nil en menú, configuración,
-- pausa y panel de pruebas sin necesitar X11 en Termux.
package.path = "./?.lua;" .. package.path

local function rng(seed)
  local state = seed or 1
  return {
    random = function(_, a, b)
      state = (state * 1103515245 + 12345) % 2147483648
      local value = state / 2147483648
      if a and b then
        return math.floor(value * (b - a + 1)) + a
      elseif a then
        return math.floor(value * a) + 1
      end
      return value
    end,
  }
end

local function noop() end
love = {
  math = {
    random = function(a, b)
      if a and b then return a end
      return 0.5
    end,
    newRandomGenerator = rng,
  },
  timer = {
    getTime = function() return 0 end,
  },
  system = {
    getOS = function() return "Linux" end,
  },
  filesystem = {
    getInfo = function() return nil end,
    write = function() return true end,
    remove = function() return true end,
  },
  graphics = {
    setColor = noop,
    rectangle = noop,
    print = noop,
    printf = noop,
    setFont = noop,
    circle = noop,
    line = noop,
    arc = noop,
    polygon = noop,
    setLineWidth = noop,
    push = noop,
    pop = noop,
    translate = noop,
    scale = noop,
    setScissor = noop,
    getDimensions = function() return 960, 540 end,
    newFont = function(size) return { size = size } end,
  },
}

local Screen = require("src.utils.screen")
local Fonts = require("src.utils.fonts")
local Save = require("src.run.save")
local Menu = require("src.estados.menu")
local Config = require("src.estados.config")
local Historia = require("src.estados.historia")
local Infinito = require("src.estados.infinito")
local Personajes = require("src.estados.personajes")
local Bestiario = require("src.estados.bestiario")
local Run = require("src.run.run")
local Sandbox = require("src.run.sandbox")
local Hud = require("src.run.hud")

Screen.resize(960, 540)
Save.load()
Fonts.load()

Menu.enter()
Menu.draw()

Config.enter()
Config.draw()
Config.leave()

Historia.enter("amado")
Historia.draw()
Historia.confirmNew = true
Historia.draw()
Historia.confirmNew = false

Infinito.enter()
Infinito.draw()

Personajes.enter("mar")
Personajes.draw()
Save.data.characters.mar = true
Save.data.progress.mar.resonance = 1
Save.data.progress.mar.upgrades.damage = 2
Personajes.draw()
local upgradeRect = Personajes.upgradeRects[1]
Personajes.pressed(upgradeRect.x + 4, upgradeRect.y + 4)
assert(Save.upgradeLevel("damage", "mar") == 3, "la ficha debe gastar resonancia")

Bestiario.enter()
Bestiario.draw()
Save.data.bestiary.automaton = true
Save.data.bestiary.bone_patriarch = true
Bestiario.selectedId = "bone_patriarch"
Bestiario.draw()

Run.enter("sandbox", "amado")
Run:setPaused(true)
Hud.drawPause(Run)
Run:setPaused(false)

Run.overlay = "sandbox"
Sandbox.reset()
Sandbox.draw(Run)
Run.overlay = nil

print("OK dibujo de menú, historia, configuración, pausa y sala de pruebas")
