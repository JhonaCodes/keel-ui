import 'package:flutter/foundation.dart';

import 'package:keel_ui/src/modules/boards/model/board.dart';

/// Cómo le fue a un paso.
class BoardStepResult {
  final BoardStepKind kind;

  /// Qué se disparó, con las plantillas ya resueltas. Es lo que mirás para
  /// entender por qué el servidor contestó lo que contestó.
  final String preview;

  final bool ok;

  /// Código HTTP, o código de salida del comando.
  final int status;

  final Duration elapsed;

  /// Cuerpo de la respuesta, o la salida estándar del comando.
  final String output;

  /// El error: cuerpo de un 4xx/5xx, stderr, o el mensaje de por qué ni
  /// siquiera se pudo intentar.
  final String error;

  final Map<String, String> headers;

  /// Lo que este paso dejó disponible para los que siguen.
  final Map<String, String> captured;

  const BoardStepResult({
    required this.kind,
    required this.preview,
    required this.ok,
    this.status = 0,
    this.elapsed = Duration.zero,
    this.output = '',
    this.error = '',
    this.headers = const {},
    this.captured = const {},
  });

  Map<String, dynamic> toJson() => {
    'kind': kind.alias,
    'preview': preview,
    'ok': ok,
    'status': status,
    'elapsedMs': elapsed.inMilliseconds,
    'output': output,
    'error': error,
    'headers': headers,
    'captured': captured,
  };

  factory BoardStepResult.fromJson(Map<String, dynamic> json) =>
      BoardStepResult(
        kind: BoardStepKind.fromAlias(json['kind'] as String? ?? 'http'),
        preview: json['preview'] as String? ?? '',
        ok: json['ok'] as bool? ?? false,
        status: json['status'] as int? ?? 0,
        elapsed: Duration(milliseconds: json['elapsedMs'] as int? ?? 0),
        output: json['output'] as String? ?? '',
        error: json['error'] as String? ?? '',
        headers: (json['headers'] as Map?)?.cast<String, String>() ?? const {},
        captured:
            (json['captured'] as Map?)?.cast<String, String>() ?? const {},
      );
}

/// Una corrida: qué se apretó, cuándo, y cómo fue paso por paso.
///
/// Se guardan las últimas de cada tablero porque probar es comparar: "antes
/// devolvía 201 y ahora 500" es la mitad del diagnóstico. **No viajan en el
/// respaldo**: lo que te contestó tu API de desarrollo no le sirve a nadie
/// más, igual que un probe de MCP o una toma de tarea.
class BoardRun {
  final String id;
  final String boardId;
  final String actionId;
  final String actionLabel;
  final DateTime at;
  final List<BoardStepResult> steps;

  const BoardRun({
    required this.id,
    required this.boardId,
    required this.actionId,
    required this.actionLabel,
    required this.at,
    this.steps = const [],
  });

  bool get ok => steps.isNotEmpty && steps.every((step) => step.ok);

  Duration get elapsed =>
      steps.fold(Duration.zero, (total, step) => total + step.elapsed);

  /// El paso que cortó la corrida, o null si terminó entera.
  BoardStepResult? get failure => steps.where((step) => !step.ok).firstOrNull;

  Map<String, dynamic> toJson() => {
    'id': id,
    'boardId': boardId,
    'actionId': actionId,
    'actionLabel': actionLabel,
    'at': at.toIso8601String(),
    'steps': [for (final step in steps) step.toJson()],
  };

  factory BoardRun.fromJson(Map<String, dynamic> json) => BoardRun(
    id: json['id'] as String,
    boardId: json['boardId'] as String,
    actionId: json['actionId'] as String? ?? '',
    actionLabel: json['actionLabel'] as String? ?? '',
    at: DateTime.parse(json['at'] as String),
    steps: [
      for (final step in json['steps'] as List? ?? const [])
        BoardStepResult.fromJson((step as Map).cast<String, dynamic>()),
    ],
  );
}

class BoardsState {
  final List<Board> boards;

  /// Las últimas corridas de cada tablero, por id de tablero, de la más
  /// nueva a la más vieja.
  final Map<String, List<BoardRun>> runs;

  /// Los tableros que están corriendo una acción ahora.
  final Set<String> running;

  const BoardsState({
    this.boards = const [],
    this.runs = const {},
    this.running = const {},
  });

  List<Board> forProject(String projectId) => [
    for (final board in boards)
      if (board.projectId == projectId) board,
  ];

  BoardsState copyWith({
    List<Board>? boards,
    Map<String, List<BoardRun>>? runs,
    Set<String>? running,
  }) => BoardsState(
    boards: boards ?? this.boards,
    runs: runs ?? this.runs,
    running: running ?? this.running,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BoardsState &&
          listEquals(boards, other.boards) &&
          setEquals(running, other.running) &&
          mapEquals(
            {for (final entry in runs.entries) entry.key: entry.value.length},
            {
              for (final entry in other.runs.entries)
                entry.key: entry.value.length,
            },
          );

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(boards), Object.hashAll(running), runs.length);

  @override
  String toString() =>
      'BoardsState(boards: ${boards.length}, running: ${running.length})';
}
