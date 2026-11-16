-- test_audio.lua: volúmenes acotados y reaplicados a las fuentes registradas.
package.path = "./?.lua;" .. package.path

local Audio = require("src.utils.audio")

local applied = 0
local source = {
  setVolume = function(_, value)
    applied = value
  end,
}

Audio.setEffectsVolume(0.5)
Audio.registerEffect(source, 0.4)
assert(math.abs(applied - 0.2) < 0.0001, "debe aplicar volumen base por bus")

Audio.setEffectsVolume(1)
assert(math.abs(applied - 0.4) < 0.0001, "debe reaplicar al cambiar el bus")

Audio.setEffectsVolume(-5)
assert(Audio.effectsVolume == 0, "el volumen de efectos debe acotarse")
assert(applied == 0, "el silencio debe llegar a la fuente")

Audio.setMusicVolume(9)
assert(Audio.musicVolume == 1, "el volumen de música debe acotarse")
Audio.setMusicVolume(0.25)
assert(Audio.musicVolume == 0.25, "debe aceptar valores válidos")

local pitches = {}
Audio.fallbackSource = {
  setPitch = function(_, value)
    pitches[#pitches + 1] = value
  end,
}
Audio.fallbackBpm(150)
assert(
  math.abs(pitches[#pitches] - 1.25) < 0.0001,
  "el metrónomo debe respetar el BPM base de 120"
)
Audio.fallbackBpm(104)
assert(
  math.abs(pitches[#pitches] - 104 / 120) < 0.0001,
  "la cripta debe acelerar el metrónomo a 104 BPM"
)

local expectedBpm = {
  menu = 120,
  config = 120,
  cripta = 104,
  forja = 124,
  catedral = 138,
  torre = 150,
  sandbox = 120,
}
for zone, bpm in pairs(expectedBpm) do
  assert(Audio.zoneBpm(zone) == bpm, "BPM incorrecto para " .. zone)
end

local seen = {}
local uniqueTracks = 0
for _, characterId in ipairs({ "amado", "mar", "amileth" }) do
  for zone in pairs(expectedBpm) do
    local path, bpm = Audio.trackFor(zone, characterId)
    assert(type(path) == "string", "falta pista para " .. characterId .. "/" .. zone)
    assert(bpm == expectedBpm[zone], "BPM de pista incorrecto")
    local file = io.open(path, "rb")
    assert(file, "no existe la pista " .. path)
    file:close()
    if not seen[path] then
      seen[path] = true
      uniqueTracks = uniqueTracks + 1
    end
  end
end
assert(uniqueTracks == 15, "deben existir 15 pistas únicas por personaje y zona")

print("OK audio: volúmenes, BPM y 15 pistas")
