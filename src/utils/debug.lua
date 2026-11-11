-- debug.lua: interruptor global para la capa de depuración (F3).
local Debug = {
  enabled = false,
}

function Debug.toggle()
  Debug.enabled = not Debug.enabled
end

return Debug
