/// El contrato de un turno del CLI: lo que TODO turno lleva puesto.
///
/// Vive en su propio archivo porque lo comparten los dos lados de la
/// frontera de isolate —el que arma el turno y el que lo corre— y una
/// constante duplicada de este tipo se despega en silencio: el chat 1:1 y
/// los proyectos terminan hablando con dos CLIs distintos sin que nadie se
/// entere.
library;

const _diagramSystemPromptHint =
    'Para mostrar un diagrama, una jerarquía, una línea de tiempo o un '
    'flujo, preferí un bloque ```mermaid antes que SVG crudo: cuesta muchos '
    'menos tokens y en este cliente se ve igual de bien. Caé a ```svg solo '
    'cuando mermaid no pueda expresar la forma (ilustraciones precisas a '
    'medida).';

const _codeEditSystemPromptHint =
    'Cuando el mensaje ES un pedido de cambiar código de un archivo real '
    'del disco —escribir, corregir, convertir, refactorizar—, hacé el '
    'cambio con tus herramientas de archivo (Write/Edit) en vez de imprimir '
    'el código en la respuesta: este cliente muestra la edición real como '
    'una tarjeta de diff que el usuario revisa, ajusta y guarda. Imprimí '
    'código inline solo cuando te piden VER o discutir un fragmento. Y si '
    'el mensaje era una pregunta y no un pedido, esta regla no aplica: '
    'primero respondé.';

/// Los dos consejos que encabezan el system prompt de TODO turno claude —
/// 1:1, proyecto o asistente. Públicos por la misma razón que
/// [kAlwaysAllowedTools]: el isolate del task runner los necesita y dos
/// copias divergiendo en silencio es exactamente lo que no puede pasar.
/// En español, como el resto del corpus: abrían en inglés un prompt que
/// después habla todo en castellano.
const kCliSystemHints =
    '$_diagramSystemPromptHint\n\n$_codeEditSystemPromptHint';

/// Tools every agent gets, no setting required. They are all read-only or
/// network reads: an agent that cannot open a file is blind, and the whole
/// point of a project is that its agents look at the real code before they
/// say anything about it. Anything that *writes* stays opt-in — see
/// `kAvailableExtraTools`.
const kAlwaysAllowedTools = <String>[
  'Read',
  'Glob',
  'Grep',
  'WebFetch',
  'WebSearch',
];
