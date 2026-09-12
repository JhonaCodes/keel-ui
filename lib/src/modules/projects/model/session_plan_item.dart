/// Un punto del plan de trabajo de una sesión.
///
/// El plan lo escribe el miembro que planifica, en su paso, y lo marca quien
/// lo cumple al cerrar el suyo. Vive aparte del hilo a propósito: escrito
/// como un mensaje más, a los diez turnos está enterrado y no hay dónde
/// mirar qué falta — que es justo la pregunta que uno se hace cuando vuelve
/// a una sesión.
class SessionPlanItem {
  final String id;
  final String text;
  final bool done;

  /// El PUESTO al que le toca, tal como lo nombra un paso del workflow
  /// (`implementador`, `revisor`). Lo escribe quien planifica.
  ///
  /// Es un rol y no un handle a propósito, igual que en los pasos: así el
  /// mismo plan sirve en el proyecto de Flutter y en la de Rust, donde ese
  /// puesto lo ocupa otro agente. Null cuando el punto no se le asignó a
  /// nadie en particular.
  final String? ownerRole;

  /// Quién lo marcó. Null mientras esté pendiente.
  final String? doneByProfileId;

  /// Lo sacaste vos de la mesa: no se va a hacer, y no cuenta como cumplido.
  ///
  /// Es un tercer estado y no un `done` piadoso. Marcarlo cumplido sería
  /// mentirle al hilo, al chequeo de cierre y al que lea la sesión en un mes;
  /// borrarlo directamente perdería que ALGUIEN decidió no hacerlo, que suele
  /// ser lo más importante del plan.
  final bool discarded;

  /// Si todavía cuenta como trabajo por hacer. Lo cumplido y lo descartado no
  /// cuentan, y esa es la única pregunta que le hace el resto del sistema.
  bool get pending => !done && !discarded;

  const SessionPlanItem({
    required this.id,
    required this.text,
    this.done = false,
    this.ownerRole,
    this.doneByProfileId,
    this.discarded = false,
  });

  SessionPlanItem copyWith({
    String? text,
    bool? done,
    String? ownerRole,
    String? doneByProfileId,
    bool? discarded,
    bool clearDoneBy = false,
  }) {
    return SessionPlanItem(
      id: id,
      text: text ?? this.text,
      done: done ?? this.done,
      ownerRole: ownerRole ?? this.ownerRole,
      doneByProfileId: clearDoneBy
          ? null
          : doneByProfileId ?? this.doneByProfileId,
      discarded: discarded ?? this.discarded,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'done': done,
    'ownerRole': ownerRole,
    'doneByProfileId': doneByProfileId,
    'discarded': discarded,
  };

  factory SessionPlanItem.fromJson(Map<String, dynamic> json) {
    return SessionPlanItem(
      id: json['id'] as String,
      text: json['text'] as String? ?? '',
      done: json['done'] as bool? ?? false,
      ownerRole: json['ownerRole'] as String?,
      doneByProfileId: json['doneByProfileId'] as String?,
      discarded: json['discarded'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionPlanItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          text == other.text &&
          done == other.done &&
          discarded == other.discarded &&
          doneByProfileId == other.doneByProfileId;

  @override
  int get hashCode => Object.hash(id, text, done, discarded, doneByProfileId);

  @override
  String toString() =>
      'SessionPlanItem($id, done: $done, "${text.length > 30 ? '${text.substring(0, 30)}…' : text}")';
}

/// Un punto tal como lo escribe quien planifica: el texto y, si lo asignó, el
/// puesto que tiene que hacerlo. El id y el estado los pone la app.
typedef PlanEntry = ({String text, String? ownerRole});

/// Resumen del plan para mostrar sin recorrer la lista en la UI.
extension SessionPlanSummary on List<SessionPlanItem> {
  /// Mapa de alcance cuando un cliente antiguo no envía la lógica Mermaid.
  /// No inventa dependencias entre puntos independientes.
  String get responsibilityDiagram {
    final lines = <String>['flowchart TD', '  plan["Plan de trabajo"]'];
    for (var index = 0; index < length; index++) {
      final item = this[index];
      final label =
          '${item.text} — ${item.ownerRole ?? 'Responsable por asignar'}'
              .replaceAll('&', '&amp;')
              .replaceAll('"', '&quot;')
              .replaceAll('<', '&lt;')
              .replaceAll('>', '&gt;')
              .replaceAll('`', '')
              .replaceAll('\n', ' ');
      lines.add('  plan --> p$index["$label"]');
    }
    return lines.join('\n');
  }

  int get doneCount => where((item) => item.done).length;

  int get discardedCount => where((item) => item.discarded).length;

  /// Los que todavía son trabajo. Es lo que mira el cierre de la sesión.
  Iterable<SessionPlanItem> get pending => where((item) => item.pending);

  /// El primer punto pendiente — el que se está haciendo ahora, o el que
  /// sigue. Null cuando no queda nada por hacer.
  SessionPlanItem? get current => pending.firstOrNull;

  /// Nada por hacer. Un punto descartado cierra el plan igual que uno
  /// cumplido: la diferencia está en el registro, no en si falta trabajo.
  bool get isComplete => isNotEmpty && pending.isEmpty;
}
