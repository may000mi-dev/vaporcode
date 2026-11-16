-- test_themes.lua: paletas exactas y tema activo sincronizado con el guardado.
package.path = "./?.lua;" .. package.path

local Themes = require("src.data.themes")
local Save = require("src.run.save")

local function near(actual, expected, label)
  assert(
    math.abs(actual - expected) < 0.0001,
    label .. ": se esperaba " .. expected .. ", llegó " .. actual
  )
end

local expected = {
  amado = { bg = 0x12161A, accent = 0x00E5FF, secondary = 0xCD7F32 },
  mar = { bg = 0x1A1212, accent = 0xFF3D00, secondary = 0xFFC107 },
  amileth = { bg = 0x1F1B12, accent = 0xFFD700, secondary = 0xFF9800 },
}

assert(#Themes.order == 3, "deben existir tres personajes con tema")
for _, id in ipairs({ "amado", "mar", "amileth" }) do
  local palette = Themes.get(id)
  local color = expected[id]
  assert(palette.id == id, "tema incorrecto para " .. id)
  near(palette.bg[1], math.floor(color.bg / 65536) / 255, id .. " fondo R")
  near(palette.bg[2], math.floor(color.bg / 256) % 256 / 255, id .. " fondo G")
  near(palette.bg[3], color.bg % 256 / 255, id .. " fondo B")
  near(palette.accent[1], math.floor(color.accent / 65536) / 255, id .. " acento R")
  near(palette.accent[2], math.floor(color.accent / 256) % 256 / 255, id .. " acento G")
  near(palette.accent[3], color.accent % 256 / 255, id .. " acento B")
  near(palette.secondary[1], math.floor(color.secondary / 65536) / 255, id .. " secundario R")
  near(palette.secondary[2], math.floor(color.secondary / 256) % 256 / 255, id .. " secundario G")
  near(palette.secondary[3], color.secondary % 256 / 255, id .. " secundario B")

  for _, key in ipairs({
    "panel", "panelAlt", "border", "muted", "dim", "button", "buttonSelected",
  }) do
    local derived = palette[key]
    assert(type(derived) == "table" and #derived == 3, "falta color " .. key)
    for channel = 1, 3 do
      assert(derived[channel] >= 0 and derived[channel] <= 1, "color fuera de rango")
    end
  end
end

assert(Themes.get("desconocido") == Themes.palettes.amado, "debe caer en Amado")

Save.data = { selectedCharacter = "mar" }
assert(Themes.current() == Themes.get("mar"), "el tema debe seguir a Mar")
Save.data.selectedCharacter = "amileth"
assert(Themes.current() == Themes.get("amileth"), "el tema debe seguir a Amileth")
Save.data.selectedCharacter = "desconocido"
assert(Themes.current() == Themes.get("amado"), "un id inválido debe caer en Amado")

print("OK temas exactos y tema activo")
