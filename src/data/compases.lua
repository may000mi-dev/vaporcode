-- compases.lua: modificadores de piso encadenados del Modo Infinito.
-- Cada tres pisos entra un compás nuevo; la cadena conserva como máximo tres
-- efectos activos. Los números viven aquí para poder balancear sin tocar lógica.

local Compases = {}

Compases.cycleFloors = 3
Compases.maxActive = 3
Compases.sequenceLength = 128

Compases.echo = {
  interval = 10,
  telegraph = 1.5,
  radius = 64,
  damageBase = 10,
  damagePerDepth = 2,
  color = { 0.42, 0.62, 1.00 },
}

Compases.types = {
  pressure = {
    name = "Presión",
    desc = "Los enemigos infligen 15% más de daño.",
    enemyDamageMultiplier = 1.15,
    color = { 1.00, 0.46, 0.32 },
  },
  overload = {
    name = "Sobrecarga",
    desc = "El intervalo de ataque enemigo se reduce 17%.",
    enemyCooldownMultiplier = 0.83,
    color = { 1.00, 0.72, 0.30 },
  },
  legion = {
    name = "Legión",
    desc = "El presupuesto de amenaza aumenta 25%.",
    threatMultiplier = 1.25,
    color = { 0.86, 0.38, 0.42 },
  },
  echo = {
    name = "Eco",
    desc = "Un eco detona sobre el jugador cada 10 segundos.",
    echo = true,
    color = { 0.42, 0.62, 1.00 },
  },
  famine = {
    name = "Hambruna",
    desc = "Toda la curación del jugador se reduce 40%.",
    playerHealingMultiplier = 0.60,
    color = { 0.64, 0.48, 0.28 },
  },
  hunt = {
    name = "Cacería",
    desc = "Aparece un Sabueso élite imposible de aturdir.",
    guaranteedKind = "sabueso",
    hunterAffix = "vampiric",
    color = { 0.72, 0.34, 0.78 },
  },
  seal = {
    name = "Sello",
    desc = "Aparece un Inquisidor y los bloqueos duran 1 s más.",
    guaranteedKind = "inquisidor",
    abilityLockBonus = 1,
    color = { 0.46, 0.70, 1.00 },
  },
  choir = {
    name = "Coro",
    desc = "Aparece un Clérigo que cura 25% más.",
    guaranteedKind = "clerigo",
    enemyHealingMultiplier = 1.25,
    color = { 0.98, 0.84, 0.38 },
  },
}

Compases.order = {
  "pressure",
  "overload",
  "legion",
  "echo",
  "famine",
  "hunt",
  "seal",
  "choir",
}

return Compases
