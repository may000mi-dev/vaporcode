# 08 · Tests y empaquetado

## Herramientas necesarias

En Termux:

```bash
pkg install lua54 luajit zip unzip love
```

No necesitas LÖVE para ejecutar los tests: son Lua puro. LÖVE solo se usa para
jugar y probar gráficos de verdad.

## Ejecutar todos los tests

```bash
sh src/tools/test_all.sh
```

El script:

1. Busca `lua`; si no existe, usa `luajit`.
2. Ejecuta cada archivo `src/tools/test_*.lua` en un proceso separado.
3. Se detiene en el primer fallo (`set -eu`).
4. Termina con `Tests OK`.

Puedes forzar el intérprete:

```bash
LUA_BIN=luajit sh src/tools/test_all.sh
```

No hay registro central: **si el archivo se llama `test_*.lua`, se ejecuta solo**.
No agregues tests fuera de `src/tools/`.

## Qué cubren los tests

| Archivo | Cubre |
|---|---|
| `test_abilities.lua` | Habilidades, maná, apuntado y efectos. |
| `test_audio.lua` | Volúmenes y audio simulado. |
| `test_autoshot.lua` | Ataque automático y selección de objetivo. |
| `test_camera.lua` | Seguimiento y arrastre de cámara. |
| `test_chain.lua` | Cadena de Amileth. |
| `test_characters.lua` | Personajes, pasivas y estadísticas. |
| `test_data.lua` | Tipos de enemigos y referencias de mazmorras. |
| `test_dungeon.lua` | Generación y línea de visión. |
| `test_estados.lua` | Ruteo de la máquina de estados. |
| `test_features.lua` | Válvulas y cofres. |
| `test_floor.lua` | Instantánea y restauración de piso. |
| `test_items.lua` | Botín, pasivas, desbloqueos, resonancias y mascotas. |
| `test_layout.lua` | Layout de pantallas y paneles. |
| `test_run_floor.lua` | Piso, reintento, dibujo y tiempo agotado. |
| `test_run_state.lua` | Aislamiento entre runs y guardado al pausar. |
| `test_sandbox.lua` | Sala de pruebas aislada del guardado. |
| `test_save.lua` | Guardado, respaldo, migración y ajustes. |
| `test_storage.lua` | Activos, guardados, intercambio y alquimia. |
| `test_story.lua` | Campaña, escenas, portales y checkpoints. |
| `test_story_run.lua` | Run de Historia, checkpoints, portales y final. |
| `test_targeting.lua` | Selección de objetivos. |
| `test_textcache.lua` | Caché de textos sin allocaciones. |
| `test_ui_smoke.lua` | Dibujo de pantallas con gráficos simulados. |
| `test_v6.lua` | Roles, élites, hazards y jefes. |

## Cómo se escribe un test

Patrón mínimo:

```lua
-- test_mi_feature.lua: verifica una regla pequeña y aislada.
package.path = "./?.lua;" .. package.path

-- Stub mínimo de love; solo lo que el módulo toca.
love = {
  filesystem = {
    getInfo = function() return nil end,
    read = function() return nil end,
    write = function() return true end,
    remove = function() return true end,
  },
}

local MiModulo = require("src.run.mi_modulo")

assert(MiModulo.suma(2, 3) == 5, "debe sumar enteros")
assert(MiModulo.suma(-1, 1) == 0, "debe sumar negativos")

print("OK mi feature")
```

Reglas:

- Un archivo por preocupación.
- `assert(condición, "mensaje claro")`.
- Nada de red, archivos reales, `sleep` ni dependencias externas.
- Simula `love` con tablas y `noop`.
- Usa RNG determinista si el test genera contenido.
- Termina con `print("OK ...")`.
- No dependas del orden de otros tests: cada uno corre en un proceso distinto.
- Si pruebas un módulo con estado global, usa `package.loaded["src.run.save"] = nil`
  antes de volver a requerirlo.
- El test debe ser rápido: milisegundos, no segundos.

### Simular `love`

`test_ui_smoke.lua` es el ejemplo más completo: simula gráficos, fuentes,
sistema, archivos y matemáticas. No valida píxeles; detecta llamadas a campos
`nil` y errores de dibujo.

Si tu módulo usa una función nueva de `love`, agrégala al stub. Si no, el test
fallará con “attempt to call a nil value” aunque el juego real funcione.

### Probar guardado sin tocar el guardado real

Los tests de guardado reemplazan `love.filesystem` por un sistema en memoria:

```lua
local files = {}
love = {
  filesystem = {
    getInfo = function(name) return files[name] and { type = "file" } or nil end,
    read = function(name) return files[name] end,
    write = function(name, content) files[name] = content return true end,
    remove = function(name) files[name] = nil return true end,
  },
}
```

Así puedes probar corrupción, respaldo y migraciones sin riesgo.

## Validar sintaxis

```bash
luac -p main.lua
luac -p src/run/run.lua
```

O todos los archivos:

```bash
find . -name '*.lua' -print0 | xargs -0 -n1 luac -p
```

`luac -p` solo revisa sintaxis; no ejecuta el código.

## Empaquetar para Android

```bash
sh src/tools/build.sh
```

El script hace cuatro pasos:

1. Verifica la sintaxis de todos los `.lua`.
2. Ejecuta todos los tests.
3. Empaqueta `conf.lua`, `main.lua` y `src/` en un `.love`.
4. Verifica el ZIP con `unzip -t`.

Salida por defecto:

- `/sdcard/Download/vaporcode.love` si `/sdcard/Download` existe.
- `build/vaporcode.love` si no existe.

Puedes elegir otra carpeta:

```bash
sh src/tools/build.sh /sdcard/Download
```

Al terminar verás:

```text
Paquete listo: /sdcard/Download/vaporcode.love
```

### Qué incluye el paquete

```text
vaporcode.love
├── conf.lua
├── main.lua
└── src/
    ├── data/
    ├── estados/
    ├── run/
    └── utils/
```

`src/tools/` queda fuera a propósito: los tests no se distribuyen. `docs/` y
`README.md` tampoco se incluyen.

### Si agregas assets

El comando actual es:

```bash
zip -r -D "$OUT" conf.lua main.lua src -x 'src/tools/*'
```

Si agregas `assets/`, tendrás que incluirlo:

```bash
zip -r -D "$OUT" conf.lua main.lua src assets -x 'src/tools/*'
```

Si no lo haces, el juego funcionará en Termux pero fallará en Android al intentar
cargar el archivo. Prueba siempre el `.love` empaquetado, no solo la carpeta.

## Probar el paquete en Android

```bash
termux-share /sdcard/Download/vaporcode.love
```

Abre el archivo con **LÖVE for Android 11.5** o **LÖVE Loader**. En Android 11+
no uses `am start` con `file://`; está bloqueado.

Checklist táctil:

- [ ] El joystick aparece donde tocas.
- [ ] A1/A2 apuntan arrastrando.
- [ ] A3/A4 se activan al toque.
- [ ] Pausa y mochila responden.
- [ ] La app se pausa al ir a segundo plano.
- [ ] El progreso sigue ahí al volver.
- [ ] Se ve bien en 16:9 y 20:9.
- [ ] No hay tirones ni sonidos cortados.

## Probar el `.love` en escritorio

```bash
love build/vaporcode.love
```

Esto confirma que el ZIP está completo y que no falta ningún archivo. Es distinto
de `love .`: `love .` usa la carpeta completa, incluidos archivos que quizá no
empaquetaste.

También puedes inspeccionar el ZIP:

```bash
unzip -l build/vaporcode.love
```

## Errores comunes

| Error | Causa | Solución |
|---|---|---|
| `module 'src...' not found` | Ejecutaste el test fuera de la raíz | Correr desde la raíz |
| `attempt to index nil (love...)` | Falta un stub en el test | Agregar la función usada |
| `luac: command not found` | Falta el compilador | `pkg install lua54` |
| `zip: command not found` | Falta zip | `pkg install zip` |
| El test pasa pero el juego falla | Los tests simulan LÖVE | Ejecutar `love .` |
| Android no abre el `.love` | Se compartió con `file://` | Usar `termux-share` |
| Faltan assets en Android | No se agregaron al ZIP | Actualizar `build.sh` |
| El guardado real cambió al probar | Un test tocó archivos reales | Usar `love.filesystem` en memoria |
| Un test deja estado para otro | Los tests corren en procesos separados | Revisar estado global dentro del mismo archivo |

## Checklist antes de commitear

- [ ] `sh src/tools/test_all.sh` termina en `Tests OK`.
- [ ] `sh src/tools/build.sh` termina con “Paquete listo”.
- [ ] `love .` arranca sin errores en consola.
- [ ] `love build/vaporcode.love` arranca.
- [ ] Se probó el `.love` en el teléfono con toque.
- [ ] No se agregaron archivos pesados ni secretos.
- [ ] La documentación se actualizó si cambió el flujo.
