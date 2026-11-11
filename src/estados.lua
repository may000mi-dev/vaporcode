-- estados.lua: máquina de estados simple para menu, run y gameover.
local State = {
  current = nil,
  name = "",
}

local function call(method, ...)
  local mod = State.current
  if mod and mod[method] then
    return mod[method](...)
  end
end

local function moduleFor(name)
  -- Run tiene su propia carpeta por concentrar toda la lógica de juego.
  if name == "run" then
    return require("src.run.run")
  end
  return require("src.estados." .. name)
end

function State.switch(name, ...)
  if State.current and State.current.leave then
    State.current.leave()
  end
  State.name = name
  State.current = moduleFor(name)
  if State.current.enter then
    State.current.enter(...)
  end
end

function State.update(dt) call("update", dt) end
function State.draw() call("draw") end

function State.keypressed(key, isrepeat) call("keypressed", key, isrepeat) end
function State.mousepressed(x, y, button, istouch) call("mousepressed", x, y, button, istouch) end
function State.mousereleased(x, y, button, istouch) call("mousereleased", x, y, button, istouch) end
function State.mousemoved(x, y) call("mousemoved", x, y) end
function State.touchpressed(id, x, y) call("touchpressed", id, x, y) end
function State.touchmoved(id, x, y) call("touchmoved", id, x, y) end
function State.touchreleased(id, x, y) call("touchreleased", id, x, y) end
function State.focus(focused) call("focus", focused) end

function State.drawDebug()
  local current = State.current
  if current and current.drawDebug then
    current.drawDebug()
  end
end

return State
