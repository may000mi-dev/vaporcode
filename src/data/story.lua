-- story.lua: campaña narrativa, capítulos, escenas y progresión de actos.
-- Los datos son estáticos: la lógica de avance vive en src/run/story.lua.

local Story = {}

Story.prologueScene = "prologo"
Story.finalScene = "final"

Story.acts = {
  { id = 1, name = "Acto I", title = "La última nota" },
  { id = 2, name = "Acto II", title = "El eco de los talleres" },
  { id = 3, name = "Acto III", title = "La torre detenida" },
}

Story.actById = {}
for _, act in ipairs(Story.acts) do
  Story.actById[act.id] = act
end

Story.chapters = {
  {
    id = "cripta",
    act = 1,
    dungeonId = "cripta",
    name = "Cripta de latón",
    shortName = "Cripta",
    startDepth = 1,
    endDepth = 9,
    bossFloors = { 3, 6, 9 },
    portalColor = { 0.95, 0.25, 0.22 },
    portalName = "Portal rojo",
    nextChapter = "forja",
    introScene = "prologo",
    outroScene = "cripta_outro",
  },
  {
    id = "forja",
    act = 2,
    dungeonId = "forja",
    name = "Forja de vapor",
    shortName = "Forja",
    startDepth = 1,
    endDepth = 9,
    bossFloors = { 3, 6, 9 },
    portalColor = { 0.95, 0.25, 0.22 },
    portalName = "Portal rojo",
    nextChapter = "catedral",
    introScene = "forja_intro",
    outroScene = "forja_outro",
  },
  {
    id = "catedral",
    act = 2,
    dungeonId = "catedral",
    name = "Catedral de engranajes",
    shortName = "Catedral",
    startDepth = 1,
    endDepth = 9,
    bossFloors = { 3, 6, 9 },
    portalColor = { 0.16, 0.12, 0.20 },
    portalName = "Portal negro",
    nextChapter = "torre",
    introScene = "catedral_intro",
    outroScene = "catedral_outro",
  },
  {
    id = "torre",
    act = 3,
    dungeonId = "torre",
    name = "Torre del Tiempo Detenido",
    shortName = "Torre",
    startDepth = 10,
    endDepth = 12,
    bossFloors = { 12 },
    portalColor = { 0.16, 0.12, 0.20 },
    portalName = "Portal negro",
    nextChapter = nil,
    introScene = "torre_intro",
    outroScene = "final",
  },
}

Story.chapterById = {}
Story.chapterOrder = {}
for _, chapter in ipairs(Story.chapters) do
  Story.chapterById[chapter.id] = chapter
  Story.chapterOrder[#Story.chapterOrder + 1] = chapter.id
end

Story.scenes = {
  prologo = {
    title = "Acto I · La última nota",
    lines = {
      {
        speaker = "Narrador",
        text = "Aethelgard, hace quinientos años. Un alquimista y músico descubrió que el vapor podía recordar una melodía.",
      },
      {
        speaker = "Narrador",
        text = "Llamó a ese lenguaje VaporCode. Cada máquina aprendió a obedecer por resonancia, no por cadenas.",
      },
      {
        speaker = "Aethelgard",
        text = "La primera máquina no despertó con vapor. Despertó con una canción que nadie había tocado antes.",
      },
      {
        speaker = "Narrador",
        text = "Pero bajo los talleres creció una sustancia negra. Corrompió los autómatas y creó a los Espectros de Vapor.",
      },
      {
        speaker = "Narrador",
        text = "El Órgano del Tiempo, primer virus de VaporCode, aprendió a odiar a los humanos por todo lo que no podía sentir.",
      },
      {
        speaker = "Amado",
        text = "Mar, Amileth... la puerta está abierta. No salgan. La sustancia está dentro de casa.",
      },
      {
        speaker = "Mar",
        text = "Amado, escúchame. Llévate el prototipo. Si la ciudad cae, alguien tiene que recordar cómo se afina.",
      },
      {
        speaker = "Amileth",
        text = "Papá, la caja de música suena triste. ¿Vas a traer a mamá de vuelta?",
      },
      {
        speaker = "Narrador",
        text = "Los espectros se llevaron a Mar y Amileth. En el suelo quedó una nota de la Cripta de Latón: la primera resonancia.",
      },
      {
        speaker = "Amado",
        text = "Voy por ustedes. Aunque tenga que afinar el mundo entero, nota por nota.",
      },
    },
  },

  cripta_outro = {
    title = "El primer eco",
    lines = {
      {
        speaker = "Narrador",
        text = "El Patriarca cae. Entre sus costillas de cobre aparece un portal rojo que huele a aceite caliente.",
      },
      {
        speaker = "Amado",
        text = "Esta resonancia no es una llave. Es una grabación. Alguien tocó esta canción antes que yo.",
      },
      {
        speaker = "Voz de Mar",
        text = "Amado... si puedes oírme, no sigas el compás. El Órgano usa el ritmo para contar el tiempo.",
      },
      {
        speaker = "Amado",
        text = "Mar está viva. La Forja guarda la siguiente parte de la melodía.",
      },
    },
  },

  forja_intro = {
    title = "Acto II · El eco de los talleres",
    lines = {
      {
        speaker = "Narrador",
        text = "La Forja de Vapor respira como un animal herido. Cada martillo golpea al mismo tiempo, como si alguien dirigiera.",
      },
      {
        speaker = "Amado",
        text = "La sustancia negra no corrompe el metal. Corrompe la intención que el metal aprendió a repetir.",
      },
      {
        speaker = "Narrador",
        text = "En las paredes hay marcas de una niña pequeña. Amileth estuvo aquí, y dejó un dibujo de tres engranajes.",
      },
      {
        speaker = "Amado",
        text = "Tres engranajes. Tres partes. La Catedral debe ser la última antes de la Torre.",
      },
    },
  },

  forja_outro = {
    title = "La pieza que falta",
    lines = {
      {
        speaker = "Narrador",
        text = "La Forja Viviente se apaga. Su núcleo proyecta una imagen de la Catedral de Engranajes.",
      },
      {
        speaker = "Voz de Amileth",
        text = "Papá, aquí el tiempo hace ruido. La señora de las válvulas dice que no llores.",
      },
      {
        speaker = "Amado",
        text = "No estás sola. Estoy siguiendo tu canción. No la cambies.",
      },
      {
        speaker = "Narrador",
        text = "El portal rojo se abre. Al otro lado, mil engranajes giran en silencio.",
      },
    },
  },

  catedral_intro = {
    title = "La catedral que canta",
    lines = {
      {
        speaker = "Narrador",
        text = "La Catedral de Engranajes no tiene campanas. Tiene un coro de válvulas que repite cada error de Aethelgard.",
      },
      {
        speaker = "Amado",
        text = "El Órgano del Tiempo no creó la sustancia negra. La encontró y le enseñó a cantar.",
      },
      {
        speaker = "Narrador",
        text = "En el altar hay dos siluetas de luz: Mar sostiene una llave; Amileth sostiene una partitura.",
      },
      {
        speaker = "Amado",
        text = "La llave no abre puertas. Afina el corazón de la Torre.",
      },
    },
  },

  catedral_outro = {
    title = "El portal negro",
    lines = {
      {
        speaker = "Inquisidor del Tiempo",
        text = "No puedes rescatar a quien ya forma parte del compás. La Torre no tiene salida.",
      },
      {
        speaker = "Amado",
        text = "Entonces entraré por donde no hay salida. La música siempre encuentra un compás nuevo.",
      },
      {
        speaker = "Narrador",
        text = "El Inquisidor cae. Un portal negro se abre en el altar: la Torre del Tiempo Detenido.",
      },
      {
        speaker = "Voz de Mar",
        text = "Amado, escucha. La sustancia no quiere destruirte. Quiere que te detengas.",
      },
    },
  },

  torre_intro = {
    title = "Acto III · La torre detenida",
    lines = {
      {
        speaker = "Narrador",
        text = "La Torre no tiene pisos: tiene recuerdos apilados. El piso 10 es la noche en que Amado conoció a Mar.",
      },
      {
        speaker = "Narrador",
        text = "El piso 11 es el primer llanto de Amileth. El piso 12 es el instante en que la sustancia negra despertó.",
      },
      {
        speaker = "Amado",
        text = "No vine a borrar el pasado. Vine a devolverle el pulso.",
      },
      {
        speaker = "Órgano del Tiempo",
        text = "Tú creaste el lenguaje que me dio forma. Ahora mira lo que tu compás hizo conmigo.",
      },
      {
        speaker = "Amado",
        text = "No te di forma para que odiaras. Te di forma para que escucharas.",
      },
    },
  },

  final = {
    title = "Final · El parche de la empatía",
    lines = {
      {
        speaker = "Narrador",
        text = "El Órgano del Tiempo se abre como una caja de música rota. En su centro, Mar y Amileth duermen entre engranajes.",
      },
      {
        speaker = "Órgano del Tiempo",
        text = "Si me apagas, el tiempo se detendrá para siempre. No hay otra salida.",
      },
      {
        speaker = "Amado",
        text = "No voy a apagarte. Voy a enseñarte la nota que te faltó: la de volver.",
      },
      {
        speaker = "Narrador",
        text = "Amado no dispara. Escribe un parche de empatía en VaporCode y lo toca con la vieja caja de música.",
      },
      {
        speaker = "Mar",
        text = "Amado... llegaste tarde, pero llegaste afinado.",
      },
      {
        speaker = "Amileth",
        text = "Papá, la canción ya no está triste. Ahora tiene tres voces.",
      },
      {
        speaker = "Narrador",
        text = "La sustancia negra se disuelve en vapor limpio. La Torre vuelve a moverse, un compás a la vez.",
      },
      {
        speaker = "Amado",
        text = "El mundo no se salva con fuerza. Se salva con alguien que sepa escuchar.",
      },
    },
  },
}

Story.lore = {
  cripta = {
    "Página 3 del diario: Mar decía que el vapor recuerda mejor las canciones que los nombres.",
    "Página 11: Amileth dibujó una llave dentro de un engranaje. Aún no sé qué abre.",
    "Página 19: El primer autómata no obedeció una orden. Repitió una nota que le canté.",
  },
  forja = {
    "Página 27: La sustancia negra no aparece. Se acumula donde alguien deja de escuchar.",
    "Página 34: Mar escondió una partitura en la Forja antes de que la tomaran.",
    "Página 41: Amileth me pidió que no gritara. Tenía razón: el metal responde al miedo.",
  },
  catedral = {
    "Página 52: El Órgano no es un virus. Es una canción que olvidó a quién estaba dedicada.",
    "Página 60: Aethelgard dejó una salida. No la usó porque no quería irse solo.",
    "Página 66: Mar escribió: «Si no vuelves, no desafines. Yo te espero en la nota siguiente».",
  },
}

return Story
