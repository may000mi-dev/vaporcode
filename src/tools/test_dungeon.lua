-- test_dungeon.lua: rangos de tamaño y bloqueo de línea de visión.
package.path = "./?.lua;" .. package.path

love = {
  math = {
    newRandomGenerator = function(seed)
      math.randomseed(seed)
      local rng = {}
      function rng:random(a, b)
        if a == nil then return math.random() end
        if b == nil then return math.random(a) end
        return math.random(a, b)
      end
      return rng
    end,
  },
}

local Dungeon = require("src.run.dungeon")

local minArea = math.huge
local maxArea = 0

for seed = 1, 200 do
  local dungeon = Dungeon.new({ depth = (seed % 5) + 1 }, seed)
  assert(dungeon.cols >= 18 and dungeon.cols <= 52, "ancho fuera de rango")
  assert(dungeon.rows >= 11 and dungeon.rows <= 30, "alto fuera de rango")
  assert(#dungeon.rooms >= 1, "la mazmorra debe tener salas")

  local area = dungeon.cols * dungeon.rows
  minArea = math.min(minArea, area)
  maxArea = math.max(maxArea, area)

  local sx, sy = dungeon:spawnPoint()
  assert(not dungeon:circleCollides(sx, sy, 16), "el spawn no debe estar en un muro")

  local ex, ey = dungeon:exitPoint()
  assert(ex and ey, "debe existir una salida")

  assert(#dungeon.valveSpots >= 1, "debe generarse al menos una válvula")
  assert(#dungeon.chestSpots >= 1, "debe generarse al menos un cofre")

  local fragile = 0
  for _, row in pairs(dungeon.destructible) do
    for _ in pairs(row) do
      fragile = fragile + 1
    end
  end
  assert(fragile >= 1, "debe generarse al menos una pared frágil")
end

assert(minArea >= 198, "el área mínima debe ser al menos 1/2 del mapa base")
assert(maxArea <= 1560, "el área máxima debe ser hasta 4 veces el mapa base")

local breakable = Dungeon.new({ depth = 1 }, 123)
local wallX, wallY
for ty, row in pairs(breakable.destructible) do
  for tx in pairs(row) do
    wallX, wallY = tx, ty
    break
  end
  if wallX then break end
end

assert(wallX and breakable:isSolidTile(wallX, wallY), "la pared frágil debe bloquear")
local wallDef = breakable.destructible[wallY][wallX]
local broken = breakable:damageWall(wallX, wallY, wallDef.hp)
assert(broken, "la pared debe romperse al agotar su vida")
assert(not breakable:isSolidTile(wallX, wallY), "la pared rota debe abrir el paso")

local wall = setmetatable({
  isSolidPixel = function(_, x)
    return x > 60 and x < 80
  end,
}, { __index = Dungeon })

assert(not Dungeon.lineOfSight(wall, 0, 0, 100, 0), "la pared debe bloquear")
assert(Dungeon.lineOfSight(wall, 0, 0, 50, 0), "sin pared debe haber visión")

print(string.format("OK mazmorras y LOS (área %d..%d)", minArea, maxArea))
