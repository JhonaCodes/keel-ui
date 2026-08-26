/// El contrato de un turno del CLI: lo que TODO turno lleva puesto.
///
/// Vive en su propio archivo porque lo comparten los dos lados de la
/// frontera de isolate —el que arma el turno y el que lo corre— y una
/// constante duplicada de este tipo se despega en silencio: el chat 1:1 y
/// los proyectos terminan hablando con dos CLIs distintos sin que nadie se
/// entere.
///
/// Las pistas de texto que acompañaban a estas tools se mudaron a
/// `integrations/system_prompt/src/cli_hints_prompt.dart`, con el resto del
/// corpus de prompts: `core/` no puede importar `integrations/`, y quien las
/// arma —`claude_cli_runner.dart`— ya vive del otro lado.
library;

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
