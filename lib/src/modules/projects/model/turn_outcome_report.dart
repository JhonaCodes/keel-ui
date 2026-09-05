import 'package:flutter/foundation.dart';

import 'package:keel_ui/src/shared/shared.dart';

/// Cómo dice el agente que quedó su turno.
enum TurnOutcomeStatus {
  /// Terminó lo que el nodo pedía, con evidencia en el resumen.
  done,

  /// No pudo seguir por algo ajeno a su contrato (no compila, falta un
  /// archivo, un servicio caído). El motor lo registra como hallazgo.
  blocked,

  /// Necesita una decisión o un dato del usuario para seguir. El nodo queda
  /// pausado y aparece una decisión pendiente.
  needsUser,

  /// Le falta un permiso (una tool, una carpeta) para seguir.
  needsPermission,

  /// Fracasó en lo suyo: intentó y no salió.
  failed,
}

/// El veredicto de un nodo de auditoría.
enum TurnVerdict { go, noGo }

/// El bloque ```keel-outcome con el que un agente cierra su turno.
///
/// Es la única forma en que el motor sabe cómo terminó un turno. Antes se
/// deducía de «hubo texto o no»: un turno que trabajó por tools y calló
/// contaba como fallo, y un `VEREDICTO: NO-GO` escrito en prosa no lo leía
/// nadie (había 197 en la base sin efecto). El bloque se parsea; la prosa no.
@immutable
class TurnOutcomeReport {
  final TurnOutcomeStatus status;
  final String summary;
  final List<String> files;
  final String artifacts;
  final TurnVerdict? verdict;

  /// Id de una capacidad opcional que el agente pide activar.
  final String next;

  /// Solo con [TurnOutcomeStatus.needsUser] o [TurnOutcomeStatus.needsPermission].
  final String question;

  const TurnOutcomeReport({
    required this.status,
    this.summary = '',
    this.files = const [],
    this.artifacts = '',
    this.verdict,
    this.next = '',
    this.question = '',
  });

  Map<String, dynamic> toJson() => {
    'status': status.name,
    'summary': summary,
    'files': files,
    'artifacts': artifacts,
    'verdict': verdict?.name,
    'next': next,
    'question': question,
  };

  factory TurnOutcomeReport.fromJson(Map<String, dynamic> json) =>
      TurnOutcomeReport(
        status: TurnOutcomeStatus.values.byName(
          json['status'] as String? ?? TurnOutcomeStatus.done.name,
        ),
        summary: json['summary'] as String? ?? '',
        files: (json['files'] as List?)?.cast<String>() ?? const [],
        artifacts: json['artifacts'] as String? ?? '',
        verdict: switch (json['verdict'] as String?) {
          'go' => TurnVerdict.go,
          'noGo' => TurnVerdict.noGo,
          _ => null,
        },
        next: json['next'] as String? ?? '',
        question: json['question'] as String? ?? '',
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TurnOutcomeReport &&
          status == other.status &&
          summary == other.summary &&
          listEquals(files, other.files) &&
          artifacts == other.artifacts &&
          verdict == other.verdict &&
          next == other.next &&
          question == other.question;

  @override
  int get hashCode => Object.hash(
    status,
    summary,
    Object.hashAll(files),
    artifacts,
    verdict,
    next,
    question,
  );
}

const _outcomeKeys = {
  'status',
  'summary',
  'files',
  'artifacts',
  'verdict',
  'next',
  'question',
};

/// Lee el ÚLTIMO bloque ```keel-outcome válido de [text], o null si no hay.
///
/// El último y no el primero: un modelo que emite el bloque, sigue
/// trabajando y lo vuelve a emitir corregido dice la verdad al final. Un
/// bloque con un `status` que no existe no cuenta como bloque.
TurnOutcomeReport? parseKeelOutcome(String text) {
  final blocks = parseFencedBlocks(text, tag: 'keel-outcome', keys: _outcomeKeys);
  for (final fields in blocks.reversed) {
    final status = _statusFromName(fields['status']);
    if (status == null) continue;
    return TurnOutcomeReport(
      status: status,
      summary: fields['summary'] ?? '',
      files: (fields['files'] ?? '')
          .split(RegExp(r'[,\n]'))
          .map((entry) => entry.trim())
          .where((entry) => entry.isNotEmpty)
          .toList(),
      artifacts: fields['artifacts'] ?? '',
      verdict: _verdictFromName(fields['verdict']),
      next: (fields['next'] ?? '').trim(),
      question: fields['question'] ?? '',
    );
  }
  return null;
}

TurnOutcomeStatus? _statusFromName(String? raw) {
  final name = (raw ?? '').trim().toLowerCase().replaceAll('-', '_');
  return switch (name) {
    'done' => TurnOutcomeStatus.done,
    'blocked' => TurnOutcomeStatus.blocked,
    'needs_user' || 'needsuser' => TurnOutcomeStatus.needsUser,
    'needs_permission' || 'needspermission' => TurnOutcomeStatus.needsPermission,
    'failed' => TurnOutcomeStatus.failed,
    _ => null,
  };
}

TurnVerdict? _verdictFromName(String? raw) {
  final name = (raw ?? '').trim().toUpperCase().replaceAll(RegExp(r'[\s_-]'), '');
  return switch (name) {
    'GO' => TurnVerdict.go,
    'NOGO' => TurnVerdict.noGo,
    _ => null,
  };
}
