import 'dart:async';

import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_core/modules/skills/model/skill.dart';
import 'package:keel_core/modules/skills/service/skills_store.dart';
import 'package:keel_ui/src/core/services/store_mirror_view_model.dart';

class SkillsViewModel extends StoreMirrorViewModel<SkillsState> {
  SkillsViewModel() : super(SkillsStore.instance);

  Future<void> get ready => SkillsStore.instance.ready;

  /// Every skill flagged global, injected into all agents without
  /// assignment.
  List<Skill> get globalSkills => SkillsStore.instance.globalSkills;

  String? createSkill({
    required String name,
    required String content,
    bool isGlobal = false,
  }) => SkillsStore.instance.createSkill(
    name: name,
    content: content,
    isGlobal: isGlobal,
  );

  String? updateSkill(
    String id, {
    required String name,
    required String content,
    bool? isGlobal,
  }) => SkillsStore.instance.updateSkill(
    id,
    name: name,
    content: content,
    isGlobal: isGlobal,
  );

  Future<void> syncReservedSkillContent(String name, String content) =>
      SkillsStore.instance.syncReservedSkillContent(name, content);

  void deleteSkill(String id) => SkillsStore.instance.deleteSkill(id);
}

mixin SkillsService {
  static final ReactiveNotifier<SkillsViewModel> instance =
      ReactiveNotifier<SkillsViewModel>(() => SkillsViewModel());
}
