-- dungeons.lua: mazmorras jugables, índice por id y cadencia de jefes.

local Dungeons = {}

Dungeons.dungeons = {
  {
    id = "cripta",
    name = "Cripta de latón",
    unlockLevel = 0,
    desc = "Salas estrechas y presión constante.",
    song = { name = "Pulso de latón", bpm = 104 },
    enemies = { "automaton", "caldera", "artillero", "maquinista", "peste" },
    boss = "bone_patriarch",
    spawnBase = 4,
    hpScale = 0.12,
    damageScale = 0.08,
  },
  {
    id = "forja",
    name = "Forja de vapor",
    unlockLevel = 2,
    desc = "Enemigos rápidos y pasillos largos.",
    song = { name = "Martillo de pistón", bpm = 124 },
    enemies = { "sabueso", "centinela", "saboteador" },
    boss = "living_forge",
    spawnBase = 5,
    hpScale = 0.16,
    damageScale = 0.10,
  },
  {
    id = "catedral",
    name = "Catedral de engranajes",
    unlockLevel = 4,
    desc = "Criaturas densas y mucho ritmo.",
    song = { name = "Coro de válvulas", bpm = 138 },
    enemies = { "espectro", "engranaje", "clerigo", "inquisidor" },
    boss = "time_inquisitor",
    spawnBase = 6,
    hpScale = 0.20,
    damageScale = 0.12,
  },
}
Dungeons.dungeonById = {}
for _, dungeon in ipairs(Dungeons.dungeons) do
  Dungeons.dungeonById[dungeon.id] = dungeon
end
Dungeons.bossEvery = 3

return Dungeons
