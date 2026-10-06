/// El ViewModel sobre `UsageLedgerStore` (keel_core).
library;

import 'dart:async';

import 'package:keel_core/integrations/usage_ledger/usage_ledger_data.dart';
import 'package:keel_core/integrations/usage_ledger/service/usage_ledger_store.dart';
import 'package:reactive_notifier/reactive_notifier.dart';
import 'package:keel_ui/src/core/services/store_mirror_view_model.dart';

class UsageLedgerViewModel extends StoreMirrorViewModel<UsageLedgerState> {
  UsageLedgerViewModel() : super(UsageLedgerStore.instance);

  Future<void> get ready => UsageLedgerStore.instance.ready;

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
  }) => UsageLedgerStore.instance.record(
    provider: provider,
    model: model,
    profileId: profileId,
    inputTokens: inputTokens,
    outputTokens: outputTokens,
    cacheReadTokens: cacheReadTokens,
    cacheCreationTokens: cacheCreationTokens,
    tokensReported: tokensReported,
    durationMs: durationMs,
    costUsd: costUsd,
    costReported: costReported,
    projectId: projectId,
    sessionId: sessionId,
    workNodeId: workNodeId,
    contextUsedTokens: contextUsedTokens,
    contextWindowTokens: contextWindowTokens,
  );
}

mixin UsageLedgerService {
  static final ReactiveNotifier<UsageLedgerViewModel> instance =
      ReactiveNotifier<UsageLedgerViewModel>(() => UsageLedgerViewModel());
}
