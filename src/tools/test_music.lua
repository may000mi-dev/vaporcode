-- test_music.lua: catálogo musical, alias de zona y desbloqueo al escuchar.
package.path = "./?.lua;" .. package.path

local files = {}
love = {
  filesystem = {
    getInfo = function(name)
      return files[name] and { type = "file" } or nil
    end,
    read = function(name) return files[name] end,
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
local Audio = require("src.utils.audio")

Save.load()

assert(#Data.music.tracks == 15, "deben existir 15 pistas únicas")
for _, characterId in ipairs(Data.music.characterOrder) do
  assert(#Data.music.byCharacter[characterId] == 5, "cada personaje debe tener 5 pistas")
end

assert(Data.music.idFor("mar", "forja") == "mar_forja", "índice por personaje/zona")
assert(Data.music.idFor("amado", "config") == "amado_menu", "config comparte el tema de menú")
assert(Data.music.idFor("amado", "sandbox") == "amado_menu", "sandbox comparte el tema de menú")
assert(Data.music.zoneFor("amileth_torre") == "torre", "la zona de la pista debe estar disponible")

local path = Audio.trackFor("forja", "mar")
assert(path == "assets/audio/music/clockwork_siege.mp3", "el bus debe usar la ruta del catálogo")
assert(Audio.trackFor("config", "amado")
  == "assets/audio/music/brass_petals_and_pendulums.mp3", "los alias deben resolver la pista")

assert(not Save.isSongDiscovered("mar", "mar_forja"), "Mar aún no ha escuchado la Forja")
Save.unlockCharacter("mar")
Audio.playZone("forja", "mar")
assert(Save.isSongDiscovered("mar", "mar_forja"),
  "escuchar una zona debe desbloquear su canción")
assert(Audio.currentZone == "forja" and Audio.currentCharacterId == "mar",
  "el bus debe recordar la zona y el personaje")
assert(Save.songCount("mar") >= 2, "el tema de menú y la Forja deben contarse")

Audio.playZone("menu", "amado")
assert(Audio.currentZone == "menu" and Audio.currentCharacterId == "amado",
  "volver al menú debe restaurar el tema global")

print("OK catálogo musical, alias y desbloqueo por escucha")
