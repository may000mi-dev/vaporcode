# VaporCode

Roguelite de acción steampunk con toques de ritmo, en LÖVE 11.5. Vista cenital 2D,
ataques automáticos y controles táctiles pensados para jugar en el teléfono con
uno o dos pulgares. Prototipo para Android/Termux primero; escritorio después.

- **Protagonista:** Amado, con Mar y Amileth desbloqueables.
- **Run:** pisos generados con semilla, jefe cada 3 pisos, tres mazmorras con
  canción y BPM propios.
- **Meta-progresión:** monedas, mejoras permanentes, personajes y mazmorras
  desbloqueables que sobreviven entre partidas.

## Estado

MVP jugable (V6). Incluye combate automático, tres personajes, cinco habilidades,
enemigos por rol (torreta, mortero, invocador, trampero, sanador, cazador de maná),
élites, hazards, cuatro jefes con fases, ítems pasivos, mascotas, mochila, tienda,
alquimia y guardado versionado.

## Ejecutar

Termux con Termux:X11 (la primera vez: `pkg install x11-repo && pkg install love termux-x11-nightly`):

```bash
termux-x11 :0 >/dev/null 2>&1 &
export DISPLAY=:0
love .
```

Escritorio: `love .` con LÖVE 11.5 (no usar LÖVE 12).

## Probar en Android (toque real)

```bash
sh src/tools/build.sh              # sintaxis + tests + empaquetado
termux-share build/vaporcode.love  # abrir con LÖVE for Android 11.5
```

`build.sh` escribe en `build/vaporcode.love` (o en `/sdcard/Download` si existe)
y excluye `src/tools/` del paquete. En Android 11+ hay que compartir el `.love`;
`file://` no funciona.

## Tests

```bash
sh src/tools/test_all.sh
```

Suites en Lua puro (sin LÖVE): datos, mazmorras y línea de visión, personajes,
habilidades, botín, estados, piso/reintento, cámara y caché de textos.

## Controles

| Acción | Teclado | Táctil |
|---|---|---|
| Mover | WASD / flechas | joystick flotante izquierdo |
| Mirar | — | arrastra la zona central |
| Habilidad A1 / A2 | R / F | botones derechos |
| Escudo / Turbo | E / T | botones derechos |
| Mochila | B | botón MOCHILA |
| Tienda | V | botón TIENDA |
| Pausa | P | botón PAUSA |
| Silenciar | M | — |
| Depuración | F3 | — |

Dentro de la mochila: `1`–`5` selecciona un activo, `Tab` recorre los 20 espacios,
`Enter` activa el guardado o guarda el activo, `Q`/`W` asignan una habilidad
guardada a A1/A2, `X` tira el ítem y `Escape` cierra (o cancela un intercambio).

## Estructura

```text
conf.lua / main.lua        -- configuración y arranque
src/
├── data/                  -- definiciones estáticas por dominio
│   ├── abilities.lua      -- habilidades activas, maná, set intercambiable
│   ├── balance.lua        -- números: jugador, economía, piso, trampas, ritmo
│   ├── bosses.lua         -- jefes y patrones de pelea
│   ├── characters.lua     -- personajes, marca de Amado, desbloqueos
│   ├── dungeons.lua       -- mazmorras, índice por id, cadencia de jefes
│   ├── enemies.lua        -- tipos, élites, hazards, IA, aparición
│   ├── items.lua          -- ítems, mascotas, espacios y reglas de tienda
│   └── upgrades.lua       -- mejoras permanentes
├── estados/               -- menú, pausa, game over
├── run/                   -- partida; run.lua orquesta y monta los sistemas
├── tools/                 -- suites de test y empaquetado
└── utils/                 -- input, cámara, joystick, JSON, textcache
docs/                      -- notas de diseño
```

`src/run/data.lua` es solo el compositor: expone la API plana `Data.*` que usa el
juego, así que los datos se pueden mover entre archivos sin tocar el resto.

## Guardado

JSON en `love.filesystem` (identidad `vaporcode`, archivo `save.json`), versión 2.
Al cargar se normaliza y se repara: valores inválidos caen a los predeterminados y
la cripta y Amado siempre quedan desbloqueados.

## Documentación

- `docs/design.md`: reglas de diseño, personajes, roles de enemigo, élites,
  hazards, jefes, ítems y meta-progresión.
