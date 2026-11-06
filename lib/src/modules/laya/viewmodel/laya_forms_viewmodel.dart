import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_core/modules/laya_forms/model/laya_form.dart';
import 'package:keel_core/modules/laya_forms/service/laya_forms_store.dart';
import 'package:keel_ui/src/core/services/store_mirror_view_model.dart';
import 'package:keel_ui/src/integrations/llm/llm_keel_ui_wiring.dart';

export 'package:keel_core/modules/laya_forms/service/laya_forms_store.dart'
    show LayaFormsState;

/// Thin mirror over [LayaFormsStore] (keel_core): the forms, their last
/// run and asking them live there, so keel-server can do the same.
class LayaFormsViewModel extends StoreMirrorViewModel<LayaFormsState> {
  LayaFormsViewModel() : super(LayaFormsStore.instance);

  Future<void> get ready => LayaFormsStore.instance.ready;

  LayaForm? formById(String id) => LayaFormsStore.instance.formById(id);

  LayaForm? formNamed(String name) => LayaFormsStore.instance.formNamed(name);

  /// Returns the problem, or null.
  String? save(LayaForm form) => LayaFormsStore.instance.upsert(form);

  ({LayaForm? form, String? problem}) createFromSpec(
    Map<String, Object?> spec, {
    required String createdBy,
  }) => LayaFormsStore.instance.createFromSpec(spec, createdBy: createdBy);

  void delete(String id) => LayaFormsStore.instance.delete(id);

  void duplicate(String id) => LayaFormsStore.instance.duplicate(id);

  Future<LayaFormRun> ask(LayaForm form, Map<String, String> values) =>
      LayaFormsStore.instance.ask(
        form,
        values,
        resolveSecret: resolveLlmSecret,
      );
}

mixin LayaFormsService {
  static final ReactiveNotifier<LayaFormsViewModel> instance =
      ReactiveNotifier<LayaFormsViewModel>(LayaFormsViewModel.new);
}
