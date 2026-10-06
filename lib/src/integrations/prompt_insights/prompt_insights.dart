library;

import 'package:keel_core/integrations/prompt_insights/prompt_insights.dart';
import 'package:keel_core/integrations/prompt_insights/service/prompt_insights_store.dart';
import 'package:reactive_notifier/reactive_notifier.dart';
import 'package:keel_ui/src/core/services/store_mirror_view_model.dart';

export 'package:keel_core/integrations/prompt_insights/prompt_insights.dart';

/// Deterministic, zero-token detector of "things you keep asking for":
/// every user prompt is logged (normalized), and a greedy Jaccard
/// clustering pass proposes a GLOBAL skill when the same kind of request
/// shows up repeatedly. No model is involved at any point — the suggestion
/// is a fact about frequency, not an opinion.
///
/// Mirror delgado de [PromptInsightsStore] (keel_core): toda la lógica real
/// vive ahí.
class PromptInsightsViewModel
    extends StoreMirrorViewModel<PromptInsightsState> {
  PromptInsightsViewModel() : super(PromptInsightsStore.instance);

  Future<void> get ready => PromptInsightsStore.instance.ready;

  /// Logs one user prompt. Fire-and-forget from the send paths — never in
  /// their critical path.
  Future<void> record(String text) => PromptInsightsStore.instance.record(text);

  /// Greedy clustering over the recent window. Emits ONE new suggestion per
  /// cluster signature — dismissed clusters never come back.
  Future<void> scan() => PromptInsightsStore.instance.scan();

  /// Marks a suggestion handled (created or dismissed) — it leaves the
  /// band, and its signature keeps future scans from re-proposing it.
  void resolveSuggestion(String id, {required bool dismissed}) =>
      PromptInsightsStore.instance.resolveSuggestion(id, dismissed: dismissed);
}

mixin PromptInsightsService {
  static final ReactiveNotifier<PromptInsightsViewModel> instance =
      ReactiveNotifier<PromptInsightsViewModel>(
        () => PromptInsightsViewModel(),
      );
}
