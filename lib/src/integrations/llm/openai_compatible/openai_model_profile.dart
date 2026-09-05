/// El vocabulario de esfuerzo de Keel traducido al del dialecto de OpenAI.
///
/// Keel ofrece cinco niveles; el dialecto define tres. `xhigh` y `max` se
/// recortan al más alto que existe: pedir un valor inventado no sube el
/// esfuerzo, solo hace que el proveedor descarte el campo entero.
const kOpenAiReasoningEffortAliases = <String, String>{
  'low': 'low',
  'medium': 'medium',
  'high': 'high',
  'xhigh': 'high',
  'max': 'high',
};

/// Marcadores de identificador de los modelos que razonan de verdad.
///
/// Se comparan contra el PRINCIPIO del identificador, ya sin el prefijo de
/// gateway (`openai/gpt-5` y `gpt-5` matchean igual). Buscarlos como subcadena
/// suelta clasificaría de más: `o4` aparece dentro de nombres que no tienen
/// nada que ver, y un modelo mal clasificado recibe un parámetro que no
/// soporta. Extender esta lista es la única edición que hace falta para que
/// una familia nueva reciba el esfuerzo que el usuario eligió.
const kOpenAiReasoningModelMarkers = <String>[
  'o1',
  'o3',
  'o4',
  'gpt-5',
  'deepseek-reasoner',
  'deepseek-v4',
];

/// Marcador de la familia `gpt-oss`, que se pregunta ANTES que la lista de
/// razonamiento: su identificador también contiene fragmentos de esa lista y
/// lo que manda es el formato que habla.
const kOpenAiHarmonyModelMarker = 'gpt-oss';

/// Cómo se le habla a un modelo, según su clase.
///
/// Las decisiones que dependen de la clase —cuántas vueltas de herramientas se
/// le presupuestan y cuánto razonamiento se le pide— se mueven JUNTAS. Repartidas
/// en dos `if` sobre el identificador, el día que entre un modelo nuevo se
/// acuerda uno y se olvida el otro, y el síntoma aparece en producción como
/// «a veces no ejecuta».
///
/// El perfil NO decide permisos, NO elige herramientas y NO cambia el catálogo:
/// solo ajusta cómo se le habla al modelo. Un perfil equivocado hace un turno
/// más caro o más corto, nunca uno más permisivo.
enum OpenAiModelProfile {
  /// Familia `gpt-oss`. Chica, razona en canales y gasta vueltas anunciando lo
  /// que va a hacer, así que necesita MÁS rondas que el resto y le alcanza con
  /// el esfuerzo bajo.
  harmony,

  /// Los grandes de razonamiento. Entienden el protocolo solos; lo único que
  /// se les ajusta es el esfuerzo que pidió el usuario.
  reasoning,

  /// Todo lo demás. Sin esfuerzo: un modelo que no razona o ignora el campo o
  /// lo rechaza con un 400, y acá un 400 no es transitorio — mata el turno sin
  /// reintento.
  generic;

  static OpenAiModelProfile fromModel(String model) {
    // El gateway antepone el proveedor (`openai/gpt-oss-20b`); el mismo modelo
    // llega plano contra su API directa. Lo que clasifica es el nombre.
    final identifier = model.toLowerCase().split('/').last;
    // `gpt-oss` se pregunta PRIMERO: su identificador también empieza como los
    // de la lista de razonamiento, y lo que manda es el formato que habla.
    if (identifier.startsWith(kOpenAiHarmonyModelMarker)) {
      return OpenAiModelProfile.harmony;
    }
    for (final marker in kOpenAiReasoningModelMarkers) {
      if (identifier.startsWith(marker)) return OpenAiModelProfile.reasoning;
    }
    return OpenAiModelProfile.generic;
  }

  /// Presupuesto de rondas de herramientas del turno.
  ///
  /// Cada ronda reenvía el historial COMPLETO: el tope es el multiplicador de
  /// costo, no el trabajo. Agotarlo NO es un fallo —el turno se cierra con lo
  /// hecho y el nodo siguiente lo continúa—, así que el número es un
  /// presupuesto y no una red. 40 plano para todos pagaba el precio de la
  /// clase más charlatana en cada turno de cualquier modelo; 24 cubre de sobra
  /// una tarea agéntica real (leer varios archivos, editar, correr un test,
  /// iterar) y `harmony` conserva las 40 porque quema vueltas anunciando.
  int get maxToolRounds => switch (this) {
    OpenAiModelProfile.harmony => 40,
    OpenAiModelProfile.reasoning || OpenAiModelProfile.generic => 24,
  };

  /// El esfuerzo que se le pide a este modelo, o null para omitir el campo.
  String? reasoningEffortFor(String keelEffort) => switch (this) {
    OpenAiModelProfile.harmony => 'low',
    OpenAiModelProfile.reasoning =>
      kOpenAiReasoningEffortAliases[keelEffort.trim().toLowerCase()],
    OpenAiModelProfile.generic => null,
  };
}
