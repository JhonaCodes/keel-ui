/// Cuánto consumió cada turno, guardado para poder mirarlo después.
///
/// Hasta ahora los contadores del CLI se leían para calcular el porcentaje
/// de contexto y se tiraban: el porcentaje es un termómetro del momento, no
/// una serie. Por eso **el historial empieza el día que esto se instala** y
/// ningún gráfico puede mostrar lo de antes. Vale decirlo en la pantalla en
/// vez de dibujar un vacío que parece un bug.
///
/// Es el consumo de KEEL, no el de tu cuenta: la app solo puede sumar lo que
/// salió por acá, y lo que gastaste en una terminal aparte no lo ve.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:logger_rs/logger_rs.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/src/core/services/local_database.dart';
import 'package:keel_ui/src/shared/shared.dart';

part 'src/usage_entry.dart';
part 'src/usage_rollup.dart';

class UsageLedgerViewModel extends ViewModel<UsageLedgerState> {
  UsageLedgerViewModel() : super(const UsageLedgerState());

  /// Cuánto se guarda. Noventa días es lo que hace falta para ver una
  /// tendencia; más allá de eso son registros que nadie mira y una base que
  /// crece sola.
  static const retention = Duration(days: 90);

  UsageLedgerRepository get _repository => UsageLedgerRepository();

  Future<void>? _ready;
  Future<void> get ready => _ready ??= _loadPersisted();

  @override
  void init() {
    if (_ready == null) updateSilently(const UsageLedgerState());
    unawaited(ready);
  }

  Future<void> _loadPersisted() async {
    try {
      final entries = await _repository.load();
      updateState(UsageLedgerState(entries: entries));
    } catch (error) {
      Log.e('Failed to load the usage ledger', error: error);
    }
  }

  /// Anota un turno. Se llama y no se espera: el ledger no puede meterse en
  /// el camino de un mensaje.
  Future<void> record({
    required String provider,
    required String model,
    required String profileId,
    required int inputTokens,
    required int outputTokens,
    required int cacheReadTokens,
    required int cacheCreationTokens,
    required bool tokensReported,
    required int durationMs,
    required double costUsd,
    required bool costReported,
    String projectId = '',
    String sessionId = '',
    String workNodeId = '',
    int contextUsedTokens = 0,
    int contextWindowTokens = 0,
  }) async {
    await ready;

    // Un turno de codex se anota igual, con todos los contadores en cero:
    // su CLI no informa nada, y eso NO es lo mismo que no haber gastado. Sin
    // la fila, la pantalla diría que codex no corrió; con la fila en cero
    // diría que salió gratis. Anotarlo es lo que deja decir la verdad —"31
    // turnos, sin medición"— más adelante.
    final entry = UsageEntry(
      id: generateUuidV4(),
      at: DateTime.now(),
      provider: provider,
      model: model,
      profileId: profileId,
      projectId: projectId,
      sessionId: sessionId,
      workNodeId: workNodeId,
      inputTokens: inputTokens,
      outputTokens: outputTokens,
      cacheReadTokens: cacheReadTokens,
      cacheCreationTokens: cacheCreationTokens,
      tokensReported: tokensReported,
      durationMs: durationMs,
      costUsd: costUsd,
      costReported: costReported,
      contextUsedTokens: contextUsedTokens,
      contextWindowTokens: contextWindowTokens,
    );

    final cutoff = DateTime.now().subtract(retention);
    final kept = [
      for (final existing in data.entries)
        if (existing.at.isAfter(cutoff)) existing,
      entry,
    ];
    final dropped = data.entries.length + 1 - kept.length;

    updateState(UsageLedgerState(entries: kept));
    await _repository.save(entry);
    if (dropped > 0) await _repository.prune(cutoff);
  }
}

mixin UsageLedgerService {
  static final ReactiveNotifier<UsageLedgerViewModel> instance =
      ReactiveNotifier<UsageLedgerViewModel>(() => UsageLedgerViewModel());
}
