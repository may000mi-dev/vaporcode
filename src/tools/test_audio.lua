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

print("OK volúmenes de audio")
