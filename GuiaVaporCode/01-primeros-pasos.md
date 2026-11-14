# 01 · Primeros pasos

## Lo que necesitas saber antes de tocar código

VaporCode es un juego de **LÖVE 11.5** escrito en **Lua**. No hay un editor
gráfico, un motor visual ni assets importados: el proyecto son archivos de texto.
Eso es una ventaja en el teléfono, porque puedes editar y ejecutar sin herramientas
pesadas.

- El teléfono es el entorno principal de **prototipo y prueba táctil**.
- La computadora es el entorno de **pulido, pruebas más cómodas y builds finales**.
- La versión de referencia es **LÖVE 11.5**. No uses LÖVE 12.
- Los comentarios del código están en **español**; los identificadores en **inglés**.

## Instalación en Android con Termux

Instala una sola vez:

```bash
pkg update && pkg upgrade -y
pkg install x11-repo
pkg install love termux-x11-nightly git zip unzip lua54 luajit entr
```

También necesitas la aplicación **Termux:X11**. Usa la variante `sharedUid` de sus
releases junto con la build de Termux de GitHub o F-Droid para mejor rendimiento.

`termux-setup-storage` solo es necesario si quieres compartir archivos fuera del
almacenamiento privado de Termux:

```bash
termux-setup-storage
```

## Instalación en escritorio

En Linux, macOS o Windows:

1. Instala **LÖVE 11.5** desde el sitio oficial.
2. Instala **Lua 5.4** o **LuaJIT** para los tests.
3. Asegúrate de tener `zip`, `unzip` y `luac` disponibles.
4. Clona el repositorio y ejecuta `love .` desde la carpeta del proyecto.

En Debian/Ubuntu suele bastar con:

```bash
sudo apt install lua5.4 love zip unzip
```

> La versión exacta de LÖVE importa. Si `love --version` no dice 11.5, corrige
> eso antes de reportar un bug visual o de física.

## Ejecutar el juego

Desde la raíz del proyecto (`vaporcode/`):

```bash
love .
```

En Termux con X11:

```bash
termux-x11 :0 >/dev/null 2>&1 &
export DISPLAY=:0
cd ~/juegos/vaporcode
love .
```

Para reiniciar automáticamente al guardar un archivo `.lua`:

```bash
cd ~/juegos/vaporcode
find . -name '*.lua' | entr -r love .
```

## Probar en el teléfono con toque real

Termux:X11 sirve para desarrollar, pero la prueba definitiva es **LÖVE for Android
11.5**:

```bash
cd ~/juegos/vaporcode
sh src/tools/build.sh
termux-share build/vaporcode.love
```

Si existe `/sdcard/Download`, `build.sh` genera el paquete ahí. Abre el archivo
compartido con **LÖVE Loader** o **LÖVE for Android 11.5**.

En Android 11 o superior no intentes abrir el `.love` con `file://` ni con
`am start`: usa `termux-share`.

## Comandos que vas a usar todo el tiempo

| Comando | Cuándo usarlo |
|---|---|
| `love .` | Ejecutar el juego. |
| `sh src/tools/test_all.sh` | Correr todas las pruebas. |
| `sh src/tools/build.sh` | Sintaxis + tests + empaquetado `.love`. |
| `luac -p archivo.lua` | Verificar sintaxis de un archivo suelto. |
| `find . -name '*.lua' \| entr -r love .` | Recargar al editar. |

## Primer recorrido del código

Lee en este orden:

1. `conf.lua`: configuración de LÖVE, identidad y módulos activos.
2. `main.lua`: callbacks de LÖVE y puente hacia la máquina de estados.
3. `src/estados.lua`: cómo se cambia de menú a partida y a game over.
4. `src/estados/menu.lua`: ejemplo completo de una pantalla.
5. `src/run/run.lua`: orquestador de la partida.
6. `src/run/data.lua`: compositor de datos.
7. `src/data/`: contenido y balance.
8. `src/run/`: sistemas de la partida.
9. `src/utils/`: piezas compartidas.
10. `src/tools/`: tests y empaquetado.

No intentes entender `src/run/run.lua` completo de una sola vez. Es un orquestador:
la lógica real vive en módulos hermanos como `spawner.lua`, `combat.lua`,
`floors.lua` o `inventory.lua`.

## Tu primer cambio seguro

Antes de agregar contenido, haz un cambio pequeño para confirmar que tu entorno
funciona:

1. Abre `src/data/balance.lua`.
2. Cambia `Balance.floor.timeLimit` de `300` a `290`.
3. Ejecuta `love .` y mira el temporizador del HUD.
4. Ejecuta `sh src/tools/test_all.sh`.
5. Revisa que todo siga en verde.

Si eso funciona, ya puedes seguir con `02-arquitectura-y-flujo.md`.

## Qué NO hacer en este proyecto

- No agregues dependencias externas sin justificarlo.
- No uses `love.graphics.newImage` por frame.
- No leas archivos de datos en caliente desde `love.update` o `love.draw`.
- No uses `os.clock()` para lógica de juego; usa el `dt` que recibe `update`.
- No metas imágenes, audio ni fuentes enormes.
- No cambies `conf.lua` sin revisar el impacto en guardado y rendimiento.
- No edites `save.json` a mano como método normal de trabajo.
- No pruebes builds de Android en el teléfono: eso se hace en laptop o CI.

## Cómo pedir ayuda

Cuando algo falle, comparte:

1. El comando exacto que ejecutaste.
2. El mensaje de error completo.
3. El archivo y la línea que menciona el error.
4. Qué esperabas que pasara y qué pasó.
5. Si ocurre solo en el teléfono, solo en escritorio o en ambos.

Con eso cualquiera del equipo puede reproducirlo y ayudarte rápido.
