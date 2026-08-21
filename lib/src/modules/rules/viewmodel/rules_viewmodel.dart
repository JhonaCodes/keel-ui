import 'dart:async';

import 'package:logger_rs/logger_rs.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/src/modules/rules/model/rule.dart';
import 'package:keel_ui/src/modules/rules/repository/rules_repository.dart';
import 'package:keel_ui/src/shared/shared.dart';

class RulesViewModel extends ViewModel<RulesState> {
  RulesViewModel() : super(const RulesState());

  RulesRepository get _repository => RulesRepository();

  /// Resolves once the persisted catalog has loaded — callers that read
  /// [data] outside a widget (catalog sync, MCP tools) must await this,
  /// and the guard keeps `reinitializeWithContext()`'s second init() from
  /// wiping an already-loaded catalog. Same pattern as SkillsViewModel.
  Future<void>? _ready;
  Future<void> get ready => _ready ??= _loadPersistedRules();

  @override
  void init() {
    if (_ready == null) updateSilently(const RulesState());
    unawaited(ready);
  }

  Future<void> _loadPersistedRules() async {
    try {
      final rules = await _repository.load();
      updateState(data.copyWith(rules: rules));
    } catch (error) {
      Log.e('Failed to load persisted rules', error: error);
    }
  }

  /// Registers a new rule. Returns a user-facing error message on failure
  /// (invalid or duplicate name), or null on success.
  String? createRule({required String name, required String content}) {
    final error = _validateName(name);
    if (error != null) return error;

    final rule = Rule(
      id: generateUuidV4(),
      name: name,
      content: content.trim(),
      createdAt: DateTime.now(),
    );
    final rules = [...data.rules, rule];
    updateState(data.copyWith(rules: rules));
    unawaited(_repository.save(rules));
    return null;
  }

  /// Updates an existing rule. Returns a user-facing error message on
  /// failure (invalid or duplicate name), or null on success.
  String? updateRule(
    String id, {
    required String name,
    required String content,
  }) {
    final error = _validateName(name, excludingId: id);
    if (error != null) return error;

    final rules = data.rules
        .map(
          (rule) => rule.id == id
              ? rule.copyWith(name: name, content: content.trim())
              : rule,
        )
        .toList();
    updateState(data.copyWith(rules: rules));
    unawaited(_repository.save(rules));
    return null;
  }

  void deleteRule(String id) {
    final rules = data.rules.where((rule) => rule.id != id).toList();
    updateState(data.copyWith(rules: rules));
    unawaited(_repository.save(rules));
  }

  String? _validateName(String name, {String? excludingId}) {
    final formatError = validateRuleName(name);
    if (formatError != null) return formatError;

    final isTaken = data.rules.any(
      (rule) => rule.name == name && rule.id != excludingId,
    );
    if (isTaken) return 'Ya existe una regla con ese nombre.';
    return null;
  }
}

mixin RulesService {
  static final ReactiveNotifier<RulesViewModel> instance =
      ReactiveNotifier<RulesViewModel>(() => RulesViewModel());
}
