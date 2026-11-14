-- sandbox.lua: panel de la sala de pruebas para invocar enemigos y dar ítems.
-- No es un sistema montado: run.lua lo llama como UI para no mezclarlo con
-- las reglas de la partida. La run.sandbox evita que estas pruebas ensucien
-- monedas, desbloqueos o récords del guardado real.
local Data = require("src.run.data")
local Fonts = require("src.utils.fonts")
local Screen = require("src.utils.screen")
local Util = require("src.utils.util")

local Sandbox = {
  activeTab = "enemies",
  quantity = 1,
  message = nil,
  enemyIds = nil,
  itemIds = nil,
  tabs = {},
  gridRects = {},
  footerRects = {},
  closeRect = nil,
  panel = { x = 0, y = 0, w = 0, h = 0 },
}

local function sortByIdName(ids, definitions)
  table.sort(ids, function(a, b)
    local an = definitions[a].name or a
    local bn = definitions[b].name or b
    return an < bn
  end)
  return ids
end

local function prepare()
  if not Sandbox.enemyIds then
    local ids = {}
    for id in pairs(Data.enemyTypes) do
      ids[#ids + 1] = id
    end
    Sandbox.enemyIds = sortByIdName(ids, Data.enemyTypes)
  end
  if not Sandbox.itemIds then
    local ids = {}
    for id, def in pairs(Data.items) do
      if def.kind ~= "character" then
        ids[#ids + 1] = id
      end
    end
    Sandbox.itemIds = sortByIdName(ids, Data.items)
  end
end

function Sandbox.reset()
  Sandbox.activeTab = "enemies"
  Sandbox.quantity = 1
  Sandbox.message = nil
end

-- Reconstruye la cuadrícula cada frame de dibujo/entrada. Son pocas tablas
-- (máximo 18 botones) y así el layout sigue cualquier relación de aspecto.
function Sandbox.layout()
  prepare()

  local width = math.min(Screen.width - 40, 900)
  local height = math.min(Screen.height - 40, 470)
  local x = (Screen.width - width) * 0.5
  local y = (Screen.height - height) * 0.5
  Sandbox.panel = { x = x, y = y, w = width, h = height }

  Sandbox.closeRect = { x = x + width - 52, y = y + 12, w = 40, h = 36 }
  Sandbox.tabs = {
    enemies = { x = x + 20, y = y + 58, w = 170, h = 42 },
    items = { x = x + 198, y = y + 58, w = 130, h = 42 },
    quantity = { x = x + 338, y = y + 58, w = 150, h = 42 },
  }

  local ids = Sandbox.activeTab == "enemies"
    and Sandbox.enemyIds
    or Sandbox.itemIds
  local columns = 3
  local gap = 6
  local gridX = x + 20
  local gridY = y + 112
  local cellW = (width - 40 - (columns - 1) * gap) / columns
  local cellH = 38

  Sandbox.gridRects = {}
  for index, id in ipairs(ids) do
    local column = (index - 1) % columns
    local row = math.floor((index - 1) / columns)
    Sandbox.gridRects[#Sandbox.gridRects + 1] = {
      x = gridX + column * (cellW + gap),
      y = gridY + row * (cellH + gap),
      w = cellW,
      h = cellH,
      id = id,
    }
  end

  local footerY = y + height - 58
  Sandbox.footerRects = {
    clear = { x = x + 20, y = footerY, w = 190, h = 40 },
    invulnerable = { x = x + 220, y = footerY, w = 230, h = 40 },
    close = { x = x + width - 190, y = footerY, w = 170, h = 40 },
  }
end

local function spawnEnemy(run, id, amount)
  local def = Data.enemyTypes[id]
  if not def then return end

  local spawned = 0
  for _ = 1, amount or 1 do
    local x, y = run.dungeon:randomFloorPoint(
      run.player.x,
      run.player.y,
      150,
      def.radius or 14
    )
    if not x then
      x = run.player.x + 130
      y = run.player.y
    end

    local enemy = run:createEnemy(id, x, y, { noElite = true })
    if enemy then
      spawned = spawned + 1
      if def.boss then
        run.boss = enemy
      end
    end
  end
  if spawned == 0 then return end

  run.overlay = nil
  run:clearInput()
  local label = def.name or id
  if spawned > 1 then
    label = label .. " x" .. spawned
  end
  run:notify("Invocado: " .. label, def.color)
end

local function giveItem(run, id)
  local def = Data.items[id]
  if not def then return end

  local status, amount = run:addItemToInventory(id, Sandbox.quantity)
  amount = amount or Sandbox.quantity
  if status == "ok" then
    Sandbox.message = def.name .. " x" .. amount .. " activo"
  elseif status == "stored" then
    Sandbox.message = def.name .. " guardado · abre la mochila (B)"
  elseif status == "full" then
    Sandbox.message = "Mochila llena"
  elseif status == "duplicate" then
    Sandbox.message = def.name .. " ya está al máximo"
  else
    Sandbox.message = "No se pudo dar " .. def.name
  end
end

local function clearInventory(run)
  run.inventory = {}
  run.storage = {}
  run.itemDrops = {}
  run.abilitySlot1 = nil
  run.abilitySlot2 = nil
  run:rebuildPassives()
  run.pets = {}
  run.petSnapshot = nil
  run.fluteReady = false
  run.pendingStorageIndex = nil
  Sandbox.message = "Inventario de pruebas vaciado"
end

function Sandbox.pressed(run, x, y)
  Sandbox.layout()
  if Util.inside(x, y, Sandbox.closeRect) then
    run.overlay = nil
    run:clearInput()
    return
  end

  if Util.inside(x, y, Sandbox.tabs.enemies) then
    Sandbox.activeTab = "enemies"
    return
  end
  if Util.inside(x, y, Sandbox.tabs.items) then
    Sandbox.activeTab = "items"
    return
  end
  if Util.inside(x, y, Sandbox.tabs.quantity) then
    Sandbox.quantity = Sandbox.quantity == 1 and 5 or 1
    return
  end

  for _, rect in ipairs(Sandbox.gridRects) do
    if Util.inside(x, y, rect) then
      if Sandbox.activeTab == "enemies" then
        spawnEnemy(run, rect.id, Sandbox.quantity)
      else
        giveItem(run, rect.id)
      end
      return
    end
  end

  if Util.inside(x, y, Sandbox.footerRects.clear) then
    clearInventory(run)
    return
  end
  if Util.inside(x, y, Sandbox.footerRects.invulnerable) then
    run.sandboxInvuln = not run.sandboxInvuln
    Sandbox.message = run.sandboxInvuln
      and "Invulnerabilidad activada"
      or "Invulnerabilidad desactivada"
    return
  end
  if Util.inside(x, y, Sandbox.footerRects.close) then
    run.overlay = nil
    run:clearInput()
  end
end

local function drawButton(rect, label, selected, accent)
  love.graphics.setColor(
    selected and 0.16 or 0.08,
    selected and 0.24 or 0.11,
    selected and 0.26 or 0.14,
    0.96
  )
  love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 6, 6)
  love.graphics.setColor(
    accent and accent[1] or 0.45,
    accent and accent[2] or 0.75,
    accent and accent[3] or 0.85
  )
  love.graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, 6, 6)
  love.graphics.setFont(Fonts.small)
  love.graphics.setColor(selected and 1 or 0.82, selected and 1 or 0.88, selected and 1 or 0.94)
  love.graphics.printf(label, rect.x + 6, rect.y + 11, rect.w - 12, "center")
end

function Sandbox.draw(run)
  Sandbox.layout()
  local panel = Sandbox.panel

  love.graphics.setColor(0, 0, 0, 0.78)
  love.graphics.rectangle("fill", 0, 0, Screen.width, Screen.height)

  love.graphics.setColor(0.05, 0.07, 0.09, 0.99)
  love.graphics.rectangle("fill", panel.x, panel.y, panel.w, panel.h, 12, 12)
  love.graphics.setColor(0.35, 0.65, 0.72)
  love.graphics.rectangle("line", panel.x, panel.y, panel.w, panel.h, 12, 12)

  love.graphics.setFont(Fonts.title)
  love.graphics.setColor(0.60, 0.92, 1.00)
  love.graphics.print("SALA DE PRUEBAS", panel.x + 20, panel.y + 14)

  love.graphics.setFont(Fonts.small)
  love.graphics.setColor(0.62, 0.72, 0.80)
  love.graphics.print(
    "Sin progreso permanente · monedas y desbloqueos no se guardan",
    panel.x + 20,
    panel.y + 36
  )

  drawButton(Sandbox.closeRect, "X", false, { 0.90, 0.40, 0.35 })
  drawButton(
    Sandbox.tabs.enemies,
    "ENEMIGOS",
    Sandbox.activeTab == "enemies"
  )
  drawButton(
    Sandbox.tabs.items,
    "ÍTEMS",
    Sandbox.activeTab == "items"
  )
  drawButton(
    Sandbox.tabs.quantity,
    "CANTIDAD x" .. Sandbox.quantity,
    Sandbox.quantity > 1,
    { 0.90, 0.72, 0.30 }
  )

  for _, rect in ipairs(Sandbox.gridRects) do
    local def
    if Sandbox.activeTab == "enemies" then
      def = Data.enemyTypes[rect.id]
    else
      def = Data.items[rect.id]
    end
    drawButton(rect, def.name or rect.id, false, def.color)
  end

  drawButton(Sandbox.footerRects.clear, "VACIAR INVENTARIO", false, { 0.90, 0.60, 0.30 })
  drawButton(
    Sandbox.footerRects.invulnerable,
    "INVULNERABLE: " .. (run.sandboxInvuln and "SÍ" or "NO"),
    run.sandboxInvuln,
    { 0.40, 0.90, 0.65 }
  )
  drawButton(Sandbox.footerRects.close, "CERRAR", false)

  if Sandbox.message then
    love.graphics.setColor(1.00, 0.88, 0.45)
    love.graphics.printf(
      Sandbox.message,
      panel.x + 20,
      panel.y + panel.h - 84,
      panel.w - 40,
      "center"
    )
  end
end

return Sandbox
