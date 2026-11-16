-- themes.lua: paletas de color por personaje para la interfaz.
-- Los valores hex se convierten a RGB 0-1 para love.graphics.setColor.
local function hex(value)
  local r = math.floor(value / 65536) % 256
  local g = math.floor(value / 256) % 256
  local b = value % 256
  return { r / 255, g / 255, b / 255 }
end

local Themes = {}

Themes.palettes = {
  amado = {
    id = "amado",
    name = "Amado",
    bg = hex(0x12161A),
    accent = hex(0x00E5FF),
    secondary = hex(0xCD7F32),
    text = { 0.92, 0.95, 0.98 },
  },
  mar = {
    id = "mar",
    name = "Mar",
    bg = hex(0x1A1212),
    accent = hex(0xFF3D00),
    secondary = hex(0xFFC107),
    text = { 0.98, 0.93, 0.92 },
  },
  amileth = {
    id = "amileth",
    name = "Amileth",
    bg = hex(0x1F1B12),
    accent = hex(0xFFD700),
    secondary = hex(0xFF9800),
    text = { 0.98, 0.96, 0.90 },
  },
}

Themes.order = { "amado", "mar", "amileth" }

local function mix(a, b, t)
  return {
    a[1] + (b[1] - a[1]) * t,
    a[2] + (b[2] - a[2]) * t,
    a[3] + (b[3] - a[3]) * t,
  }
end

function Themes.get(characterId)
  return Themes.palettes[characterId] or Themes.palettes.amado
end

function Themes.applyDerived(palette)
  palette.panel = mix(palette.bg, { 0, 0, 0 }, 0.15)
  palette.panelAlt = mix(palette.bg, palette.accent, 0.08)
  palette.border = mix(palette.accent, palette.bg, 0.35)
  palette.muted = mix(palette.text, palette.bg, 0.45)
  palette.dim = mix(palette.text, palette.bg, 0.65)
  palette.button = mix(palette.bg, palette.accent, 0.12)
  palette.buttonSelected = mix(palette.bg, palette.accent, 0.22)
  return palette
end

for _, id in ipairs(Themes.order) do
  Themes.applyDerived(Themes.palettes[id])
end

function Themes.current()
  local ok, Save = pcall(require, "src.run.save")
  local id = ok and Save.data and Save.data.selectedCharacter or "amado"
  return Themes.get(id)
end

return Themes
