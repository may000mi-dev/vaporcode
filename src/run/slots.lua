-- slots.lua: espacios de habilidades, maná y efectos sobre el jugador.
-- Las funciones reciben run como primer argumento y run.lua las monta
-- como métodos para conservar la API run:metodo(...).
local Data = require("src.run.data")
local Rhythm = require("src.run.rhythm")
local Abilities = require("src.run.abilities")
local FX = require("src.run.fx")

local Slots = {}

function Slots.abilityIdForSlot(run, slot)
  if slot == 1 then return run.abilitySlot1 end
  if slot == 2 then return run.abilitySlot2 end
  if slot == 4 then return run.abilitySlot4 end
  return run.abilitySlot3
end

function Slots.cooldownKeyForSlot(run, slot)
  if slot == 1 then return "a1" end
  if slot == 2 then return "a2" end
  if slot == 3 then return "shield" end
  if slot == 4 then return "turbo" end
  return tostring(slot)
end

function Slots.equipAbility(run, slot, abilityId)
  if slot ~= 1 and slot ~= 2 then return false end
  if not Data.exchangeableSet[abilityId] then return false end
  if slot == 1 then
    run.abilitySlot1 = abilityId
  else
    run.abilitySlot2 = abilityId
  end
  run.cooldowns[run:cooldownKeyForSlot(slot)] = 0
  return true
end

function Slots.useAbility(run, slot, aim)
  return Abilities.cast(run, slot, aim)
end

function Slots.onAbilityLocked(run)
  run:notify("Habilidades selladas", { 0.55, 0.72, 1.00 })
end

function Slots.addAbilityLock(run, seconds)
  run.abilityLockTimer = math.max(run.abilityLockTimer or 0, seconds or 0)
end

function Slots.onManaFail(run, ability)
  run.manaFlash = Data.mana.flashDuration
  Rhythm.playLockedClick()
  if ability and run.player then
    FX.ring(run.player.x, run.player.y, 28, { 0.95, 0.25, 0.25 })
  end
end

function Slots.updateMana(run, dt)
  run.manaFlash = math.max(0, (run.manaFlash or 0) - dt)
  run.manaIdleTimer = (run.manaIdleTimer or 0) + dt

  local idle = run.manaIdleTimer >= Data.mana.idleDelay
  local multiplier = idle and Data.mana.idleMultiplier or 1
  local regen = Data.mana.regen * multiplier
  run.mana = math.min(run.manaMax, (run.mana or 0) + regen * dt)
end

function Slots.applyPlayerEffect(run, effect, data)
  data = data or {}
  if effect == "slow" then
    run.player:applySlow(data.duration or 1.5, data.factor or 0.45)
    run:notify("Lodo: ralentizado", { 0.45, 0.80, 0.40 })
  elseif effect == "mana_drain" then
    local drain = run.manaMax * (data.manaDrain or 0.12)
    run.mana = math.max(0, run.mana - drain)
    run:addAbilityLock(data.lock or 2)
    run:notify("Reloj: maná drenado", { 0.55, 0.72, 1.00 })
  end
end

function Slots.marDash(run, angle, allowAtRest)
  local player = run.player
  if not player then return false end
  if not player.moving and not allowAtRest then return false end

  local def = Data.characters.mar
  local dx, dy
  if player.moving then
    dx, dy = player.moveX, player.moveY
  elseif angle then
    dx, dy = math.cos(angle), math.sin(angle)
  else
    dx, dy = player.facingX, player.facingY
  end

  local distance = def.dashRadiusFactor * player.radius
  local targetX = player.x + dx * distance
  local targetY = player.y + dy * distance
  local landingX, landingY = run.dungeon:nearestWalkable(
    targetX,
    targetY,
    player.radius,
    def.dashSearch
  )
  if not landingX then return false end

  player.x = landingX
  player.y = landingY
  player.invuln = math.max(player.invuln, def.dashInvuln)
  FX.ring(player.x, player.y, player.radius + 10, def.color)
  return true
end

function Slots.onAbilityActivated(run, abilityId, aim, meta)
  if meta and meta.skipPassive then return end
  if run.characterId == "mar" and run.player.moving then
    run:marDash(nil, false)
  end
end

return Slots
