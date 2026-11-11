-- test_run_floor.lua: entrar a un piso y reintentarlo con el mismo estado.
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
love.timer.getFPS = function()
  return 60
end

local Save = require("src.run.save")
local State = require("src.estados")
local Run = require("src.run.run")

Save.load()
Run.enter("cripta", "amado", "resonance")

assert(Run.timeLeft == 300, "el piso debe iniciar con cinco minutos")
assert(Run.mana == 100 and Run.manaMax == 100, "el maná debe iniciar lleno")
assert(Run.floorSnapshot, "debe guardarse la instantánea del piso")
assert(#Run.valves >= 1, "el piso debe tener válvulas")
assert(#Run.chests >= 1, "el piso debe tener cofres")

local seed = Run.seed
local depth = Run.depth
local spawnX, spawnY = Run.spawnX, Run.spawnY
local firstValves = {}
for i, valve in ipairs(Run.valves) do
  firstValves[i] = { x = valve.x, y = valve.y }
end
local firstChests = {}
for i, chest in ipairs(Run.chests) do
  firstChests[i] = { x = chest.x, y = chest.y, loot = chest.lootIndex }
end
local firstWalls = 0
for _, row in pairs(Run.dungeon.destructible) do
  for _ in pairs(row) do
    firstWalls = firstWalls + 1
  end
end
assert(firstWalls >= 1, "el piso debe tener paredes frágiles")

local firstPositions = {}
for i, enemy in ipairs(Run.enemies) do
  firstPositions[i] = { x = enemy.x, y = enemy.y, kind = enemy.kind }
end

Run.hp = 1
Run.mana = 0
Run.timeLeft = 0.25
Run.xp = 99
Run.playerLevel = 8

assert(Run.retryFloor(Run.floorSnapshot), "el reintento debe cargar la instantánea")
assert(Run.seed == seed and Run.depth == depth, "debe conservarse la semilla y el piso")
assert(Run.spawnX == spawnX and Run.spawnY == spawnY, "debe reaparecer en el mismo punto")
assert(Run.hp == 100 and Run.mana == 100, "debe restaurarse la vida y el maná iniciales")
assert(Run.playerLevel == 1 and Run.xp == 0, "debe restaurarse el nivel inicial del piso")
assert(Run.timeLeft == 300, "el tiempo debe reiniciarse")
assert(#Run.enemies == #firstPositions, "deben reaparecer los mismos enemigos")
assert(#Run.valves == #firstValves, "deben reaparecer las mismas válvulas")
assert(#Run.chests == #firstChests, "deben reaparecer los mismos cofres")

for i, valve in ipairs(Run.valves) do
  local before = firstValves[i]
  assert(
    math.abs(valve.x - before.x) < 0.001
      and math.abs(valve.y - before.y) < 0.001,
    "las válvulas deben conservar su posición"
  )
end

for i, chest in ipairs(Run.chests) do
  local before = firstChests[i]
  assert(
    math.abs(chest.x - before.x) < 0.001
      and math.abs(chest.y - before.y) < 0.001
      and chest.lootIndex == before.loot,
    "los cofres deben conservar su posición y botín"
  )
end

local wallsAfter = 0
for _, row in pairs(Run.dungeon.destructible) do
  for _ in pairs(row) do
    wallsAfter = wallsAfter + 1
  end
end
assert(wallsAfter == firstWalls, "deben reaparecer las mismas paredes frágiles")

for i, enemy in ipairs(Run.enemies) do
  local before = firstPositions[i]
  assert(
    enemy.kind == before.kind
      and math.abs(enemy.x - before.x) < 0.001
      and math.abs(enemy.y - before.y) < 0.001,
    "los enemigos deben regenerarse en las mismas posiciones"
  )
end

local valve = Run.valves[1]
assert(Run:hitValve(valve.x, valve.y, 4), "un disparo debe activar la válvula")
assert(valve.active > 0, "la válvula debe quedar liberando vapor")

local wallX, wallY
for ty, row in pairs(Run.dungeon.destructible) do
  for tx in pairs(row) do
    wallX, wallY = tx, ty
    break
  end
  if wallX then break end
end
assert(wallX, "debe existir una pared frágil para romper")
local wallDef = Run.dungeon.destructible[wallY][wallX]
assert(
  Run:damageWallAt(wallX, wallY, wallDef.hp),
  "la Resonancia/Flecha debe romper la pared"
)
assert(
  not Run.dungeon:isSolidTile(wallX, wallY),
  "la pared destruida debe abrir el paso"
)

local beforeCoins = Save.data.coins
Run:spawnChest(Run.player.x, Run.player.y, "test")
local beforeTime = Run.timeLeft
Run.update(0.016)
assert(Run.timeLeft < beforeTime, "el temporizador debe avanzar durante el juego")
assert(Save.data.coins > beforeCoins, "el cofre debe dar monedas")
assert(#Run.inventory > 0, "el cofre debe entregar un ítem al inventario")

Run.draw()

Run.timeLeft = 0.01
Run.update(0.02)
assert(State.name == "gameover", "agotar el tiempo debe llevar a derrota")
assert(Run.gameOverInfo.reason == "timeout", "la derrota debe indicar tiempo agotado")
assert(Run.gameOverInfo.snapshot, "la derrota debe conservar el piso para reintentar")

print("OK piso, reintento exacto, dibujo y tiempo agotado")
