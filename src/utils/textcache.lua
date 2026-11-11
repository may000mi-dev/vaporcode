-- textcache.lua: textos de HUD sin alocar strings cada frame.
-- Regenera string.format solo cuando cambian los argumentos; los frames
-- sin cambios devuelven el string cacheado (cero alocaciones).
-- Reglas de uso: la clave y el formato deben ser literales constantes por
-- sitio de llamada y los argumentos no pueden ser nil; una clave distinta
-- por texto dibujado (claves dinámicas derrotarían la caché).
local TextCache = {}
local entries = {}

TextCache.hits = 0
TextCache.misses = 0

function TextCache.format(key, fmt, ...)
  local entry = entries[key]
  local count = select("#", ...)
  if entry ~= nil and entry.fmt == fmt and entry.count == count then
    local equal = true
    for i = 1, count do
      if select(i, ...) ~= entry.args[i] then
        equal = false
        break
      end
    end
    if equal then
      TextCache.hits = TextCache.hits + 1
      return entry.text
    end
  end

  entry = {
    fmt = fmt,
    count = count,
    args = { ... },
    text = string.format(fmt, ...),
  }
  entries[key] = entry
  TextCache.misses = TextCache.misses + 1
  return entry.text
end

function TextCache.reset()
  entries = {}
  TextCache.hits = 0
  TextCache.misses = 0
end

return TextCache
