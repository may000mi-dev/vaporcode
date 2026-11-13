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

-- Reiniciar borra monedas, mejoras, personajes y vuelve a los ajustes base.
Save.data.coins = 99
assert(Save.reset(), "el reinicio debe devolver los datos")
assert(Save.data.coins == 0, "el reinicio debe borrar las monedas")
assert(Save.data.bestLevel == 0, "el reinicio debe borrar el récord")
assert(Save.data.settings.musicVolume == 0.6, "el reinicio debe restaurar el audio")
assert(files["save.json"], "el reinicio debe dejar un guardado limpio")
assert(files["save.json.tmp"], "el reinicio debe escribir el respaldo")

print("OK guardado versionado, ajustes y reinicio")
