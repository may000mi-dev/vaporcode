-- conf.lua: configuración de LÖVE 11.5 para el prototipo.
-- Se fija la versión para evitar diferencias entre Termux, Android y laptop.
function love.conf(t)
  -- Identidad propia para no compartir guardado con versiones anteriores.
  t.identity = "vaporcode"
  t.version = "11.5"
  t.console = false

  t.window.title = "VaporCode - May000mi"
  t.window.width = 960
  t.window.height = 540
  t.window.resizable = true
  t.window.vsync = 1
  t.window.msaa = 0
  t.window.usedpiscale = true

  -- Solo los módulos necesarios: menos memoria en el teléfono.
  t.modules.joystick = false
  t.modules.physics = false
  t.modules.video = false
  t.modules.touch = true
end
