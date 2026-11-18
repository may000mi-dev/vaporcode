-- music.lua: catálogo de pistas, metadatos y índices por personaje/zona.
-- La ruta de audio vive aquí para que el menú y el bus de música compartan
-- una sola fuente de verdad; audio.lua solo decide cuándo crossfadear.
local Music = {}

Music.zones = { "menu", "cripta", "forja", "catedral", "torre" }

Music.zoneLabels = {
  menu = "MENÚ",
  cripta = "CRIPTA",
  forja = "FORJA",
  catedral = "CATEDRAL",
  torre = "TORRE",
}

local function track(id, characterId, zone, title, file, aliases)
  return {
    id = id,
    characterId = characterId,
    zone = zone,
    title = title,
    file = file,
    aliases = aliases or {},
  }
end

Music.tracks = {
  track("amado_menu", "amado", "menu", "Flores de latón y péndulos",
    "assets/audio/music/brass_petals_and_pendulums.mp3", { "config", "sandbox" }),
  track("amado_cripta", "amado", "cripta", "Bajo el suelo de hierro",
    "assets/audio/music/beneath_the_iron_floor.mp3"),
  track("amado_forja", "amado", "forja", "La forja pesada",
    "assets/audio/music/the_heavy_forge.mp3"),
  track("amado_catedral", "amado", "catedral", "Salmo para un trono mecánico",
    "assets/audio/music/psalm_for_a_mechanical_throne.mp3"),
  track("amado_torre", "amado", "torre", "Contra el péndulo de hierro",
    "assets/audio/music/against_the_iron_pendulum.mp3"),

  track("mar_menu", "mar", "menu", "El metrónomo de cristal",
    "assets/audio/music/the_glassmaker_s_metronome.mp3", { "config", "sandbox" }),
  track("mar_cripta", "mar", "cripta", "Bajo la bóveda de obsidiana",
    "assets/audio/music/beneath_the_obsidian_vault.mp3"),
  track("mar_forja", "mar", "forja", "Asedio de engranajes",
    "assets/audio/music/clockwork_siege.mp3"),
  track("mar_catedral", "mar", "catedral", "Liturgia del reloj",
    "assets/audio/music/the_clockwork_liturgy.mp3"),
  track("mar_torre", "mar", "torre", "Réquiem del gran alquimista",
    "assets/audio/music/grand_alchemist_s_requiem.mp3"),

  track("amileth_menu", "amileth", "menu", "Lamento de la llave de metal",
    "assets/audio/music/the_metal_key_s_lament.mp3", { "config", "sandbox" }),
  track("amileth_cripta", "amileth", "cripta", "Trazando el laberinto de hierro",
    "assets/audio/music/charting_the_iron_maze.mp3"),
  track("amileth_forja", "amileth", "forja", "Chasquido del muelle",
    "assets/audio/music/mainspring_snap.mp3"),
  track("amileth_catedral", "amileth", "catedral", "Santuario de cuerda",
    "assets/audio/music/clockwork_sanctum.mp3"),
  track("amileth_torre", "amileth", "torre", "Latón y oraciones rotas",
    "assets/audio/music/brass_gears_and_broken_prayers.mp3"),
}

Music.characterOrder = { "amado", "mar", "amileth" }

Music.byId = {}
Music.byKey = {}
Music.byCharacter = {}
for _, characterId in ipairs(Music.characterOrder) do
  Music.byCharacter[characterId] = {}
end

for _, def in ipairs(Music.tracks) do
  Music.byId[def.id] = def
  Music.byKey[def.characterId .. ":" .. def.zone] = def
  Music.byCharacter[def.characterId][#Music.byCharacter[def.characterId] + 1] = def.id
end

function Music.idFor(characterId, zone)
  local def = Music.byKey[characterId .. ":" .. zone]
  if def then return def.id end
  for _, id in ipairs(Music.byCharacter[characterId] or {}) do
    for _, alias in ipairs(Music.byId[id].aliases) do
      if alias == zone then return id end
    end
  end
  return nil
end

function Music.menuIdFor(characterId)
  return Music.idFor(characterId, "menu")
end

function Music.zoneFor(id)
  local def = Music.byId[id]
  return def and def.zone or nil
end

return Music
