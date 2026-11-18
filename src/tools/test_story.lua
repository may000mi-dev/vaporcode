-- test_story.lua: datos de campaña, reglas de portal y guardado del Modo Historia.
package.path = "./?.lua;" .. package.path

local files = {}
love = {
  filesystem = {
    getInfo = function(name)
      return files[name] and { type = "file" } or nil
    end,
    read = function(name)
      return files[name]
    end,
    write = function(name, content)
      files[name] = content
      return true
    end,
    remove = function(name)
      files[name] = nil
      return true
    end,
  },
}

local Data = require("src.run.data")
local Save = require("src.run.save")
local Story = require("src.run.story")
local StoryData = Data.story

assert(#StoryData.chapters == 4, "la campaña debe tener cuatro capítulos")
assert(StoryData.chapterById.cripta.act == 1, "Cripta pertenece al Acto I")
assert(StoryData.chapterById.forja.act == 2, "Forja pertenece al Acto II")
assert(StoryData.chapterById.catedral.act == 2, "Catedral pertenece al Acto II")
assert(StoryData.chapterById.torre.act == 3, "Torre pertenece al Acto III")
assert(StoryData.chapterById.cripta.nextChapter == "forja", "Cripta debe abrir Forja")
assert(StoryData.chapterById.forja.nextChapter == "catedral", "Forja debe abrir Catedral")
assert(StoryData.chapterById.catedral.nextChapter == "torre", "Catedral debe abrir Torre")
assert(StoryData.chapterById.torre.nextChapter == nil, "Torre debe cerrar la campaña")

for _, chapter in ipairs(StoryData.chapters) do
  assert(Data.dungeonById[chapter.dungeonId], chapter.id .. " debe tener mazmorra")
  assert(StoryData.actById[chapter.act], chapter.id .. " debe tener acto")
  assert(StoryData.scenes[chapter.introScene], chapter.id .. " debe tener intro")
  assert(StoryData.scenes[chapter.outroScene], chapter.id .. " debe tener outro")
  assert(chapter.startDepth <= chapter.endDepth, chapter.id .. " debe tener pisos válidos")
  for _, floor in ipairs(chapter.bossFloors) do
    assert(
      floor >= chapter.startDepth and floor <= chapter.endDepth,
      chapter.id .. " debe tener jefes dentro de sus pisos"
    )
  end
end

assert(StoryData.chapterById.torre.startDepth == 10, "la Torre debe iniciar en el piso 10")
assert(StoryData.chapterById.torre.endDepth == 12, "la Torre debe terminar en el piso 12")
assert(Data.dungeonById.torre.storyUnlock, "la Torre debe desbloquearse con la historia")
assert(not Data.dungeonById.torre.storyOnly, "la Torre también debe existir en modo Infinito")
assert(Data.dungeonById.torre.boss == "time_organ", "la Torre debe usar al Órgano del Tiempo")
assert(Data.enemyTypes.time_organ.bossKind == "organ", "el jefe final debe usar la IA de órgano")

for id, scene in pairs(StoryData.scenes) do
  assert(type(id) == "string" and #scene.lines > 0, "cada escena debe tener líneas")
  for _, line in ipairs(scene.lines) do
    assert(line.speaker and line.text, "cada línea debe tener voz y texto")
  end
  for _, characterId in ipairs({ "mar", "amileth" }) do
    local variant = StoryData.characterScenes[characterId]
      and StoryData.characterScenes[characterId][id]
    assert(variant, characterId .. " debe tener variante para " .. id)
    assert(#variant.lines > 0, "la variante debe tener líneas")
  end
end

assert(
  Story.exitKind({ mode = "story", storyChapterId = "cripta", depth = 8 }) == "normal",
  "los pisos internos no deben abrir portal"
)
assert(
  Story.exitKind({ mode = "story", storyChapterId = "cripta", depth = 9 }) == "portal",
  "el último piso de Cripta debe abrir portal"
)
assert(
  Story.exitKind({ mode = "story", storyChapterId = "torre", depth = 11 }) == "normal",
  "la Torre no debe abrir portal antes del final"
)
assert(
  Story.exitKind({ mode = "story", storyChapterId = "torre", depth = 12 }) == "ending",
  "el piso 12 debe cerrar la campaña"
)
assert(Story.exitKind({ mode = "free", depth = 9 }) == "normal", "el modo libre no usa portales")

local index, total = Story.floorIndex({
  mode = "story",
  storyChapterId = "torre",
  depth = 11,
})
assert(index == 2 and total == 3, "la Torre debe mostrar 2 de 3 pisos")

Save.load()
assert(Save.data.version == 7, "el guardado debe usar la versión 7")
assert(Save.getStory("amado") and not Save.getStory("amado").active, "la historia inicia inactiva")
assert(not Save.hasStoryCheckpoint(), "sin checkpoint no debe haber continuación")

local snapshot = {
  seed = 123,
  depth = 4,
  dungeonId = "cripta",
  characterId = "amado",
  playerLevel = 3,
  hp = 70,
  xp = 4,
  xpToNext = 40,
  mana = 55,
  manaMax = 100,
  timeLeft = 180,
  stats = { damage = 18, maxHp = 100, speed = 150, attackRate = 2.7 },
  inventory = {},
}
assert(Save.setStoryCheckpoint("cripta", snapshot), "debe guardar un checkpoint")
assert(Save.hasStoryCheckpoint(), "el checkpoint debe quedar activo")
assert(Save.hasStoryCheckpoint("amado"), "el checkpoint debe ser de Amado")
assert(Save.getStory("amado").chapterId == "cripta", "debe recordar el capítulo")
assert(Save.getStory("amado").depth == 4, "debe recordar el piso")
assert(snapshot.mode == "story", "el snapshot debe quedar marcado como historia")
assert(snapshot.storyChapterId == "cripta", "el snapshot debe recordar el capítulo")

Save.load()
assert(Save.hasStoryCheckpoint("amado"), "el checkpoint debe persistir")
assert(Save.getStory("amado").depth == 4, "el piso debe persistir")
assert(Save.getStory("amado").checkpoint.hp == 70, "el estado del piso debe persistir")

local marStory = Save.getStory("mar")
marStory.active = true
marStory.chapterId = "torre"
marStory.depth = 99
marStory.checkpoint = { depth = 99, characterId = "mar" }
Save.save()
Save.load()
assert(not Save.hasStoryCheckpoint("mar"), "un checkpoint fuera de rango debe descartarse")
assert(Save.getStory("mar").chapterId == "torre", "el capítulo válido debe conservarse")
assert(Save.getStory("mar").depth == 12, "la profundidad debe acotarse al capítulo")

local amadoStory = Save.getStory("amado")
amadoStory.active = true
amadoStory.chapterId = "cripta"
amadoStory.depth = 2
amadoStory.checkpoint = {
  depth = 2,
  dungeonId = "cripta",
  characterId = "amado",
  seed = 1,
  playerLevel = 1,
  hp = 1,
  xp = 0,
  xpToNext = 10,
  mana = 0,
  manaMax = 100,
  timeLeft = 300,
  stats = {},
}
Save.save()
Save.load()
assert(not Save.hasStoryCheckpoint("amado"), "un checkpoint incompleto debe descartarse")
assert(Save.getStory("amado").chapterId == "cripta", "el capítulo válido debe conservarse")
assert(Save.getStory("amado").depth == 2, "la profundidad válida debe conservarse")

assert(Save.setStoryCheckpoint("cripta", snapshot), "debe poder reiniciar el checkpoint")
local marSnapshot = {}
for key, value in pairs(snapshot) do marSnapshot[key] = value end
marSnapshot.seed = 456
marSnapshot.depth = 3
marSnapshot.characterId = "mar"
marSnapshot.hp = 50
assert(Save.setStoryCheckpoint("cripta", marSnapshot), "Mar debe guardar su propio checkpoint")
assert(Save.hasStoryCheckpoint("amado") and Save.hasStoryCheckpoint("mar"),
  "cada personaje debe conservar su checkpoint")
assert(Save.resetStory("amado"), "reiniciar debe afectar solo al personaje indicado")
assert(not Save.hasStoryCheckpoint("amado"), "Amado debe perder su checkpoint")
assert(Save.hasStoryCheckpoint("mar"), "Mar debe conservar su checkpoint")
Save.load()
assert(not Save.hasStoryCheckpoint("amado"), "el reinicio por personaje debe persistir")
assert(Save.hasStoryCheckpoint("mar") and Save.getStory("mar").depth == 3,
  "el checkpoint de Mar debe persistir tras reiniciar a Amado")

assert(Save.setStoryCheckpoint("cripta", snapshot), "debe poder reiniciar el checkpoint de Amado")
assert(Save.completeStory("amado"), "debe poder completar la historia de Amado")
assert(not Save.hasStoryCheckpoint("amado"), "completar debe borrar el checkpoint de Amado")
assert(Save.hasStoryCheckpoint("mar"), "completar a Amado no debe borrar el checkpoint de Mar")
assert(Save.getStory("amado").completed, "completar debe marcar el final de la sesión")
assert(Save.isStoryCompleted("amado"), "Amado debe tener su historia completada")
assert(Save.storyCompletionCount() == 1, "debe contar una historia completada")
assert(not Save.isDungeonUnlocked("torre"), "la Torre exige las tres historias")
Save.load()
assert(Save.getStory("amado").completed, "el final debe persistir")
assert(Save.isStoryCompleted("amado"), "la historia de Amado debe persistir")
assert(Save.hasStoryCheckpoint("mar"), "cargar el guardado no debe tocar la historia de Mar")

assert(Save.completeStory("mar"), "debe poder completar la historia de Mar")
assert(Save.completeStory("amileth"), "debe poder completar la historia de Amileth")
assert(Save.storyCompletionCount() == 3, "deben quedar tres historias completadas")
assert(Save.isDungeonUnlocked("torre"), "la Torre debe abrirse con las tres historias")

assert(Save.resetStory("amado"), "debe poder reiniciar la campaña activa del personaje")
assert(not Save.getStory("amado").active, "reiniciar debe desactivar la historia")
assert(not Save.getStory("amado").completed, "reiniciar debe borrar el final de la sesión")
assert(not Save.hasStoryCheckpoint("amado"), "reiniciar debe borrar el checkpoint")
assert(Save.storyCompletionCount() == 3, "reiniciar no debe borrar historias completadas")
assert(Save.isDungeonUnlocked("torre"), "la Torre debe seguir abierta tras reiniciar la sesión")

print("OK historia por personaje, portales, escenas y guardado v7")
