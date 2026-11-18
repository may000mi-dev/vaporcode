-- audio.lua: bus de música por personaje/zona con fallback al metrónomo.
-- Las pistas están en assets/audio/music; si falta un archivo se usa el
-- bucle procedural para no dejar la partida en silencio.
local Save = require("src.run.save")
local Music = require("src.data.music")

local Audio = {
  musicVolume = 0.6,
  effectsVolume = 0.8,
  musicSource = nil,
  fallbackSource = nil,
  effects = {},
  currentZone = "menu",
  currentCharacterId = "amado",
  currentBpm = 120,
  currentPath = nil,
  fallbackBaseBpm = 120,
  pending = nil,
  crossfade = 0,
  crossfadeDuration = 0.45,
}

local TRACKS = {}
for _, def in ipairs(Music.tracks) do
  TRACKS[def.characterId] = TRACKS[def.characterId] or {}
  TRACKS[def.characterId][def.zone] = def.file
  for _, alias in ipairs(def.aliases) do
    TRACKS[def.characterId][alias] = def.file
  end
end

local ZONE_BPM = {
  menu = 120,
  config = 120,
  cripta = 104,
  forja = 124,
  catedral = 138,
  torre = 150,
  sandbox = 120,
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

local function stopSource(source)
  if not source or not source.stop then return end
  pcall(source.stop, source)
end

local function playSource(source)
  if not source then return end
  local ok, playing = pcall(source.isPlaying, source)
  if not ok or not playing then
    pcall(source.play, source)
  end
end

local function pauseSource(source)
  if not source or not source.pause then return end
  pcall(source.pause, source)
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
    setSourceVolume(effect.source, effect.baseVolume * Audio.effectsVolume)
  end
end

function Audio.applyMusic()
  local progress = Audio.pending and (Audio.crossfade / Audio.crossfadeDuration) or 1
  local mainVolume = Audio.musicVolume * progress
  local outVolume = Audio.musicVolume * (1 - progress)
  setSourceVolume(Audio.musicSource, mainVolume)
  setSourceVolume(Audio.pending, outVolume)
  setSourceVolume(Audio.fallbackSource, Audio.musicSource and 0 or Audio.musicVolume)
end

function Audio.setMusicVolume(value)
  Audio.musicVolume = clamp01(value) or Audio.musicVolume
  Audio.applyMusic()
end

function Audio.setEffectsVolume(value)
  Audio.effectsVolume = clamp01(value) or Audio.effectsVolume
  Audio.applyEffects()
end

local function buildFallback()
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

function Audio.fallbackBpm(bpm)
  Audio.currentBpm = bpm or Audio.currentBpm or 120
  Audio.fallbackSource = Audio.fallbackSource or buildFallback()
  if not Audio.fallbackSource then return end
  local pitch = math.max(0.5, math.min(2, Audio.currentBpm / Audio.fallbackBaseBpm))
  pcall(Audio.fallbackSource.setPitch, Audio.fallbackSource, pitch)
end

local function resolveTrack(zone, characterId)
  zone = zone or Audio.currentZone or "menu"
  characterId = characterId or Audio.currentCharacterId or "amado"
  local byCharacter = TRACKS[characterId] or TRACKS.amado
  local path = byCharacter[zone] or byCharacter.menu or TRACKS.amado.menu
  return path, ZONE_BPM[zone] or 120
end

function Audio.trackFor(zone, characterId)
  return resolveTrack(zone, characterId)
end

local function loadStream(path)
  if not (love and love.audio and love.filesystem) then return nil end
  local ok, exists = pcall(love.filesystem.getInfo, path)
  if not ok or not exists then return nil end
  local okSource, source = pcall(love.audio.newSource, path, "stream")
  if not okSource or not source then return nil end
  pcall(source.setLooping, source, true)
  return source
end

function Audio.update(dt)
  if not Audio.pending then return end
  Audio.crossfade = math.min(Audio.crossfadeDuration, Audio.crossfade + (dt or 0))
  local progress = Audio.crossfade / Audio.crossfadeDuration
  setSourceVolume(Audio.musicSource, Audio.musicVolume * progress)
  setSourceVolume(Audio.pending, Audio.musicVolume * (1 - progress))
  if Audio.crossfade >= Audio.crossfadeDuration then
    stopSource(Audio.pending)
    Audio.pending = nil
    Audio.crossfade = 0
    Audio.applyMusic()
  end
end

function Audio.playZone(zone, characterId, opts)
  opts = opts or {}
  local selected = characterId or (Save and Save.getSelectedCharacter and Save.getSelectedCharacter()) or "amado"
  local songId = Music.idFor(selected, zone)
  if songId and Save.discoverSong then
    Save.discoverSong(selected, songId)
  end
  local path, bpm = resolveTrack(zone, selected)
  Audio.currentZone = zone or Audio.currentZone
  Audio.currentCharacterId = selected
  Audio.currentBpm = bpm

  if path and Audio.currentPath == path and Audio.musicSource then
    if Audio.pending then
      stopSource(Audio.pending)
      Audio.pending = nil
    end
    Audio.crossfade = 0
    if Audio.fallbackSource then
      stopSource(Audio.fallbackSource)
    end
    Audio.applyMusic()
    playSource(Audio.musicSource)
    return
  end

  local nextSource = loadStream(path)
  if not nextSource then
    Audio.currentPath = nil
    if Audio.musicSource then
      stopSource(Audio.musicSource)
      Audio.musicSource = nil
    end
    if Audio.pending then
      stopSource(Audio.pending)
      Audio.pending = nil
    end
    Audio.fallbackBpm(bpm)
    Audio.applyMusic()
    playSource(Audio.fallbackSource)
    return
  end

  local previous = Audio.musicSource
  if previous and opts.crossfade ~= false then
    if Audio.pending and Audio.pending ~= previous then
      stopSource(Audio.pending)
    end
    Audio.pending = previous
    Audio.crossfade = 0
  elseif previous then
    if Audio.pending then
      stopSource(Audio.pending)
      Audio.pending = nil
    end
    stopSource(previous)
  end

  Audio.musicSource = nextSource
  Audio.currentPath = path
  if Audio.fallbackSource then
    stopSource(Audio.fallbackSource)
  end
  Audio.applyMusic()
  playSource(Audio.musicSource)
end

-- Compatibilidad con llamadas anteriores (run.lua, rhythm.lua, etc.)
function Audio.startMusic(bpmOrZone, characterId)
  if type(bpmOrZone) == "number" then
    Audio.fallbackBpm(bpmOrZone)
    Audio.applyMusic()
    playSource(Audio.fallbackSource)
    return
  end
  Audio.playZone(bpmOrZone or Audio.currentZone, characterId)
end

function Audio.stopMusic()
  stopSource(Audio.musicSource)
  stopSource(Audio.pending)
  stopSource(Audio.fallbackSource)
  Audio.pending = nil
end

function Audio.pauseMusic()
  pauseSource(Audio.musicSource)
  pauseSource(Audio.pending)
  pauseSource(Audio.fallbackSource)
end

function Audio.resumeMusic()
  Audio.applyMusic()
  playSource(Audio.musicSource or Audio.fallbackSource)
  if Audio.pending then playSource(Audio.pending) end
end

function Audio.setCharacter(characterId)
  Audio.playZone(Audio.currentZone, characterId)
end

function Audio.zoneBpm(zone)
  return ZONE_BPM[zone] or 120
end

return Audio
