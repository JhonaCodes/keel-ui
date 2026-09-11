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
/// El perfil NO decide permisos, NO elige herramientas y NO cambia el catálogo:
/// solo ajusta cómo se le habla al modelo (el formato y el esfuerzo de
/// razonamiento que se le pide). Un perfil equivocado hace un turno más caro,
/// nunca uno más permisivo.
enum OpenAiModelProfile {
  /// Familia `gpt-oss`. Chica, razona en canales; le alcanza con el esfuerzo
  /// bajo aunque el agente pida el máximo.
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

  /// El esfuerzo que se le pide a este modelo, o null para omitir el campo.
  String? reasoningEffortFor(String keelEffort) => switch (this) {
    OpenAiModelProfile.harmony => 'low',
    OpenAiModelProfile.reasoning =>
      kOpenAiReasoningEffortAliases[keelEffort.trim().toLowerCase()],
    OpenAiModelProfile.generic => null,
  };
}
