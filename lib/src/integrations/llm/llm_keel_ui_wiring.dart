/// The keel-ui-specific glue the `keel_core` LLM runners and the remote
/// model catalog need but can't depend on directly: reading a secret and
/// reading the usage ledger both go through `reactive_notifier` ViewModels,
/// which live here because `reactive_notifier` depends on Flutter.
///
/// Every `keel_core` class that needs one of these takes it as an injected
/// callback (`LlmSecretResolver`, `observedModels`); this file is where
/// keel-ui supplies the real implementation at the call site.
library;

import 'package:keel_ui/src/integrations/usage_ledger/usage_ledger.dart';
import 'package:keel_core/modules/agents/model/agent_provider.dart';
import 'package:keel_ui/src/modules/secrets/viewmodel/secrets_viewmodel.dart';

/// Shared by every runner and the remote model picker. It intentionally
/// returns only the requested secret, never the vault object or another
/// secret value.
Future<String?> resolveLlmSecret(String secretRef) =>
    SecretsService.instance.notifier.resolveValue(secretRef);

/// The Claude models this machine has actually run, per the usage ledger —
/// fed to [RemoteModelCatalog] as its `observedModels` callback.
Future<List<String>> ledgerObservedClaudeModels() async {
  final ledger = UsageLedgerService.instance.notifier;
  await ledger.ready;
  return [
    for (final entry in ledger.data.entries)
      if (entry.provider == AgentProvider.claude.alias) entry.model,
  ];
}
