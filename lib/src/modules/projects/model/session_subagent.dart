import 'package:flutter/foundation.dart';

import 'package:keel_ui/src/modules/agents/model/agent_tool_activity.dart';

/// En qué anda un subagente. Corre en paralelo al [TurnPhase] del padre y por
/// eso es un enum aparte: mientras el hijo piensa, el padre está trabajando, y
/// el mapa tiene que poder decir las dos cosas a la vez.
enum SubagentPhase { thinking, working, writing, done, failed, unconfirmed }

/// Un subagente que un miembro abrió con `Task`, con nombre propio.
///
/// Hasta acá lo único que quedaba de una delegación era la frase «Delegando
/// tarea a un subagente» en la tira de actividad: ni qué se le pidió, ni qué
/// estaba haciendo, ni qué devolvió. Con `--forward-subagent-text` el CLI
/// manda su texto y su pensamiento marcados con el `tool_use_id` del `Task`,
/// que es [id], y esto es donde se acumulan.
///
/// Se guarda con la sesión, no en memoria: lo que un subagente devolvió es
/// historia del hilo igual que un mensaje, y cerrar la app no debería
/// borrarla. Lo único que no se puede guardar son sus tokens — el CLI los
/// suma al turno del padre y no los separa.
@immutable
class SessionSubagent {
  final String id;
  final String parentProfileId;

  /// Nodo de resolución que lo abrió, o null fuera de un caso. La relación
  /// no depende de una posición que pueda cambiar durante una reformulación.
  final String? parentWorkNodeId;
  final String? parentSubagentId;

  final String agentType;
  final String ask;
  final String prompt;
  final String reasoning;
  final String text;
  final String result;
  final SubagentPhase phase;
  final AgentToolActivity? activity;
  final List<AgentToolActivity> tools;
  final DateTime startedAt;
  final DateTime? finishedAt;

  const SessionSubagent({
    required this.id,
    required this.parentProfileId,
    required this.agentType,
    this.parentWorkNodeId,
    this.parentSubagentId,
    required this.ask,
    required this.prompt,
    required this.startedAt,
    this.reasoning = '',
    this.text = '',
    this.result = '',
    this.phase = SubagentPhase.thinking,
    this.activity,
    this.tools = const [],
    this.finishedAt,
  });

  bool get isRunning =>
      phase == .thinking || phase == .working || phase == .writing;

  Duration get elapsed => (finishedAt ?? DateTime.now()).difference(startedAt);

  SessionSubagent copyWith({
    String? reasoning,
    String? text,
    String? result,
    SubagentPhase? phase,
    AgentToolActivity? activity,
    List<AgentToolActivity>? tools,
    DateTime? finishedAt,
    bool clearActivity = false,
    bool clearFinishedAt = false,
  }) {
    return SessionSubagent(
      id: id,
      parentProfileId: parentProfileId,
      parentWorkNodeId: parentWorkNodeId,
      parentSubagentId: parentSubagentId,
      agentType: agentType,
      ask: ask,
      prompt: prompt,
      startedAt: startedAt,
      reasoning: reasoning ?? this.reasoning,
      text: text ?? this.text,
      result: result ?? this.result,
      phase: phase ?? this.phase,
      activity: clearActivity ? null : (activity ?? this.activity),
      tools: tools ?? this.tools,
      finishedAt: clearFinishedAt ? null : (finishedAt ?? this.finishedAt),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'parentProfileId': parentProfileId,
    'parentWorkNodeId': parentWorkNodeId,
    'parentSubagentId': parentSubagentId,
    'agentType': agentType,
    'ask': ask,
    'prompt': prompt,
    'reasoning': reasoning,
    'text': text,
    'result': result,
    'phase': phase.name,
    'tools': [for (final tool in tools) tool.toJson()],
    'startedAt': startedAt.toIso8601String(),
    'finishedAt': finishedAt?.toIso8601String(),
  };

  factory SessionSubagent.fromJson(Map<String, dynamic> json) {
    // Un subagente que quedó a medias cuando se cerró la app no está
    // corriendo: no hay proceso que lo devuelva. Se relee como cortado, para
    // que el mapa no muestre un halo latiendo sobre algo que ya no existe.
    final phase = SubagentPhase.values.byName(json['phase'] as String);
    return SessionSubagent(
      id: json['id'] as String,
      parentProfileId: json['parentProfileId'] as String,
      parentWorkNodeId: json['parentWorkNodeId'] as String?,
      parentSubagentId: json['parentSubagentId'] as String?,
      agentType: json['agentType'] as String,
      ask: json['ask'] as String,
      prompt: json['prompt'] as String,
      reasoning: json['reasoning'] as String,
      text: json['text'] as String,
      result: json['result'] as String,
      phase: switch (phase) {
        SubagentPhase.done => SubagentPhase.done,
        SubagentPhase.failed => SubagentPhase.failed,
        _ => SubagentPhase.unconfirmed,
      },
      tools: [
        for (final tool in json['tools'] as List)
          AgentToolActivity.fromJson(tool as Map<String, dynamic>),
      ],
      startedAt: DateTime.parse(json['startedAt'] as String),
      finishedAt: switch (json['finishedAt'] as String?) {
        null => DateTime.parse(json['startedAt'] as String),
        final value => DateTime.parse(value),
      },
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionSubagent &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          parentProfileId == other.parentProfileId &&
          parentWorkNodeId == other.parentWorkNodeId &&
          parentSubagentId == other.parentSubagentId &&
          agentType == other.agentType &&
          ask == other.ask &&
          prompt == other.prompt &&
          reasoning == other.reasoning &&
          text == other.text &&
          result == other.result &&
          phase == other.phase &&
          activity == other.activity &&
          listEquals(tools, other.tools) &&
          startedAt == other.startedAt &&
          finishedAt == other.finishedAt;

  @override
  int get hashCode => Object.hash(
    id,
    parentProfileId,
    parentWorkNodeId,
    parentSubagentId,
    agentType,
    ask,
    prompt,
    reasoning,
    text,
    result,
    phase,
    activity,
    Object.hashAll(tools),
    startedAt,
    finishedAt,
  );

  @override
  String toString() =>
      'SessionSubagent(id: $id, type: $agentType, phase: ${phase.name}, '
      'parent: $parentProfileId, tools: ${tools.length})';
}
