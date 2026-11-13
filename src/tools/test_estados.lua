-- test_estados.lua: el gestor enruta menu/gameover y la carpeta run correctamente.
package.path = "./?.lua;" .. package.path

local entered = {}

package.preload["src.estados.menu"] = function()
  return { enter = function() entered.menu = true end }
end
package.preload["src.estados.gameover"] = function()
  return { enter = function() entered.gameover = true end }
end
package.preload["src.estados.config"] = function()
  return { enter = function() entered.config = true end }
end
package.preload["src.estados.historia"] = function()
  return { enter = function() entered.historia = true end }
end
package.preload["src.run.run"] = function()
  return { enter = function() entered.run = true end }
end

local State = require("src.estados")

State.switch("menu")
assert(State.name == "menu" and entered.menu, "debe cargar el menú")

State.switch("run", "cripta")
assert(State.name == "run" and entered.run, "debe cargar src/run/run.lua")

State.switch("gameover")
assert(State.name == "gameover" and entered.gameover, "debe cargar gameover")

State.switch("config")
assert(State.name == "config" and entered.config, "debe cargar configuración")

State.switch("historia")
assert(State.name == "historia" and entered.historia, "debe cargar historia")

print("OK ruteo de estados")
