-- test_data.lua: las definiciones de enemigos mantienen tipos consistentes.
-- Un booleano en un campo numérico rompe comparaciones en enemy.lua
-- (p.ej. keepDistance = true hacia caer a updateRanged).
package.path = "./?.lua;" .. package.path

local Data = require("src.run.data")

-- Campos que enemy.lua compara o usa en aritmética; deben ser números >= 0.
-- speed admite 0 (torretas). El resto, si aparece, no puede ser negativo.
local numericFields = {
  "radius", "speed", "hp", "damage", "xp",
  "attackRange", "attackInterval", "retreatDistance", "flankDistance",
  "fleeDistance", "firstAttackDelay", "projectileSpeed", "projectileRadius",
}

local function isNumberOrNil(value)
  return value == nil or (type(value) == "number" and value >= 0)
end

for id, def in pairs(Data.enemyTypes) do
  for _, field in ipairs(numericFields) do
    assert(isNumberOrNil(def[field]),
      id .. "." .. field .. " debe ser número >= 0, no booleano")
  end

  -- keepDistance también acepta false (chaser puro), pero nunca true.
  local keep = def.keepDistance
  assert(keep == nil or keep == false or isNumberOrNil(keep),
    id .. ".keepDistance debe ser false o número >= 0")
end

-- Los enemigos listados por cada mazmorra deben existir realmente.
for _, dungeon in ipairs(Data.dungeons) do
  for _, enemyId in ipairs(dungeon.enemies) do
    assert(Data.enemyTypes[enemyId],
      dungeon.id .. " lista un enemigo inexistente: " .. enemyId)
  end
  assert(Data.enemyTypes[dungeon.boss],
    dungeon.id .. " lista un jefe inexistente: " .. tostring(dungeon.boss))
end

print("OK tipos de datos de enemigos y mazmorras")
