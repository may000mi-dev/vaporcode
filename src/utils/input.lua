-- input.lua: acciones pendientes que el estado de partida consume cada frame.
local Input = {
  moveX = 0,
  moveY = 0,
  abilities = {},
}

function Input.reset()
  Input.moveX = 0
  Input.moveY = 0
  for i = 1, 4 do
    Input.abilities[i] = false
  end
end

-- Lee WASD/flechas para poder probar también con teclado en la laptop.
function Input.pollKeyboard()
  if not love.keyboard then
    Input.moveX = 0
    Input.moveY = 0
    return
  end

  local x, y = 0, 0
  if love.keyboard.isDown("a", "left") then x = x - 1 end
  if love.keyboard.isDown("d", "right") then x = x + 1 end
  if love.keyboard.isDown("w", "up") then y = y - 1 end
  if love.keyboard.isDown("s", "down") then y = y + 1 end
  Input.moveX = x
  Input.moveY = y
end

function Input.triggerAbility(index)
  Input.abilities[index] = true
end

function Input.consumeAbility(index)
  if Input.abilities[index] then
    Input.abilities[index] = false
    return true
  end
  return false
end

function Input.consumeMove()
  local x = Input.moveX
  local y = Input.moveY
  Input.moveX = 0
  Input.moveY = 0
  return x, y
end

Input.reset()

return Input
