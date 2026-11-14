-- test_atrition.lua: curación y tiempo escalonados del Modo Infinito.
package.path = "./?.lua;" .. package.path

local Data = require("src.run.data")
local Atricion = require("src.run.atrition")

local function fakeRun(mode, depth, sandbox, healingMultiplier)
  return {
    mode = mode or "free",
    sandbox = sandbox or false,
    depth = depth or 1,
    hp = 50,
    stats = { maxHp = 100 },
    compases = { playerHealingMultiplier = healingMultiplier or 1 },
  }
end

local timeCases = {
  { 1, 300 }, { 3, 300 },
  { 4, 270 }, { 6, 270 },
  { 7, 240 }, { 9, 240 },
  { 10, 210 }, { 30, 210 },
}
for _, case in ipairs(timeCases) do
  local depth, expected = case[1], case[2]
  assert(
    Atricion.timeLimit(fakeRun("free", depth)) == expected,
    "tiempo límite incorrecto en el piso " .. depth
  )
end

local healCases = {
  { 1, 0.15 }, { 3, 0.15 },
  { 4, 0.10 }, { 6, 0.10 },
  { 7, 0.05 }, { 9, 0.05 },
  { 10, 0.00 }, { 30, 0.00 },
}
for _, case in ipairs(healCases) do
  local depth, expected = case[1], case[2]
  assert(
    math.abs(Atricion.floorHealPercent(fakeRun("free", depth), depth) - expected) < 0.0001,
    "curación incorrecta en el piso " .. depth
  )
end

local story = fakeRun("story", 10)
assert(Atricion.timeLimit(story) == Data.floor.timeLimit, "Historia debe conservar 300 s")
assert(
  Atricion.floorHealPercent(story, 10) == Data.player.nextLevelHealPercent,
  "Historia debe conservar la curación base"
)
assert(not Atricion.enabled(story), "la atrición no debe activarse en Historia")

local sandbox = fakeRun("free", 12, true)
assert(not Atricion.enabled(sandbox), "la sala de pruebas debe quedar exenta")
assert(Atricion.timeLimit(sandbox) == Data.floor.timeLimit, "pruebas conservan el tiempo base")

local normal = fakeRun("free", 4)
local healed, percent = Atricion.applyFloorHeal(normal, 4)
assert(healed == 10 and percent == 0.10, "el piso 4 debe curar 10%")
assert(normal.hp == 60, "la curación debe sumarse a la vida actual")

local hungry = fakeRun("free", 4, false, 0.60)
assert(Atricion.applyFloorHeal(hungry, 4) == 6, "Hambruna debe reducir la curación de atrición")

local depleted = fakeRun("free", 10)
depleted.hp = 50
assert(Atricion.applyFloorHeal(depleted, 10) == 0, "desde el piso 10 no debe curar")
assert(depleted.hp == 50, "la vida no debe cambiar sin curación")

local storyHeal = fakeRun("story", 10)
assert(Atricion.applyFloorHeal(storyHeal, 10) == 15, "Historia debe curar 15%")

assert(Atricion.formatClock(300) == "5:00", "el reloj debe mostrar minutos y segundos")
assert(Atricion.formatClock(210) == "3:30", "el reloj debe formatear 210 s")

print("OK atrición de curación, tiempo e aislamiento por modo")
