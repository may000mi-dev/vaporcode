-- boss_memories.lua: memorias de jefe y límite de Sobrecarga del Infinito.
-- Los valores viven aquí para ajustar la dificultad sin tocar la lógica.
-- Solo se aplican en Modo Infinito; Historia conserva sus jefes originales.

local BossMemories = {}

-- Límite estricto de la pelea. Al agotarse, la sobrecarga cierra la run.
BossMemories.enrageSeconds = 180
BossMemories.maxMemories = 2

BossMemories.types = {
  rage = {
    name = "Furia",
    desc = "Tras 45 s gana 25% de velocidad y daño.",
    delay = 45,
    speedMultiplier = 1.25,
    damageMultiplier = 1.25,
    color = { 1.00, 0.18, 0.14 },
  },
  echo = {
    name = "Eco",
    desc = "Cada 12 s deja un eco telegrafiado sobre el jugador.",
    interval = 12,
    radius = 64,
    telegraph = 1.3,
    damageBase = 12,
    damagePerDepth = 2,
    color = { 0.42, 0.62, 1.00 },
  },
  siphon = {
    name = "Sifón",
    desc = "Sus impactos drenan 8 de maná y añaden 1 s de recarga.",
    manaDrain = 8,
    cooldownPenalty = 1,
    hitCooldown = 0.75,
    color = { 0.72, 0.34, 0.78 },
  },
  regen = {
    name = "Regeneración",
    desc = "Sin recibir daño 3 s, recupera 1% de vida por segundo.",
    idle = 3,
    percentPerSecond = 0.01,
    color = { 0.42, 0.92, 0.42 },
  },
  guard = {
    name = "Guardia",
    desc = "Dos élites del piso protegen al jefe.",
    count = 2,
    distance = 96,
    color = { 0.86, 0.68, 0.26 },
  },
  fortified = {
    name = "Fortificado",
    desc = "Recibe 30% menos daño hasta bajar al 66% de vida.",
    reduction = 0.30,
    threshold = 0.66,
    color = { 0.62, 0.72, 0.86 },
  },
}

-- Cada compás deja una memoria distinta. Si dos compases apuntan a la misma
-- memoria, se muestra una sola vez y el jefe conserva entre 1 y 2 memorias.
BossMemories.fromCompas = {
  pressure = "rage",
  overload = "siphon",
  legion = "guard",
  echo = "echo",
  famine = "regen",
  hunt = "guard",
  seal = "fortified",
  choir = "regen",
}

return BossMemories
