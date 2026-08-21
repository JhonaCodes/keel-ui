enum AgentToolKind {
  bash,
  read,
  write,
  edit,
  multiEdit,
  grep,
  glob,
  webFetch,
  webSearch,
  task,
  todoWrite,
  notebookEdit,
  bashOutput,
  killShell,
  exitPlanMode,
  other,
}

class AgentToolActivity {
  final AgentToolKind kind;
  final String label;

  const AgentToolActivity({required this.kind, required this.label});

  factory AgentToolActivity.fromToolUse(
    String toolName,
    Map<String, dynamic>? input,
  ) {
    final kind = _kindFor(toolName);
    return AgentToolActivity(
      kind: kind,
      label: _labelFor(kind, toolName, input),
    );
  }

  static AgentToolKind _kindFor(String toolName) => switch (toolName) {
    'Bash' => AgentToolKind.bash,
    'Read' => AgentToolKind.read,
    'Write' => AgentToolKind.write,
    'Edit' => AgentToolKind.edit,
    'MultiEdit' => AgentToolKind.multiEdit,
    'Grep' => AgentToolKind.grep,
    'Glob' => AgentToolKind.glob,
    'WebFetch' => AgentToolKind.webFetch,
    'WebSearch' => AgentToolKind.webSearch,
    'Task' => AgentToolKind.task,
    'TodoWrite' => AgentToolKind.todoWrite,
    'NotebookEdit' => AgentToolKind.notebookEdit,
    'BashOutput' => AgentToolKind.bashOutput,
    'KillShell' => AgentToolKind.killShell,
    'ExitPlanMode' => AgentToolKind.exitPlanMode,
    _ => AgentToolKind.other,
  };

  static String _labelFor(
    AgentToolKind kind,
    String toolName,
    Map<String, dynamic>? input,
  ) {
    String? str(String key) => input?[key] as String?;

    return switch (kind) {
      AgentToolKind.bash => 'Ejecutando: ${str('command') ?? 'comando'}',
      AgentToolKind.read => 'Leyendo ${str('file_path') ?? 'archivo'}',
      AgentToolKind.write => 'Escribiendo ${str('file_path') ?? 'archivo'}',
      AgentToolKind.edit => 'Editando ${str('file_path') ?? 'archivo'}',
      AgentToolKind.multiEdit => 'Editando ${str('file_path') ?? 'archivo'}',
      AgentToolKind.grep => 'Buscando "${str('pattern') ?? ''}"',
      AgentToolKind.glob => 'Buscando archivos ${str('pattern') ?? ''}',
      AgentToolKind.webFetch => 'Abriendo ${str('url') ?? 'sitio web'}',
      AgentToolKind.webSearch => 'Buscando en la web: ${str('query') ?? ''}',
      AgentToolKind.task => 'Delegando tarea a un subagente',
      AgentToolKind.todoWrite => 'Actualizando lista de tareas',
      AgentToolKind.notebookEdit =>
        'Editando notebook ${str('notebook_path') ?? ''}',
      AgentToolKind.bashOutput => 'Leyendo salida del proceso',
      AgentToolKind.killShell => 'Deteniendo proceso',
      AgentToolKind.exitPlanMode => 'Preparando plan',
      AgentToolKind.other => 'Usando $toolName',
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AgentToolActivity &&
          runtimeType == other.runtimeType &&
          kind == other.kind &&
          label == other.label;

  @override
  int get hashCode => Object.hash(kind, label);

  @override
  String toString() => 'AgentToolActivity(kind: $kind, label: $label)';
}
