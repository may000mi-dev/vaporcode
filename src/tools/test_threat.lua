-- test_threat.lua: presupuesto, roles garantizados y oleadas del Modo Infinito.
package.path = "./?.lua;" .. package.path

local Data = require("src.run.data")
local Threat = require("src.run.threat")

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

local function rooms(count)
  local list = {}
  for index = 1, count do
    list[index] = { index = index }
  end
  return list
end

local function fakeRun(depth, pool, roomCount, seed)
  local run = {
    mode = "free",
    sandbox = false,
    depth = depth,
    def = { enemies = pool },
    player = { x = 0, y = 0 },
    enemies = {},
    enemyCount = 0,
    spawnX = 0,
    spawnY = 0,
    dungeon = {
      rooms = rooms(roomCount or 7),
      rng = rng(seed or 1),
    },
  }
  run.dungeon.randomFloorPoint = function(_, _, _, _, _, _)
    return 100 + #run.enemies * 20, 100
  end
  run.createEnemy = function(self, kind, x, y)
    local enemy = {
      kind = kind,
      x = x,
      y = y,
      dead = false,
    }
    self.enemies[#self.enemies + 1] = enemy
    return enemy
  end
  return run
end

local function roleCost(units, roles)
  local total = 0
  for _, kind in ipairs(units) do
    local def = Data.enemyTypes[kind]
    local matches = false
    for _, role in ipairs(roles) do
      for _, own in ipairs(def.threatRoles or {}) do
        if role == own then
          matches = true
          break
        end
      end
      if matches then break end
    end
    if matches then
      total = total + (def.threat or 0)
    end
  end
  return total
end

local function unitCost(units)
  local total = 0
  for _, kind in ipairs(units) do
    total = total + Threat.cost(kind)
  end
  return total
end

-- Costos de amenaza de todos los enemigos que pueden aparecer en las salas.
local expectedCosts = {
  automaton = 1,
  sabueso = 1,
  caldera = 2,
  espectro = 2,
  peste = 2,
  engranaje = 3,
  centinela = 3,
  artillero = 3,
  maquinista = 3,
  saboteador = 3,
  clerigo = 4,
  inquisidor = 4,
}
for kind, cost in pairs(expectedCosts) do
  assert(Data.enemyTypes[kind].threat == cost,
    kind .. " debe costar " .. cost .. " de amenaza")
end
for _, dungeon in ipairs(Data.dungeons) do
  for _, kind in ipairs(dungeon.enemies) do
    assert((Data.enemyTypes[kind].threat or 0) > 0,
      dungeon.id .. " no puede usar " .. kind .. " sin costo de amenaza")
  end
end

-- Fórmula base y multiplicador por tamaño de mazmorra.
assert(Threat.calculateBudget(1, 7) == 6, "piso 1 con 7 salas debe dar 6")
assert(Threat.calculateBudget(5, 7) == 16, "piso 5 con 7 salas debe dar 16")
assert(Threat.calculateBudget(10, 7) == 28, "piso 10 con 7 salas debe dar 28")
assert(Threat.calculateBudget(1, 3) == 4, "mazmorra pequeña debe dar 4")
assert(Threat.calculateBudget(1, 12) == 7, "mazmorra grande debe dar 7")
assert(Threat.sizeMultiplier(3) == 0.7, "el multiplicador mínimo es 0.7")
assert(Threat.sizeMultiplier(12) == 1.3, "el multiplicador máximo es 1.3")

-- Garantías de roles: distancia desde el piso 4 y soporte/control desde el 8.
local configurations = {
  Data.dungeons[1].enemies,
  Data.dungeons[2].enemies,
  Data.dungeons[3].enemies,
  Data.dungeons[4].enemies,
}
for index, pool in ipairs(configurations) do
  local run = fakeRun(4, pool, 7, index * 97)
  local units, spent, remaining = Threat.generateComposition(run, 30)
  assert(unitCost(units) == spent, "el gasto debe coincidir con la composición")
  assert(spent <= 30 and remaining < 4, "no debe exceder ni desperdiciar el presupuesto")
  assert(roleCost(units, Data.threat.rangedRoles) >= 2,
    "desde el piso 4 debe haber al menos 2 puntos a distancia")

  run = fakeRun(8, pool, 7, index * 131)
  units = Threat.generateComposition(run, 40)
  assert(roleCost(units, Data.threat.rangedRoles) >= 2,
    "desde el piso 8 se conserva la garantía a distancia")
  assert(roleCost(units, Data.threat.supportRoles) >= 4,
    "desde el piso 8 debe haber 4 puntos de soporte o control")
end

-- Cantidad de oleadas por presupuesto y mazmorra pequeña.
assert(Threat.waveCount(10, 7) == 1, "hasta 10 puntos debe haber 1 oleada")
assert(Threat.waveCount(11, 7) == 2, "de 11 a 20 deben ser 2 oleadas")
assert(Threat.waveCount(20, 7) == 2, "20 puntos aún son 2 oleadas")
assert(Threat.waveCount(21, 7) == 3, "más de 20 deben ser 3 oleadas")
assert(Threat.waveCount(9, 4) == 2, "mazmorra con menos de 5 salas fuerza 2 oleadas")

-- El reparto conserva todas las unidades y ninguna oleada queda vacía.
local splitRun = fakeRun(10, Data.dungeons[3].enemies, 7, 55)
local units = Threat.generateComposition(splitRun, 28)
local spent = unitCost(units)
local waves = Threat.splitWaves(splitRun, units, spent, 7)
assert(#waves == 3, "28 puntos deben dividirse en 3 oleadas")
local waveCost = 0
local waveUnits = 0
for _, wave in ipairs(waves) do
  assert(#wave.units > 0, "ninguna oleada puede quedar vacía")
  waveCost = waveCost + wave.cost
  waveUnits = waveUnits + #wave.units
  assert(wave.nextAt == math.max(1, math.ceil(wave.total * 0.7)),
    "la siguiente oleada debe activarse al matar el 70%")
end
assert(waveCost == spent, "las oleadas deben sumar el presupuesto gastado")
assert(waveUnits == #units, "las oleadas no deben perder unidades")

local tricky = { "automaton", "automaton", "automaton" }
local trickyWaves = Threat.splitWaves(splitRun, tricky, 3, 4)
assert(#trickyWaves == 2, "una mazmorra pequeña fuerza 2 oleadas")
assert(#trickyWaves[1].units > 0 and #trickyWaves[2].units > 0,
  "el reparto pequeño tampoco debe dejar oleadas vacías")

-- En salas pequeñas el primer enemigo no debe agotar todo el presupuesto.
for seed = 1, 20 do
  local smallRun = fakeRun(1, Data.dungeons[3].enemies, 4, seed)
  local smallUnits = Threat.generateComposition(smallRun, 4)
  local smallSpent = unitCost(smallUnits)
  local smallWaves = Threat.splitWaves(smallRun, smallUnits, smallSpent, 4)
  assert(#smallUnits >= 2, "la sala pequeña debe tener al menos 2 enemigos")
  assert(#smallWaves == 2, "la sala pequeña debe conservar sus 2 oleadas")
end

-- Integración: spawn con tope activo y cierre al desplegar todas las oleadas.
local run = fakeRun(10, Data.dungeons[3].enemies, 7, 1234)
local state = Threat.startFloor(run)
assert(state and state.enabled, "el piso libre debe activar amenazas")
assert(#state.waves == 3, "el piso 10 debe tener 3 oleadas")
assert(#run.enemies <= Data.threat.maxActive,
  "no deben superarse los 18 enemigos activos")
assert(state.spent > 0, "el piso debe gastar presupuesto")

local guarded = 0
while not state.complete and guarded < 20 do
  guarded = guarded + 1
  local killed = run.enemies
  run.enemies = {}
  for _, enemy in ipairs(killed) do
    Threat.onEnemyKilled(run, enemy)
  end
  Threat.updateWaves(run)
end
assert(state.complete, "la sala debe completarse al limpiar todas las oleadas")
assert(not Threat.pending(run), "una sala completa ya no bloquea la salida")
assert(#run.enemies == 0, "no deben quedar enemigos al completar la sala")

-- Mazmorra pequeña: el presupuesto baja y se fuerza el reparto en dos oleadas.
local small = fakeRun(1, Data.dungeons[1].enemies, 4, 9)
local smallState = Threat.startFloor(small)
assert(smallState.roomCount == 4, "debe registrar el número de salas")
assert(smallState.sizeMultiplier == 0.7, "debe aplicar el mínimo por tamaño")
assert(smallState.budget == 4, "la mazmorra pequeña debe reducir el presupuesto")
assert(#smallState.waves >= 1, "debe existir al menos una oleada")

print("OK amenaza: presupuesto, roles, tamaño y oleadas")
