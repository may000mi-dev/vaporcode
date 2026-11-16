-- test_character_select.lua: confirmación global y persistencia al aceptar.
package.path = "./?.lua;" .. package.path

love = {
  filesystem = {
    write = function() return true end,
    remove = function() return true end,
  },
}

local Save = require("src.run.save")
local CharacterSelect = require("src.ui.character_select")

Save.data = {
  selectedCharacter = "amado",
  characters = { amado = true, mar = false, amileth = false },
}

local Select = CharacterSelect.new({
  getZone = function() return "menu" end,
})
local panel = {
  x = 100, y = 20, w = 700, h = 500,
  cardY = 60, cardH = 48, screenW = 960, screenH = 540,
}
Select:layout(panel)

assert(#Select.rects == 3, "deben existir tres tarjetas globales")
Select:request("amado")
assert(Select.confirm == nil, "el personaje actual no debe pedir confirmación")

local mar = Select.rects[2]
assert(Select:pressed(mar.x + 2, mar.y + 2), "la tarjeta de Mar debe responder")
assert(Select.confirm == nil, "un personaje bloqueado no debe pedir confirmación")
assert(Save.getSelectedCharacter() == "amado", "un personaje bloqueado no debe seleccionarse")

Save.data.characters.mar = true
assert(Select:pressed(mar.x + 2, mar.y + 2), "la tarjeta desbloqueada debe responder")
assert(Select.confirm and Select.confirm.id == "mar", "debe abrir la confirmación")

Select:layout(panel)
assert(Select:pressed(
  Select.confirm.cancel.x + 2,
  Select.confirm.cancel.y + 2
), "cancelar debe responder")
assert(Select.confirm == nil, "cancelar debe cerrar el modal")
assert(Save.getSelectedCharacter() == "amado", "cancelar no debe cambiar el personaje")

local changed = nil
Select.onChanged = function(id) changed = id end
Select:request("mar")
Select:layout(panel)
assert(Select:pressed(
  Select.confirm.ok.x + 2,
  Select.confirm.ok.y + 2
), "OK debe responder")
assert(Select.confirm == nil, "aceptar debe cerrar el modal")
assert(Save.getSelectedCharacter() == "mar", "debe persistir el personaje elegido")
assert(changed == "mar", "debe notificar el cambio una sola vez")

Select:request("mar")
assert(Select.confirm == nil, "repetir el personaje actual no debe pedir confirmación")

print("OK selección global de personaje")
