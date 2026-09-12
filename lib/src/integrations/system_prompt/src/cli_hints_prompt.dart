part of '../system_prompt.dart';

/// LAS DOS PISTAS QUE ENCABEZAN TODO TURNO DE CLAUDE.
///
/// Qué dicen: prefiere ```mermaid antes que SVG crudo para diagramas, y
/// cuando el pedido es cambiar código de un archivo real usa Write/Edit en
/// vez de imprimir el código en la respuesta.
///
/// Por qué existen: las dos describen capacidades DE ESTE CLIENTE que el
/// modelo no puede adivinar — que aquí un bloque mermaid se renderiza, y que
/// una edición real se muestra como tarjeta de diff revisable. Sin decirlo,
/// el agente elige lo que sirve en una terminal: SVG carísimo y código
/// pegado en el chat que el usuario tiene que copiar a mano.
///
/// Quién las usa: `llm/claude/claude_cli_runner.dart`, que las antepone al
/// stack de instrucciones del member en CADA turno claude — 1:1, proyecto o
/// asistente. Un solo lugar a propósito: dos copias divergiendo en silencio
/// serían dos CLIs distintos sin que nadie se entere.
///
/// En español, como el resto del corpus: abrían en inglés un prompt que
/// después habla todo en castellano.
const _diagramSystemPromptHint =
    'Para mostrar un diagrama, una jerarquía, una línea de tiempo o un '
    'flujo, prefiere un bloque ```mermaid antes que SVG crudo: cuesta muchos '
    'menos tokens y en este cliente se ve igual de bien. Recurre a ```svg solo '
    'cuando mermaid no pueda expresar la forma (ilustraciones precisas a '
    'medida).';

const _codeEditSystemPromptHint =
    'Cuando el mensaje ES un pedido de cambiar código de un archivo real '
    'del disco —escribir, corregir, convertir, refactorizar—, haz el '
    'cambio con tus herramientas de archivo (Write/Edit) en vez de imprimir '
    'el código en la respuesta: este cliente muestra la edición real como '
    'una tarjeta de diff que el usuario revisa, ajusta y guarda. Imprime '
    'código inline solo cuando te piden VER o discutir un fragmento. Y si '
    'el mensaje era una pregunta y no un pedido, esta regla no aplica: '
    'primero responde.';

const kCliSystemHints =
    '$_diagramSystemPromptHint\n\n$_codeEditSystemPromptHint\n\n'
    '$kNeutralSpanishPrompt\n\n$kPlanningDiagramPrompt';
