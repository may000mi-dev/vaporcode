-- test_director.lua: métricas, evaluación y modificadores del Director.
package.path = "./?.lua;" .. package.path

local Data = require("src.run.data")
local Director = require("src.run.director")

local function fakeRun(mode, sandbox)
  return {
    mode = mode or "free",
    sandbox = sandbox or false,
    depth = 4,
    hp = 100,
    stats = { maxHp = 100 },
  }
end

assert(Director.evaluate(nil).state == "standard", "sin métricas debe ser estándar")
assert(
  Director.evaluate({ floorTime = 44, damageTaken = 0, endHpRatio = 1 }).state == "high",
  "un piso rápido sin daño debe ser alta presión"
)
assert(
  Director.evaluate({ floorTime = 44, damageTaken = 8, endHpRatio = 0.85 }).state == "high",
  "85% de vida debe alcanzar para alta presión"
)
assert(
  Director.evaluate({ floorTime = 45, damageTaken = 0, endHpRatio = 1 }).state == "standard",
  "45 s exactos no cuentan como piso rápido"
)
assert(
  Director.evaluate({ floorTime = 50, damageTaken = 5, endHpRatio = 0.60 }).state == "standard",
  "un piso promedio debe quedar estándar"
)
assert(
  Director.evaluate({ floorTime = 50, damageTaken = 5, endHpRatio = 0.24 }).state == "low",
  "terminar al borde de la muerte debe ser baja presión"
)
assert(
  Director.evaluate({ floorTime = 121, damageTaken = 5, endHpRatio = 0.80 }).state == "low",
  "tardar demasiado debe ser baja presión"
)

local highRun = fakeRun("free")
highRun.director = {
  next = Director.evaluate({ floorTime = 30, damageTaken = 0, endHpRatio = 1 }),
}
local active = Director.beginFloor(highRun)
assert(active.state == "high", "el siguiente piso debe activar alta presión")
assert(highRun.director.next == nil, "la evaluación debe consumirse una sola vez")
assert(Director.threatMultiplier(highRun) == Data.director.highThreatMultiplier,
  "alta presión debe subir el presupuesto")
assert(Director.extraEliteCount(highRun) == 1, "alta presión debe garantizar un élite")
assert(not Director.suppressDoubleAffixes(highRun), "alta presión no suspende afijos")
assert(Director.currentNotice(highRun) == Data.director.messages.high,
  "el aviso de alta presión debe estar visible")
Director.update(highRun, Data.director.noticeDuration + 0.1)
assert(Director.currentNotice(highRun) == nil, "el aviso debe expirar")

local retryActive = Director.beginFloor(highRun)
assert(retryActive.state == "high", "un reintento debe conservar el modificador activo")

local lowRun = fakeRun("free")
lowRun.director = {
  next = Director.evaluate({ floorTime = 130, damageTaken = 8, endHpRatio = 0.20 }),
}
Director.beginFloor(lowRun)
assert(Director.threatMultiplier(lowRun) == Data.director.lowThreatMultiplier,
  "baja presión debe reducir el presupuesto")
assert(Director.extraEliteCount(lowRun) == 0, "baja presión no añade élites")
assert(Director.suppressDoubleAffixes(lowRun), "baja presión debe suspender doble afijo")

local run = fakeRun("free")
Director.beginFloor(run)
Director.update(run, 30)
Director.onPlayerDamaged(run, 12)
Director.update(run, 10)
run.hp = 70
local nextState = Director.completeFloor(run)
local metrics = Director.lastMetrics(run)
assert(math.abs(metrics.floorTime - 40) < 0.0001, "floorTime debe acumular solo el piso")
assert(metrics.damageTaken == 12, "damageTaken debe acumular el daño real")
assert(math.abs(metrics.endHpRatio - 0.70) < 0.0001, "endHpRatio debe usar la vida final")
assert(nextState.state == "standard", "las métricas deben evaluar el siguiente piso")

local frozenTime = metrics.floorTime
Director.update(run, 30)
assert(Director.lastMetrics(run).floorTime == frozenTime,
  "el tiempo no debe seguir corriendo tras completar")
assert(Director.completeFloor(run) == nextState,
  "completar dos veces no debe reemplazar la evaluación")

local story = fakeRun("story")
assert(not Director.enabled(story), "Historia no debe usar Director")
assert(Director.beginFloor(story) == nil, "Historia no debe activar modificadores")
assert(story.director == nil, "Historia debe quedar sin estado de Director")
assert(Director.completeFloor(story) == nil, "Historia no debe registrar evaluaciones")
assert(Director.threatMultiplier(story) == 1, "Historia conserva el presupuesto normal")
assert(not Director.suppressDoubleAffixes(story), "Historia conserva doble afijo")

local sandbox = fakeRun("free", true)
assert(not Director.enabled(sandbox), "la sala de pruebas debe quedar exenta")
assert(Director.beginFloor(sandbox) == nil, "la sala de pruebas no debe activar Director")

print("OK Director: métricas, alta/baja presión, avisos y aislamiento")
