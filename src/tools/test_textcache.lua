-- test_textcache.lua: la caché de textos regenera solo al cambiar valores.
package.path = "./?.lua;" .. package.path

local TextCache = require("src.utils.textcache")

TextCache.reset()

-- Primer uso: falla la caché y formatea.
assert(TextCache.format("k", "Monedas %d", 10) == "Monedas 10")
assert(TextCache.misses == 1 and TextCache.hits == 0, "el primer uso debe fallar la caché")

-- Mismo valor: reutiliza el string sin formatear de nuevo.
assert(TextCache.format("k", "Monedas %d", 10) == "Monedas 10")
assert(TextCache.hits == 1 and TextCache.misses == 1, "el segundo uso debe acertar")

-- Valor nuevo: regenera.
assert(TextCache.format("k", "Monedas %d", 11) == "Monedas 11")
assert(TextCache.misses == 2, "un valor nuevo debe regenerar")

-- Varios argumentos: cualquier cambio regenera.
assert(TextCache.format("p", "%d / %d", 3, 9) == "3 / 9")
assert(TextCache.format("p", "%d / %d", 3, 9) == "3 / 9")
assert(TextCache.format("p", "%d / %d", 4, 9) == "4 / 9")
assert(TextCache.misses == 4 and TextCache.hits == 2, "cualquier argumento cambia el texto")

-- Cambiar el formato con la misma clave no entrega texto viejo.
assert(TextCache.format("p", "HP %d", 4) == "HP 4")
assert(TextCache.misses == 5, "un formato distinto debe regenerar")

-- Claves distintas no colisionan.
assert(TextCache.format("a", "X %d", 1) == "X 1")
assert(TextCache.format("b", "X %d", 2) == "X 2")
assert(TextCache.format("a", "X %d", 1) == "X 1")

-- reset limpia contadores y entradas.
TextCache.reset()
assert(TextCache.hits == 0 and TextCache.misses == 0)
assert(TextCache.format("k", "Monedas %d", 10) == "Monedas 10")
assert(TextCache.misses == 1, "tras reset el primer uso vuelve a fallar")

print("OK textcache")
