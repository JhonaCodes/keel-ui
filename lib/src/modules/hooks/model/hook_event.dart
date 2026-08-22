/// Qué CLI conoce un evento de hook.
enum HookProvider {
  claude(alias: 'claude', label: 'Claude'),
  codex(alias: 'codex', label: 'Codex');

  final String alias;
  final String label;

  const HookProvider({required this.alias, required this.label});
}

/// Un momento del ciclo de vida de un turno en el que un hook puede correr.
///
/// La lista NO es inventada: es la de los dos CLIs. Los 11 eventos de codex
/// resultaron ser un subconjunto exacto de los de claude, así que hay un
/// núcleo [portable] que corre en cualquier proveedor, y un resto que solo
/// existe en claude. Esa diferencia se muestra en la UI en vez de
/// disimularse: un hook que no puede correr donde lo asignaste tiene que
/// decirlo, no fallar en silencio.
enum HookEvent {
  sessionStart(
    alias: 'SessionStart',
    label: 'Al empezar la sesión',
    detail: 'Arranque, resume, clear o después de compactar.',
    matcherHint: 'startup, resume, clear, compact',
  ),
  sessionEnd(
    alias: 'SessionEnd',
    label: 'Al terminar la sesión',
    detail: 'Informativo: no puede frenar nada.',
    blocking: false,
  ),
  userPromptSubmit(
    alias: 'UserPromptSubmit',
    label: 'Al enviar un mensaje',
    detail: 'Antes de que el modelo lo vea. Puede frenarlo.',
  ),
  preToolUse(
    alias: 'PreToolUse',
    label: 'Antes de usar una herramienta',
    detail:
        'El lugar donde se bloquea de verdad: corre antes de CADA '
        'herramienta, así que conviene que sea rápido.',
    matcherHint: 'Bash, Edit|Write, mcp__.*',
  ),
  permissionRequest(
    alias: 'PermissionRequest',
    label: 'Cuando hace falta un permiso',
    detail: 'Permite conceder o denegar sin preguntarle al usuario.',
    matcherHint: 'Bash, Edit|Write',
  ),
  postToolUse(
    alias: 'PostToolUse',
    label: 'Después de usar una herramienta',
    detail:
        'Para reaccionar: formatear lo que se escribió, correr tests. No '
        'deshace lo que ya pasó.',
    matcherHint: 'Bash, Edit|Write',
  ),
  preCompact(
    alias: 'PreCompact',
    label: 'Antes de compactar el contexto',
    matcherHint: 'manual, auto',
  ),
  postCompact(
    alias: 'PostCompact',
    label: 'Después de compactar',
    blocking: false,
    matcherHint: 'manual, auto',
  ),
  subagentStart(
    alias: 'SubagentStart',
    label: 'Al lanzar un subagente',
    blocking: false,
  ),
  subagentStop(alias: 'SubagentStop', label: 'Cuando termina un subagente'),
  stop(
    alias: 'Stop',
    label: 'Cuando el agente termina de responder',
    detail:
        'Puede pedir que siga trabajando. Ojo con los bucles: un hook que '
        'siempre pide continuar no deja terminar nunca.',
  ),

  // ── de acá para abajo, solo claude ──────────────────────────────────
  notification(
    alias: 'Notification',
    label: 'Cuando el CLI notifica algo',
    providers: {HookProvider.claude},
    blocking: false,
    matcherHint: 'permission_prompt, idle_prompt',
  ),
  permissionDenied(
    alias: 'PermissionDenied',
    label: 'Cuando se deniega un permiso',
    providers: {HookProvider.claude},
    blocking: false,
  ),
  postToolUseFailure(
    alias: 'PostToolUseFailure',
    label: 'Cuando una herramienta falla',
    providers: {HookProvider.claude},
    matcherHint: 'Bash, Edit|Write',
  ),
  fileChanged(
    alias: 'FileChanged',
    label: 'Cuando cambia un archivo vigilado',
    providers: {HookProvider.claude},
    blocking: false,
    matcherHint: '.env|.envrc',
  ),
  instructionsLoaded(
    alias: 'InstructionsLoaded',
    label: 'Cuando se carga un CLAUDE.md',
    providers: {HookProvider.claude},
    blocking: false,
  ),
  stopFailure(
    alias: 'StopFailure',
    label: 'Cuando el turno corta por error de API',
    providers: {HookProvider.claude},
    blocking: false,
    matcherHint: 'rate_limit, overloaded',
  );

  const HookEvent({
    required this.alias,
    required this.label,
    this.detail = '',
    this.matcherHint = '',
    this.providers = const {HookProvider.claude, HookProvider.codex},
    this.blocking = true,
  });

  /// El nombre exacto del evento en la configuración de los CLIs. Es lo que
  /// persiste y lo que viaja en un respaldo.
  final String alias;

  final String label;

  /// Una línea sobre cuándo conviene usarlo, para el formulario.
  final String detail;

  /// Qué filtra el matcher en este evento, como ejemplo para el formulario.
  final String matcherHint;

  /// Qué CLIs lo conocen.
  final Set<HookProvider> providers;

  /// Si un hook en este evento puede frenar lo que está por pasar. Los que
  /// no pueden son informativos, y el formulario lo dice para que nadie
  /// espere un bloqueo que no va a ocurrir.
  final bool blocking;

  /// Los que corren en cualquier proveedor.
  bool get isPortable => providers.length > 1;

  bool runsOn(HookProvider provider) => providers.contains(provider);

  static HookEvent? tryFromAlias(String alias) {
    for (final event in values) {
      if (event.alias == alias) return event;
    }
    return null;
  }

  factory HookEvent.fromAlias(String alias) {
    final event = tryFromAlias(alias);
    if (event == null) {
      throw ArgumentError('Evento de hook desconocido: $alias');
    }
    return event;
  }

  /// Los portables primero y después los de claude, que es el orden en que
  /// se ofrecen: lo que anda en todos lados no debería costar más de
  /// encontrar que lo que anda en uno.
  static List<HookEvent> get ordered => [
    ...values.where((event) => event.isPortable),
    ...values.where((event) => !event.isPortable),
  ];
}
