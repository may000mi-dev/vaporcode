-- upgrades.lua: mejoras permanentes de meta-progresión.

local Upgrades = {}

Upgrades.upgrades = {
  damage = {
    label = "Filo de vapor",
    desc = "Daño +4",
    base = 10,
    step = 4,
    maxLevel = 8,
  },
  maxHp = {
    label = "Caldera reforzada",
    desc = "Vida máxima +20",
    base = 100,
    step = 20,
    maxLevel = 8,
  },
  speed = {
    label = "Botas de presión",
    desc = "Velocidad +12",
    base = 150,
    step = 12,
    maxLevel = 8,
  },
}

Upgrades.upgradeOrder = { "damage", "maxHp", "speed" }

return Upgrades
