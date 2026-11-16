-- test_bestiario.lua: categorías múltiples, layout sin solapes y scroll.
package.path = "./?.lua;" .. package.path

local noop = function() end
love = {
  math = {
    random = function(a, b)
      if a and b then return a end
      return 0.5
    end,
    newRandomGenerator = function()
      return { random = function() return 0.5 end }
    end,
  },
  timer = { getTime = function() return 0 end },
  system = { getOS = function() return "Linux" end },
  filesystem = {
    getInfo = function() return nil end,
    write = function() return true end,
    remove = function() return true end,
  },
  graphics = {
    setColor = noop,
    setLineWidth = noop,
    rectangle = noop,
    circle = noop,
    line = noop,
    arc = noop,
    polygon = noop,
    print = noop,
    printf = noop,
    setFont = noop,
    setScissor = noop,
    push = noop,
    pop = noop,
    translate = noop,
    scale = noop,
    getDimensions = function() return 960, 540 end,
    newFont = function(size) return { size = size } end,
  },
}

local Screen = require("src.utils.screen")
local Fonts = require("src.utils.fonts")
local Data = require("src.run.data")
local Save = require("src.run.save")
local Bestiario = require("src.estados.bestiario")

Screen.resize(960, 540)
Fonts.load()
Save.load()

local function contains(list, value)
  for _, item in ipairs(list) do
    if item == value then return true end
  end
  return false
end

local function overlaps(a, b)
  return a.x < b.x + b.w
    and a.x + a.w > b.x
    and a.y < b.y + b.h
    and a.y + a.h > b.y
end

Bestiario.enter()
assert(Bestiario.category == "all", "el bestiario debe abrir en Todos")
assert(Bestiario.tabs[1] and Bestiario.tabs[1].id == "all", "Todos debe ser la primera pestaña")

local all = Bestiario.filteredFor("all")
assert(#all == #Data.bestiaryOrder, "Todos debe incluir todo el bestiario")
local unique = {}
for _, id in ipairs(all) do
  assert(not unique[id], "Todos no debe duplicar enemigos: " .. id)
  unique[id] = true
end

assert(contains(Bestiario.categoriesFor("peste"), "ranged"), "Peste debe contar como distancia")
assert(contains(Bestiario.categoriesFor("peste"), "support"), "Peste debe contar como soporte")
assert(contains(Bestiario.categoriesFor("maquinista"), "summoner"), "Maquinista debe invocar")
assert(contains(Bestiario.categoriesFor("maquinista"), "support"), "Maquinista también apoya")
assert(contains(Bestiario.categoriesFor("inquisidor"), "ranged"), "Inquisidor dispara")
assert(contains(Bestiario.categoriesFor("inquisidor"), "support"), "Inquisidor también controla")
assert(contains(Bestiario.categoriesFor("devorador"), "support"), "Devorador debe contar como soporte")
assert(contains(Bestiario.categoriesFor("guardian"), "boss"), "Guardián debe ser jefe")

local selectorBottom = Bestiario.selectorPanel.y
  + Bestiario.selectorPanel.cardY
  + Bestiario.selectorPanel.cardH
assert(
  Bestiario.detailRect.y >= selectorBottom,
  "el detalle no debe tapar las tarjetas de personaje"
)
for _, card in ipairs(Bestiario.cards) do
  assert(not overlaps(card, Bestiario.detailRect), "una ficha tapa el detalle")
end
for _, tab in ipairs(Bestiario.tabs) do
  assert(not overlaps(tab, Bestiario.detailRect), "una pestaña tapa el detalle")
end

assert(Bestiario.maxScroll > 0, "Todos debe tener scroll con el catálogo actual")
Bestiario.setScroll(0)
Bestiario.wheelmoved(0, -1)
assert(Bestiario.scroll > 0, "la rueda debe bajar la lista")

Bestiario.setScroll(0)
local grid = Bestiario.grid
Bestiario.touchpressed("drag", grid.x + 10, grid.y + 60)
Bestiario.touchmoved("drag", grid.x + 10, grid.y + 10)
Bestiario.touchreleased("drag", grid.x + 10, grid.y + 10)
assert(Bestiario.scroll > 0, "el arrastre táctil debe desplazar la lista")

Bestiario.setCategory("support")
assert(Bestiario.category == "support", "debe cambiar de categoría")
assert(contains(Bestiario.filtered, Bestiario.selectedId), "la selección debe quedar en la categoría")
for _, id in ipairs(Bestiario.filtered) do
  assert(contains(Bestiario.categoriesFor(id), "support"), "enemigo fuera de soporte: " .. id)
end

Bestiario.setCategory("all")
Bestiario.setScroll(0)
Save.data.characters.mar = true
Bestiario.selector:request("mar")
assert(Bestiario.selector.confirm ~= nil, "debe abrir la confirmación de personaje")
Bestiario.draw()

print("OK bestiario: Todos, tipos múltiples, layout y scroll")
