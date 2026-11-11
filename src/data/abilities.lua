-- abilities.lua: habilidades activas, maná compartido y set intercambiable.

local Abilities = {}

-- Maná compartido por los personajes; las habilidades activas lo consumen.
Abilities.mana = {
  max = 100,
  regen = 2.5,
  idleDelay = 5,
  idleMultiplier = 3,
  flashDuration = 0.6,
}
Abilities.abilities = {
  resonance = {
    id = "resonance",
    name = "Resonancia",
    short = "R",
    desc = "Onda de área; mantén y arrastra para lanzarla.",
    cooldown = 6,
    manaCost = 28,
    radius = 120,
    damageMultiplier = 1.6,
    throwRangeBase = 170,
    throwRangePerLevel = 18,
    throwRangeMax = 360,
    displacement = 80,
    color = { 0.50, 0.90, 1.00 },
  },
  shield = {
    id = "shield",
    name = "Escudo",
    short = "E",
    cooldown = 10,
    manaCost = 35,
    duration = 4,
    healPercent = 0.20,
    color = { 0.95, 0.80, 0.30 },
  },
  turbo = {
    id = "turbo",
    name = "Turbo",
    short = "T",
    cooldown = 12,
    manaCost = 30,
    duration = 5,
    speedMultiplier = 1.5,
    attackRateMultiplier = 1.6,
    color = { 0.45, 1.00, 0.55 },
  },
  light_arrow = {
    id = "light_arrow",
    name = "Flecha de luz",
    short = "L",
    desc = "Rayo perforante de largo alcance.",
    cooldown = 5,
    manaCost = 22,
    damageMultiplier = 2.8,
    range = 430,
    width = 12,
    color = { 1.00, 0.96, 0.62 },
  },
  shadow_swap = {
    id = "shadow_swap",
    name = "Intercambio de sombra",
    short = "S",
    desc = "Salta y deja un señuelo que explota.",
    cooldown = 8,
    manaCost = 30,
    range = 280,
    duration = 2,
    explosionRadius = 90,
    explosionMultiplier = 1.1,
    color = { 0.68, 0.42, 0.95 },
  },
}

Abilities.exchangeable = { "resonance", "light_arrow", "shadow_swap" }
Abilities.exchangeableSet = {}
for _, id in ipairs(Abilities.exchangeable) do
  Abilities.exchangeableSet[id] = true
end

return Abilities
