-- balance.lua: números de juego (jugador, economía, piso, trampas, ritmo, colores).

local Balance = {}

Balance.economy = {
  coinsBase = 1,
  xpPerCoin = 10,
  costGrowth = 1.65,
}
Balance.floor = {
  timeLimit = 300,
  warningTime = 60,
}

-- Válvulas de presión: trampas activables al pisarlas o dispararles.
Balance.valve = {
  radius = 11,
  triggerRadius = 20,
  jetRadius = 78,
  activeTime = 1.2,
  cooldown = 3.2,
  tickInterval = 0.3,
  damage = 4,
  countBase = 1,
  countPerDepth = 0.25,
  maxCount = 3,
  minDistance = 120,
  color = { 0.56, 0.64, 0.70 },
  accent = { 0.95, 0.62, 0.20 },
  steam = { 0.88, 0.94, 1.00 },
}

-- Paredes frágiles: Resonancia o Flecha de luz las abren.
Balance.destructible = {
  hp = 2,
  minCount = 1,
  maxCount = 3,
  perDepth = 0.25,
  maxCountCap = 5,
  resonanceDamage = 1,
  lightArrowDamage = 2,
  lootChance = 0.55,
  color = { 0.30, 0.24, 0.17 },
  crack = { 0.95, 0.62, 0.20 },
}

-- Cofres: entregan XP, monedas y un ítem que aparece en el suelo.
Balance.chest = {
  radius = 12,
  openRadius = 30,
  countBase = 1,
  countPerDepth = 0.5,
  maxCount = 3,
  minDistance = 210,
  xpBase = 12,
  xpPerDepth = 5,
  coinsBase = 4,
  coinsPerDepth = 1,
  color = { 0.78, 0.54, 0.20 },
  dark = { 0.28, 0.18, 0.08 },
}

Balance.dungeonGen = {
  -- Tamaño base equivalente al prototipo original (26x15 tiles).
  baseCols = 26,
  baseRows = 15,
  -- El área de cada piso varía entre 1/2 y 4 veces el mapa original.
  sizeScaleMin = 0.5,
  sizeScaleMax = 4.0,
  minCols = 13,
  minRows = 8,
  minRooms = 6,
  maxRooms = 8,
  extraRoomsPerDepth = 0.5,
  maxRoomsCap = 10,
  minRoomW = 4,
  maxRoomW = 7,
  minRoomH = 3,
  maxRoomH = 5,
  spacing = 2,
  losStep = 16,
  rayStep = 8,
}

Balance.player = {
  radius = 16,
  attackRate = 2.7,
  attackRange = 520,
  invulnTime = 0.18,
  levelDamage = 1,
  levelMaxHp = 6,
  levelHeal = 14,
  xpBase = 20,
  xpStep = 16,
  exitRadius = 26,
  exitDelay = 0.6,
  nextLevelHealPercent = 0.15,
}
Balance.camera = {
  -- Zona central libre entre joystick y botones.
  dragZone = { x = 360, y = 150, w = 190, h = 240 },
  maxOffset = 270,
  returnSpeed = 12,
}
Balance.projectile = {
  friendlyRadius = 4,
  hostileRadius = 6,
  friendlyLife = 1.25,
  hostileLife = 4.0,
  friendlySpeed = 400,
  hostileSpeed = 200,
}
Balance.rhythm = {
  bpm = 104,
  firstBeatDelay = 1.6,
  visualWindow = 0.12,
  hitWindow = 0.12,
  perfectMultiplier = 2,
}

Balance.colors = {
  bg = { 0.04, 0.05, 0.07 },
  floor = { 0.10, 0.11, 0.14 },
  grid = { 0.07, 0.08, 0.10 },
  wall = { 0.17, 0.19, 0.23 },
  wallEdge = { 0.30, 0.34, 0.40 },
  wallTop = { 0.22, 0.25, 0.30 },
  player = { 0.50, 0.90, 1.00 },
  xp = { 0.35, 0.85, 1.00 },
}

return Balance
