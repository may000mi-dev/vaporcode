-- hud.lua: vida, experiencia, monedas, pulso, pausa y capa de depuración.
local Data = require("src.run.data")
local Fonts = require("src.utils.fonts")
local Screen = require("src.utils.screen")
local Rhythm = require("src.run.rhythm")
local Threat = require("src.run.threat")
local Save = require("src.run.save")
local Util = require("src.utils.util")
local Debug = require("src.utils.debug")
local TextCache = require("src.utils.textcache")
local Atricion = require("src.run.atrition")
local Director = require("src.run.director")
local Antidote = require("src.run.antidote")
local Themes = require("src.data.themes")

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
    y = py + 270,
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
  local theme = Themes.current()
  for index = 1, Data.inventory.maxActive do
    local rect = HUD.inventoryRect(index)
    local slot = run.inventory and run.inventory[index]
    local selected = run.overlay == "backpack"
      and run.selectionSection == "active"
      and run.selectedInventory == index

    love.graphics.setColor(theme.panelAlt[1], theme.panelAlt[2], theme.panelAlt[3], 0.92)
    love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h, 6, 6)
    if selected then
      love.graphics.setColor(theme.secondary[1], theme.secondary[2], theme.secondary[3])
      love.graphics.setLineWidth(2)
    else
      love.graphics.setColor(theme.border[1], theme.border[2], theme.border[3])
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
      love.graphics.setColor(theme.text[1], theme.text[2], theme.text[3])
      love.graphics.print(def.short, rect.x + 23, rect.y + 4)
      love.graphics.setColor(theme.muted[1], theme.muted[2], theme.muted[3])
      local amount = slot.amount or 1
      local fmt = amount > 1 and "i%dx%d" or "i%d"
      love.graphics.print(TextCache.format(invLabelKeys[index], fmt, index, amount), rect.x + 23, rect.y + 20)
    else
      love.graphics.setColor(theme.muted[1], theme.muted[2], theme.muted[3])
      love.graphics.print(TextCache.format(invIndexKeys[index], "i%d", index), rect.x + 6, rect.y + 5)
      love.graphics.setColor(theme.dim[1], theme.dim[2], theme.dim[3])
      love.graphics.print("--", rect.x + 22, rect.y + 20)
    end
  end

  love.graphics.setFont(Fonts.small)
  love.graphics.setColor(theme.muted[1], theme.muted[2], theme.muted[3])
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
  local theme = Themes.current()
  local characterTheme = Themes.get(run.characterId)
  love.graphics.setColor(theme.panel[1], theme.panel[2], theme.panel[3], 0.92)
  love.graphics.rectangle("fill", 10, 8, 500, 138, 8, 8)

  love.graphics.setFont(Fonts.small)
  if run.mode == "story" then
    love.graphics.setColor(theme.secondary[1], theme.secondary[2], theme.secondary[3])
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
    love.graphics.setColor(theme.accent[1], theme.accent[2], theme.accent[3])
    love.graphics.print(
      TextCache.format("hud-floor", "%s · Piso %d", run.def.name, run.depth),
      20,
      12
    )
  end

  love.graphics.setColor(theme.secondary[1], theme.secondary[2], theme.secondary[3])
  love.graphics.print(TextCache.format("coins", "Monedas %d", Save.data.coins), 398, 12)

  if run.sandbox then
    love.graphics.setColor(theme.accent[1], theme.accent[2], theme.accent[3])
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
  love.graphics.setColor(theme.bg[1], theme.bg[2], theme.bg[3], 0.95)
  love.graphics.rectangle("fill", 20, 34, 230, 14, 4, 4)
  love.graphics.setColor(0.70, 0.18, 0.18)
  love.graphics.rectangle("fill", 20, 34, 230 * hpRatio, 14, 4, 4)

  if run.player and run.player.shieldMax > 0 then
    local shieldRatio = Util.clamp(run.player.shield / run.player.shieldMax, 0, 1)
    love.graphics.setColor(theme.bg[1], theme.bg[2], theme.bg[3], 0.95)
    love.graphics.rectangle("fill", 20, 50, 230, 4, 2, 2)
    love.graphics.setColor(theme.secondary[1], theme.secondary[2], theme.secondary[3])
    love.graphics.rectangle("fill", 20, 50, 230 * shieldRatio, 4, 2, 2)
  end

  love.graphics.setColor(theme.text[1], theme.text[2], theme.text[3])
  love.graphics.print(TextCache.format("hud-hp", "%d / %d", Util.round(run.hp), run.stats.maxHp), 258, 34)

  local xpRatio = 0
  if run.xpToNext > 0 then
    xpRatio = Util.clamp(run.xp / run.xpToNext, 0, 1)
  end
  love.graphics.setColor(theme.bg[1], theme.bg[2], theme.bg[3], 0.95)
  love.graphics.rectangle("fill", 20, 58, 230, 8, 3, 3)
  love.graphics.setColor(theme.accent[1], theme.accent[2], theme.accent[3])
  love.graphics.rectangle("fill", 20, 58, 230 * xpRatio, 8, 3, 3)

  love.graphics.setColor(theme.muted[1], theme.muted[2], theme.muted[3])
  love.graphics.print(TextCache.format("hud-xp", "XP %d / %d", run.xp, run.xpToNext), 258, 54)

  local manaRatio = 0
  if run.manaMax > 0 then
    manaRatio = Util.clamp((run.mana or 0) / run.manaMax, 0, 1)
  end
  love.graphics.setColor(theme.bg[1], theme.bg[2], theme.bg[3], 0.95)
  love.graphics.rectangle("fill", 20, 72, 230, 8, 3, 3)
  if (run.manaFlash or 0) > 0 and math.floor(run.manaFlash * 18) % 2 == 0 then
    love.graphics.setColor(0.95, 0.22, 0.22)
  else
    love.graphics.setColor(0.30, 0.55, 1.00)
  end
  love.graphics.rectangle("fill", 20, 72, 230 * manaRatio, 8, 3, 3)

  love.graphics.setColor(theme.muted[1], theme.muted[2], theme.muted[3])
  love.graphics.print(
    TextCache.format("hud-mana", "Maná %d / %d", Util.round(run.mana or 0), run.manaMax),
    258,
    68
  )

  love.graphics.setColor(theme.text[1], theme.text[2], theme.text[3])
  love.graphics.print(TextCache.format("hud-level", "Nv. %d", run.playerLevel), 398, 34)

  local character = Data.characters[run.characterId]
  local a1 = run.abilitySlot1 and Data.abilities[run.abilitySlot1]
  local a2 = run.abilitySlot2 and Data.abilities[run.abilitySlot2]
  if character then
    love.graphics.setColor(characterTheme.accent[1], characterTheme.accent[2], characterTheme.accent[3])
    love.graphics.print(character.name, 20, 88)
    love.graphics.setColor(theme.muted[1], theme.muted[2], theme.muted[3])
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
    love.graphics.setColor(theme.accent[1], theme.accent[2], theme.accent[3])
    -- Se cuantiza a décimas: el texto cambia 10 veces por segundo, no 60.
    love.graphics.print(
      TextCache.format("hud-lock", "Habilidades selladas: %.1fs", math.floor(lock * 10) / 10),
      20,
      104
    )
  else
    love.graphics.setColor(theme.muted[1], theme.muted[2], theme.muted[3])
    love.graphics.print("Escudo (E) y Turbo (T) siempre disponibles", 20, 104)
  end

  if Antidote.suppressed(run) then
    love.graphics.setColor(0.74, 0.95, 0.55)
    love.graphics.print("PURIFICADO · -50%", 388, 104)
  end

  local compas = run.compases
  if compas then
    love.graphics.setColor(theme.secondary[1], theme.secondary[2], theme.secondary[3])
    love.graphics.print(
      TextCache.format("hud-compas", "%s", compas.label),
      20,
      120
    )
  end

  local beatsPerBar = Data.rhythm.beatsPerBar or 4
  local strong = Data.colors.beatStrong
  local beatInBar = -1
  if Rhythm.beat > 0 then
    beatInBar = Rhythm.beat % beatsPerBar
  end
  for i = 0, beatsPerBar - 1 do
    local dotRadius = 5
    local isStrong = i == 0
    if i == beatInBar then
      if isStrong then
        love.graphics.setColor(strong[1], strong[2], strong[3])
      else
        love.graphics.setColor(theme.secondary[1], theme.secondary[2], theme.secondary[3])
      end
      dotRadius = 5 * Rhythm.pulse
    elseif isStrong then
      love.graphics.setColor(strong[1] * 0.55, strong[2] * 0.55, strong[3] * 0.55)
    else
      love.graphics.setColor(theme.dim[1], theme.dim[2], theme.dim[3])
    end
    love.graphics.circle("fill", 404 + i * 16, 92, dotRadius)
  end

  if not run.sandbox then
    love.graphics.setFont(Fonts.small)
    if run.exitOpen then
      love.graphics.setColor(theme.secondary[1], theme.secondary[2], theme.secondary[3])
      love.graphics.printf("¡Salida abierta!", 380, 70, 96, "center")
    else
      love.graphics.setColor(theme.text[1], theme.text[2], theme.text[3])
      local text
      if run.threat and run.threat.enabled then
        text = TextCache.format(
          "hud-threat-remaining",
          "Oleada %d/%d · %d",
          run.threat.activeWave or 1,
          #run.threat.waves,
          Threat.remainingTotal(run)
        )
      else
        text = TextCache.format("hud-remaining", "Faltan %d", run.enemyCount or 0)
      end
      love.graphics.printf(text, 360, 70, 140, "center")
    end
  end

  local pause = HUD.pauseButton
  love.graphics.setColor(theme.button[1], theme.button[2], theme.button[3], 0.95)
  love.graphics.rectangle("fill", pause.x, pause.y, pause.w, pause.h, 8, 8)
  love.graphics.setColor(theme.accent[1], theme.accent[2], theme.accent[3])
  love.graphics.rectangle("line", pause.x, pause.y, pause.w, pause.h, 8, 8)
  love.graphics.setColor(theme.text[1], theme.text[2], theme.text[3])
  love.graphics.printf("PAUSA", pause.x, pause.y + 11, pause.w, "center")

  local backpack = HUD.backpackButton
  love.graphics.setColor(theme.button[1], theme.button[2], theme.button[3], 0.95)
  love.graphics.rectangle("fill", backpack.x, backpack.y, backpack.w, backpack.h, 8, 8)
  love.graphics.setColor(theme.accent[1], theme.accent[2], theme.accent[3])
  love.graphics.rectangle("line", backpack.x, backpack.y, backpack.w, backpack.h, 8, 8)
  love.graphics.setColor(theme.text[1], theme.text[2], theme.text[3])
  love.graphics.printf("MOCHILA", backpack.x, backpack.y + 11, backpack.w, "center")

  local shop = HUD.shopButton
  local shopOpen = HUD.shopUnlocked(run)
  local shopBorder = shopOpen and theme.secondary or theme.border
  local shopText = shopOpen and theme.secondary or theme.dim
  love.graphics.setColor(theme.button[1], theme.button[2], theme.button[3], 0.95)
  love.graphics.rectangle("fill", shop.x, shop.y, shop.w, shop.h, 8, 8)
  love.graphics.setColor(shopBorder[1], shopBorder[2], shopBorder[3])
  love.graphics.rectangle("line", shop.x, shop.y, shop.w, shop.h, 8, 8)
  love.graphics.setColor(shopText[1], shopText[2], shopText[3])
  love.graphics.printf("TIENDA", shop.x, shop.y + 11, shop.w, "center")

  if run.sandbox then
    local sandbox = HUD.sandboxButton
    love.graphics.setColor(theme.button[1], theme.button[2], theme.button[3], 0.95)
    love.graphics.rectangle("fill", sandbox.x, sandbox.y, sandbox.w, sandbox.h, 8, 8)
    love.graphics.setColor(theme.accent[1], theme.accent[2], theme.accent[3])
    love.graphics.rectangle("line", sandbox.x, sandbox.y, sandbox.w, sandbox.h, 8, 8)
    love.graphics.setColor(theme.text[1], theme.text[2], theme.text[3])
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
  HUD.drawDirectorNotice(run)
end

function HUD.drawDirectorNotice(run)
  local text, color = Director.currentNotice(run)
  if not text then return end

  local theme = Themes.current()
  local state = run.director
  local alpha = math.min(1, (state.noticeTimer or 0) / 0.4)
  local w = 460
  local x = (Screen.width - w) * 0.5
  local y = 190

  love.graphics.setColor(theme.panel[1], theme.panel[2], theme.panel[3], 0.92 * alpha)
  love.graphics.rectangle("fill", x, y, w, 24, 6, 6)
  love.graphics.setFont(Fonts.small)
  love.graphics.setColor(
    color and color[1] or theme.text[1],
    color and color[2] or theme.text[2],
    color and color[3] or theme.text[3],
    alpha
  )
  love.graphics.printf(
    TextCache.format("hud-director-notice", "%s", text),
    x,
    y + 5,
    w,
    "center"
  )
end

function HUD.drawBoss(run)
  local boss = run.boss
  if not boss or boss.dead then return end

  local theme = Themes.current()
  local w = 280
  local x, y = (Screen.width - w) * 0.5, 148
  love.graphics.setColor(theme.panel[1], theme.panel[2], theme.panel[3], 0.94)
  love.graphics.rectangle("fill", x, y, w, 22, 6, 6)

  love.graphics.setFont(Fonts.small)
  love.graphics.setColor(theme.secondary[1], theme.secondary[2], theme.secondary[3])
  love.graphics.print(boss.def.name or "GUARDIÁN", x + 8, y + 3)

  local ratio = 0
  if boss.maxHp > 0 then
    ratio = Util.clamp(boss.hp / boss.maxHp, 0, 1)
  end
  love.graphics.setColor(theme.bg[1], theme.bg[2], theme.bg[3])
  love.graphics.rectangle("fill", x + 8, y + 14, w - 16, 5, 2, 2)
  love.graphics.setColor(0.85, 0.25, 0.45)
  love.graphics.rectangle("fill", x + 8, y + 14, (w - 16) * ratio, 5, 2, 2)

  if boss.memoryEnrageTimer then
    local seconds = math.max(0, math.ceil(boss.memoryEnrageTimer))
    local minutes = math.floor(seconds / 60)
    local rest = seconds % 60
    local text
    if boss.memoryLabel then
      text = TextCache.format(
        "hud-boss-memories",
        "%s · %d:%02d",
        boss.memoryLabel,
        minutes,
        rest
      )
    else
      text = TextCache.format("hud-boss-enrage", "Sobrecarga %d:%02d", minutes, rest)
    end
    if boss.memoryRageActive or seconds <= 30 then
      love.graphics.setColor(1.00, 0.45, 0.38)
    else
      love.graphics.setColor(theme.secondary[1], theme.secondary[2], theme.secondary[3])
    end
    love.graphics.print(text, x + 8, y + 24)
  end
end

function HUD.drawPause(run)
  local theme = Themes.current()
  local panelW, panelH = 560, 390
  local px = (Screen.width - panelW) * 0.5
  local py = (Screen.height - panelH) * 0.5

  love.graphics.setColor(0, 0, 0, 0.70)
  love.graphics.rectangle("fill", 0, 0, Screen.width, Screen.height)

  love.graphics.setColor(theme.panel[1], theme.panel[2], theme.panel[3], 0.99)
  love.graphics.rectangle("fill", px, py, panelW, panelH, 12, 12)
  love.graphics.setColor(theme.border[1], theme.border[2], theme.border[3])
  love.graphics.rectangle("line", px, py, panelW, panelH, 12, 12)

  love.graphics.setFont(Fonts.title)
  love.graphics.setColor(theme.accent[1], theme.accent[2], theme.accent[3])
  love.graphics.printf("PAUSA", px, py + 22, panelW, "center")

  local director = Director.active(run)
  if director and director.state ~= "standard" then
    local color = director.color
    love.graphics.setFont(Fonts.small)
    love.graphics.setColor(color[1], color[2], color[3], 0.95)
    love.graphics.printf(director.message, px, py + 54, panelW, "center")
  end

  love.graphics.setFont(Fonts.body)
  love.graphics.setColor(theme.text[1], theme.text[2], theme.text[3])
  love.graphics.printf("Toca o pulsa P para continuar", px, py + 78, panelW, "center")

  love.graphics.setColor(theme.muted[1], theme.muted[2], theme.muted[3])
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
  local detailY = py + 136
  if run.compases then
    love.graphics.setColor(theme.secondary[1], theme.secondary[2], theme.secondary[3])
    love.graphics.printf(TextCache.format("pause-compas", "%s", run.compases.label),
      px, detailY, panelW, "center")
    detailY = detailY + 14
  end

  if Atricion.enabled(run) then
    local nextHeal = Atricion.floorHealPercent(run, run.depth + 1)
    local limit = Atricion.timeLimit(run)
    love.graphics.setColor(theme.secondary[1], theme.secondary[2], theme.secondary[3])
    love.graphics.printf(
      TextCache.format(
        "pause-atrition",
        "Atrición: curación próx. piso %d%% · límite %d:%02d",
        math.floor(nextHeal * 100 + 0.5),
        math.floor(limit / 60),
        limit % 60
      ),
      px,
      detailY,
      panelW,
      "center"
    )
    detailY = detailY + 14
  end

  local boss = run.boss
  if boss and not boss.dead and boss.memoryEnrageTimer then
    local seconds = math.max(0, math.ceil(boss.memoryEnrageTimer))
    local minutes = math.floor(seconds / 60)
    local rest = seconds % 60
    local text
    if boss.memoryLabel then
      text = TextCache.format(
        "pause-boss-memories",
        "Memorias del jefe: %s · Sobrecarga %d:%02d",
        boss.memoryLabel,
        minutes,
        rest
      )
    else
      text = TextCache.format(
        "pause-boss-enrage",
        "Sobrecarga del jefe: %d:%02d",
        minutes,
        rest
      )
    end
    if boss.memoryRageActive or seconds <= 30 then
      love.graphics.setColor(1.00, 0.45, 0.38)
    else
      love.graphics.setColor(theme.secondary[1], theme.secondary[2], theme.secondary[3])
    end
    love.graphics.printf(text, px, detailY, panelW, "center")
    detailY = detailY + 14
  end

  local footerY = math.max(py + 150, detailY + 4)
  love.graphics.setColor(theme.muted[1], theme.muted[2], theme.muted[3])
  love.graphics.printf(
    "Izquierda: moverte · Centro: arrastra para mirar · A1/A2 se asignan en la mochila.",
    px,
    footerY,
    panelW,
    "center"
  )
  love.graphics.printf(
    "Teclado: WASD/flechas · R/F/E/T habilidades · B mochila · P pausa · F3 depuración",
    px,
    footerY + 24,
    panelW,
    "center"
  )
  love.graphics.printf(
    "Válvulas: dispara o pisa · Paredes frágiles: Resonancia/Flecha · Cofres: acércate",
    px,
    footerY + 48,
    panelW,
    "center"
  )
  love.graphics.printf(
    "Ítems: pasivas y mascotas activas son por run · Cofres ocultos: personajes",
    px,
    footerY + 72,
    panelW,
    "center"
  )

  local confirm = run.pauseExitConfirm
  local button = HUD.pauseExitRect()
  if confirm then
    love.graphics.setColor(0.28, 0.08, 0.08, 0.98)
  else
    love.graphics.setColor(theme.button[1], theme.button[2], theme.button[3], 0.98)
  end
  love.graphics.rectangle("fill", button.x, button.y, button.w, button.h, 8, 8)
  if confirm then
    love.graphics.setColor(0.95, 0.30, 0.28)
  else
    love.graphics.setColor(theme.accent[1], theme.accent[2], theme.accent[3])
  end
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", button.x, button.y, button.w, button.h, 8, 8)
  love.graphics.setLineWidth(1)

  love.graphics.setFont(Fonts.button)
  love.graphics.setColor(theme.text[1], theme.text[2], theme.text[3])
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
      py + 328,
      panelW,
      "center"
    )
    love.graphics.printf(
      run.sandbox and "Se cierra la sesión de pruebas."
        or "Se pierde el piso, el nivel y el inventario de esta partida.",
      px,
      py + 348,
      panelW,
      "center"
    )
    love.graphics.setColor(theme.muted[1], theme.muted[2], theme.muted[3])
    love.graphics.printf(
      "Confirmación válida por 3 segundos · P continúa",
      px,
      py + 370,
      panelW,
      "center"
    )
  else
    love.graphics.setColor(theme.secondary[1], theme.secondary[2], theme.secondary[3])
    love.graphics.printf(
      run.sandbox and "Salir cierra la sala de pruebas."
        or "Salir al menú descarta el progreso de esta partida.",
      px,
      py + 328,
      panelW,
      "center"
    )
    love.graphics.setColor(theme.muted[1], theme.muted[2], theme.muted[3])
    love.graphics.printf(
      run.sandbox and "El guardado real queda intacto."
        or "Las monedas, mejoras y desbloqueos ya guardados se conservan.",
      px,
      py + 348,
      panelW,
      "center"
    )
    love.graphics.printf(
      "Esc también sale (doble pulsación)",
      px,
      py + 370,
      panelW,
      "center"
    )
  end
end

function HUD.drawDebug(run)
  if not Debug.enabled then return end

  local theme = Themes.current()
  love.graphics.setColor(theme.panel[1], theme.panel[2], theme.panel[3], 0.90)
  love.graphics.rectangle("fill", 10, 136, 286, 166, 6, 6)

  love.graphics.setFont(Fonts.small)
  love.graphics.setColor(theme.accent[1], theme.accent[2], theme.accent[3])
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
