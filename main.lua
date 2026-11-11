-- main.lua: arranque y puente entre LÖVE y la máquina de estados.
local Screen = require("src.utils.screen")
local State = require("src.estados")
local Save = require("src.run.save")
local Fonts = require("src.utils.fonts")
local Debug = require("src.utils.debug")

function love.load()
  love.graphics.setDefaultFilter("nearest", "nearest")
  love.graphics.setBackgroundColor(0.04, 0.05, 0.07)

  Fonts.load()
  Screen.resize(love.graphics.getDimensions())
  Save.load()
  State.switch("menu")
end

function love.resize(w, h)
  Screen.resize(w, h)
end

function love.update(dt)
  -- Evita saltos grandes al recuperar el foco en Android.
  if dt > 0.1 then dt = 0.1 end
  State.update(dt)
end

function love.draw()
  Screen.push()
  State.draw()
  State.drawDebug()
  Screen.pop()
end

function love.keypressed(key, scancode, isrepeat)
  if key == "f3" and not isrepeat then
    Debug.toggle()
    return
  end
  State.keypressed(key, isrepeat)
end

function love.mousepressed(x, y, button, istouch)
  if istouch then return end
  State.mousepressed(Screen.toVirtualX(x), Screen.toVirtualY(y), button, false)
end

function love.mousereleased(x, y, button, istouch)
  if istouch then return end
  State.mousereleased(Screen.toVirtualX(x), Screen.toVirtualY(y), button, false)
end

function love.mousemoved(x, y, dx, dy, istouch)
  if istouch then return end
  State.mousemoved(Screen.toVirtualX(x), Screen.toVirtualY(y))
end

function love.touchpressed(id, x, y)
  State.touchpressed(id, Screen.toVirtualX(x), Screen.toVirtualY(y))
end

function love.touchmoved(id, x, y)
  State.touchmoved(id, Screen.toVirtualX(x), Screen.toVirtualY(y))
end

function love.touchreleased(id, x, y)
  State.touchreleased(id, Screen.toVirtualX(x), Screen.toVirtualY(y))
end

function love.focus(focused)
  State.focus(focused)
end

function love.quit()
  -- Se conserva el progreso aunque se cierre la ventana.
  if Save.data then
    Save.save()
  end
end
