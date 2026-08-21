import 'dart:async';

import 'package:logger_rs/logger_rs.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/src/modules/skills/model/skill.dart';
import 'package:keel_ui/src/modules/skills/repository/skills_repository.dart';
import 'package:keel_ui/src/shared/shared.dart';

class SkillsViewModel extends ViewModel<SkillsState> {
  SkillsViewModel() : super(const SkillsState());

  SkillsRepository get _repository => SkillsRepository();

  /// Resolves once the persisted catalog has loaded into [data]. Seeding a
  /// skill at startup (e.g. Keel AI's own knowledge) must await this first —
  /// checking against an empty in-flight list would insert a duplicate the
  /// moment the real load lands.
  ///
  /// Memoized rather than a `late final` set once in [init]: a ViewModel
  /// touched before any [BuildContext] exists (e.g. by the startup seed in
  /// `main.dart`) gets `init()` called a second time the moment its first
  /// context-bearing subscriber mounts — `reactive_notifier`'s own
  /// `reinitializeWithContext()`. A `late final` assigned again there throws;
  /// this getter just returns the already-in-flight future instead.
  Future<void>? _ready;
  Future<void> get ready => _ready ??= _loadPersistedSkills();

  @override
  void init() {
    // Only reset state on the FIRST init — a re-init triggered by the
    // context hand-off above must not wipe a catalog that already loaded.
    if (_ready == null) updateSilently(const SkillsState());
    unawaited(ready);
  }

  Future<void> _loadPersistedSkills() async {
    try {
      final skills = await _repository.load();
      updateState(data.copyWith(skills: skills));
    } catch (error) {
      Log.e('Failed to load persisted skills', error: error);
    }
  }

  /// Every skill flagged global, injected into all agents without
  /// assignment.
  List<Skill> get globalSkills =>
      data.skills.where((skill) => skill.isGlobal).toList();

  /// Registers a new skill. Returns a user-facing error message on failure
  /// (invalid or duplicate name), or null on success.
  String? createSkill({
    required String name,
    required String content,
    bool isGlobal = false,
  }) {
    final error = _validateName(name);
    if (error != null) return error;

    final skill = Skill(
      id: generateUuidV4(),
      name: name,
      content: content.trim(),
      isGlobal: isGlobal,
      createdAt: DateTime.now(),
    );
    final skills = [...data.skills, skill];
    updateState(data.copyWith(skills: skills));
    unawaited(_repository.save(skills));
    return null;
  }

  /// Updates an existing skill. Returns a user-facing error message on
  /// failure (invalid or duplicate name), or null on success.
  String? updateSkill(
    String id, {
    required String name,
    required String content,
    bool? isGlobal,
  }) {
    final error = _validateName(name, excludingId: id);
    if (error != null) return error;

    final skills = data.skills
        .map(
          (skill) => skill.id == id
              ? skill.copyWith(
                  name: name,
                  content: content.trim(),
                  isGlobal: isGlobal,
                )
              : skill,
        )
        .toList();
    updateState(data.copyWith(skills: skills));
    unawaited(_repository.save(skills));
    return null;
  }

  /// Keeps an app-owned skill's content in sync with the code on every
  /// launch — mirror of `syncReservedProfilePrompt` on the profiles VM. The
  /// system map that Keel AI carries is compiled knowledge: letting it drift
  /// as editable data meant every feature shipped after the first seed was
  /// invisible to existing installs. No-op when content already matches, so
  /// callers run it unconditionally at startup. Callers must `await ready`
  /// first.
  Future<void> syncReservedSkillContent(String name, String content) async {
    final index = data.skills.indexWhere((skill) => skill.name == name);
    if (index == -1 || data.skills[index].content == content.trim()) return;

    final skills = [...data.skills];
    skills[index] = skills[index].copyWith(content: content.trim());
    updateState(data.copyWith(skills: skills));
    await _repository.save(skills);
  }

  void deleteSkill(String id) {
    final skills = data.skills.where((skill) => skill.id != id).toList();
    updateState(data.copyWith(skills: skills));
    unawaited(_repository.save(skills));
  }

  String? _validateName(String name, {String? excludingId}) {
    final formatError = validateSkillName(name);
    if (formatError != null) return formatError;

    final isTaken = data.skills.any(
      (skill) => skill.name == name && skill.id != excludingId,
    );
    if (isTaken) return 'Ya existe un skill con ese nombre.';
    return null;
  }
}

mixin SkillsService {
  static final ReactiveNotifier<SkillsViewModel> instance =
      ReactiveNotifier<SkillsViewModel>(() => SkillsViewModel());
}
