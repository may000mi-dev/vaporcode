# VaporCode — resumen integral y roadmap

> Estado del código documentado hasta el commit `f06c542` (`Añade catálogos, corrige música de Historia y ajusta pilas de ítems`) en la rama `main`. Este documento se añade después de ese commit.
> Fecha: 17 de noviembre de 2026.

## 1. Resumen ejecutivo

VaporCode pasó de un prototipo base de LÖVE 11.5 a un **MVP jugable V9** con dos modos, tres personajes, combate automático, ritmo por BPM, generación procedural, jefes con fases, progreso persistente y catálogos dentro del juego. Todo el contenido vive en tablas de `src/data/`, la partida se orquesta desde `src/run/run.lua` y la presentación se separa en estados, HUD y utilidades.

El proyecto ya es **jugable y empaquetable en el teléfono**: `sh src/tools/build.sh` verifica sintaxis, ejecuta 34 suites de tests y genera un `.love`. El siguiente gran salto no es más contenido por sí solo, sino resolver tres bloqueos estructurales antes de escalar:

1. **Peso del audio por personaje**: 15 pistas MP3 ocupan ~61 MB; el patrón actual de 5 pistas por personaje sería inviable con 30 personajes.
2. **Estado de partida singular y RNG parcialmente no determinista**: `Run` es un singleton y parte del botín/IA usa `love.math.random`; online/LAN con semilla compartida exige refactor.
3. **Documentación y artefactos desincronizados**: hay texto que aún dice guardado v5/v6 o 12 enemigos activos, y `build/vaporcode.love` es viejo e ignora los módulos nuevos.

La expansión planteada (30 personajes, evolución de enemigos, nuevos capítulos, assets y online) es alcanzable por fases, pero debe hacerse en ese orden: primero **determinismo y estructura de datos**, después **contenido**, luego **assets/builds finales** y al final **red**.

---

## 2. Estado actual del proyecto

### 2.1 Datos duros

| Métrica | Valor |
|---|---:|
| Motor | LÖVE 11.5 (no LÖVE 12) |
| Resolución | Altura lógica 540, ancho adaptable 960–1200 |
| Commits en el repositorio | 24 |
| Módulos Lua | ~117 |
| Suites de test | 34 (`src/tools/test_*.lua`) |
| Personajes jugables | 3: Amado, Mar, Amileth |
| Habilidades | 5 (3 intercambiables en A1/A2) |
| Mazmorras | 4 jugables + 1 sala de pruebas |
| Tipos de enemigo | 17 |
| Jefes | 5 |
| Afijos de élite | 7 |
| Antídotos | 4 |
| Compases | 8 |
| Memorias de jefe | 6 |
| Ítems | 18 |
| Mascotas | 4 |
| Mejoras permanentes | 3 por personaje, nivel máximo 8 |
| Temas visuales | 3 paletas por personaje |
| Pistas musicales | 15 MP3, ~61 MB |
| Capítulos de Historia | 4 (3 actos) |
| Escenas de Historia | 24 (8 base + variantes por personaje) |
| Líneas de diálogo | 132 |
| Fragmentos de lore | 9 |
| Formato de guardado | v7 con migraciones desde v4 |

### 2.2 Sistemas implementados

- **Combate y movimiento.** Joystick flotante, arrastre central para cámara, ataque automático con línea de visión, marcas de Amado, cadena de Amileth, dash de Mar, proyectiles con `sourceEnemy`, hazards y retrospectiva visual.
- **Ritmo.** Reloj de BPM por zona (120 menú, 104 cripta, 124 forja, 138 catedral, 150 torre), pulso fuerte cada 4 beats, ventana de ±120 ms y multiplicador ×2. Hay metrónomo procedural de respaldo si falla el MP3.
- **Modo Historia.** Cripta → Forja → Catedral → Torre con portales, escenas propias por personaje, checkpoint por piso y por personaje, reintento exacto, final separado y contador `x/3`.
- **Modo Infinito.** Presupuesto de amenaza por profundidad y tamaño, roles garantizados, oleadas, tope de 18 enemigos activos, atrición, Director Dinámico, Antídotos, compases, élites y memorias de jefe con Sobrecarga de 3 minutos.
- **Dungeon.** Generación por semilla, 26×15 base, 6–8 salas, raycasting para línea de visión, válvulas, cofres ocultos en paredes frágiles y salida bloqueada hasta limpiar oleadas.
- **Enemigos y jefes.** Roles chaser, turret, ranged, mortar, summoner, trapper, blight, healer, mana_hunter, purifier, pet_hunter, mirror_guard y siege. Jefes: Guardián, Patriarca, Forja Viviente, Inquisidor y Órgano del Tiempo; todos inmunes al aturdimiento.
- **Ítems y economía.** 5 espacios activos + 15 guardados, intercambio sin pérdida, tienda desde nivel 15 y piso 10, alquimia de pares guardados a x2/x3/x4/x5, y límite **x5 por pila**, no global: pueden coexistir `x3 + x2`, dos `x5` o más siempre que haya huecos. Las entregas grandes se reparten en pilas de 5.
- **Mascotas y habilidades.** Perro, Gato, Dragón y Hámster con personalidad mecánica distinta; maná compartido, regeneración mejorada tras 5 s y asignación de A1/A2 desde la mochila.
- **Guardado v7.** `save.json` con `save.json.tmp`, normalización al cargar, migraciones v4→v5→v6→v7, checkpoints por personaje, `bestiary`, `items` e `songs[personaje]`. Se guarda al cambiar de piso, pausar, perder foco, ocultarse y salir.
- **Interfaz.** Menú de 7 accesos (Historia, Infinito, Personajes, Canciones, Ítems, Bestiario, Configuración), tarjeta global de selección de personaje, catálogos con `???`, pestañas y scroll, HUD con metrónomo y contador de enemigos, pausa, game over y salida segura al menú.
- **Sala de pruebas.** `Dungeons.sandbox` sin oleadas, tiempo ni progreso; invoca enemigos/jefes x1/x5, da ítems, vacía inventario y alterna invulnerabilidad. Sus listas tienen scroll propio y no escriben en el guardado real.

### 2.3 Arquitectura actual

- `conf.lua` / `main.lua`: arranque, callbacks de LÖVE, guardado en foco/quit, F3 para depuración.
- `src/estados.lua`: máquina de estados delgada; resuelve `"run"` a `src.run.run` y el resto a `src.estados.*`.
- `src/run/`: 45 módulos. `run.lua` inyecta 10 sistemas como métodos `Run:*` mediante `sys()`, con validación de colisiones de nombres.
- `src/data/`: 13 módulos estáticos. `src/run/data.lua` compone la API plana `Data.*`.
- `src/utils/`: input, cámara, joystick, JSON, audio, fuentes, textcache y pantalla adaptable.
- `src/tools/`: 34 suites Lua puro con mock de `love` y scripts `test_all.sh` / `build.sh`.

---

## 3. Historial de cambios y mejoras

### Fase 1 — Base y modularización (`ccf0e2b` … `2d4b56a`)

- Prototipo `v0.1` heredado de `roguelike5`.
- Corrección de `keepDistance` del espectro que rompía `updateRanged`.
- `run.lua` dividido en 9 módulos de sistema.
- Caché de textos del HUD y `data.lua` dividido por dominio.
- Documentación de requisitos de Termux:X11 y LÖVE en el README.

### Fase 2 — Móvil, inventario y herramientas (`32ad6c7` … `0d57fc0`)

- Inventario de 5 activos y 15 guardados con intercambio.
- Área de juego adaptable al aspecto del dispositivo.
- Audio configurable, salida al menú y sala de pruebas.
- Guía de onboarding para desarrolladores Junior en `GuiaVaporCode/`.

### Fase 3 — Modos, personajes y bestiario (`c602448` … `a36f578`)

- Modo Historia con checkpoints y final en la Torre.
- Mejoras en mascotas, Inquisidor y lectura del pulso fuerte.
- Progreso por personaje, Bestiario y Modo Infinito.
- Nuevo patrón del Órgano del Tiempo y corrección de sus zonas.

### Fase 4 — Dificultad avanzada de Infinito (`39a0d17` … `fa525c6`)

- Mejoras de jefes, Guardián opcional y HUD.
- Pelea del Inquisidor alargada.
- Presupuesto de amenaza y oleadas.
- Compases, élites y escolta obligatoria de Clérigos.
- Memorias de jefe y Sobrecarga crítica.
- Atrición progresiva de curación y tiempo.
- Director Dinámico según tiempo, daño y vida al limpiar piso.

### Fase 5 — Identidad, contenido y pulida final (`da7c4a7` … `f06c542`)

- Selección global de personaje, temas visuales, audio por zona y Antídotos.
- Guardado de Historia por personaje con checkpoint aislado.
- Catálogo musical de 15 pistas con bloqueo por escucha y vista previa.
- Catálogo de ítems con descubrimiento al caer al suelo.
- Corrección de la música de Historia al entrar, cambiar de capítulo y reintentar piso.
- Scroll en las listas de la sala de pruebas sin tapar botones inferiores.
- Fix de apilado: se pueden comprar duplicados aunque existan otras pilas; el tope de x5 es por pila y nunca se fusiona una pila por encima de x5.
- Documentación actualizada en `README.md` y `docs/design.md`.

---

## 4. Calidad, pruebas y build

- `sh src/tools/test_all.sh` ejecuta 34 suites en procesos separados; usa `lua` o `luajit` y permite `LUA_BIN=luajit`.
- Los tests son de lógica pura: simulan la API de LÖVE en memoria. Cubren datos, LOS, cámara, targeting, autodisparo, personajes, habilidades, botín, inventario, alquimia, tienda, historia, guardado, audio, catálogos, dificultad de Infinito, sala de pruebas, layout y dibujo de pantallas.
- `sh src/tools/build.sh` hace 4 pasos: `luac -p`, tests, `zip` de `conf.lua`, `main.lua`, `src` y `assets/audio/music` excluyendo `src/tools/`, y `unzip -t`.
- Salida real del último build: `/sdcard/Download/vaporcode.love`.
- En Android hay que compartir el `.love` con `termux-share`; `file://` no funciona en Android 11+.

**Limitaciones de la validación actual:** no hay tests reales de GPU, audio ni touch en dispositivo; no hay CI; no hay cobertura automatizada; el artefacto `build/vaporcode.love` versionado localmente está desactualizado aunque está ignorado por Git.

---

## 5. Deuda técnica y riesgos detectados

| Riesgo | Impacto | Comentario |
|---|---|---|
| `Run` singleton con ~95 campos y métodos inyectados | Alto | Bloquea dos partidas simultáneas, replays y autoridad remota. |
| RNG no totalmente determinista | Alto | Mapa y compases usan semilla, pero botín/IA usan `love.math.random`; online con semilla compartida no es reproducible. |
| 15 MP3 = ~61 MB | Alto | 30 personajes × 5 pistas ≈ 610 MB. Necesita OGG, streaming o carga por personaje. |
| 24 archivos Lua superan ~300 líneas | Medio | `enemy.lua` 985, `run.lua` 801, `hud.lua` 742, `boss.lua` 709. Dificulta cambios seguros. |
| `themes`, `music` y `story` se requieren directamente desde módulos de juego | Medio | Rompe la regla de pasar todo por `Data.*`; escalar dominios nuevos exigirá tocar varios archivos. |
| Ids de personaje escritos en lógica (`"amado"`, `"mar"`, `"amileth"`) | Medio | Cada personaje nuevo obliga a revisar habilidades, slots, retratos y guardado. |
| Textos de progreso duros (`x/3`) | Medio | El desbloqueo de Torre y la campaña están pensados para 3 historias; con 5 de 30 hay que redefinir reglas. |
| Documentación desincronizada | Medio | `docs/design.md` dice guardado v6 en meta-progresión y 12 enemigos activos; `GuiaVaporCode/` dice v5 y "música generada en el dispositivo". |
| Sin CI ni artefactos multiplataforma | Medio | El build solo produce `.love` desde Android; Steam/App Store/Play Store requieren laptop o CI. |
| Sin pooling real | Bajo/medio | Se compactan tablas cada frame; con más habilidades y mascotas conviene medir en el A55. |

---

## 6. Planes futuros planteados y evaluación

### 6.1 Evaluación rápida

| Plan | Dificultad | Por qué | Primer paso recomendado |
|---|---|---|---|
| Más de 30 personajes con mecánicas propias | Media-alta | Las tablas escalan, pero cada básico/pasiva/animación necesita código, balance y tests. | Definir un contrato de `CharacterDef` con hooks de basic/pasiva y migrar los 3 actuales. |
| Canciones propias respetando BPM | Media en diseño, alta en almacenamiento | El catálogo ya existe, pero 150 pistas MP3 serían ~610 MB. | Convertir a OGG y cargar solo las pistas del personaje activo. |
| Ítems únicos, mascotas con personalidades y habilidades exclusivas | Media | Encaja con `src/data/`, pero las personalidades requieren IA y diálogo/feedback. | Extender `PetDef` y `ItemDef` con `ownerCharacter` y `personality`. |
| Evolución de enemigos por condición | Media | El ejemplo del Devorador es event-driven y cabe en el sistema actual. | Crear `run/evolution.lua` con reglas disparadas por eventos. |
| Extensión de Historia a nuevos capítulos | Alta | Mucho texto, escenas, checkpoints y equilibrio; peor aún con 30 perspectivas. | Escribir el capítulo 2 como contenido nuevo con un solo personaje piloto. |
| Nuevas mazmorras con reglas y BPM propios | Media-alta | El BPM ya es data, pero las "reglas especiales" necesitan un módulo por mazmorra. | Crear `DungeonDef.rules` con modificadores data-driven. |
| Asignación de assets definitivos | Media-alta | Es trabajo de producción, no de lógica; consume almacenamiento y tiempo. | Hacerlo en laptop: atlas, OGG y pipeline de build. |
| Online/LAN con semilla compartida y autoridad | Muy alta | Requiere determinismo, instancias de partida, protocolo, reconciliación y sesión. | Auditoría de RNG y refactor de `Run` a instancia antes de tocar sockets. |
| Voto de pausa/continuar en partida compartida | Media dentro de red | Fácil comparado con el netcode, pero depende de que ya exista transporte y sesión. | Definir mensaje `PAUSE_VOTE` y política de mayoría en el host/servidor. |

### 6.2 Detalle de las ideas planteadas

**Personajes (30+).** La base de datos y la selección global ya soportan más personajes: `characters.lua`, `themes.lua`, `save.data.progress[characterId]`, `songs[characterId]` y los catálogos son tablas. Lo difícil no es agregar filas, sino que cada personaje tenga un básico y una pasiva realmente distintos sin llenar la lógica de condicionales. Conviene pasar de `if characterId == "mar"` a un contrato de hooks por personaje y mover los retratos procedurales a una definición de paleta/forma.

**Música y BPM.** La regla actual (BPM por zona) ya funciona y debe conservarse. Para 30 personajes no se puede repetir el patrón de 5 MP3 por personaje: habría 150 pistas. La solución lightweight es OGG comprimido, un tema de menú por personaje y un número menor de pistas reutilizables por capítulo, más capas rítmicas procedurales para variar la sensación sin duplicar audio.

**Ítems, mascotas y habilidades exclusivas.** Los catálogos de 18 ítems y 5 habilidades son un buen punto de partida. Un ítem único por personaje es barato en datos; una mascota con personalidad ("celosa", "tímida", "glotona", "protectiva") implica IA adicional y feedback visible. Lo recomendable es empezar con 1 mascota y 1 habilidad exclusiva para un personaje piloto, validar el patrón y recién entonces replicar.

**Evolución de enemigos.** Es una de las mejoras más alcanzables. El caso del Devorador de Núcleos que mate a una mascota y se convierta en "Asesino de Núcleos", gane agresividad y robe vida dentro de un aura, puede implementarse con eventos: `pet_died → sourceEnemy → evolve()`. Requiere decidir si la evolución dura solo la run o se guarda en el Bestiario como variante descubierta. Es más fácil que los jefes con fases porque reutiliza IA y solo cambia parámetros/affixes.

**Historia y capítulos.** El capítulo 1 actual (virus y derrota del Órgano del Tiempo) ya está cerrado. El capítulo 2 (limpieza y aparición del creador del virus) encaja con el lore, pero multiplica el trabajo de guion y escenas. La regla de desbloquear con 5 de 30 personajes es fácil de guardar en `Save` (`chapterUnlocked` + `storyCompletionCount >= 5`), pero obliga a revisar el texto de "3 historias", la Torre y la pantalla de Personajes. Conviene separar "desbloqueo de capítulo" de "final canon" para no exigir 30 campañas completas.

**Nuevas mazmorras y reglas.** El BPM ya es data-driven y `Dungeons` acepta nuevas entradas. Lo difícil es que cada mazmorra tenga reglas distintas (por ejemplo, sin curación, oleadas invertidas, enemigos hostiles adicionales). La solución limpia es un campo `rules` con modificadores interpretados por sistemas existentes, no un `if dungeonId == ...` dentro de `run.lua`.

**Assets.** Hoy no hay imágenes: retratos, fuentes y UI son procedurales. Eso fue ideal para el teléfono, pero limita la presentación final. La asignación de sprites para personajes, enemigos e ítems debe hacerse en laptop, con atlas y OGG; el teléfono solo debe probar el `.love` resultante. Conviene no subir assets grandes al repositorio hasta tener pipeline de compresión.

**Online y LAN.** Es el cambio más complejo y debe ir al final. La semilla compartida solo garantiza el mismo mapa; para que todos vean lo mismo también deben ser deterministas el botín, los críticos, la IA, los compases y el orden de resolución de eventos. Además, "servidor con la última palabra" y "host LAN con la última palabra" son dos modelos de autoridad distintos. La pausa por voto es sencilla una vez que existe sesión y transporte; ahora mismo no hay ni un módulo de red.

---

## 7. Orden recomendado de trabajo

1. **Sanidad documental y determinismo.** Corregir textos v5/v6 y 12/18 enemigos, actualizar artefacto de build, auditar `love.math.random` y unificar todo el RNG bajo `run.dungeon.rng` o un `Rng` por sistema.
2. **Refactor de estado.** Convertir `Run` en instancia creada por `Run.new(seed, mode, characterId)`; mantener un singleton solo para la partida local. Es requisito previo para replays, LAN y servidor.
3. **Contratos de contenido.** Definir `CharacterDef`, `PetDef`, `ItemDef`, `DungeonDef.rules` y eventos de enemigo. Migrar los 3 personajes actuales a esos contratos antes de crear el 4.
4. **Contenido piloto.** Un personaje nuevo, una canción OGG, una mascota con personalidad, una habilidad exclusiva y una evolución de enemigo. Probar en teléfono antes de producir 30.
5. **Capítulo 2.** Primero con un personaje, luego variantes. Guardar desbloqueo por `≥5` personajes completados sin romper el final del capítulo 1.
6. **Assets y build de distribución.** Laptop: atlas, OGG, compresión, iconos y wrappers por plataforma.
7. **Red.** Determinismo → protocolo → LAN host-autoritativa → voto de pausa → servidor online autoritativo.

---

## 8. Pasos para lanzar en Steam / Play Store / App Store

### 8.1 Preparación común

- Fijar LÖVE 11.5 en todas las plataformas y generar builds desde laptop o CI, nunca desde el teléfono.
- Separar el núcleo `.love` de los wrappers de cada tienda; el código de juego debe ser el mismo.
- Convertir música a OGG, revisar licencias de audio/arte y guardarlas en el repositorio o en un pipeline de assets.
- Definir versión de producto, política de guardados, migraciones y respaldo antes del primer lanzamiento.
- Preparar lista de requisitos: título, descripción, capturas, íconos, clasificación por edad, política de privacidad y datos que se recogen (idealmente ninguno si no hay online).
- Smoke tests por plataforma: arranque, audio, touch/ratón/teclado, pausa al perder foco, guardado/carga y salida.
- Añadir reporte de errores liviano y logs no sensibles; no registrar llaves ni datos personales.

### 8.2 Steam

1. Empaquetar el `.love` junto con un runtime de LÖVE 11.5 para Windows, Linux y macOS.
2. Integrar Steamworks SDK desde la laptop: App ID, Steam Cloud para `save.json`, logros y, si se desea, controladores/Steam Deck.
3. Probar el build en modo offline y con Steam Cloud activo; verificar que el guardado no se corra entre perfiles.
4. Crear depots por sistema operativo y subirlos con `steamcmd`.
5. Preparar material de tienda y configurar prueba privada antes del lanzamiento.
6. Verificar Steam Deck (controles, rendimiento y suspensión/reanudación) porque el juego ya está pensado para pantalla pequeña y 60 FPS.

### 8.3 Play Store

1. Generar APK/AAB con `love-android` 11.5 desde laptop o CI; **no ejecutar Gradle/NDK en Termux**.
2. Firmar con un keystore propio guardado fuera del repositorio; perderlo impide actualizar la app.
3. Revisar permisos mínimos, target SDK actual, compatibilidad 64 bits y orientación horizontal.
4. Probar en 16:9 y 20:9 reales, con audio, notificaciones y pérdida de foco; el juego ya guarda en `love.focus` pero debe verificarse en dispositivos que matan el proceso.
5. Subir a Play Console: ficha, capturas de teléfono/tablet, clasificación, política de privacidad y pista de pruebas internas.
6. Vigilar tamaño del AAB; si el contenido crece, usar OGG y asset packs para no inflar la descarga inicial.

### 8.4 App Store (iOS)

1. Requiere macOS + Xcode; no es viable desde Termux ni desde Linux.
2. Portar el `.love` con un wrapper de LÖVE para iOS o una capa native; probar en iPhone y iPad con safe-area y touch real.
3. Firmar, entitlements y notarización desde Xcode; subir a App Store Connect con capturas para todos los tamaños requeridos.
4. Revisar preferencias de privacidad, permisos de audio y comportamiento en segundo plano; iOS es estricto con audio y suspensión.
5. iOS queda después de Steam y Android: el proyecto lo marca como fuera del MVP y conviene esperar a que el contenido y los assets estén estables.

### 8.5 Checklist de "listo para tienda"

- [ ] Guardado v7/v8 con migraciones probadas desde versiones anteriores.
- [ ] Música OGG/licenciada y sin MP3 duplicados.
- [ ] Builds reproducibles desde laptop/CI con LÖVE 11.5 fijo.
- [ ] Sin secretos, keystores ni artefactos generados en el repositorio.
- [ ] Tests unitarios + smoke manual en cada plataforma.
- [ ] Política de privacidad y clasificación por edad.
- [ ] Manejo de foco, pausa, audio y batería verificado.
- [ ] Plan de actualizaciones y versionado semántico.

---

## 9. Próximos pasos inmediatos

1. Corregir los textos desactualizados de `docs/design.md` y `GuiaVaporCode/` (guardado v7, 18 enemigos activos en Infinito, música incluida).
2. Decidir el formato de guardado v8 si se agregarán capítulos/personajes nuevos, y documentarlo antes de implementarlo.
3. Auditar y unificar RNG; agregar tests de reproducibilidad con la misma semilla.
4. Diseñar el contrato de personaje/mascota/ítem y migrar a Amado, Mar y Amileth como prueba.
5. Convertir las 15 pistas actuales a OGG y medir ahorro real antes de producir más música.
6. Implementar la evolución del Devorador de Núcleos como primer sistema de eventos de enemigo.
7. Solo después de esos pasos, crear el personaje 4 y el capítulo 2.

Este documento debe actualizarse al terminar cada hito grande, igual que `README.md` y `docs/design.md`.
