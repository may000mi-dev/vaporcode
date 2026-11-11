-- dungeon.lua: generación procedural de salas y colisiones contra la rejilla.
local Data = require("src.run.data")
local Util = require("src.utils.util")

local Dungeon = {}
Dungeon.__index = Dungeon

Dungeon.TILE = 36

function Dungeon.new(spec, seed)
  local self = setmetatable({}, Dungeon)
  self.spec = spec
  self.rng = love.math.newRandomGenerator(seed)
  self.tile = Dungeon.TILE
  -- El mundo ya no se centra en la pantalla: la cámara sigue al jugador.
  self.offsetX = 0
  self.offsetY = 0
  self:chooseSize()
  self.grid = {}
  self.solid = {}
  self.rooms = {}
  self.destructible = {}
  self.valveSpots = {}
  self.chestSpots = {}
  self.reserved = {}
  self:generate()
  self:buildWalls()
  self:placeFeatures()
  return self
end

function Dungeon:chooseSize()
  local gen = Data.dungeonGen
  self.sizeScale = gen.sizeScaleMin
    + self.rng:random() * (gen.sizeScaleMax - gen.sizeScaleMin)

  -- La escala se aplica al área; las dimensiones crecen con su raíz.
  local dimScale = math.sqrt(self.sizeScale)
  self.cols = math.max(gen.minCols, math.floor(gen.baseCols * dimScale + 0.5))
  self.rows = math.max(gen.minRows, math.floor(gen.baseRows * dimScale + 0.5))
  self.width = self.cols * self.tile
  self.height = self.rows * self.tile
end

function Dungeon:tileCenter(tx, ty)
  return self.offsetX + (tx - 0.5) * self.tile,
    self.offsetY + (ty - 0.5) * self.tile
end

function Dungeon:generate()
  for y = 1, self.rows do
    local row = {}
    for x = 1, self.cols do
      row[x] = 1
    end
    self.grid[y] = row
  end

  local gen = Data.dungeonGen
  local dimScale = math.sqrt(self.sizeScale)
  local count = self.rng:random(gen.minRooms, gen.maxRooms)
    + math.floor((self.spec.depth - 1) * gen.extraRoomsPerDepth)

  -- Más área implica más salas para conservar una densidad jugable.
  count = math.floor(count * dimScale + 0.5)
  count = math.min(count, math.max(1, math.floor(gen.maxRoomsCap * dimScale + 0.5)))

  for _ = 1, count do
    local w = self.rng:random(gen.minRoomW, gen.maxRoomW)
    local h = self.rng:random(gen.minRoomH, gen.maxRoomH)
    local x = self.rng:random(2, self.cols - w - 1)
    local y = self.rng:random(2, self.rows - h - 1)
    local room = {
      x = x,
      y = y,
      w = w,
      h = h,
      cx = x + math.floor((w - 1) / 2),
      cy = y + math.floor((h - 1) / 2),
    }

    if self:canPlace(room) then
      if #self.rooms > 0 then
        self:carveCorridor(self.rooms[#self.rooms], room)
      end
      self:carveRoom(room)
      self.rooms[#self.rooms + 1] = room
    end
  end

  if #self.rooms == 0 then
    local w = Data.dungeonGen.minRoomW + 2
    local h = Data.dungeonGen.minRoomH + 1
    local x = math.floor((self.cols - w) * 0.5)
    local y = math.floor((self.rows - h) * 0.5)
    local room = {
      x = x,
      y = y,
      w = w,
      h = h,
      cx = x + math.floor((w - 1) / 2),
      cy = y + math.floor((h - 1) / 2),
    }
    self:carveRoom(room)
    self.rooms[1] = room
  end
end

function Dungeon:canPlace(room)
  local spacing = Data.dungeonGen.spacing
  for _, other in ipairs(self.rooms) do
    local dx = math.abs((room.x + room.w * 0.5) - (other.x + other.w * 0.5))
    local dy = math.abs((room.y + room.h * 0.5) - (other.y + other.h * 0.5))
    if dx < (room.w + other.w) * 0.5 + spacing
      and dy < (room.h + other.h) * 0.5 + spacing
    then
      return false
    end
  end
  return true
end

function Dungeon:carveRoom(room)
  for y = room.y, room.y + room.h - 1 do
    for x = room.x, room.x + room.w - 1 do
      self.grid[y][x] = 0
    end
  end
end

function Dungeon:carveCorridor(a, b)
  local x1, y1 = a.cx, a.cy
  local x2, y2 = b.cx, b.cy
  local midX = math.floor((x1 + x2) * 0.5)

  for x = math.min(x1, midX), math.max(x1, midX) do
    self.grid[y1][x] = 0
  end
  for y = math.min(y1, y2), math.max(y1, y2) do
    self.grid[y][midX] = 0
  end
  for x = math.min(midX, x2), math.max(midX, x2) do
    self.grid[y2][x] = 0
  end
end

function Dungeon:buildWalls()
  for y = 1, self.rows do
    self.solid[y] = {}
    for x = 1, self.cols do
      local border = x == 1 or x == self.cols or y == 1 or y == self.rows
      if border then
        self.solid[y][x] = 1
      elseif self.grid[y][x] == 1 then
        self.solid[y][x] = 1
      else
        self.solid[y][x] = 0
      end
    end
  end
end

function Dungeon:isReserved(tx, ty)
  return self.reserved[ty] and self.reserved[ty][tx] == true
end

function Dungeon:reserve(tx, ty)
  self.reserved[ty] = self.reserved[ty] or {}
  self.reserved[ty][tx] = true
end

function Dungeon:roomTiles(firstRoom, lastRoom, minDistance, spawnX, spawnY)
  local candidates = {}
  local minD2 = (minDistance or 0) * (minDistance or 0)

  for i = firstRoom, lastRoom do
    local room = self.rooms[i]
    if room then
      for ty = room.y, room.y + room.h - 1 do
        for tx = room.x, room.x + room.w - 1 do
          if self.grid[ty][tx] == 0 and not self:isReserved(tx, ty) then
            local px, py = self:tileCenter(tx, ty)
            local farEnough = not spawnX
              or Util.dist2(px, py, spawnX, spawnY) >= minD2
            if farEnough then
              candidates[#candidates + 1] = {
                tx = tx,
                ty = ty,
                x = px,
                y = py,
              }
            end
          end
        end
      end
    end
  end

  return candidates
end

function Dungeon:pickFeaturePoint(firstRoom, lastRoom, minDistance, spawnX, spawnY)
  local candidates = self:roomTiles(
    firstRoom,
    lastRoom,
    minDistance,
    spawnX,
    spawnY
  )

  -- En mapas pequeños se relaja la distancia para no quedarse sin cofres.
  if #candidates == 0 then
    candidates = self:roomTiles(firstRoom, lastRoom, 0, spawnX, spawnY)
  end
  if #candidates == 0 then return nil end

  local point = candidates[self.rng:random(1, #candidates)]
  self:reserve(point.tx, point.ty)
  return point.x, point.y, point.tx, point.ty
end

function Dungeon:placeFeatures()
  local sx, sy = self:spawnPoint()
  local ex, ey = self:exitPoint()
  local spawnTx, spawnTy = self:tileAtPixel(sx, sy)
  local exitTx, exitTy = self:tileAtPixel(ex, ey)
  self:reserve(spawnTx, spawnTy)
  self:reserve(exitTx, exitTy)

  local depth = self.spec.depth or 1
  local valveCount = Data.valve.countBase
    + math.floor((depth - 1) * Data.valve.countPerDepth)
  valveCount = math.min(valveCount, Data.valve.maxCount)
  for _ = 1, valveCount do
    local x, y, tx, ty = self:pickFeaturePoint(
      1,
      #self.rooms,
      Data.valve.minDistance,
      sx,
      sy
    )
    if not x then break end
    self.valveSpots[#self.valveSpots + 1] = {
      x = x,
      y = y,
      tx = tx,
      ty = ty,
    }
  end

  local chestCount = Data.chest.countBase
    + math.floor((depth - 1) * Data.chest.countPerDepth)
  chestCount = math.min(chestCount, Data.chest.maxCount)
  local firstChestRoom = #self.rooms > 2 and 2 or 1
  local lastChestRoom = #self.rooms > 2 and #self.rooms - 1 or #self.rooms
  for _ = 1, chestCount do
    local x, y, tx, ty = self:pickFeaturePoint(
      firstChestRoom,
      lastChestRoom,
      Data.chest.minDistance,
      sx,
      sy
    )
    if not x then break end
    self.chestSpots[#self.chestSpots + 1] = {
      x = x,
      y = y,
      tx = tx,
      ty = ty,
    }
  end

  self:placeDestructibles(depth)
end

function Dungeon:placeDestructibles(depth)
  local candidates = {}
  for ty = 2, self.rows - 1 do
    for tx = 2, self.cols - 1 do
      if self.grid[ty][tx] == 1 then
        local left = self.grid[ty][tx - 1] == 0
        local right = self.grid[ty][tx + 1] == 0
        local up = self.grid[ty - 1][tx] == 0
        local down = self.grid[ty + 1][tx] == 0
        if left or right or up or down then
          candidates[#candidates + 1] = {
            tx = tx,
            ty = ty,
            shortcut = (left and right) or (up and down),
          }
        end
      end
    end
  end

  local count = self.rng:random(
    Data.destructible.minCount,
    Data.destructible.maxCount
  )
  count = count
    + math.floor((depth - 1) * Data.destructible.perDepth)
  count = math.min(count, Data.destructible.maxCountCap)
  count = math.min(count, #candidates)

  for _ = 1, count do
    local index = self.rng:random(1, #candidates)
    local wall = candidates[index]
    table.remove(candidates, index)

    local loot = not wall.shortcut
      or self.rng:random() < Data.destructible.lootChance
    self.destructible[wall.ty] = self.destructible[wall.ty] or {}
    self.destructible[wall.ty][wall.tx] = {
      hp = Data.destructible.hp,
      maxHp = Data.destructible.hp,
      loot = loot,
      shortcut = wall.shortcut,
    }
  end
end

function Dungeon:isDestructibleTile(tx, ty)
  return self.destructible[ty] ~= nil
    and self.destructible[ty][tx] ~= nil
end

function Dungeon:damageWall(tx, ty, amount)
  local wall = self.destructible[ty] and self.destructible[ty][tx]
  if not wall then return false, nil end

  wall.hp = wall.hp - (amount or 1)
  if wall.hp > 0 then
    return false, wall
  end

  self.destructible[ty][tx] = nil
  self.solid[ty][tx] = 0
  self.grid[ty][tx] = 0
  return true, wall
end

function Dungeon:spawnPoint()
  local room = self.rooms[1]
  return self:tileCenter(room.cx, room.cy)
end

function Dungeon:exitPoint()
  local room = self.rooms[#self.rooms]
  local px, py = self:tileCenter(room.cx, room.cy)
  local sx, sy = self:spawnPoint()
  if px == sx and py == sy then
    px, py = self:tileCenter(room.x, room.y)
  end
  return px, py
end

function Dungeon:tileAtPixel(px, py)
  local tx = math.floor((px - self.offsetX) / self.tile) + 1
  local ty = math.floor((py - self.offsetY) / self.tile) + 1
  return tx, ty
end

function Dungeon:isSolidTile(tx, ty)
  if tx < 1 or tx > self.cols or ty < 1 or ty > self.rows then
    return true
  end
  return self.solid[ty][tx] == 1
end

function Dungeon:isSolidPixel(px, py)
  local tx, ty = self:tileAtPixel(px, py)
  return self:isSolidTile(tx, ty)
end

function Dungeon:circleCollides(px, py, radius)
  local minX = math.floor((px - radius - self.offsetX) / self.tile) + 1
  local maxX = math.floor((px + radius - self.offsetX) / self.tile) + 1
  local minY = math.floor((py - radius - self.offsetY) / self.tile) + 1
  local maxY = math.floor((py + radius - self.offsetY) / self.tile) + 1

  for ty = minY, maxY do
    for tx = minX, maxX do
      if self:isSolidTile(tx, ty) then
        local left = self.offsetX + (tx - 1) * self.tile
        local top = self.offsetY + (ty - 1) * self.tile
        local nearX = Util.clamp(px, left, left + self.tile)
        local nearY = Util.clamp(py, top, top + self.tile)
        local dx = px - nearX
        local dy = py - nearY
        if dx * dx + dy * dy < radius * radius then
          return true
        end
      end
    end
  end

  return false
end

function Dungeon:moveCircle(x, y, dx, dy, radius)
  x = x + dx
  if self:circleCollides(x, y, radius) then
    x = x - dx
  end

  y = y + dy
  if self:circleCollides(x, y, radius) then
    y = y - dy
  end

  x = Util.clamp(x, self.offsetX + radius, self.offsetX + self.width - radius)
  y = Util.clamp(y, self.offsetY + radius, self.offsetY + self.height - radius)
  return x, y
end

function Dungeon:lineOfSight(ax, ay, bx, by)
  local d = Util.dist(ax, ay, bx, by)
  local steps = math.ceil(d / Data.dungeonGen.losStep)
  if steps < 1 then return true end

  for i = 1, steps - 1 do
    local t = i / steps
    if self:isSolidPixel(ax + (bx - ax) * t, ay + (by - ay) * t) then
      return false
    end
  end

  return true
end

-- Distancia recorrida por un rayo hasta chocar con un muro.
function Dungeon:raycast(ax, ay, dx, dy, maxDistance, step)
  step = step or Data.dungeonGen.rayStep
  local steps = math.ceil((maxDistance or 0) / step)
  local previous = 0

  for i = 1, steps do
    local distance = math.min(i * step, maxDistance)
    local px = ax + dx * distance
    local py = ay + dy * distance
    if self:isSolidPixel(px, py) then
      local tx, ty = self:tileAtPixel(px, py)
      return previous, true, tx, ty
    end
    previous = distance
  end

  return maxDistance or previous, false
end

-- Punto libre más cercano; permite saltos que cruzan paredes al aterrizar.
function Dungeon:nearestWalkable(px, py, radius, maxSearch)
  if not self:circleCollides(px, py, radius) then
    return px, py
  end

  local tx, ty = self:tileAtPixel(px, py)
  local maxRing = math.max(1, math.ceil((maxSearch or self.tile * 4) / self.tile))
  local bestX, bestY = nil, nil
  local bestD2 = math.huge

  for ry = -maxRing, maxRing do
    for rx = -maxRing, maxRing do
      local gx = tx + rx
      local gy = ty + ry
      if gx >= 2 and gx <= self.cols - 1 and gy >= 2 and gy <= self.rows - 1 then
        if self.grid[gy][gx] == 0 then
          local cx, cy = self:tileCenter(gx, gy)
          local d2 = Util.dist2(px, py, cx, cy)
          if d2 < bestD2 and not self:circleCollides(cx, cy, radius) then
            bestX, bestY = cx, cy
            bestD2 = d2
          end
        end
      end
    end
  end

  return bestX, bestY
end

function Dungeon:randomFloorPoint(avoidX, avoidY, minDist, radius)
  local candidates = {}
  local minD2 = (minDist or 0) * (minDist or 0)

  for ty = 2, self.rows - 1 do
    for tx = 2, self.cols - 1 do
      if self.grid[ty][tx] == 0 and not self:isReserved(tx, ty) then
        local px, py = self:tileCenter(tx, ty)
        local farEnough = true
        if avoidX then
          farEnough = Util.dist2(px, py, avoidX, avoidY) >= minD2
        end
        if farEnough and (not radius or not self:circleCollides(px, py, radius)) then
          candidates[#candidates + 1] = { x = px, y = py }
        end
      end
    end
  end

  if #candidates == 0 then
    return nil
  end

  local point = candidates[self.rng:random(1, #candidates)]
  return point.x, point.y
end

function Dungeon:draw(camera)
  local colors = Data.colors

  -- Solo se rellena el área de la mazmorra; el exterior queda en oscuridad.
  love.graphics.setColor(colors.floor[1], colors.floor[2], colors.floor[3])
  love.graphics.rectangle("fill", self.offsetX, self.offsetY, self.width, self.height)

  love.graphics.setColor(colors.grid[1], colors.grid[2], colors.grid[3])
  for x = 0, self.cols do
    love.graphics.rectangle("fill", self.offsetX + x * self.tile, self.offsetY, 1, self.height)
  end
  for y = 0, self.rows do
    love.graphics.rectangle("fill", self.offsetX, self.offsetY + y * self.tile, self.width, 1)
  end

  local minX, maxX = 1, self.cols
  local minY, maxY = 1, self.rows
  if camera then
    local left, top, right, bottom = camera.view()
    minX = math.max(1, math.floor((left - self.offsetX) / self.tile) + 1)
    maxX = math.min(self.cols, math.floor((right - self.offsetX) / self.tile) + 1)
    minY = math.max(1, math.floor((top - self.offsetY) / self.tile) + 1)
    maxY = math.min(self.rows, math.floor((bottom - self.offsetY) / self.tile) + 1)
  end

  for y = minY, maxY do
    for x = minX, maxX do
      if self.solid[y][x] == 1 then
        local px = self.offsetX + (x - 1) * self.tile
        local py = self.offsetY + (y - 1) * self.tile
        local fragile = self.destructible[y] and self.destructible[y][x]
        if fragile then
          local color = Data.destructible.color
          love.graphics.setColor(color[1], color[2], color[3])
        else
          love.graphics.setColor(colors.wall[1], colors.wall[2], colors.wall[3])
        end
        love.graphics.rectangle("fill", px, py, self.tile, self.tile)

        if self:isSolidTile(x, y - 1) then
          love.graphics.setColor(
            colors.wallEdge[1],
            colors.wallEdge[2],
            colors.wallEdge[3]
          )
        else
          love.graphics.setColor(
            colors.wallTop[1],
            colors.wallTop[2],
            colors.wallTop[3]
          )
        end
        love.graphics.rectangle("fill", px, py, self.tile, 3)

        if fragile then
          local ratio = fragile.hp / fragile.maxHp
          local crack = Data.destructible.crack
          love.graphics.setColor(crack[1], crack[2], crack[3], 0.45 + 0.40 * (1 - ratio))
          love.graphics.setLineWidth(2)
          love.graphics.line(
            px + 7,
            py + 5,
            px + 17,
            py + 16,
            px + 11,
            py + 29
          )
          love.graphics.line(
            px + 18,
            py + 7,
            px + 26,
            py + 15,
            px + 22,
            py + 25
          )
          love.graphics.setLineWidth(1)
        end
      end
    end
  end

  love.graphics.setColor(1, 1, 1)
end

function Dungeon:drawExit(x, y, open)
  local t = love.timer.getTime()
  local radius = 16 + math.sin(t * 4) * 2

  love.graphics.setColor(0, 0, 0, 0.35)
  love.graphics.circle("fill", x, y + 2, radius + 4)

  if open then
    love.graphics.setColor(0.35, 0.95, 0.65)
    love.graphics.circle("fill", x, y, radius)
    love.graphics.setColor(0.80, 1.00, 0.90)
    love.graphics.circle("line", x, y, radius + 3)
  else
    love.graphics.setColor(0.25, 0.30, 0.30)
    love.graphics.circle("fill", x, y, radius)
    love.graphics.setColor(0.40, 0.45, 0.45)
    love.graphics.circle("line", x, y, radius + 3)
  end
end

return Dungeon
