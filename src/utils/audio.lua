-- audio.lua: bus ligero de música y efectos con volúmenes persistentes.
-- La música es procedural: un bucle corto de taller evita cargar pistas y
-- mantiene el APK pequeño. Los efectos se registran con su volumen base para
-- poder reaplicar el ajuste del usuario sin reiniciar la partida.
local Audio = {
  musicVolume = 0.6,
  effectsVolume = 0.8,
  musicSource = nil,
  musicBpm = 104,
  effects = {},
}

local function clamp01(value)
  value = tonumber(value)
  if not value then return nil end
  return math.max(0, math.min(1, value))
end

local function setSourceVolume(source, volume)
  if not source or not source.setVolume then return end
  pcall(source.setVolume, source, volume)
end

function Audio.registerEffect(source, baseVolume)
  if not source then return end
  Audio.effects[#Audio.effects + 1] = {
    source = source,
    baseVolume = baseVolume or 1,
  }
  setSourceVolume(source, (baseVolume or 1) * Audio.effectsVolume)
end

function Audio.applyEffects()
  for _, effect in ipairs(Audio.effects) do
    setSourceVolume(
      effect.source,
      effect.baseVolume * Audio.effectsVolume
    )
  end
end

function Audio.applyMusic()
  setSourceVolume(Audio.musicSource, Audio.musicVolume)
end

function Audio.setMusicVolume(value)
  Audio.musicVolume = clamp01(value) or Audio.musicVolume
  Audio.applyMusic()
end

function Audio.setEffectsVolume(value)
  Audio.effectsVolume = clamp01(value) or Audio.effectsVolume
  Audio.applyEffects()
end

-- Bucle de 4 segundos en La menor con bajo, arpegio y pulso de metrónomo.
-- 11 kHz mono es suficiente para un colchón de fondo y pesa muy poco.
local function buildMusic()
  if not (love and love.sound and love.audio) then return nil end

  local ok, source = pcall(function()
    local rate = 11025
    local duration = 4
    local samples = rate * duration
    local data = love.sound.newSoundData(samples, rate, 16, 1)
    local notes = {
      220.00, 261.63, 329.63, 392.00,
      329.63, 261.63, 196.00, 246.94,
    }
    local beat = duration / #notes

    for i = 0, samples - 1 do
      local t = i / rate
      local index = math.floor(t / beat) + 1
      local localT = t - (index - 1) * beat
      local frequency = notes[index]
      local envelope = math.min(1, localT * 8) * math.max(0, 1 - localT / beat)
      local bass = math.sin(t * math.pi * 2 * (frequency * 0.5)) * 0.16
      local lead = math.sin(t * math.pi * 2 * frequency) * 0.07
      local pulse = math.sin(t * math.pi * 2 * 55) * 0.04
      data:setSample(i, (bass + lead + pulse) * envelope)
    end

    local music = love.audio.newSource(data, "static")
    music:setLooping(true)
    return music
  end)

  return ok and source or nil
end

function Audio.startMusic(bpm)
  if not (love and love.audio) then return end
  Audio.musicSource = Audio.musicSource or buildMusic()
  if not Audio.musicSource then return end

  Audio.musicBpm = bpm or Audio.musicBpm
  local pitch = math.max(0.5, math.min(2, Audio.musicBpm / 104))
  pcall(Audio.musicSource.setPitch, Audio.musicSource, pitch)
  Audio.applyMusic()
  local ok, playing = pcall(Audio.musicSource.isPlaying, Audio.musicSource)
  if not ok or not playing then
    pcall(Audio.musicSource.play, Audio.musicSource)
  end
end

function Audio.stopMusic()
  if not Audio.musicSource then return end
  pcall(Audio.musicSource.stop, Audio.musicSource)
end

function Audio.pauseMusic()
  if not Audio.musicSource then return end
  pcall(Audio.musicSource.pause, Audio.musicSource)
end

function Audio.resumeMusic()
  if not Audio.musicSource then return end
  Audio.applyMusic()
  local ok, playing = pcall(Audio.musicSource.isPlaying, Audio.musicSource)
  if not ok or not playing then
    pcall(Audio.musicSource.play, Audio.musicSource)
  end
end

return Audio
