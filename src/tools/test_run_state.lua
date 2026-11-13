-- test_run_state.lua: una run nueva no debe heredar estado de la anterior.
package.path = "./?.lua;" .. package.path

local function rng(seed)
  local state = seed or 1
  return {
    random = function(_, a, b)
      state = (state * 1103515245 + 12345) % 2147483648
      local value = state / 2147483648
      if a and b then
        return math.floor(value * (b - a + 1)) + a
      elseif a then
        return math.floor(value * a) + 1
      end
      return value
    end,
  }
end

love = {
  math = {
    random = function(a, b)
      if a and b then return a end
      return 0.5
    end,
    newRandomGenerator = rng,
  },
  timer = {
    getTime = function()
      return 0
    end,
  },
  system = {
    getOS = function()
      return "Linux"
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

local function noop() end
love.graphics = {
  setColor = noop,
  rectangle = noop,
  print = noop,
  printf = noop,
  rotate = noop,
  polygon = noop,
  setFont = noop,
  circle = noop,
  line = noop,
  arc = noop,
  setLineWidth = noop,
  push = noop,
  pop = noop,
  translate = noop,
}

local Save = require("src.run.save")
local Run = require("src.run.run")

Save.load()
Run.enter("cripta", "amado", "resonance")

-- Se ensucia la run con mascota y pasivas reales.
assert(Run:addItemToInventory("dog", 1) == "ok", "la mascota debe activarse")
assert(Run:addItemToInventory("poison", 2) == "ok", "la pasiva debe activarse")
assert(#Run.pets == 1 and Run.passiveStacks.poison == 2, "la run debe tener estado")
Run.fluteReady = true
Run.petSnapshot = { { kind = "dog" } }

-- Una run nueva debe empezar limpia aunque la anterior tuviera ítems.
Run.enter("cripta", "amado", "resonance")
assert(#Run.pets == 0, "la mascota no debe sobrevivir a una run nueva")
assert(#Run.inventory == 0, "el inventario debe reiniciarse")
assert(next(Run.passiveStacks) == nil, "las pasivas no deben sobrevivir")
assert(Run.fluteReady == false, "la flauta no debe seguir lista")
assert(Run.petSnapshot == nil, "no debe quedar una instantánea de mascotas")

-- Pausar y perder el foco deben guardar, para sobrevivir a Android.
local saves = 0
local originalSave = Save.save
Save.save = function()
  saves = saves + 1
  return true
end

Run:setPaused(true)
assert(Run.paused and saves == 1, "pausar debe guardar el progreso")
Run:setPaused(false)
assert(not Run.paused and saves == 1, "reanudar no debe repetir el guardado")
Run.focus(false)
assert(Run.paused and saves == 2, "perder el foco debe pausar y guardar")
Run.focus(true)
assert(Run.paused, "recuperar el foco no debe reanudar solo")

Save.save = originalSave
Run.paused = false

print("OK aislamiento de estado entre runs y guardado al pausar")

