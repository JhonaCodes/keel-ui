part of '../fault_journal.dart';

/// Cuánto texto se guarda de una falla. Un stack de Flutter entero pasa los
/// veinte mil caracteres y las últimas cincuenta líneas son siempre el
/// mismo andamiaje del framework.
const _kDetailCap = 4000;

/// Algo que se rompió, con lo que hace falta para entender qué fue.
class Fault {
  final String id;

  /// La primera vez que pasó.
  final DateTime at;

  /// La última. Con [count] en 1 es la misma que [at].
  final DateTime lastAt;

  /// Cuántas veces seguidas pasó lo mismo.
  final int count;

  /// De qué parte de la app salió: `integrations/system_vault`,
  /// `modules/projects`, `interfaz`. Sale del stack, no lo escribe nadie a
  /// mano — así lo tienen también las cuarenta y pico de llamadas a `Log.e`
  /// que ya existían.
  final String where;

  /// Una línea. Es lo que se lee en la lista.
  final String message;

  /// Todo lo demás: la excepción entera y el stack, recortados.
  final String detail;

  /// Qué estaba pasando, en palabras: `proyecto «con-app» · sesión «...»`.
  /// Vacío cuando la falla no vino de un lugar identificable.
  ///
  /// Son palabras y no ids a propósito: guardar el id invita a poner un
  /// botón que navegue, y para eso el diario tendría que conocer a los
  /// proyectos y a la navegación — que ya lo conocen a él.
  final String context;

  final bool seen;

  const Fault({
    required this.id,
    required this.at,
    required this.lastAt,
    required this.message,
    this.count = 1,
    this.where = '',
    this.detail = '',
    this.context = '',
    this.seen = false,
  });

  /// Si esta falla es "la misma" que la que se está anotando. La comparación
  /// es por texto y origen: dos excepciones distintas del mismo archivo son
  /// dos fallas, y la misma excepción dos veces es una.
  bool sameAs(String otherMessage, String otherWhere) =>
      message == otherMessage && where == otherWhere;

  /// Volvió a pasar.
  Fault again(DateTime now) => Fault(
    id: id,
    at: at,
    lastAt: now,
    count: count + 1,
    where: where,
    message: message,
    detail: detail,
    context: context,
    // Repetirse la vuelve a poner sin ver: que ya hayas leído la primera no
    // dice nada sobre que siga pasando.
    seen: false,
  );

  Fault asSeen() => seen
      ? this
      : Fault(
          id: id,
          at: at,
          lastAt: lastAt,
          count: count,
          where: where,
          message: message,
          detail: detail,
          context: context,
          seen: true,
        );

  /// Lo que se copia al portapapeles: todo, en texto plano, listo para
  /// pegarlo en una sesión y preguntarle a un agente qué pasó.
  String get asText => [
    message,
    if (where.isNotEmpty) 'Dónde: $where',
    if (context.isNotEmpty) 'Contexto: $context',
    'Cuándo: ${lastAt.toIso8601String()}${count > 1 ? ' (×$count)' : ''}',
    if (detail.isNotEmpty) '\n$detail',
  ].join('\n');

  Map<String, dynamic> toJson() => {
    'id': id,
    'at': at.toIso8601String(),
    'lastAt': lastAt.toIso8601String(),
    'count': count,
    'where': where,
    'message': message,
    'detail': detail,
    'context': context,
    'seen': seen,
  };

  factory Fault.fromJson(Map<String, dynamic> json) {
    final at = DateTime.parse(json['at'] as String);
    return Fault(
      id: json['id'] as String,
      at: at,
      lastAt: DateTime.tryParse(json['lastAt'] as String? ?? '') ?? at,
      count: json['count'] as int? ?? 1,
      where: json['where'] as String? ?? '',
      message: json['message'] as String? ?? '',
      detail: json['detail'] as String? ?? '',
      context: json['context'] as String? ?? '',
      seen: json['seen'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Fault &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          count == other.count &&
          seen == other.seen;

  @override
  int get hashCode => Object.hash(id, count, seen);

  @override
  String toString() => 'Fault($where: $message ×$count)';
}

class FaultJournalState {
  /// De la más nueva a la más vieja.
  final List<Fault> faults;

  const FaultJournalState({this.faults = const []});

  /// Cuántas no miraste. Es el número del punto rojo.
  int get unseen => faults.where((fault) => !fault.seen).length;

  Fault? get newest => faults.firstOrNull;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FaultJournalState && listEquals(faults, other.faults);

  @override
  int get hashCode => Object.hashAll(faults);

  @override
  String toString() =>
      'FaultJournalState(${faults.length} fallas, $unseen sin ver)';
}

class FaultJournalRepository {
  static const _prefix = 'fault_';

  Future<List<Fault>> load() async {
    final records = await LocalDatabase.getAllWithPrefix(_prefix);
    return records.map(Fault.fromJson).toList()
      ..sort((a, b) => b.lastAt.compareTo(a.lastAt));
  }

  /// Escribe UNA. El diario es append-only salvo por el contador de
  /// repeticiones y la marca de visto, que reescriben esa misma fila.
  Future<void> save(Fault fault) =>
      LocalDatabase.put('$_prefix${fault.id}', fault.toJson());

  Future<void> remove(String id) => LocalDatabase.delete('$_prefix$id');

  Future<void> clear() async {
    final records = await LocalDatabase.entriesWithPrefix(_prefix);
    for (final record in records) {
      await LocalDatabase.delete(record.key);
    }
  }
}

/// La primera línea con algo escrito, recortada. Es lo que entra en la lista.
String _oneLine(String text) {
  for (final line in text.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;
    return trimmed.length > 200 ? '${trimmed.substring(0, 200)}…' : trimmed;
  }
  return '';
}

String _capped(String text) {
  final trimmed = text.trim();
  if (trimmed.length <= _kDetailCap) return trimmed;
  return '${trimmed.substring(0, _kDetailCap)}\n… (recortado)';
}
