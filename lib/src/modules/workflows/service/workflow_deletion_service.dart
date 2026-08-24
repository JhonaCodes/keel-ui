import 'dart:async';

import 'package:keel_ui/src/modules/projects/viewmodel/projects_viewmodel.dart';
import 'package:keel_ui/src/modules/workflows/repository/workflows_repository.dart';
import 'package:keel_ui/src/modules/workflows/viewmodel/workflows_viewmodel.dart';

/// Coordinates deletion across the workflow catalog and every project that
/// can reference it. This is the single deletion entry point for UI and tools.
class WorkflowDeletionService {
  const WorkflowDeletionService();

  /// Returns false when the workflow no longer exists. Otherwise updates both
  /// in-memory aggregates immediately and schedules their persistence.
  bool deleteWorkflow(String id) {
    final workflowsViewModel = WorkflowsService.instance.notifier;
    final exists = workflowsViewModel.data.workflows.any(
      (workflow) => workflow.id == id,
    );
    if (!exists) return false;

    ProjectsService.instance.notifier.detachWorkflow(id);
    final workflows = workflowsViewModel.data.workflows
        .where((workflow) => workflow.id != id)
        .toList();
    workflowsViewModel.updateState(
      workflowsViewModel.data.copyWith(workflows: workflows),
    );
    unawaited(WorkflowsRepository().save(workflows));
    return true;
  }
}

const workflowDeletionService = WorkflowDeletionService();
