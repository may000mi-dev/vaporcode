-- sandbox.lua: panel de la sala de pruebas para invocar enemigos y dar ítems.
-- No es un sistema montado: run.lua lo llama como UI para no mezclarlo con
-- las reglas de la partida. La run.sandbox evita que estas pruebas ensucien
-- monedas, desbloqueos o récords del guardado real.
local Data = require("src.run.data")
local Fonts = require("src.utils.fonts")
local Screen = require("src.utils.screen")
local Util = require("src.utils.util")
local Themes = require("src.data.themes")

local Sandbox = {
  activeTab = "enemies",
  quantity = 1,
  message = nil,
  enemyIds = nil,
  itemIds = nil,
  tabs = {},
  gridRects = {},
  gridClip = nil,
  scroll = 0,
  maxScroll = 0,
  drag = nil,
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
  Sandbox.scroll = 0
  Sandbox.maxScroll = 0
  Sandbox.drag = nil
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

  local footerY = y + height - 58
  Sandbox.gridClip = {
    x = gridX,
    y = gridY,
    w = width - 40,
    h = math.max(cellH, footerY - 14 - gridY),
  }

  Sandbox.gridRects = {}
  for index, id in ipairs(ids) do
    local column = (index - 1) % columns
    local row = math.floor((index - 1) / columns)
    Sandbox.gridRects[#Sandbox.gridRects + 1] = {
      x = gridX + column * (cellW + gap),
      y = gridY + row * (cellH + gap) - Sandbox.scroll,
      w = cellW,
      h = cellH,
      id = id,
    }
  end

  local rowCount = math.ceil(#ids / columns)
  local contentHeight = math.max(0, rowCount * (cellH + gap) - gap)
  Sandbox.maxScroll = math.max(0, contentHeight - Sandbox.gridClip.h)
  Sandbox.scroll = math.max(0, math.min(Sandbox.scroll, Sandbox.maxScroll))
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
    Sandbox.scroll = 0
    Sandbox.drag = nil
    return
  end
  if Util.inside(x, y, Sandbox.tabs.items) then
    Sandbox.activeTab = "items"
    Sandbox.scroll = 0
    Sandbox.drag = nil
    return
  end
  if Util.inside(x, y, Sandbox.tabs.quantity) then
    Sandbox.quantity = Sandbox.quantity == 1 and 5 or 1
    return
  end

  for _, rect in ipairs(Sandbox.gridRects) do
    if Util.inside(x, y, rect)
      and Util.inside(x, y, Sandbox.gridClip) then
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

function Sandbox.setScroll(value)
  Sandbox.scroll = math.max(0, math.min(value, Sandbox.maxScroll or 0))
end

function Sandbox.pointerPressed(run, pointerId, x, y)
  Sandbox.layout()
  if Sandbox.maxScroll > 0 and Util.inside(x, y, Sandbox.gridClip) then
    Sandbox.drag = {
      pointerId = pointerId,
      run = run,
      y = y,
      scroll = Sandbox.scroll,
      moved = false,
    }
    return
  end
  Sandbox.pressed(run, x, y)
end

function Sandbox.pointerMoved(pointerId, x, y)
  local drag = Sandbox.drag
  if not drag or drag.pointerId ~= pointerId then return end
  local delta = drag.y - y
  if math.abs(delta) > 6 then drag.moved = true end
  Sandbox.setScroll(drag.scroll + delta)
end

function Sandbox.pointerReleased(pointerId, x, y)
  local drag = Sandbox.drag
  if not drag or drag.pointerId ~= pointerId then return end
  Sandbox.drag = nil
  if not drag.moved then Sandbox.pressed(drag.run, x, y) end
end

function Sandbox.wheelmoved(x, y)
  Sandbox.layout()
  if Sandbox.maxScroll <= 0 then return end
  Sandbox.setScroll(Sandbox.scroll - (y or 0) * 36)
end

local function setListClip(rect)
  if not love.graphics.setScissor then return end
  love.graphics.setScissor(
    Screen.ox + rect.x * Screen.scale,
    Screen.oy + rect.y * Screen.scale,
    rect.w * Screen.scale,
    rect.h * Screen.scale
  )
end

local function clearListClip()
  if not love.graphics.setScissor then return end
  love.graphics.setScissor(
    Screen.ox,
    Screen.oy,
    Screen.width * Screen.scale,
    Screen.height * Screen.scale
  )
end

local function drawButton(rect, label, selected, accent, theme)
  local background = selected and theme.buttonSelected or theme.button
  love.graphics.setColor(background[1], background[2], background[3], 0.96)
  love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 6, 6)
  local border = accent or theme.border
  love.graphics.setColor(border[1], border[2], border[3])
  love.graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, 6, 6)
  love.graphics.setFont(Fonts.small)
  local text = selected and theme.text or theme.muted
  love.graphics.setColor(text[1], text[2], text[3])
  love.graphics.printf(label, rect.x + 6, rect.y + 11, rect.w - 12, "center")
end

function Sandbox.draw(run)
  Sandbox.layout()
  local theme = Themes.current()
  local panel = Sandbox.panel

  love.graphics.setColor(0, 0, 0, 0.78)
  love.graphics.rectangle("fill", 0, 0, Screen.width, Screen.height)

  love.graphics.setColor(theme.panel[1], theme.panel[2], theme.panel[3], 0.99)
  love.graphics.rectangle("fill", panel.x, panel.y, panel.w, panel.h, 12, 12)
  love.graphics.setColor(theme.border[1], theme.border[2], theme.border[3])
  love.graphics.rectangle("line", panel.x, panel.y, panel.w, panel.h, 12, 12)

  love.graphics.setFont(Fonts.title)
  love.graphics.setColor(theme.accent[1], theme.accent[2], theme.accent[3])
  love.graphics.print("SALA DE PRUEBAS", panel.x + 20, panel.y + 14)

  love.graphics.setFont(Fonts.small)
  love.graphics.setColor(theme.muted[1], theme.muted[2], theme.muted[3])
  love.graphics.print(
    "Sin progreso permanente · monedas y desbloqueos no se guardan",
    panel.x + 20,
    panel.y + 36
  )

  drawButton(Sandbox.closeRect, "X", false, { 0.90, 0.40, 0.35 }, theme)
  drawButton(
    Sandbox.tabs.enemies,
    "ENEMIGOS",
    Sandbox.activeTab == "enemies",
    nil,
    theme
  )
  drawButton(
    Sandbox.tabs.items,
    "ÍTEMS",
    Sandbox.activeTab == "items",
    nil,
    theme
  )
  drawButton(
    Sandbox.tabs.quantity,
    "CANTIDAD x" .. Sandbox.quantity,
    Sandbox.quantity > 1,
    theme.secondary,
    theme
  )

  setListClip(Sandbox.gridClip)
  for _, rect in ipairs(Sandbox.gridRects) do
    if rect.y + rect.h >= Sandbox.gridClip.y
      and rect.y <= Sandbox.gridClip.y + Sandbox.gridClip.h then
      local def
      if Sandbox.activeTab == "enemies" then
        def = Data.enemyTypes[rect.id]
      else
        def = Data.items[rect.id]
      end
      drawButton(rect, def.name or rect.id, false, def.color, theme)
    end
  end
  clearListClip()

  if Sandbox.maxScroll > 0 then
    local track = {
      x = Sandbox.gridClip.x + Sandbox.gridClip.w + 6,
      y = Sandbox.gridClip.y,
      w = 4,
      h = Sandbox.gridClip.h,
    }
    local ratio = Sandbox.gridClip.h / (Sandbox.gridClip.h + Sandbox.maxScroll)
    local thumbH = math.max(18, track.h * ratio)
    local thumbY = track.y + (track.h - thumbH) *
      (Sandbox.scroll / Sandbox.maxScroll)
    love.graphics.setColor(theme.border[1], theme.border[2], theme.border[3], 0.5)
    love.graphics.rectangle("fill", track.x, track.y, track.w, track.h, 2, 2)
    love.graphics.setColor(theme.accent[1], theme.accent[2], theme.accent[3], 0.9)
    love.graphics.rectangle("fill", track.x, thumbY, track.w, thumbH, 2, 2)
  end

  drawButton(Sandbox.footerRects.clear, "VACIAR INVENTARIO", false, theme.secondary, theme)
  drawButton(
    Sandbox.footerRects.invulnerable,
    "INVULNERABLE: " .. (run.sandboxInvuln and "SÍ" or "NO"),
    run.sandboxInvuln,
    theme.accent,
    theme
  )
  drawButton(Sandbox.footerRects.close, "CERRAR", false, nil, theme)

  if Sandbox.message then
    love.graphics.setColor(theme.secondary[1], theme.secondary[2], theme.secondary[3])
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
