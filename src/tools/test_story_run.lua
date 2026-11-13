-- test_story_run.lua: entrada, checkpoints, portales y final del Modo Historia.
package.path = "./?.lua;" .. package.path

local function rng(seed)
  local state = seed or 1
  return {
    random = function(_, a, b)
      state = (state * 1103515245 + 12345) % 2147483648
      local value = state / 2147483648
      if a and b then
        return math.floor(value * (b - a + 1)) + a
      elseif a then
        return math.floor(value * a) + 1
      end
      return value
    end,
  }
end

local function noop() end
love = {
  math = {
    random = function(a, b)
      if a and b then return a end
      return 0.5
    end,
    newRandomGenerator = rng,
  },
  timer = {
    getTime = function() return 0 end,
  },
  system = {
    getOS = function() return "Linux" end,
  },
  filesystem = {
    getInfo = function() return nil end,
    write = function() return true end,
    remove = function() return true end,
  },
  graphics = {
    setColor = noop,
    rectangle = noop,
    print = noop,
    printf = noop,
    setFont = noop,
    circle = noop,
    line = noop,
    arc = noop,
    polygon = noop,
    setLineWidth = noop,
    push = noop,
    pop = noop,
    translate = noop,
    scale = noop,
    setScissor = noop,
  },
}
love.timer.getFPS = function() return 60 end

local Save = require("src.run.save")
local State = require("src.estados")
local Data = require("src.run.data")
local Historia = require("src.estados.historia")
local Run = require("src.run.run")
local StoryUI = require("src.run.story_ui")
local Progression = require("src.run.progression")

local function finishScenes()
  local guard = 0
  while Run.overlay == "story" do
    StoryUI.advance(Run)
    guard = guard + 1
    assert(guard < 100, "las escenas no deben quedar atascadas")
  end
end

Save.load()
Run.enter("cripta", "amado", nil, { mode = "story", chapterId = "cripta" })

assert(Run.mode == "story", "la run debe entrar en modo historia")
assert(Run.storyChapterId == "cripta", "debe iniciar en la Cripta")
assert(Run.depth == 1, "la Cripta debe iniciar en el piso 1")
assert(Run.exitKind == "normal", "el primer piso no debe tener portal")
assert(Run.overlay == "story", "el prólogo debe mostrarse como escena")
assert(Run.storyScene == Data.story.scenes.prologo, "debe mostrarse el prólogo")
assert(Save.hasStoryCheckpoint(), "el inicio del piso debe guardar checkpoint")
assert(Save.data.story.chapterId == "cripta" and Save.data.story.depth == 1, "el checkpoint debe ser el piso 1")

local frozenTime = Run.timeLeft
Run.update(1)
assert(Run.timeLeft == frozenTime, "las escenas no deben consumir el temporizador")

finishScenes()
assert(Run.overlay == nil, "al terminar el prólogo debe volver el juego")
assert(Run.mode == "story" and Run.storyChapterId == "cripta", "debe seguir en la Cripta")

Progression.nextLevel(Run)
assert(Run.depth == 2, "el avance normal debe llevar al piso 2")
assert(Run.overlay == nil, "un piso normal no debe abrir escena")
assert(Save.data.story.depth == 2, "el nuevo piso debe guardar checkpoint")

Run.hp = 1
State.switch("historia", "amado")
Historia.keypressed("return")
assert(Run.mode == "story" and Run.storyChapterId == "cripta", "continuar debe recuperar el capítulo")
assert(Run.depth == 2, "continuar debe recuperar el piso guardado")
assert(Run.hp > 1, "continuar debe recuperar el estado del inicio del piso")
assert(Run.overlay == nil, "continuar no debe repetir la introducción")

Run.depth = 9
Progression.nextLevel(Run)
assert(Run.overlay == "story", "el último piso debe abrir el cierre del capítulo")
assert(Run.storyScene == Data.story.scenes.cripta_outro, "debe mostrarse el outro de la Cripta")
finishScenes()
assert(Run.storyChapterId == "forja", "la Cripta debe abrir la Forja")
assert(Run.depth == 1 and Run.def.id == "forja", "la Forja debe iniciar en su piso 1")
assert(Save.data.story.chapterId == "forja" and Save.data.story.depth == 1, "debe guardarse el nuevo capítulo")

Run.depth = Run.storyChapter.endDepth
Progression.nextLevel(Run)
assert(Run.storyScene == Data.story.scenes.forja_outro, "debe mostrarse el outro de la Forja")
finishScenes()
assert(Run.storyChapterId == "catedral", "la Forja debe abrir la Catedral")
assert(Run.depth == 1 and Run.def.id == "catedral", "la Catedral debe iniciar en su piso 1")

Run.depth = Run.storyChapter.endDepth
Progression.nextLevel(Run)
assert(Run.storyScene == Data.story.scenes.catedral_outro, "debe mostrarse el outro de la Catedral")
finishScenes()
assert(Run.storyChapterId == "torre", "la Catedral debe abrir la Torre")
assert(Run.depth == 10 and Run.def.id == "torre", "la Torre debe iniciar en el piso 10")
assert(Run.exitKind == "normal", "la Torre no debe abrir portal antes del final")

Run.depth = 11
Progression.nextLevel(Run)
assert(Run.depth == 12 and Run.exitKind == "ending", "el piso 12 debe cerrar la campaña")
Progression.nextLevel(Run)
assert(Run.storyScene == Data.story.scenes.final, "el jefe final debe abrir el desenlace")
finishScenes()
assert(State.name == "menu", "el final debe volver al menú")
assert(Save.data.story.completed, "el final debe marcar la historia como completada")
assert(not Save.hasStoryCheckpoint(), "el final debe borrar el checkpoint")

Run.enter("cripta", "amado")
assert(Run.mode == "free", "el modo libre debe seguir disponible tras la campaña")
assert(Run.storyChapterId == nil and Run.overlay == nil, "el modo libre no debe heredar escenas")

print("OK run de historia, checkpoints, portales y final")
