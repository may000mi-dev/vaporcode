# VaporCode — notas de diseño

Documento de referencia del prototipo. Todo lo aquí descrito vive en `src/data/`
como tablas; para balancear no hace falta tocar la lógica.

## Concepto y loop

Roguelite de acción con ataques automáticos y ventanas de ritmo. El loop de una run:

1. Entrar a un piso generado con semilla (tamaño, salas y contenido varían).
2. Moverse con joystick; el ataque básico dispara solo al enemigo más cercano.
3. Limpiar el piso antes de que se agote el tiempo (300 s, aviso a los 60 s).
4. La salida se abre al morir el último enemigo; tocarla sube al siguiente piso.
5. Cada 3 pisos hay jefe de mazmorra. Al morir se puede reintentar el piso exacto
   (instantánea) o volver al menú; monedas y mejoras permanentes se conservan.
6. **Modo Historia** encadena Cripta, Forja, Catedral y Torre con escenas,
   checkpoints por piso y portales al cerrar cada capítulo. **Modo Infinito**
   permite elegir personaje y cualquier mazmorra ya desbloqueada.
7. El **Bestiario** revela retrato, nombre y habilidades de cada enemigo visto.
8. La pantalla de **Personajes** concentra estadísticas, pasivas, historia y
   mejoras permanentes por personaje.

La cámara sigue al jugador con margen de arrastre; el área de juego es mayor que
la pantalla y se explora moviéndose.

## Personajes

| Personaje | Básico | Rasgo | Velocidad | Cadencia |
|---|---|---|---|---|
| Amado | a distancia (520) | marca hasta 3 enemigos: +15% daño, −10% velocidad por 2 s | 1.00x | 2.7/s |
| Mar | cuerpo a cuerpo giratorio | dash al usar habilidades en movimiento (invulnerable 0.5 s) | 1.18x | 2.2/s |
| Amileth | cadena (2 saltos, 220, caída 50%, requiere LOS) | escudo del 10% que se repara fuera de combate | 1.06x | 2.4/s |

Mar y Amileth se desbloquean con ítems de personaje, que solo aparecen en cofres
ocultos en paredes frágiles (35% por cofre mientras falten personajes).

Cada personaje tiene su propia perspectiva de la Historia, sus mejoras
permanentes, su contador de resonancias y su estado de campaña completada:

- **Amado:** alerta sobre la sustancia negra en una junta cuando secuestran a su
  familia; reprograma espectros de vapor con el parche de empatía.
- **Mar:** llega durante el secuestro, ataca sin prudencia y cae junto con
  Amileth; toma dos cuchillos y el prototipo, que se adapta a ella.
- **Amileth:** Amado la esconde y le deja una versión del prototipo que se
  combina con su libro de dibujos; ella sigue a los enemigos para rescatar a su
  familia.

## Habilidades y maná

Maná compartido: 100 máximo, +2.5/s; tras 5 s sin gastar se regenera al triple.

| Habilidad | Ranura | Enfriamiento | Maná | Efecto |
|---|---|---|---|---|
| Resonancia | A1 o A2 | 6 s | 28 | onda de área (120) a 1.6x; se mantiene y arrastra para lanzarla |
| Escudo | E (fija) | 10 s | 35 | 4 s de escudo y cura 20% |
| Turbo | T (fija) | 12 s | 30 | 5 s: +50% velocidad y +60% cadencia |
| Flecha de luz | A1 o A2 | 5 s | 22 | rayo perforante 2.8x, alcance 430 |
| Intercambio de sombra | A1 o A2 | 8 s | 30 | salto con señuelo que explota (radio 90) |

A1 y A2 se asignan desde la mochila (ítems `*_skill`). El Tambor abarata
habilidades a ritmo y reduce enfriamientos.

## Ritmo

- Cada mazmorra tiene canción y BPM (104, 124 y 138).
- Ventana de acierto: ±120 ms alrededor del pulso (visible ±120 ms).
- Acierto perfecto: ×2 daño (Resonancia y básicos a ritmo).
- La racha rítmica se muestra en la capa de depuración (F3).

## Mazmorras

| Mazmorra | Desbloqueo | BPM | Enemigos | Jefe |
|---|---|---|---|---|
| Cripta de latón | inicial | 104 | autómata, caldera, artillero, maquinista, peste | Patriarca de Huesos y Cobre |
| Forja de vapor | piso 2 | 124 | sabueso, centinela, saboteador | Forja Viviente |
| Catedral de engranajes | piso 4 | 138 | espectro, engranaje, clérigo, inquisidor | Inquisidor del Tiempo |
| Torre del Tiempo Detenido | 3 historias completadas | 150 | todos los regulares | Órgano del Tiempo |

Los desbloqueos se guardan al alcanzar el piso indicado. `bossEvery = 3`; la Torre
es la excepción narrativa: ocupa los pisos 10–12 y solo tiene jefe en el 12.
En Modo Infinito la Torre se habilita al completar la Historia con Amado, Mar y
Amileth, y puede invocar a todos los tipos de enemigo del juego.

## Enemigos por rol

Los roles viven en `enemyTypes[*].role`; la IA decide el movimiento y el ataque.

- **chaser** (autómata, caldera, sabueso, engranaje): persigue en línea recta.
- **turret** (centinela): inmóvil; dispara cada 3 s a 520 de alcance.
- **ranged** (espectro): mantiene 190 de distancia y dispara.
- **mortar** (artillero): mantiene 210, retrocede a 145; lanza proyectiles en área
  con retraso (radio 44, 7 de daño).
- **summoner** (maquinista): huye a 190 e invoca autómatas rotos (máximo 4).
- **trapper** (saboteador): flanquea a 118 y deja minas.
- **blight** (peste): proyectil y contacto que ralentizan (−55% por 1.5 s).
- **healer** (clérigo): cura 15% a aliados en radio 190; mantiene distancia.
- **mana_hunter** (inquisidor): drena 12% de maná por impacto y sella habilidades
  2 s.

El autómata roto (`broken_automaton`) es invocado: 1 HP, no suelta botín ni puede
ser élite.

## Élites

15% de probabilidad por enemigo elegible. Un élite añade un modificador:

- **volátil**: explota al morir (radio 90, 1.5x de daño).
- **blindado**: escudo de 50.
- **espectral**: se vuelve intocable 0.5 s cada 2 s.

## Hazards del piso

- **Fuego**: daño por tick cada 0.5 s.
- **Minas**: se arman en 0.8 s, viven 60 s, detonan a 24 y pegan 18 en radio 74.
- **Rayos**: daño por tick cada 0.45 s.

## Elementos interactivos

- **Válvulas de vapor**: se activan al pisarlas o dispararles; chorro de 78 de
  radio, 4 de daño por tick, 3.2 s de enfriamiento.
- **Paredes frágiles**: 2 golpes de Resonancia o 1 de Flecha de luz; 55% de soltar
  botín. Pueden esconder cofres.
- **Cofres**: dan XP (12 + 5/piso), monedas (4 + 1/piso) y un ítem; los apilables
  pueden salir dobles (30%) o triples (6%).
- **Cofres ocultos** (en paredes frágiles): 35% de soltar un ítem de personaje si
  queda alguno bloqueado.

## Ítems

Inventario de **5 espacios activos + 15 guardados**. Solo los activos aplican
efectos y se ven en el HUD; los guardados son reserva y materia prima de alquimia.
Los ítems en el suelo duran 7 s (parpadean el último 1.5 s). Las pasivas se
acumulan hasta su máximo global (activos + guardados); mascotas y desbloqueos son
únicos.

- **Colocación:** pasivas y mascotas entran activas si hay hueco; si no, quedan
  guardadas. Las habilidades siempre caen en guardados.
- **Activar un guardado:** con hueco libre sube a activos; con los 5 activos llenos
  se pide elegir uno para **intercambiarlo** (nada se pierde).
- **Guardar un activo:** libera su efecto y lo manda a la reserva; es el paso previo
  para alquimia o para hacer espacio.
- **Asignar habilidad:** un ítem `*_skill` guardado se asigna a A1/A2 y se consume.

- **Pasivas apilables (máx 5):** Veneno (daño en tiempo), Vampiro (roba vida con el
  básico), Hada (recupera maná con el básico), Pólvora (explosión con aturdimiento;
  los jefes son inmunes).
- **Pasivas únicas:** Tambor (ritmo: menos costo y enfriamiento), Flauta (el
  siguiente básico invoca un tornado).
- **Habilidades de ítem:** Resonancia, Flecha de luz, Intercambio de sombra.
- **Mascotas:** Perro (muerde al ritmo, inmune al cuerpo a cuerpo), Gato (los
  enemigos lo ignoran), Dragón (aliento potente, débil al cuerpo a cuerpo), Hámster
  (recoge ítems; al pulso fuerte puede meterse en una pared frágil y romperla desde
  dentro tras 4 beats, con 10 s de recarga). Si una mascota queda atrapada y se aleja
  más de 360 px del jugador, reaparece a su lado.
- **Personajes:** Mar y Amileth.
- **Resonancias de personaje:** cada jefe deja la resonancia del personaje con el
  que se juega. No ocupa inventario: al recogerla suma un punto permanente para
  esa ficha. En la Sala de pruebas no se generan.

### Alquimia

Dos ítems pasivos iguales del mismo nivel **guardados** se combinan y suben a x2,
x3, x4 o x5. Costo: 10, 30, 50 y 150 monedas. El resultado queda guardado y no
aplica efectos hasta activarse.

### Tienda

Se abre durante la partida al alcanzar nivel 15 de personaje y piso 10. Precios
entre 25 y 120 monedas; vende pasivas, mascotas y habilidades de ítem.

## Jefes

| Jefe | Rasgo principal |
|---|---|
| Guardián de la Caldera | cuerpo a cuerpo rápido; 320 HP |
| Patriarca de Huesos y Cobre | invoca autómatas y dispara abanicos; fases en 66%/33% |
| Forja Viviente | zonas de fuego (radio 58) e invoca sabuesos; 500 HP |
| Inquisidor del Tiempo | tamaño del jugador; aura de daño, cono congelante y reubicación si queda bloqueado; 560 HP |
| Órgano del Tiempo | jefe final; invoca espectros y lanza compases de rayos en fases |

Todos los jefes son inmunes al aturdimiento para que la Pólvora o el Perro no
anulen sus patrones de ataque. Al morir sueltan una Resonancia del personaje de la
run, que se gasta en la pantalla de Personajes.

## Modo Historia

Campaña de tres actos con una perspectiva por personaje. Se entra desde el menú
(`H` o `Historia`) y usa las mismas reglas de combate, economía, mejoras y
personajes que el modo Infinito. La melodía, los diálogos y el motivo del
protagonista cambian según el personaje elegido.

| Capítulo | Pisos | Jefes | Salida |
|---|---|---|---|
| Cripta de latón | 1–9 | 3, 6, 9 | portal rojo a la Forja |
| Forja de vapor | 1–9 | 3, 6, 9 | portal rojo a la Catedral |
| Catedral de engranajes | 1–9 | 3, 6, 9 | portal negro a la Torre |
| Torre del Tiempo Detenido | 10–12 | 12 | final de la campaña |

- **Escenas:** `src/data/story.lua` guarda prólogo, intros, cierres y desenlace;
  `src/run/story_ui.lua` las muestra sin assets externos. Se avanzan con toque,
  `Enter` o `Espacio`; `Esc` omite la escena actual.
- **Checkpoint:** al entrar a cada piso se guarda capítulo, profundidad,
  personaje y la instantánea completa. `CONTINUAR HISTORIA` retoma ese piso sin
  repetir la intro ya vista.
- **Derrota:** `REINTENTAR PISO` restaura el checkpoint; el menú conserva la
  campaña para continuar después. La derrota por tiempo se narra como
  desestabilización del núcleo.
- **Final:** el piso 12 abre el desenlace. Al terminarlo se marca la historia de
  ese personaje como completada y se borra el checkpoint, pero se conservan las
  demás historias, mejoras y monedas. `NUEVA HISTORIA` pide confirmación antes de
  reiniciar la campaña activa.
- **Personajes:** se puede jugar con Mar o Amileth solo si ya están desbloqueados.
  Cada uno tiene escenas propias y su final se contabiliza por separado (`x/3`).
- **Torre:** se desbloquea al completar las tres historias y entonces también
  aparece como mazmorra elegible en Modo Infinito.

## Meta-progresión

Persistente en `save.json` (versión 5, normalizado al cargar). Se escribe al
cambiar de piso, al terminar la run, al pausar y al perder el foco; usa
`save.json.tmp` como respaldo para escrituras interrumpidas en Android. También
guarda `settings.musicVolume`, `settings.effectsVolume` (0..1), el estado del
Modo Historia con su checkpoint validado por capítulo y el Bestiario.

| Mejora | Efecto | Base | +Nivel | Máx |
|---|---|---|---|---|
| Filo de vapor | daño | 10 | +4 | 8 |
| Caldera reforzada | vida máxima | 100 | +20 | 8 |
| Botas de presión | velocidad | 150 | +12 | 8 |

Las mejoras son **por personaje** y ya no se compran con monedas. Cada jefe
derrotado suelta una **Resonancia del personaje** de la run; recogerla suma un
punto que se gasta en la pantalla de Personajes para subir una mejora. Al migrar
un guardado v4, los niveles globales se reparten entre Amado, Mar y Amileth.

También persisten monedas, récord de piso, mazmorras desbloqueadas, historias
completadas por personaje, resonancias, personajes desbloqueados, enemigos vistos
y volúmenes de audio.

## Menú, Personajes y Bestiario

El menú principal tiene cinco accesos: **Historia**, **Infinito**, **Personajes**,
**Bestiario** y **Configuración**. Cada uno muestra un resumen del progreso.

- **Infinito:** elegir personaje y mazmorra desbloqueada; si falta una condición,
  se explica en la ficha. La Torre exige las tres historias.
- **Personajes:** retrato procedural a la izquierda; estadísticas base, pasiva,
  estado de Historia, resonancias y mejoras a la derecha. Solo los personajes
  desbloqueados pueden mejorar.
- **Bestiario:** cuadrícula de enemigos y jefes ya vistos. Los no vistos aparecen
  como `???`; al seleccionarlos se muestra retrato procedural y descripción de
  sus habilidades. Los descubrimientos persisten entre partidas.

## Audio y configuración

El menú abre Configuración con `C`. Desde ahí se ajustan música y efectos en pasos
de 10%; cada cambio se guarda en `save.json`. La música es un bucle procedural de
4 segundos generado con `love.sound` (11 kHz mono), con bajo, arpegio y pulso, y
se reutiliza con `pitch` según el BPM de la mazmorra. Los efectos registran su
volumen base en un bus (`src/utils/audio.lua`) para que el ajuste se aplique sin
reiniciar la partida. Sin `love.audio` (tests) todo el bus queda inactivo.

Configuración también permite borrar todos los datos: monedas, mejoras, récords,
personajes, desbloqueos y ajustes. El borrado pide una segunda confirmación de
4 segundos y reescribe un guardado limpio.

## Sala de pruebas

Se entra desde Configuración y usa una definición `Dungeons.sandbox` que no
aparece en el menú ni en `Data.dungeons`. La run se marca con `run.sandbox`:

- No hay oleadas automáticas, temporizador, salida ni jefes de piso.
- El panel `PRUEBAS`/`F2` invoca enemigos y jefes del catálogo, da ítems en
  cantidad x1 o x5, vacía el inventario y alterna invulnerabilidad.
- Morir restaura la vida y limpia proyectiles/hazards; la sesión continúa.
- Las monedas se contabilizan solo en `run.coinsEarned`; no se escriben en el
  guardado. Tampoco se guardan desbloqueos de personaje, récords ni autosave.
- La tienda está deshabilitada y los ítems de personaje no desbloquean nada.

## Salir al menú

El panel de pausa incluye `SALIR AL MENÚ`. El primer toque (o `Esc`) arma una
confirmación de 3 segundos; el segundo sale. Se descartan piso, nivel e inventario
de la partida actual, pero las monedas, mejoras y desbloqueos ya guardados se
conservan. Al salir se guarda el progreso meta y se detiene la música.

## Rendimiento en el A55

- Resolución virtual adaptable: altura fija de 540 y ancho según el aspecto
  (960 en 16:9, hasta 1200 en 20:9). En teléfonos el área de juego llena la
  pantalla sin barras laterales; en tabletas 4:3 se conserva 960×540 con
  letterboxing. HUD, habilidades y paneles se anclan a los bordes visibles.
- Módulos de LÖVE innecesarios desactivados (joystick, física, video).
- Textos de HUD, tienda, mochila y game over pasan por `src/utils/textcache.lua`:
  se formatean solo cuando cambian sus valores, no cada frame.
- Límite de 12 enemigos activos por piso; proyectiles con vida acotada.
- Datos congelados por módulo (`src/data/`), sin lecturas de archivo en caliente.
