-- fonts.lua: fuentes por defecto de LÖVE, sin assets externos.
local Fonts = {}

function Fonts.load()
  Fonts.title = love.graphics.newFont(30)
  Fonts.subtitle = love.graphics.newFont(15)
  Fonts.body = love.graphics.newFont(14)
  Fonts.button = love.graphics.newFont(16)
  Fonts.small = love.graphics.newFont(11)
end

return Fonts
