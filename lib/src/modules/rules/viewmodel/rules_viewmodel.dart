import 'dart:async';

import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_core/modules/rules/model/rule.dart';
import 'package:keel_core/modules/rules/service/rules_store.dart';
import 'package:keel_ui/src/core/services/store_mirror_view_model.dart';

class RulesViewModel extends StoreMirrorViewModel<RulesState> {
  RulesViewModel() : super(RulesStore.instance);

  Future<void> get ready => RulesStore.instance.ready;

  String? createRule({required String name, required String content}) =>
      RulesStore.instance.createRule(name: name, content: content);

  String? updateRule(
    String id, {
    required String name,
    required String content,
  }) => RulesStore.instance.updateRule(id, name: name, content: content);

  void deleteRule(String id) => RulesStore.instance.deleteRule(id);
}

mixin RulesService {
  static final ReactiveNotifier<RulesViewModel> instance =
      ReactiveNotifier<RulesViewModel>(() => RulesViewModel());
}
