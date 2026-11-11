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

Los desbloqueos se guardan al alcanzar el piso indicado. `bossEvery = 3`.

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

Mochila de 5 espacios; los ítems en el suelo duran 7 s (parpadean el último 1.5 s).
Las pasivas se acumulan hasta su máximo; mascotas y desbloqueos son únicos.

- **Pasivas apilables (máx 5):** Veneno (daño en tiempo), Vampiro (roba vida con el
  básico), Hada (recupera maná con el básico), Pólvora (explosión con aturdimiento).
- **Pasivas únicas:** Tambor (ritmo: menos costo y enfriamiento), Flauta (el
  siguiente básico invoca un tornado).
- **Habilidades de ítem:** Resonancia, Flecha de luz, Intercambio de sombra.
- **Mascotas:** Perro (muerde al ritmo, inmune al cuerpo a cuerpo), Gato (los
  enemigos lo ignoran), Dragón (aliento potente, débil al cuerpo a cuerpo), Hámster
  (recoge ítems y busca paredes frágiles).
- **Personajes:** Mar y Amileth.

### Alquimia

Dos ítems pasivos iguales del mismo nivel se combinan y suben a x2, x3, x4 o x5.
Costo: 10, 30, 50 y 150 monedas.

### Tienda

Se abre durante la partida al alcanzar nivel 15 de personaje y piso 10. Precios
entre 25 y 120 monedas; vende pasivas, mascotas y habilidades de ítem.

## Jefes

| Jefe | Rasgo principal |
|---|---|
| Guardián de la Caldera | cuerpo a cuerpo rápido; 320 HP |
| Patriarca de Huesos y Cobre | invoca autómatas y dispara abanicos; fases en 66%/33% |
| Forja Viviente | zonas de fuego (radio 58) e invoca sabuesos; 500 HP |
| Inquisidor del Tiempo | dash telegrafiado y cono a 2x daño |

## Meta-progresión

Persistente en `save.json` (versión 2, normalizado al cargar):

| Mejora | Efecto | Base | +Nivel | Costo base | Máx |
|---|---|---|---|---|---|
| Filo de vapor | daño | 10 | +4 | 30 | 8 |
| Caldera reforzada | vida máxima | 100 | +20 | 40 | 8 |
| Botas de presión | velocidad | 150 | +12 | 35 | 8 |

El costo crece ×1.65 por nivel. También persisten monedas, récord de piso,
mazmorras desbloqueadas y personajes desbloqueados.

## Rendimiento en el A55

- Resolución virtual 960×540 con escalado por transformación (letterboxing).
- Módulos de LÖVE innecesarios desactivados (joystick, física, video).
- Textos de HUD, tienda, mochila y game over pasan por `src/utils/textcache.lua`:
  se formatean solo cuando cambian sus valores, no cada frame.
- Límite de 12 enemigos activos por piso; proyectiles con vida acotada.
- Datos congelados por módulo (`src/data/`), sin lecturas de archivo en caliente.
