/// Un punto del plan de trabajo de una tarea.
///
/// El plan lo escribe el miembro que planifica, en su paso, y lo marca quien
/// lo cumple al cerrar el suyo. Vive aparte del hilo a propósito: escrito
/// como un mensaje más, a los diez turnos está enterrado y no hay dónde
/// mirar qué falta — que es justo la pregunta que uno se hace cuando vuelve
/// a una tarea.
class TaskPlanItem {
  final String id;
  final String text;
  final bool done;

  /// Quién lo marcó. Null mientras esté pendiente.
  final String? doneByProfileId;

  const TaskPlanItem({
    required this.id,
    required this.text,
    this.done = false,
    this.doneByProfileId,
  });

  TaskPlanItem copyWith({
    String? text,
    bool? done,
    String? doneByProfileId,
    bool clearDoneBy = false,
  }) {
    return TaskPlanItem(
      id: id,
      text: text ?? this.text,
      done: done ?? this.done,
      doneByProfileId: clearDoneBy
          ? null
          : doneByProfileId ?? this.doneByProfileId,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'done': done,
    'doneByProfileId': doneByProfileId,
  };

  factory TaskPlanItem.fromJson(Map<String, dynamic> json) {
    return TaskPlanItem(
      id: json['id'] as String,
      text: json['text'] as String? ?? '',
      done: json['done'] as bool? ?? false,
      doneByProfileId: json['doneByProfileId'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskPlanItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          text == other.text &&
          done == other.done &&
          doneByProfileId == other.doneByProfileId;

  @override
  int get hashCode => Object.hash(id, text, done, doneByProfileId);

  @override
  String toString() =>
      'TaskPlanItem($id, done: $done, "${text.length > 30 ? '${text.substring(0, 30)}…' : text}")';
}

/// Resumen del plan para mostrar sin recorrer la lista en la UI.
extension TaskPlanSummary on List<TaskPlanItem> {
  int get doneCount => where((item) => item.done).length;

  /// El primer punto pendiente — el que se está haciendo ahora, o el que
  /// sigue. Null cuando el plan está completo.
  TaskPlanItem? get current =>
      where((item) => !item.done).firstOrNull;

  bool get isComplete => isNotEmpty && doneCount == length;
}
