-- screen.lua: resolución virtual 960x540 con escalado y letterboxing.
local Screen = {
  width = 960,
  height = 540,
  scale = 1,
  ox = 0,
  oy = 0,
}

function Screen.resize(windowWidth, windowHeight)
  if windowWidth <= 0 or windowHeight <= 0 then return end
  Screen.scale = math.min(windowWidth / Screen.width, windowHeight / Screen.height)
  Screen.ox = (windowWidth - Screen.width * Screen.scale) * 0.5
  Screen.oy = (windowHeight - Screen.height * Screen.scale) * 0.5
end

function Screen.toVirtualX(x)
  return (x - Screen.ox) / Screen.scale
end

function Screen.toVirtualY(y)
  return (y - Screen.oy) / Screen.scale
end

function Screen.push()
  love.graphics.push()
  love.graphics.translate(Screen.ox, Screen.oy)
  love.graphics.scale(Screen.scale)
  love.graphics.setScissor(
    Screen.ox,
    Screen.oy,
    Screen.width * Screen.scale,
    Screen.height * Screen.scale
  )
end

function Screen.pop()
  love.graphics.setScissor()
  love.graphics.pop()
end

return Screen
