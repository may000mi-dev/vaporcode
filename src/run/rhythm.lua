-- rhythm.lua: reloj de pulso compartido y ventana de acierto.
local Data = require("src.run.data")

local Rhythm = {
  song = nil,
  bpm = Data.rhythm.bpm,
  spb = 60 / Data.rhythm.bpm,
  t = 0,
  beat = 0,
  nextBeat = 0,
  near = false,
  nearest = 99,
  perfect = false,
  justBeat = false,
  streak = 0,
  pulse = 1,
  click = nil,
  lockedClick = nil,
  muted = false,
}

local function ensureClick()
  if Rhythm.click then return end
  if not (love and love.sound and love.audio) then return end

  local ok, source = pcall(function()
    local rate = 22050
    local samples = math.floor(rate * 0.03)
    local data = love.sound.newSoundData(samples, rate, 16, 1)

    for i = 0, samples - 1 do
      local t = i / rate
      local envelope = 1 - i / samples
      local sample = math.sin(t * math.pi * 2 * 880) * 0.35 * envelope
      data:setSample(i, sample)
    end

    local click = love.audio.newSource(data, "static")
    click:setVolume(0.22)
    return click
  end)

  if ok then
    Rhythm.click = source
  end
end

local function ensureLockedClick()
  if Rhythm.lockedClick then return end
  if not (love and love.sound and love.audio) then return end

  local ok, source = pcall(function()
    local rate = 22050
    local samples = math.floor(rate * 0.09)
    local data = love.sound.newSoundData(samples, rate, 16, 1)

    for i = 0, samples - 1 do
      local t = i / rate
      local envelope = (1 - i / samples) ^ 2
      local low = math.sin(t * math.pi * 2 * 92) * 0.22
      local rough = math.sin(t * math.pi * 2 * 57) * 0.10
      data:setSample(i, (low + rough) * envelope)
    end

    local click = love.audio.newSource(data, "static")
    click:setVolume(0.30)
    return click
  end)

  if ok then
    Rhythm.lockedClick = source
  end
end

function Rhythm.toggleMute()
  Rhythm.muted = not Rhythm.muted
end

-- Sonido corto de engranaje trabado al intentar usar una habilidad sin maná.
function Rhythm.playLockedClick()
  ensureLockedClick()
  if Rhythm.lockedClick and not Rhythm.muted then
    Rhythm.lockedClick:stop()
    Rhythm.lockedClick:play()
  end
end

function Rhythm.enter(song)
  Rhythm.song = song
  Rhythm.bpm = song and song.bpm or Data.rhythm.bpm
  Rhythm.spb = 60 / Rhythm.bpm
  Rhythm.t = 0
  Rhythm.beat = 0
  Rhythm.nextBeat = Data.rhythm.firstBeatDelay
  Rhythm.near = false
  Rhythm.nearest = 99
  Rhythm.perfect = false
  Rhythm.justBeat = false
  Rhythm.streak = 0
  Rhythm.pulse = 1
  ensureClick()
end

-- Distancia al pulso más cercano (anterior o siguiente) en segundos.
local function beatDistance()
  local toNext = math.abs(Rhythm.nextBeat - Rhythm.t)
  if Rhythm.beat == 0 then return toNext end

  local toPrev = math.abs(Rhythm.t - (Rhythm.nextBeat - Rhythm.spb))
  if toPrev < toNext then return toPrev end
  return toNext
end

function Rhythm.update(dt)
  Rhythm.t = Rhythm.t + dt
  Rhythm.justBeat = false

  while Rhythm.t >= Rhythm.nextBeat do
    Rhythm.beat = Rhythm.beat + 1
    Rhythm.justBeat = true
    Rhythm.nextBeat = Rhythm.nextBeat + Rhythm.spb
    if Rhythm.click and not Rhythm.muted then
      Rhythm.click:stop()
      Rhythm.click:play()
    end
  end

  Rhythm.nearest = beatDistance()
  Rhythm.near = Rhythm.nearest <= Data.rhythm.visualWindow
  Rhythm.pulse = Rhythm.near and 1.25 or 1.0
end

-- Consulta la ventana sin alterar la racha.
function Rhythm.inWindow()
  return beatDistance() <= Data.rhythm.hitWindow
end

function Rhythm.registerHit(perfect)
  Rhythm.perfect = perfect and true or false
  if Rhythm.perfect then
    Rhythm.streak = Rhythm.streak + 1
  else
    Rhythm.streak = 0
  end
  return Rhythm.perfect
end

-- Devuelve true si el ataque cae dentro de la ventana del pulso.
function Rhythm.tryHit()
  local perfect = Rhythm.inWindow()
  Rhythm.registerHit(perfect)
  return perfect, beatDistance()
end

return Rhythm
