-- test_save.lua: guardado versionado y recuperación ante escrituras incompletas.
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

local Save = require("src.run.save")
local Json = require("src.utils.json")

Save.load()
assert(Save.data.coins == 0, "sin archivo debe usar los valores por defecto")

Save.data.coins = 42
Save.data.bestLevel = 7
assert(Save.save(), "debe escribir el guardado")
assert(files["save.json"] and files["save.json.tmp"], "debe escribir principal y respaldo")

Save.data.coins = 0
Save.load()
assert(Save.data.coins == 42 and Save.data.bestLevel == 7, "debe releer el progreso")

-- Si Android interrumpe la escritura principal, se recupera el respaldo.
files["save.json"] = "{ incompleto"
Save.load()
assert(Save.data.coins == 42, "debe recuperar desde la copia temporal")
assert(files["save.json"] == files["save.json.tmp"], "debe reparar el principal")

-- También debe servir si el principal no existe.
files["save.json"] = nil
Save.load()
assert(Save.data.coins == 42, "debe usar la copia temporal si falta el principal")

-- Sin archivos válidos se vuelve a los valores por defecto sin romper.
files["save.json"] = "roto"
files["save.json.tmp"] = "también roto"
Save.load()
assert(Save.data.coins == 0, "datos inválidos deben caer a los valores por defecto")

-- Los volúmenes se validan y se guardan dentro de settings.
Save.setVolumes(10, -3)
assert(Save.data.settings.musicVolume == 1, "el volumen debe acotarse a 1")
assert(Save.data.settings.effectsVolume == 0, "el volumen debe acotarse a 0")
Save.load()
assert(Save.data.settings.musicVolume == 1, "el volumen debe persistir")
assert(Save.data.settings.effectsVolume == 0, "el volumen de efectos debe persistir")

-- Las mejoras permanentes y las resonancias son independientes por personaje.
assert(Save.addResonance("amado", 2), "debe guardar resonancia de Amado")
assert(Save.addResonance("mar", 1), "debe guardar resonancia de Mar")
assert(Save.useResonance("amado", "damage"), "debe gastar una resonancia")
assert(Save.upgradeLevel("damage", "amado") == 1, "Amado debe subir daño")
assert(Save.upgradeLevel("damage", "mar") == 0, "Mar no debe heredar la mejora")
assert(Save.progressFor("amado").resonance == 1, "debe descontar la resonancia")
assert(Save.stat("damage", "amado") > Save.stat("damage", "mar"), "el stat debe cambiar")

assert(Save.discoverEnemy("automaton"), "debe registrar un enemigo del bestiario")
assert(Save.isEnemyDiscovered("automaton"), "el enemigo debe quedar descubierto")
assert(not Save.discoverEnemy("no_existe"), "no debe registrar enemigos inválidos")
Save.load()
assert(Save.upgradeLevel("damage", "amado") == 1, "la mejora por personaje debe persistir")
assert(Save.progressFor("amado").resonance == 1, "la resonancia debe persistir")
assert(Save.isEnemyDiscovered("automaton"), "el bestiario debe persistir")

-- Los ítems vistos y las canciones desbloqueadas sobreviven a cada partida.
assert(Save.discoverItem("poison"), "debe registrar un ítem visto")
assert(not Save.discoverItem("no_existe"), "no debe registrar ítems inválidos")
assert(Save.discoverSong("amado", "amado_forja"), "debe registrar una canción")
assert(not Save.discoverSong("amileth", "amileth_forja"),
  "no puede desbloquear canciones de un personaje bloqueado")
assert(Save.isSongDiscovered("amado", "amado_menu"),
  "elegir personaje desbloquea su tema de menú")
Save.load()
assert(Save.isItemDiscovered("poison"), "el ítem descubierto debe persistir")
assert(Save.isSongDiscovered("amado", "amado_forja"),
  "la canción desbloqueada debe persistir")
assert(Save.itemCount() >= 1 and Save.songCount("amado") >= 2,
  "los contadores deben reflejar el catálogo")

-- Migración v4: las mejoras globales se reparten entre los tres personajes.
files["save.json.tmp"] = nil
files["save.json"] = Json.encode({
  version = 4,
  upgrades = { damage = 2, maxHp = 1, speed = 0 },
  story = { completed = true, characterId = "mar" },
})
Save.load()
assert(Save.data.version == 7, "la migración debe actualizar a la versión 7")
for _, id in ipairs({ "amado", "mar", "amileth" }) do
  assert(Save.upgradeLevel("damage", id) == 2, "la migración debe repartir las mejoras")
end
assert(Save.isStoryCompleted("mar"), "el final v4 debe asignarse a su personaje")
assert(not Save.isStoryCompleted("amado"), "la migración no debe inventar finales")
assert(not Save.isDungeonUnlocked("torre"), "la Torre exige las tres historias")

-- Migración v5: el checkpoint global se asigna al personaje que lo tenía.
files["save.json.tmp"] = nil
files["save.json"] = Json.encode({
  version = 5,
  story = {
    active = true,
    chapterId = "cripta",
    depth = 4,
    characterId = "mar",
    checkpoint = {
      seed = 9,
      depth = 4,
      dungeonId = "cripta",
      characterId = "mar",
      playerLevel = 2,
      hp = 60,
      xp = 0,
      xpToNext = 30,
      mana = 50,
      manaMax = 100,
      timeLeft = 200,
      stats = { damage = 15, maxHp = 100, speed = 150, attackRate = 2.5 },
    },
  },
})
Save.load()
assert(Save.data.version == 7, "la migración v5 debe usar la versión 7")
assert(Save.hasStoryCheckpoint("mar"), "el checkpoint v5 debe migrar a Mar")
assert(Save.getStory("mar").chapterId == "cripta" and Save.getStory("mar").depth == 4,
  "el capítulo y piso v5 deben migrarse")
assert(not Save.hasStoryCheckpoint("amado"), "la migración no debe duplicar el checkpoint")

-- Migración v6: no había registro musical, se precarga el tema de quien
-- ya estaba seleccionado y se conservan ítems y historias por personaje.
files["save.json.tmp"] = nil
files["save.json"] = Json.encode({
  version = 6,
  selectedCharacter = "amado",
  characters = { amado = true, mar = true, amileth = false },
  items = { vampire = true, fantasma = true },
  stories = {
    amado = {
      chapterId = "forja",
      depth = 3,
      characterId = "amado",
    },
  },
})
Save.load()
assert(Save.data.version == 7, "la migración v6 debe usar la versión 7")
assert(Save.isSongDiscovered("amado", "amado_menu"), "Amado conserva su tema")
assert(Save.isSongDiscovered("mar", "mar_menu"), "Mar también tenía tema propio")
assert(not Save.isSongDiscovered("amileth", "amileth_menu"),
  "no se inventa música de personajes bloqueados")
assert(Save.isItemDiscovered("vampire"), "los ítems v6 deben migrarse")
assert(not Save.isItemDiscovered("fantasma"), "los ítems inválidos se descartan")
assert(Save.getStory("amado").chapterId == "forja", "las historias v6 se conservan")

-- Reiniciar borra monedas, mejoras, personajes y vuelve a los ajustes base.
Save.data.coins = 99
assert(Save.reset(), "el reinicio debe devolver los datos")
assert(Save.data.coins == 0, "el reinicio debe borrar las monedas")
assert(Save.data.bestLevel == 0, "el reinicio debe borrar el récord")
assert(Save.data.settings.musicVolume == 0.6, "el reinicio debe restaurar el audio")
assert(files["save.json"], "el reinicio debe dejar un guardado limpio")
assert(files["save.json.tmp"], "el reinicio debe escribir el respaldo")

print("OK guardado versionado v7, migración, ajustes y reinicio")
