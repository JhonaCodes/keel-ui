import 'dart:async';

import 'package:logger_rs/logger_rs.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/src/modules/workflows/model/workflow.dart';
import 'package:keel_ui/src/modules/workflows/repository/workflows_repository.dart';
import 'package:keel_ui/src/shared/shared.dart';

class WorkflowsViewModel extends ViewModel<WorkflowsState> {
  WorkflowsViewModel() : super(const WorkflowsState());

  WorkflowsRepository get _repository => WorkflowsRepository();

  @override
  void init() {
    updateSilently(const WorkflowsState());
    unawaited(_loadPersistedWorkflows());
  }

  Future<void> _loadPersistedWorkflows() async {
    try {
      final workflows = await _repository.load();
      updateState(data.copyWith(workflows: workflows));
    } catch (error) {
      Log.e('Failed to load persisted workflows', error: error);
    }
  }

  /// Registers a new workflow. Returns a user-facing error message on
  /// failure (invalid or duplicate name), or null on success.
  String? createWorkflow({
    required String name,
    required String whenToApply,
    required List<WorkflowStep> steps,
  }) {
    final error = _validateName(name);
    if (error != null) return error;

    final workflow = Workflow(
      id: generateUuidV4(),
      name: name,
      whenToApply: whenToApply.trim(),
      steps: steps,
      createdAt: DateTime.now(),
    );
    final workflows = [...data.workflows, workflow];
    updateState(data.copyWith(workflows: workflows));
    unawaited(_repository.save(workflows));
    return null;
  }

  /// Updates an existing workflow. Returns a user-facing error message on
  /// failure (invalid or duplicate name), or null on success.
  String? updateWorkflow(
    String id, {
    required String name,
    required String whenToApply,
    required List<WorkflowStep> steps,
  }) {
    final error = _validateName(name, excludingId: id);
    if (error != null) return error;

    final workflows = data.workflows
        .map(
          (workflow) => workflow.id == id
              ? workflow.copyWith(
                  name: name,
                  whenToApply: whenToApply.trim(),
                  steps: steps,
                )
              : workflow,
        )
        .toList();
    updateState(data.copyWith(workflows: workflows));
    unawaited(_repository.save(workflows));
    return null;
  }

  void deleteWorkflow(String id) {
    final workflows = data.workflows
        .where((workflow) => workflow.id != id)
        .toList();
    updateState(data.copyWith(workflows: workflows));
    unawaited(_repository.save(workflows));
  }

  String? _validateName(String name, {String? excludingId}) {
    final formatError = validateWorkflowName(name);
    if (formatError != null) return formatError;

    final isTaken = data.workflows.any(
      (workflow) => workflow.name == name && workflow.id != excludingId,
    );
    if (isTaken) return 'Ya existe un workflow con ese nombre.';
    return null;
  }
}

mixin WorkflowsService {
  static final ReactiveNotifier<WorkflowsViewModel> instance =
      ReactiveNotifier<WorkflowsViewModel>(() => WorkflowsViewModel());
}
