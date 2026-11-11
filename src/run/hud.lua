-- hud.lua: vida, experiencia, monedas, pulso, pausa y capa de depuración.
local Data = require("src.run.data")
local Fonts = require("src.utils.fonts")
local Rhythm = require("src.run.rhythm")
local Save = require("src.run.save")
local Util = require("src.utils.util")
local Debug = require("src.utils.debug")

local HUD = {}

HUD.pauseButton = { x = 852, y = 10, w = 92, h = 36 }
HUD.backpackButton = { x = 736, y = 10, w = 104, h = 36 }
HUD.shopButton = { x = 736, y = 52, w = 104, h = 36 }

local inventoryX = 334
local inventoryY = 493
local inventoryW = 52
local inventoryH = 38
local inventoryGap = 6

function HUD.hitPause(x, y)
  return Util.inside(x, y, HUD.pauseButton)
end

function HUD.hitBackpack(x, y)
  return Util.inside(x, y, HUD.backpackButton)
end

function HUD.hitShop(x, y)
  return Util.inside(x, y, HUD.shopButton)
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
  for index = 1, Data.inventory.maxSlots do
    local rect = HUD.inventoryRect(index)
    local slot = run.inventory and run.inventory[index]
    local selected = run.overlay == "backpack" and run.selectedInventory == index

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
      love.graphics.print("i" .. index .. (amount > 1 and ("x" .. amount) or ""), rect.x + 23, rect.y + 20)
    else
      love.graphics.setColor(0.34, 0.42, 0.49)
      love.graphics.print("i" .. index, rect.x + 6, rect.y + 5)
      love.graphics.setColor(0.24, 0.30, 0.36)
      love.graphics.print("--", rect.x + 22, rect.y + 20)
    end
  end
end

function HUD.draw(run)
  love.graphics.setColor(0.05, 0.06, 0.08, 0.82)
  love.graphics.rectangle("fill", 10, 8, 500, 122, 8, 8)

  love.graphics.setFont(Fonts.small)
  love.graphics.setColor(0.55, 0.85, 0.95)
  love.graphics.print(run.def.name .. " · Piso " .. run.depth, 20, 12)

  love.graphics.setColor(0.80, 0.85, 0.90)
  love.graphics.print("Monedas " .. Save.data.coins, 398, 12)

  local timeLeft = math.max(0, math.ceil(run.timeLeft or 0))
  local warning = timeLeft <= Data.floor.warningTime
  local pulse = warning and (0.65 + 0.35 * math.sin(love.timer.getTime() * 6)) or 1
  love.graphics.setColor(0.95 * pulse, 0.35 * pulse, 0.30 * pulse)
  love.graphics.print(
    string.format("Tiempo %02d:%02d", math.floor(timeLeft / 60), timeLeft % 60),
    620,
    12
  )

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
  love.graphics.print(string.format("%d / %d", Util.round(run.hp), run.stats.maxHp), 258, 34)

  local xpRatio = 0
  if run.xpToNext > 0 then
    xpRatio = Util.clamp(run.xp / run.xpToNext, 0, 1)
  end
  love.graphics.setColor(0.08, 0.10, 0.12, 0.95)
  love.graphics.rectangle("fill", 20, 58, 230, 8, 3, 3)
  love.graphics.setColor(0.30, 0.75, 0.95)
  love.graphics.rectangle("fill", 20, 58, 230 * xpRatio, 8, 3, 3)

  love.graphics.setColor(0.75, 0.82, 0.90)
  love.graphics.print(string.format("XP %d / %d", run.xp, run.xpToNext), 258, 54)

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
    string.format("Maná %d / %d", Util.round(run.mana or 0), run.manaMax),
    258,
    68
  )

  love.graphics.setColor(0.80, 0.85, 0.90)
  love.graphics.print("Nv. " .. run.playerLevel, 398, 34)

  local character = Data.characters[run.characterId]
  local a1 = run.abilitySlot1 and Data.abilities[run.abilitySlot1]
  local a2 = run.abilitySlot2 and Data.abilities[run.abilitySlot2]
  if character then
    love.graphics.setColor(character.color[1], character.color[2], character.color[3])
    love.graphics.print(character.name, 20, 88)
    love.graphics.setColor(0.72, 0.80, 0.88)
    love.graphics.print(
      "A1 " .. (a1 and a1.name or "libre")
        .. " · A2 " .. (a2 and a2.name or "libre"),
      120,
      88
    )
  end

  local lock = run.abilityLockTimer or 0
  if lock > 0 then
    love.graphics.setColor(0.55, 0.72, 1.00)
    love.graphics.print(
      string.format("Habilidades selladas: %.1fs", lock),
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

  HUD.drawInventory(run)
  HUD.drawBoss(run)
end

function HUD.drawBoss(run)
  local boss = run.boss
  if not boss or boss.dead then return end

  local x, y, w = 340, 132, 280
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
  love.graphics.setColor(0, 0, 0, 0.65)
  love.graphics.rectangle("fill", 0, 0, 960, 540)

  love.graphics.setColor(0.06, 0.08, 0.11, 0.98)
  love.graphics.rectangle("fill", 200, 120, 560, 300, 12, 12)
  love.graphics.setColor(0.30, 0.50, 0.60)
  love.graphics.rectangle("line", 200, 120, 560, 300, 12, 12)

  love.graphics.setFont(Fonts.title)
  love.graphics.setColor(0.60, 0.90, 1.00)
  love.graphics.printf("PAUSA", 200, 145, 560, "center")

  love.graphics.setFont(Fonts.body)
  love.graphics.setColor(0.80, 0.85, 0.90)
  love.graphics.printf("Toca o pulsa P para continuar", 200, 220, 560, "center")

  love.graphics.setColor(0.60, 0.70, 0.80)
  love.graphics.printf(
    "Piso " .. run.depth .. " · Nv. " .. run.playerLevel .. " · Monedas " .. Save.data.coins,
    200,
    260,
    560,
    "center"
  )

  love.graphics.setFont(Fonts.small)
  love.graphics.setColor(0.55, 0.62, 0.70)
  love.graphics.printf(
    "Izquierda: moverte · Centro: arrastra para mirar · A1/A2 se asignan en la mochila.",
    200,
    310,
    560,
    "center"
  )
  love.graphics.printf(
    "Teclado: WASD/flechas · R/F/E/T habilidades · B mochila · P pausa · F3 depuración",
    200,
    335,
    560,
    "center"
  )
  love.graphics.printf(
    "Válvulas: dispara o pisa · Paredes frágiles: Resonancia/Flecha · Cofres: acércate",
    200,
    360,
    560,
    "center"
  )
  love.graphics.printf(
    "Ítems: enemigos y cofres · Pasivas y mascotas son por run · Cofres ocultos: personajes",
    200,
    385,
    560,
    "center"
  )
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
    "Mochila " .. #(run.inventory or {}) .. "/" .. Data.inventory.maxSlots
      .. " · Capa " .. tostring(run.overlay or "ninguna"),
    20,
    288
  )
end

return HUD
