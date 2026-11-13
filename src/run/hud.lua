-- hud.lua: vida, experiencia, monedas, pulso, pausa y capa de depuración.
local Data = require("src.run.data")
local Fonts = require("src.utils.fonts")
local Screen = require("src.utils.screen")
local Rhythm = require("src.run.rhythm")
local Save = require("src.run.save")
local Util = require("src.utils.util")
local Debug = require("src.utils.debug")
local TextCache = require("src.utils.textcache")

local HUD = {}

HUD.pauseButton = { x = 0, y = 10, w = 92, h = 36 }
HUD.backpackButton = { x = 0, y = 10, w = 104, h = 36 }
HUD.shopButton = { x = 0, y = 52, w = 104, h = 36 }
HUD.sandboxButton = { x = 0, y = 94, w = 104, h = 36 }

local inventoryX = 0
local inventoryY = 493
local inventoryW = 52
local inventoryH = 38
local inventoryGap = 6

-- Ancla los botones al borde derecho y centra la franja según el ancho real.
function HUD.layout()
  local width = Screen.width
  HUD.pauseButton.x = width - 108
  HUD.backpackButton.x = width - 224
  HUD.shopButton.x = width - 224
  HUD.sandboxButton.x = width - 224
  local strip = Data.inventory.maxActive * inventoryW
    + (Data.inventory.maxActive - 1) * inventoryGap
  inventoryX = (width - strip) * 0.5
end

-- Claves fijas por espacio: una clave concatenada por frame alocaría
-- tanto como el string que queremos ahorrar.
local invIndexKeys = { "hud-inv-i1", "hud-inv-i2", "hud-inv-i3", "hud-inv-i4", "hud-inv-i5" }
local invLabelKeys = { "hud-inv-l1", "hud-inv-l2", "hud-inv-l3", "hud-inv-l4", "hud-inv-l5" }

function HUD.hitPause(x, y)
  HUD.layout()
  return Util.inside(x, y, HUD.pauseButton)
end

function HUD.hitBackpack(x, y)
  HUD.layout()
  return Util.inside(x, y, HUD.backpackButton)
end

function HUD.hitShop(x, y)
  HUD.layout()
  return Util.inside(x, y, HUD.shopButton)
end

function HUD.hitSandbox(x, y)
  HUD.layout()
  return Util.inside(x, y, HUD.sandboxButton)
end

-- El panel de pausa calcula su botón de salida con el mismo tamaño que el
-- dibujo; así el toque y la confirmación coinciden en cualquier pantalla.
function HUD.pauseExitRect()
  local panelW, panelH = 560, 390
  local px = (Screen.width - panelW) * 0.5
  local py = (Screen.height - panelH) * 0.5
  local width, height = 340, 46
  return {
    x = px + (panelW - width) * 0.5,
    y = py + 252,
    w = width,
    h = height,
  }
end

function HUD.hitExitMenu(x, y)
  return Util.inside(x, y, HUD.pauseExitRect())
end

function HUD.inventoryRect(index)
  return {
    x = inventoryX + (index - 1) * (inventoryW + inventoryGap),
    y = inventoryY,
    w = inventoryW,
    h = inventoryH,
  }
end

function HUD.shopUnlocked(run)
  local unlock = Data.shop.unlock
  return run.playerLevel >= unlock.characterLevel and run.depth >= unlock.floor
end

function HUD.drawInventory(run)
  HUD.layout()
  for index = 1, Data.inventory.maxActive do
    local rect = HUD.inventoryRect(index)
    local slot = run.inventory and run.inventory[index]
    local selected = run.overlay == "backpack"
      and run.selectionSection == "active"
      and run.selectedInventory == index

    love.graphics.setColor(0.05, 0.065, 0.08, 0.86)
    love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 6, 6)
    if selected then
      love.graphics.setColor(1.00, 0.82, 0.32)
      love.graphics.setLineWidth(2)
    else
      love.graphics.setColor(0.22, 0.30, 0.36)
      love.graphics.setLineWidth(1)
    end
    love.graphics.rectangle("line", rect.x, rect.y, rect.w, rect.h, 6, 6)
    love.graphics.setLineWidth(1)

    love.graphics.setFont(Fonts.small)
    if slot then
      local def = Data.items[slot.itemId]
      local color = def.color
      love.graphics.setColor(color[1], color[2], color[3], 0.22)
      love.graphics.circle("fill", rect.x + 13, rect.y + rect.h * 0.5, 12)
      love.graphics.setColor(color[1], color[2], color[3])
      love.graphics.circle("fill", rect.x + 13, rect.y + rect.h * 0.5, 7)
      love.graphics.setColor(1, 1, 1)
      love.graphics.print(def.short, rect.x + 23, rect.y + 4)
      love.graphics.setColor(0.66, 0.74, 0.82)
      local amount = slot.amount or 1
      local fmt = amount > 1 and "i%dx%d" or "i%d"
      love.graphics.print(TextCache.format(invLabelKeys[index], fmt, index, amount), rect.x + 23, rect.y + 20)
    else
      love.graphics.setColor(0.34, 0.42, 0.49)
      love.graphics.print(TextCache.format(invIndexKeys[index], "i%d", index), rect.x + 6, rect.y + 5)
      love.graphics.setColor(0.24, 0.30, 0.36)
      love.graphics.print("--", rect.x + 22, rect.y + 20)
    end
  end

  love.graphics.setFont(Fonts.small)
  love.graphics.setColor(0.55, 0.64, 0.72)
  love.graphics.print(
    TextCache.format(
      "hud-storage",
      "Guardados %d/%d",
      #(run.storage or {}),
      Data.inventory.maxInactive
    ),
    inventoryX + Data.inventory.maxActive * inventoryW
      + (Data.inventory.maxActive - 1) * inventoryGap + 12,
    501
  )
end

function HUD.draw(run)
  HUD.layout()
  love.graphics.setColor(0.05, 0.06, 0.08, 0.82)
  love.graphics.rectangle("fill", 10, 8, 500, 122, 8, 8)

  love.graphics.setFont(Fonts.small)
  if run.mode == "story" then
    love.graphics.setColor(0.78, 0.64, 1.00)
    love.graphics.print(
      TextCache.format(
        "hud-floor-story",
        "Historia · %s · Piso %d",
        run.def.name,
        run.depth
      ),
      20,
      12
    )
  else
    love.graphics.setColor(0.55, 0.85, 0.95)
    love.graphics.print(
      TextCache.format("hud-floor", "%s · Piso %d", run.def.name, run.depth),
      20,
      12
    )
  end

  love.graphics.setColor(0.80, 0.85, 0.90)
  love.graphics.print(TextCache.format("coins", "Monedas %d", Save.data.coins), 398, 12)

  if run.sandbox then
    love.graphics.setColor(0.55, 0.90, 1.00)
    love.graphics.print(
      TextCache.format("hud-time-sandbox", "Sala de pruebas · tiempo libre"),
      600,
      12
    )
  else
    local timeLeft = math.max(0, math.ceil(run.timeLeft or 0))
    local warning = timeLeft <= Data.floor.warningTime
    local pulse = warning and (0.65 + 0.35 * math.sin(love.timer.getTime() * 6)) or 1
    love.graphics.setColor(0.95 * pulse, 0.35 * pulse, 0.30 * pulse)
    love.graphics.print(
      TextCache.format("hud-time", "Tiempo %02d:%02d", math.floor(timeLeft / 60), timeLeft % 60),
      620,
      12
    )
  end

  local hpRatio = 0
  if run.stats.maxHp > 0 then
    hpRatio = Util.clamp(run.hp / run.stats.maxHp, 0, 1)
  end
  love.graphics.setColor(0.08, 0.10, 0.12, 0.95)
  love.graphics.rectangle("fill", 20, 34, 230, 14, 4, 4)
  love.graphics.setColor(0.70, 0.18, 0.18)
  love.graphics.rectangle("fill", 20, 34, 230 * hpRatio, 14, 4, 4)

  if run.player and run.player.shieldMax > 0 then
    local shieldRatio = Util.clamp(run.player.shield / run.player.shieldMax, 0, 1)
    love.graphics.setColor(0.08, 0.10, 0.12, 0.95)
    love.graphics.rectangle("fill", 20, 50, 230, 4, 2, 2)
    love.graphics.setColor(0.45, 0.95, 0.85)
    love.graphics.rectangle("fill", 20, 50, 230 * shieldRatio, 4, 2, 2)
  end

  love.graphics.setColor(0.90, 0.95, 1.00)
  love.graphics.print(TextCache.format("hud-hp", "%d / %d", Util.round(run.hp), run.stats.maxHp), 258, 34)

  local xpRatio = 0
  if run.xpToNext > 0 then
    xpRatio = Util.clamp(run.xp / run.xpToNext, 0, 1)
  end
  love.graphics.setColor(0.08, 0.10, 0.12, 0.95)
  love.graphics.rectangle("fill", 20, 58, 230, 8, 3, 3)
  love.graphics.setColor(0.30, 0.75, 0.95)
  love.graphics.rectangle("fill", 20, 58, 230 * xpRatio, 8, 3, 3)

  love.graphics.setColor(0.75, 0.82, 0.90)
  love.graphics.print(TextCache.format("hud-xp", "XP %d / %d", run.xp, run.xpToNext), 258, 54)

  local manaRatio = 0
  if run.manaMax > 0 then
    manaRatio = Util.clamp((run.mana or 0) / run.manaMax, 0, 1)
  end
  love.graphics.setColor(0.08, 0.10, 0.12, 0.95)
  love.graphics.rectangle("fill", 20, 72, 230, 8, 3, 3)
  if (run.manaFlash or 0) > 0 and math.floor(run.manaFlash * 18) % 2 == 0 then
    love.graphics.setColor(0.95, 0.22, 0.22)
  else
    love.graphics.setColor(0.30, 0.55, 1.00)
  end
  love.graphics.rectangle("fill", 20, 72, 230 * manaRatio, 8, 3, 3)

  love.graphics.setColor(0.75, 0.82, 0.90)
  love.graphics.print(
    TextCache.format("hud-mana", "Maná %d / %d", Util.round(run.mana or 0), run.manaMax),
    258,
    68
  )

  love.graphics.setColor(0.80, 0.85, 0.90)
  love.graphics.print(TextCache.format("hud-level", "Nv. %d", run.playerLevel), 398, 34)

  local character = Data.characters[run.characterId]
  local a1 = run.abilitySlot1 and Data.abilities[run.abilitySlot1]
  local a2 = run.abilitySlot2 and Data.abilities[run.abilitySlot2]
  if character then
    love.graphics.setColor(character.color[1], character.color[2], character.color[3])
    love.graphics.print(character.name, 20, 88)
    love.graphics.setColor(0.72, 0.80, 0.88)
    love.graphics.print(
      TextCache.format(
        "hud-abilities",
        "A1 %s · A2 %s",
        a1 and a1.name or "libre",
        a2 and a2.name or "libre"
      ),
      120,
      88
    )
  end

  local lock = run.abilityLockTimer or 0
  if lock > 0 then
    love.graphics.setColor(0.55, 0.72, 1.00)
    -- Se cuantiza a décimas: el texto cambia 10 veces por segundo, no 60.
    love.graphics.print(
      TextCache.format("hud-lock", "Habilidades selladas: %.1fs", math.floor(lock * 10) / 10),
      20,
      104
    )
  else
    love.graphics.setColor(0.55, 0.64, 0.72)
    love.graphics.print("Escudo (E) y Turbo (T) siempre disponibles", 20, 104)
  end

  local beatInBar = -1
  if Rhythm.beat > 0 then
    beatInBar = Rhythm.beat % 4
  end
  for i = 0, 3 do
    local dotRadius = 5
    if i == beatInBar then
      love.graphics.setColor(1.00, 0.85, 0.35)
      dotRadius = 5 * Rhythm.pulse
    else
      love.graphics.setColor(0.25, 0.30, 0.35)
    end
    love.graphics.circle("fill", 404 + i * 16, 92, dotRadius)
  end

  local pause = HUD.pauseButton
  love.graphics.setColor(0.08, 0.10, 0.13, 0.90)
  love.graphics.rectangle("fill", pause.x, pause.y, pause.w, pause.h, 8, 8)
  love.graphics.setColor(0.40, 0.70, 0.80)
  love.graphics.rectangle("line", pause.x, pause.y, pause.w, pause.h, 8, 8)
  love.graphics.setColor(0.80, 0.90, 1.00)
  love.graphics.printf("PAUSA", pause.x, pause.y + 11, pause.w, "center")

  local backpack = HUD.backpackButton
  love.graphics.setColor(0.08, 0.10, 0.13, 0.90)
  love.graphics.rectangle("fill", backpack.x, backpack.y, backpack.w, backpack.h, 8, 8)
  love.graphics.setColor(0.50, 0.82, 0.90)
  love.graphics.rectangle("line", backpack.x, backpack.y, backpack.w, backpack.h, 8, 8)
  love.graphics.setColor(0.84, 0.94, 1.00)
  love.graphics.printf("MOCHILA", backpack.x, backpack.y + 11, backpack.w, "center")

  local shop = HUD.shopButton
  local shopOpen = HUD.shopUnlocked(run)
  love.graphics.setColor(0.08, 0.10, 0.13, 0.90)
  love.graphics.rectangle("fill", shop.x, shop.y, shop.w, shop.h, 8, 8)
  love.graphics.setColor(shopOpen and 0.95 or 0.30, shopOpen and 0.78 or 0.36, shopOpen and 0.32 or 0.42)
  love.graphics.rectangle("line", shop.x, shop.y, shop.w, shop.h, 8, 8)
  love.graphics.setColor(shopOpen and 1.00 or 0.52, shopOpen and 0.88 or 0.58, shopOpen and 0.55 or 0.64)
  love.graphics.printf("TIENDA", shop.x, shop.y + 11, shop.w, "center")

  if run.sandbox then
    local sandbox = HUD.sandboxButton
    love.graphics.setColor(0.08, 0.13, 0.11, 0.94)
    love.graphics.rectangle("fill", sandbox.x, sandbox.y, sandbox.w, sandbox.h, 8, 8)
    love.graphics.setColor(0.45, 0.95, 0.65)
    love.graphics.rectangle("line", sandbox.x, sandbox.y, sandbox.w, sandbox.h, 8, 8)
    love.graphics.setColor(0.76, 1.00, 0.86)
    love.graphics.printf(
      run.sandboxInvuln and "PRUEBAS · INV" or "PRUEBAS",
      sandbox.x,
      sandbox.y + 11,
      sandbox.w,
      "center"
    )
  end

  HUD.drawInventory(run)
  HUD.drawBoss(run)
end

function HUD.drawBoss(run)
  local boss = run.boss
  if not boss or boss.dead then return end

  local w = 280
  local x, y = (Screen.width - w) * 0.5, 132
  love.graphics.setColor(0.05, 0.06, 0.08, 0.88)
  love.graphics.rectangle("fill", x, y, w, 22, 6, 6)

  love.graphics.setFont(Fonts.small)
  love.graphics.setColor(0.95, 0.75, 0.85)
  love.graphics.print(boss.def.name or "GUARDIÁN", x + 8, y + 3)

  local ratio = 0
  if boss.maxHp > 0 then
    ratio = Util.clamp(boss.hp / boss.maxHp, 0, 1)
  end
  love.graphics.setColor(0.08, 0.10, 0.12)
  love.graphics.rectangle("fill", x + 8, y + 14, w - 16, 5, 2, 2)
  love.graphics.setColor(0.85, 0.25, 0.45)
  love.graphics.rectangle("fill", x + 8, y + 14, (w - 16) * ratio, 5, 2, 2)
end

function HUD.drawPause(run)
  local panelW, panelH = 560, 390
  local px = (Screen.width - panelW) * 0.5
  local py = (Screen.height - panelH) * 0.5

  love.graphics.setColor(0, 0, 0, 0.70)
  love.graphics.rectangle("fill", 0, 0, Screen.width, Screen.height)

  love.graphics.setColor(0.06, 0.08, 0.11, 0.99)
  love.graphics.rectangle("fill", px, py, panelW, panelH, 12, 12)
  love.graphics.setColor(0.30, 0.50, 0.60)
  love.graphics.rectangle("line", px, py, panelW, panelH, 12, 12)

  love.graphics.setFont(Fonts.title)
  love.graphics.setColor(0.60, 0.90, 1.00)
  love.graphics.printf("PAUSA", px, py + 22, panelW, "center")

  love.graphics.setFont(Fonts.body)
  love.graphics.setColor(0.80, 0.85, 0.90)
  love.graphics.printf("Toca o pulsa P para continuar", px, py + 78, panelW, "center")

  love.graphics.setColor(0.60, 0.70, 0.80)
  love.graphics.printf(
    TextCache.format(
      run.sandbox and "pause-summary-sandbox"
        or (run.mode == "story" and "pause-summary-story" or "pause-summary"),
      run.sandbox and "Sala de pruebas · Nv. %d · Sin progreso permanente"
        or (run.mode == "story" and "Historia · Piso %d · Nv. %d · Monedas %d"
          or "Piso %d · Nv. %d · Monedas %d"),
      run.depth,
      run.playerLevel,
      Save.data.coins
    ),
    px,
    py + 112,
    panelW,
    "center"
  )

  love.graphics.setFont(Fonts.small)
  love.graphics.setColor(0.55, 0.62, 0.70)
  love.graphics.printf(
    "Izquierda: moverte · Centro: arrastra para mirar · A1/A2 se asignan en la mochila.",
    px,
    py + 150,
    panelW,
    "center"
  )
  love.graphics.printf(
    "Teclado: WASD/flechas · R/F/E/T habilidades · B mochila · P pausa · F3 depuración",
    px,
    py + 174,
    panelW,
    "center"
  )
  love.graphics.printf(
    "Válvulas: dispara o pisa · Paredes frágiles: Resonancia/Flecha · Cofres: acércate",
    px,
    py + 198,
    panelW,
    "center"
  )
  love.graphics.printf(
    "Ítems: pasivas y mascotas activas son por run · Cofres ocultos: personajes",
    px,
    py + 222,
    panelW,
    "center"
  )

  local confirm = run.pauseExitConfirm
  local button = HUD.pauseExitRect()
  if confirm then
    love.graphics.setColor(0.28, 0.08, 0.08, 0.98)
  else
    love.graphics.setColor(0.08, 0.16, 0.20, 0.98)
  end
  love.graphics.rectangle("fill", button.x, button.y, button.w, button.h, 8, 8)
  love.graphics.setColor(confirm and 0.95 or 0.48, confirm and 0.30 or 0.78, confirm and 0.28 or 0.90)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", button.x, button.y, button.w, button.h, 8, 8)
  love.graphics.setLineWidth(1)

  love.graphics.setFont(Fonts.button)
  love.graphics.setColor(1, 1, 1)
  love.graphics.printf(
    confirm and "CONFIRMAR SALIDA" or "SALIR AL MENÚ",
    button.x,
    button.y + 13,
    button.w,
    "center"
  )

  love.graphics.setFont(Fonts.small)
  if confirm then
    love.graphics.setColor(1.00, 0.55, 0.45)
    love.graphics.printf(
      "¿Seguro? Toca de nuevo para salir.",
      px,
      py + 310,
      panelW,
      "center"
    )
    love.graphics.printf(
      run.sandbox and "Se cierra la sesión de pruebas."
        or "Se pierde el piso, el nivel y el inventario de esta partida.",
      px,
      py + 330,
      panelW,
      "center"
    )
    love.graphics.setColor(0.72, 0.62, 0.55)
    love.graphics.printf(
      "Confirmación válida por 3 segundos · P continúa",
      px,
      py + 352,
      panelW,
      "center"
    )
  else
    love.graphics.setColor(0.90, 0.72, 0.45)
    love.graphics.printf(
      run.sandbox and "Salir cierra la sala de pruebas."
        or "Salir al menú descarta el progreso de esta partida.",
      px,
      py + 310,
      panelW,
      "center"
    )
    love.graphics.setColor(0.62, 0.70, 0.76)
    love.graphics.printf(
      run.sandbox and "El guardado real queda intacto."
        or "Las monedas, mejoras y desbloqueos ya guardados se conservan.",
      px,
      py + 330,
      panelW,
      "center"
    )
    love.graphics.printf(
      "Esc también sale (doble pulsación)",
      px,
      py + 354,
      panelW,
      "center"
    )
  end
end

function HUD.drawDebug(run)
  if not Debug.enabled then return end

  love.graphics.setColor(0, 0, 0, 0.65)
  love.graphics.rectangle("fill", 10, 136, 286, 166, 6, 6)

  love.graphics.setFont(Fonts.small)
  love.graphics.setColor(0.40, 1.00, 0.60)
  love.graphics.print("FPS " .. love.timer.getFPS(), 20, 144)
  love.graphics.print("Jugador " .. Util.round(run.player.x) .. ", " .. Util.round(run.player.y), 20, 160)
  love.graphics.print("Enemigos " .. run.enemyCount, 20, 176)
  love.graphics.print(
    string.format("Pulso %d · %.3f s", Rhythm.beat, Rhythm.nearest),
    20,
    192
  )
  love.graphics.print("Racha rítmica " .. Rhythm.streak, 20, 208)
  love.graphics.print("Estado " .. (run.paused and "pausa" or "activo"), 20, 224)
  love.graphics.print("Mudo " .. (Rhythm.muted and "sí" or "no"), 20, 240)
  love.graphics.print("Semilla " .. tostring(run.seed), 20, 256)
  love.graphics.print(
    string.format("Maná %.1f · Tiempo %.1f", run.mana or 0, run.timeLeft or 0),
    20,
    272
  )
  love.graphics.print(
    "Mochila " .. #(run.inventory or {}) .. "/" .. Data.inventory.maxActive
      .. " · Guardados " .. #(run.storage or {}) .. "/" .. Data.inventory.maxInactive
      .. " · Capa " .. tostring(run.overlay or "ninguna"),
    20,
    288
  )
end

HUD.layout()

return HUD
