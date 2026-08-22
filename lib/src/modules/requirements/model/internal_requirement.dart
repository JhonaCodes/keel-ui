import 'package:flutter/foundation.dart';

/// En qué anda un requerimiento.
///
/// El orden importa: es el camino normal, y quién puede moverlo en cada
/// tramo no es simétrico. Del lado del destino se toma, se evalúa y se
/// contesta; **cerrar es del origen y de nadie más**.
enum RequirementStatus {
  abierto('abierto', 'Abierto'),
  tomado('tomado', 'Tomado'),
  enCurso('en-curso', 'En curso'),

  /// El destino dio por hecho su lado y pidió el cierre, con justificación.
  /// Todavía no está cerrado: eso lo decide quien lo abrió.
  respondido('respondido', 'Cierre solicitado'),

  cerrado('cerrado', 'Cerrado'),
  cancelado('cancelado', 'Cancelado'),

  /// El proyecto destino existe pero el usuario no lo mantiene. Queda
  /// anotado y a la vista, y no lo toma nadie: lo resuelve el usuario por
  /// afuera.
  externo('externo', 'Externo');

  const RequirementStatus(this.alias, this.label);

  final String alias;
  final String label;

  static RequirementStatus fromAlias(String value) =>
      values.where((status) => status.alias == value).firstOrNull ??
      RequirementStatus.abierto;

  /// Si todavía espera un movimiento de alguien.
  bool get isOpen => this != cerrado && this != cancelado;

  /// De qué lado está la pelota.
  bool get waitsOnTarget =>
      this == abierto || this == tomado || this == enCurso;
}

/// Qué dijo el destino después de mirarlo contra su propio roadmap.
enum RequirementVerdictKind {
  viable('viable', 'Viable'),
  bloqueado('bloqueado', 'Bloqueado'),
  noViable('no-viable', 'No viable'),

  /// El caso que un ticket no sabe contar: el trabajo existe, pero con otra
  /// forma que la que se pidió.
  yaResuelto('ya-resuelto', 'Ya resuelto, de otra forma');

  const RequirementVerdictKind(this.alias, this.label);

  final String alias;
  final String label;

  static RequirementVerdictKind fromAlias(String value) =>
      values.where((kind) => kind.alias == value).firstOrNull ??
      RequirementVerdictKind.viable;
}

/// Quién escribe. Son tres y no dos: vos también entrás al hilo, y lo que
/// escribís lo ven los dos lados.
enum RequirementSide {
  origen('origen', 'Origen'),
  destino('destino', 'Destino'),
  usuario('usuario', 'Vos');

  const RequirementSide(this.alias, this.label);

  final String alias;
  final String label;

  static RequirementSide fromAlias(String value) =>
      values.where((side) => side.alias == value).firstOrNull ??
      RequirementSide.usuario;
}

enum RequirementEntryKind {
  pedido('pedido'),
  evaluacion('evaluacion'),
  avance('avance'),
  respuesta('respuesta'),
  correccion('correccion'),
  cierre('cierre');

  const RequirementEntryKind(this.alias);

  final String alias;

  static RequirementEntryKind fromAlias(String value) =>
      values.where((kind) => kind.alias == value).firstOrNull ??
      RequirementEntryKind.respuesta;
}

/// El dictamen del destino, con lo que hay que hacer antes si no se puede ya.
class RequirementVerdict {
  const RequirementVerdict({
    required this.kind,
    required this.reason,
    this.prerequisites = const [],
  });

  final RequirementVerdictKind kind;
  final String reason;

  /// Lo que va primero, nombrado. Un "bloqueado" sin esto no le sirve a
  /// nadie: el que pide no puede ni estimar cuándo volver a preguntar.
  final List<String> prerequisites;

  Map<String, dynamic> toJson() => {
    'kind': kind.alias,
    'reason': reason,
    'prerequisites': prerequisites,
  };

  factory RequirementVerdict.fromJson(Map<String, dynamic> json) =>
      RequirementVerdict(
        kind: RequirementVerdictKind.fromAlias(json['kind'] as String? ?? ''),
        reason: json['reason'] as String? ?? '',
        prerequisites:
            (json['prerequisites'] as List?)?.cast<String>() ?? const [],
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RequirementVerdict &&
          kind == other.kind &&
          reason == other.reason &&
          listEquals(prerequisites, other.prerequisites);

  @override
  int get hashCode => Object.hash(kind, reason, Object.hashAll(prerequisites));
}

/// Una entrada del hilo compartido.
class RequirementEntry {
  const RequirementEntry({
    required this.id,
    required this.side,
    required this.kind,
    required this.text,
    required this.createdAt,
    this.authorHandle,
  });

  final String id;
  final RequirementSide side;
  final RequirementEntryKind kind;
  final String text;
  final DateTime createdAt;

  /// Null cuando lo escribiste vos: no sos un agente.
  final String? authorHandle;

  Map<String, dynamic> toJson() => {
    'id': id,
    'side': side.alias,
    'kind': kind.alias,
    'text': text,
    'createdAt': createdAt.toIso8601String(),
    'authorHandle': authorHandle,
  };

  factory RequirementEntry.fromJson(Map<String, dynamic> json) =>
      RequirementEntry(
        id: json['id'] as String,
        side: RequirementSide.fromAlias(json['side'] as String? ?? ''),
        kind: RequirementEntryKind.fromAlias(json['kind'] as String? ?? ''),
        text: json['text'] as String? ?? '',
        createdAt: DateTime.parse(json['createdAt'] as String),
        authorHandle: json['authorHandle'] as String?,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RequirementEntry &&
          id == other.id &&
          side == other.side &&
          kind == other.kind &&
          text == other.text &&
          createdAt == other.createdAt &&
          authorHandle == other.authorHandle;

  @override
  int get hashCode =>
      Object.hash(id, side, kind, text, createdAt, authorHandle);
}

/// Lo que un proyecto le pide a otro.
///
/// **Es lo único que cruza la frontera entre dos proyectos.** El hilo de la
/// sesión que lo abrió, su plan, su `TASKS/`, su carpeta y sus reglas se
/// quedan de su lado; del otro lado entra esto y nada más. Esa frontera es lo
/// que hace que dos proyectos puedan pedirse cosas sin ensuciarse el contexto.
class InternalRequirement {
  const InternalRequirement({
    required this.id,
    required this.code,
    required this.title,
    required this.fromProjectId,
    required this.toProjectId,
    required this.need,
    required this.context,
    required this.openedByHandle,
    required this.openedInSessionId,
    required this.createdAt,
    required this.updatedAt,
    this.blocking = false,
    this.status = RequirementStatus.abierto,
    this.verdict,
    this.thread = const [],
    this.takenByHandle,
    this.takenInSessionId,
  });

  final String id;

  /// `REQ-0007`. Es la identidad que se puede decir en voz alta, y la clave
  /// con la que el respaldo fusiona.
  final String code;

  final String title;

  final String fromProjectId;
  final String toProjectId;

  /// Qué necesita.
  final String need;

  /// Qué hicieron y por qué lo necesitan. Es la mitad que hace que el otro
  /// lado pueda decidir sin preguntar tres veces.
  final String context;

  /// Si frena a quien lo pide.
  final bool blocking;

  final String openedByHandle;
  final String openedInSessionId;

  final String? takenByHandle;
  final String? takenInSessionId;

  final RequirementStatus status;
  final RequirementVerdict? verdict;
  final List<RequirementEntry> thread;

  final DateTime createdAt;
  final DateTime updatedAt;

  InternalRequirement copyWith({
    String? title,
    String? need,
    String? context,
    bool? blocking,
    RequirementStatus? status,
    RequirementVerdict? verdict,
    List<RequirementEntry>? thread,
    String? takenByHandle,
    String? takenInSessionId,
    DateTime? updatedAt,
  }) => InternalRequirement(
    id: id,
    code: code,
    title: title ?? this.title,
    fromProjectId: fromProjectId,
    toProjectId: toProjectId,
    need: need ?? this.need,
    context: context ?? this.context,
    blocking: blocking ?? this.blocking,
    openedByHandle: openedByHandle,
    openedInSessionId: openedInSessionId,
    takenByHandle: takenByHandle ?? this.takenByHandle,
    takenInSessionId: takenInSessionId ?? this.takenInSessionId,
    status: status ?? this.status,
    verdict: verdict ?? this.verdict,
    thread: thread ?? this.thread,
    createdAt: createdAt,
    updatedAt: updatedAt ?? DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'code': code,
    'title': title,
    'fromProjectId': fromProjectId,
    'toProjectId': toProjectId,
    'need': need,
    'context': context,
    'blocking': blocking,
    'openedByHandle': openedByHandle,
    'openedInSessionId': openedInSessionId,
    'takenByHandle': takenByHandle,
    'takenInSessionId': takenInSessionId,
    'status': status.alias,
    'verdict': verdict?.toJson(),
    'thread': thread.map((entry) => entry.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory InternalRequirement.fromJson(
    Map<String, dynamic> json,
  ) => InternalRequirement(
    id: json['id'] as String,
    code: json['code'] as String? ?? '',
    title: json['title'] as String? ?? '',
    fromProjectId: json['fromProjectId'] as String? ?? '',
    toProjectId: json['toProjectId'] as String? ?? '',
    need: json['need'] as String? ?? '',
    context: json['context'] as String? ?? '',
    blocking: json['blocking'] as bool? ?? false,
    openedByHandle: json['openedByHandle'] as String? ?? '',
    openedInSessionId: json['openedInSessionId'] as String? ?? '',
    takenByHandle: json['takenByHandle'] as String?,
    takenInSessionId: json['takenInSessionId'] as String?,
    status: RequirementStatus.fromAlias(json['status'] as String? ?? ''),
    verdict: json['verdict'] == null
        ? null
        : RequirementVerdict.fromJson(
            (json['verdict'] as Map).cast<String, dynamic>(),
          ),
    thread: (json['thread'] as List? ?? const [])
        .map(
          (entry) =>
              RequirementEntry.fromJson((entry as Map).cast<String, dynamic>()),
        )
        .toList(),
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(
      json['updatedAt'] as String? ?? json['createdAt'] as String,
    ),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InternalRequirement &&
          id == other.id &&
          code == other.code &&
          title == other.title &&
          fromProjectId == other.fromProjectId &&
          toProjectId == other.toProjectId &&
          need == other.need &&
          context == other.context &&
          blocking == other.blocking &&
          openedByHandle == other.openedByHandle &&
          openedInSessionId == other.openedInSessionId &&
          takenByHandle == other.takenByHandle &&
          takenInSessionId == other.takenInSessionId &&
          status == other.status &&
          verdict == other.verdict &&
          listEquals(thread, other.thread) &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hash(
    id,
    code,
    title,
    fromProjectId,
    toProjectId,
    need,
    context,
    blocking,
    status,
    verdict,
    Object.hashAll(thread),
    createdAt,
    updatedAt,
  );

  @override
  String toString() => 'InternalRequirement($code, ${status.alias})';
}

class RequirementsState {
  const RequirementsState({this.requirements = const [], this.selectedId});

  final List<InternalRequirement> requirements;
  final String? selectedId;

  InternalRequirement? get selected {
    final id = selectedId;
    if (id == null) return null;
    return requirements.where((entry) => entry.id == id).firstOrNull;
  }

  RequirementsState copyWith({
    List<InternalRequirement>? requirements,
    String? selectedId,
    bool clearSelection = false,
  }) => RequirementsState(
    requirements: requirements ?? this.requirements,
    selectedId: clearSelection ? null : (selectedId ?? this.selectedId),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RequirementsState &&
          listEquals(requirements, other.requirements) &&
          selectedId == other.selectedId;

  @override
  int get hashCode => Object.hash(Object.hashAll(requirements), selectedId);
}
