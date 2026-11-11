-- test_abilities.lua: flecha perforante, sombra, resonancia y cooldowns.
package.path = "./?.lua;" .. package.path

love = {
  math = {
    random = function(a)
      return a or 0.5
    end,
  },
  timer = {
    getTime = function()
      return 0
    end,
  },
}

local Data = require("src.run.data")
local Rhythm = require("src.run.rhythm")
local Abilities = require("src.run.abilities")

local function makeEnemy(x, y)
  return {
    x = x,
    y = y,
    radius = 10,
    hp = 1000,
    dead = false,
    takeDamage = function(self, amount)
      self.hp = self.hp - amount
    end,
  }
end

local function makeRun(enemies, abilityId, characterId, wallDistance)
  local run = {
    player = {
      x = 0,
      y = 0,
      radius = 16,
      facingX = 1,
      facingY = 0,
      invuln = 0,
      shieldTimer = 0,
    },
    enemies = enemies,
    stats = { damage = 10, maxHp = 100 },
    hp = 100,
    playerLevel = 1,
    characterId = characterId or "amado",
    abilitySlot1 = abilityId,
    abilitySlot2 = nil,
    abilitySlot3 = "shield",
    abilitySlot4 = "turbo",
    cooldowns = {},
    activated = 0,
    lastMove = nil,
    shadow = nil,
    mana = 100,
    manaMax = 100,
    manaIdleTimer = 0,
    manaFlash = 0,
  }

  run.dungeon = {
    tile = 36,
    raycast = function(_, _, _, _, _, maxDistance)
      local stop = wallDistance or maxDistance
      return stop, stop < maxDistance
    end,
    nearestWalkable = function(_, x, y)
      return x, y
    end,
    moveCircle = function(_, x, y, dx, dy)
      run.lastMove = { x = dx, y = dy }
      return x + dx, y + dy
    end,
    circleCollides = function()
      return false
    end,
    lineOfSight = function()
      return true
    end,
  }

  function run:nearestEnemy()
    return self.enemies[1]
  end

  function run:abilityIdForSlot(slot)
    if slot == 1 then return self.abilitySlot1 end
    if slot == 2 then return self.abilitySlot2 end
    if slot == 4 then return self.abilitySlot4 end
    return self.abilitySlot3
  end

  function run:cooldownKeyForSlot(slot)
    if slot == 1 then return "a1" end
    if slot == 2 then return "a2" end
    if slot == 3 then return "shield" end
    return "turbo"
  end

  function run:onAbilityActivated()
    self.activated = self.activated + 1
  end

  function run:onManaFail(ability)
    self.manaFlash = 1
    self.failedAbility = ability and ability.id
  end

  function run:spawnShadow(x, y)
    self.shadow = { x = x, y = y }
  end

  function run:marDash()
    self.dashed = true
  end

  return run
end

local near = makeEnemy(100, 0)
local far = makeEnemy(200, 0)
local arrowRun = makeRun({ near, far }, "light_arrow")
assert(Abilities.cast(arrowRun, 1, nil), "la flecha debe lanzarse")
assert(
  math.abs(
    arrowRun.mana
      - (100 - Data.abilities.light_arrow.manaCost)
  ) < 0.001,
  "la habilidad debe consumir maná"
)
assert(arrowRun.manaIdleTimer == 0, "usar maná debe reiniciar la espera de regeneración")
assert(
  math.abs(near.hp - (1000 - 10 * Data.abilities.light_arrow.damageMultiplier)) < 0.001,
  "el primer enemigo debe recibir el daño completo"
)
assert(
  math.abs(far.hp - (1000 - 10 * Data.abilities.light_arrow.damageMultiplier)) < 0.001,
  "la flecha debe perforar y golpear a varios enemigos"
)
assert(not Abilities.cast(arrowRun, 1, nil), "el cooldown debe bloquear el segundo lanzamiento")

local blocked = makeEnemy(200, 0)
local wallRun = makeRun({ blocked }, "light_arrow", "amado", 150)
assert(Abilities.cast(wallRun, 1, nil), "la flecha debe lanzarse aunque haya pared")
assert(blocked.hp == 1000, "la pared debe cortar el rayo antes del enemigo")

local marEnemy = makeEnemy(60, 0)
local resonanceRun = makeRun({ marEnemy }, "resonance", "mar")
assert(Abilities.cast(resonanceRun, 1, nil), "la resonancia debe lanzarse")
assert(resonanceRun.lastMove and resonanceRun.lastMove.x > 0, "Mar debe empujar al enemigo")

local shadowEnemy = makeEnemy(100, 0)
local shadowRun = makeRun({ shadowEnemy }, "shadow_swap")
assert(Abilities.cast(shadowRun, 1, nil), "la sombra debe lanzarse")
assert(shadowRun.player.x == 100, "el jugador debe saltar al objetivo")
assert(shadowRun.shadow and shadowRun.shadow.x == 0, "debe quedar una sombra en el origen")

local poorRun = makeRun({ makeEnemy(100, 0) }, "light_arrow")
poorRun.mana = 1
assert(not Abilities.cast(poorRun, 1, nil), "sin maná no debe lanzarse la habilidad")
assert(poorRun.failedAbility == "light_arrow", "debe avisarse que faltó maná")
assert(poorRun.mana == 1, "un intento fallido no debe gastar maná")

Rhythm.enter({ bpm = 104 })
Rhythm.t = Rhythm.nextBeat
local drumRun = makeRun({ makeEnemy(100, 0) }, "light_arrow")
drumRun.passiveStacks = { drum = 1 }
drumRun.cooldowns.shield = 8
assert(Abilities.cast(drumRun, 1, nil), "con Tambor la habilidad debe lanzarse a ritmo")
assert(
  math.abs(drumRun.mana - (100 - Data.abilities.light_arrow.manaCost * 0.75)) < 0.001,
  "Tambor debe reducir el maná a ritmo"
)
assert(
  math.abs(drumRun.cooldowns.a1 - Data.abilities.light_arrow.cooldown * 0.5) < 0.001,
  "Tambor debe reducir el cooldown propio a la mitad"
)
assert(drumRun.cooldowns.shield == 6, "Tambor debe restar dos segundos a las demás")

local duplicateRun = makeRun({ makeEnemy(100, 0) }, "light_arrow")
duplicateRun.abilitySlot2 = "light_arrow"
assert(Abilities.cast(duplicateRun, 1, nil), "A1 debe lanzar la primera copia")
assert(duplicateRun.cooldowns.a1 > 0 and duplicateRun.cooldowns.a2 == nil, "los cooldowns deben ser independientes")
assert(Abilities.cast(duplicateRun, 2, nil), "A2 debe lanzar su propia copia")

local refreshRun = makeRun({})
refreshRun.player.shieldTimer = 2
refreshRun.hp = 50
assert(Abilities.cast(refreshRun, 3, nil), "el escudo debe refrescarse con Tambor")
assert(refreshRun.hp == 50, "refrescar el escudo no debe curar otra vez")
assert(refreshRun.player.shieldTimer == Data.abilities.shield.duration, "debe reiniciar duración")

local turboRun = makeRun({})
assert(Abilities.cast(turboRun, 4, nil), "Turbo debe estar siempre en la ranura T")
assert(turboRun.turboTimer == Data.abilities.turbo.duration, "Turbo debe activar su duración")

print("OK habilidades, apuntado, maná, Tambor y cooldowns")
