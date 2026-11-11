-- test_camera.lua: la cámara centra al jugador y calcula su viewport.
package.path = "./?.lua;" .. package.path

love = {
  math = {
    random = function()
      return 0
    end,
  },
}

local Camera = require("src.utils.camera")

Camera.reset(1000, 800)
local left, top, right, bottom = Camera.view()
assert(left == 520 and top == 530, "borde superior izquierdo incorrecto")
assert(right == 1480 and bottom == 1070, "borde inferior derecho incorrecto")

Camera.follow(250, 300)
left, top, right, bottom = Camera.view()
assert(left == -230 and top == 30, "seguimiento horizontal incorrecto")
assert(right == 730 and bottom == 570, "seguimiento vertical incorrecto")

assert(Camera.beginDrag(1, 480, 270), "debe iniciar el arrastre en el centro")
assert(Camera.moveDrag(1, 530, 300), "debe actualizar el arrastre")
assert(Camera.x == 300 and Camera.y == 330, "el arrastre debe desplazar la cámara")
assert(Camera.endDrag(1), "debe terminar el arrastre")
Camera.update(0.1)
assert(Camera.x == 250 and Camera.y == 300, "al soltar debe volver al jugador")

Camera.shake(10, 0.5)
Camera.update(0.1)
assert(Camera.x == 250 and Camera.y == 300, "la vibración no debe alterar la lógica")
assert(Camera.shakeX ~= 0, "la vibración debe desplazar el dibujo")
Camera.update(0.5)
assert(Camera.shakeX == 0 and Camera.shakeY == 0, "la vibración debe terminar")

print("OK cámara centrada, arrastrable y con vibración")
