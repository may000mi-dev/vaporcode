-- characters.lua: personajes jugables, marca de Amado y desbloqueos.

local Characters = {}

-- Reglas compartidas de la marca de Amado.
Characters.mark = {
  maxMarks = 3,
  damageBonus = 0.15,
  slow = 0.10,
  duration = 2,
}

Characters.characters = {
  amado = {
    id = "amado",
    name = "Amado",
    color = { 0.50, 0.90, 1.00 },
    desc = "Marca hasta 3 enemigos: +15% daño y -10% velocidad.",
    speedMultiplier = 1,
    attackRate = 2.7,
    basic = "ranged",
    attackRange = 520,
  },
  mar = {
    id = "mar",
    name = "Mar",
    color = { 0.95, 0.38, 0.34 },
    desc = "Golpe giratorio y dash al usar habilidades en movimiento.",
    speedMultiplier = 1.18,
    attackRate = 2.2,
    basic = "melee",
    meleeRangeMinFactor = 8,
    meleeRangeMaxFactor = 14,
    meleeLevelSpan = 9,
    dashRadiusFactor = 8,
    dashInvuln = 0.5,
    dashSearch = 240,
  },
  amileth = {
    id = "amileth",
    name = "Amileth",
    color = { 0.98, 0.86, 0.30 },
    desc = "Arcoíris en cadena y escudo que se repara fuera de combate.",
    speedMultiplier = 1.06,
    attackRate = 2.4,
    basic = "chain",
    chain = {
      jumps = 2,
      range = 220,
      falloff = 0.5,
      requireLineOfSight = true,
    },
    shieldPercent = 0.10,
    shieldRepairDelay = 5,
    shieldRepairRate = 0.20,
  },
}

Characters.characterOrder = { "amado", "mar", "amileth" }
Characters.characterItem = {
  mar = "mar_unlock",
  amileth = "amileth_unlock",
}

return Characters
