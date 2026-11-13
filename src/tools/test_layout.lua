-- test_layout.lua: resolución adaptable y UI anclada al tamaño visible.
package.path = "./?.lua;" .. package.path

love = {
  math = {
    random = function(a, b)
      if a and b then return a end
      return 0.5
    end,
  },
  timer = {
    getTime = function()
      return 0
    end,
  },
  filesystem = {
    getInfo = function()
      return nil
    end,
    write = function()
      return true
    end,
  },
}

local noop = function() end
love.graphics = {
  setColor = noop,
  rectangle = noop,
  print = noop,
  printf = noop,
  setFont = noop,
  circle = noop,
  setLineWidth = noop,
}

local Screen = require("src.utils.screen")
local Camera = require("src.utils.camera")
local Data = require("src.run.data")
local Save = require("src.run.save")
local Hud = require("src.run.hud")
local Buttons = require("src.utils.buttons")
local Backpack = require("src.run.backpack")
local Shop = require("src.run.shop")
local Menu = require("src.estados.menu")
local Gameover = require("src.estados.gameover")
local Config = require("src.estados.config")
local Sandbox = require("src.run.sandbox")

Save.load()

local function insideScreen(rect, width, height)
  return rect.x >= 0
    and rect.y >= 0
    and rect.x + rect.w <= width + 0.001
    and rect.y + rect.h <= height + 0.001
end

local function checkWide(width, height, expectedWidth, expectedScale)
  Screen.resize(width, height)
  assert(
    math.abs(Screen.width - expectedWidth) < 0.001,
    "ancho virtual incorrecto para " .. width .. "x" .. height
  )
  assert(math.abs(Screen.height - 540) < 0.001, "la altura virtual debe ser 540")
  assert(math.abs(Screen.scale - expectedScale) < 0.001, "escala incorrecta")
  assert(math.abs(Screen.ox) < 0.001 and math.abs(Screen.oy) < 0.001, "no debe haber barras")

  assert(math.abs(Screen.toVirtualX(0)) < 0.001, "borde izquierdo mal mapeado")
  assert(
    math.abs(Screen.toVirtualX(width) - Screen.width) < 0.001,
    "borde derecho mal mapeado"
  )
  assert(math.abs(Screen.toVirtualY(height) - 540) < 0.001, "borde inferior mal mapeado")

  -- Todos los botones táctiles deben quedar dentro del área visible.
  Hud.layout()
  for _, rect in ipairs({
    Hud.pauseButton,
    Hud.backpackButton,
    Hud.shopButton,
    Hud.sandboxButton,
  }) do
    assert(insideScreen(rect, Screen.width, Screen.height), "botón del HUD fuera de pantalla")
  end
  assert(
    insideScreen(Hud.pauseExitRect(), Screen.width, Screen.height),
    "botón de salir en pausa fuera de pantalla"
  )
  for index = 1, Data.inventory.maxActive do
    assert(
      insideScreen(Hud.inventoryRect(index), Screen.width, Screen.height),
      "franja de inventario fuera de pantalla"
    )
  end

  assert(
    Camera.beginDrag(1, Screen.width * 0.5, Screen.height * 0.5),
    "el arrastre central debe funcionar en cualquier aspecto"
  )
  Camera.endDrag(1)

  local buttons = Buttons.new()
  for _, button in ipairs(buttons.items) do
    assert(button.x - button.r >= 0, "habilidad fuera por la izquierda")
    assert(button.x + button.r <= Screen.width, "habilidad fuera por la derecha")
    assert(button.y - button.r >= 0, "habilidad fuera por arriba")
    assert(button.y + button.r <= Screen.height, "habilidad fuera por abajo")
  end

  Backpack.layout()
  assert(
    insideScreen(Backpack.panel, Screen.width, Screen.height),
    "panel de mochila fuera de pantalla"
  )
  assert(
    insideScreen(Backpack.closeButton, Screen.width, Screen.height),
    "cerrar mochila fuera de pantalla"
  )
  for index = 1, 4 do
    assert(
      insideScreen(Backpack.actionRect(index), Screen.width, Screen.height),
      "acción de mochila fuera de pantalla"
    )
  end

  Shop.layout()
  assert(insideScreen(Shop.panel, Screen.width, Screen.height), "tienda fuera de pantalla")
  assert(insideScreen(Shop.closeButton, Screen.width, Screen.height), "cerrar tienda fuera")
  assert(insideScreen(Shop.tabBuy, Screen.width, Screen.height), "pestaña comprar fuera")
  assert(insideScreen(Shop.tabAlchemy, Screen.width, Screen.height), "pestaña alquimia fuera")

  Menu.enter()
  assert(Menu.leftX >= 0, "columna izquierda fuera de pantalla")
  assert(Menu.rightX + 444 <= Screen.width + 0.001, "columna derecha fuera de pantalla")
  for _, rect in ipairs(Menu.characterRects) do
    assert(insideScreen(rect, Screen.width, Screen.height), "personaje fuera de pantalla")
  end
  for _, rect in ipairs(Menu.dungeonRects) do
    assert(insideScreen(rect, Screen.width, Screen.height), "mazmorra fuera de pantalla")
  end
  for _, rect in ipairs(Menu.upgradeRects) do
    assert(insideScreen(rect, Screen.width, Screen.height), "mejora fuera de pantalla")
  end
  assert(
    insideScreen(Menu.configRect, Screen.width, Screen.height),
    "configuración fuera de pantalla"
  )

  Config.layout()
  assert(insideScreen(Config.panel, Screen.width, Screen.height), "configuración fuera")
  for _, rect in pairs(Config.rects) do
    assert(insideScreen(rect, Screen.width, Screen.height), "botón de configuración fuera")
  end

  Sandbox.reset()
  Sandbox.activeTab = "enemies"
  Sandbox.layout()
  assert(insideScreen(Sandbox.panel, Screen.width, Screen.height), "sandbox fuera")
  assert(insideScreen(Sandbox.closeRect, Screen.width, Screen.height), "cerrar sandbox fuera")
  for _, rect in pairs(Sandbox.tabs) do
    assert(insideScreen(rect, Screen.width, Screen.height), "pestaña sandbox fuera")
  end
  for _, rect in ipairs(Sandbox.gridRects) do
    assert(insideScreen(rect, Screen.width, Screen.height), "enemigo sandbox fuera")
  end
  Sandbox.activeTab = "items"
  Sandbox.layout()
  for _, rect in ipairs(Sandbox.gridRects) do
    assert(insideScreen(rect, Screen.width, Screen.height), "ítem sandbox fuera")
  end

  Gameover.layout()
  assert(
    insideScreen(Gameover.panel, Screen.width, Screen.height),
    "panel de derrota fuera de pantalla"
  )
  assert(
    insideScreen(Gameover.rects.retry, Screen.width, Screen.height),
    "botón reintentar fuera de pantalla"
  )
  assert(
    insideScreen(Gameover.rects.menu, Screen.width, Screen.height),
    "botón menú fuera de pantalla"
  )
end

-- 20:9 (teléfono): crece el ancho virtual y no quedan barras negras.
checkWide(2400, 1080, 1200, 2)
-- 16:9: se conserva el diseño original.
checkWide(1920, 1080, 960, 2)
-- 19.5:9 típico de Android.
checkWide(2340, 1080, 1170, 2)

-- 4:3 (tableta): se mantiene 960x540 con letterboxing vertical.
Screen.resize(1024, 768)
assert(math.abs(Screen.width - 960) < 0.001, "tableta debe conservar ancho 960")
assert(math.abs(Screen.height - 540) < 0.001, "tableta debe conservar alto 540")
assert(math.abs(Screen.scale - 1024 / 960) < 0.001, "escala de tableta incorrecta")
assert(Screen.oy > 0, "tableta debe centrar con barras verticales")
assert(math.abs(Screen.toVirtualX(0)) < 0.001, "mapeo horizontal de tableta")
assert(math.abs(Screen.toVirtualY(Screen.oy)) < 0.001, "mapeo vertical de tableta")

-- Un tamaño inválido no debe romper la resolución anterior.
Screen.resize(0, 0)
assert(math.abs(Screen.width - 960) < 0.001, "tamaño inválido no debe alterar la pantalla")

print("test_layout OK")
