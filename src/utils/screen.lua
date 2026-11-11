-- screen.lua: resolución virtual adaptable.
-- En pantallas más anchas que 16:9 se conserva la altura de diseño (540) y
-- crece el ancho visible: el área de juego llena la pantalla sin barras.
-- En pantallas más angostas (tabletas) se mantiene 960x540 con letterboxing.
local Screen = {
  designWidth = 960,
  designHeight = 540,
  width = 960,
  height = 540,
  scale = 1,
  ox = 0,
  oy = 0,
}

function Screen.resize(windowWidth, windowHeight)
  if windowWidth <= 0 or windowHeight <= 0 then return end

  local aspect = windowWidth / windowHeight
  local designAspect = Screen.designWidth / Screen.designHeight

  if aspect >= designAspect then
    Screen.height = Screen.designHeight
    Screen.width = Screen.designHeight * aspect
    Screen.scale = windowHeight / Screen.designHeight
  else
    Screen.width = Screen.designWidth
    Screen.height = Screen.designHeight
    Screen.scale = math.min(
      windowWidth / Screen.width,
      windowHeight / Screen.height
    )
  end

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
