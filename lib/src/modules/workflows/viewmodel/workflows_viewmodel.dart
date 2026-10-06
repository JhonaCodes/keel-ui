import 'dart:async';

import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_core/modules/workflows/model/workflow.dart';
import 'package:keel_core/modules/workflows/service/workflows_store.dart';
import 'package:keel_ui/src/core/services/store_mirror_view_model.dart';

class WorkflowsViewModel extends StoreMirrorViewModel<WorkflowsState> {
  WorkflowsViewModel() : super(WorkflowsStore.instance);

  Future<void> get ready => WorkflowsStore.instance.ready;

  String? createWorkflow({
    required String name,
    required String whenToApply,
    List<String> skillNames = const [],
    bool buildsRoadmap = false,
    WorkflowKind kind = WorkflowKind.general,
    WorkflowPolicy policy = const WorkflowPolicy(),
    List<WorkflowCapability>? capabilities,
  }) => WorkflowsStore.instance.createWorkflow(
    name: name,
    whenToApply: whenToApply,
    skillNames: skillNames,
    buildsRoadmap: buildsRoadmap,
    kind: kind,
    policy: policy,
    capabilities: capabilities,
  );

  String? updateWorkflow(
    String id, {
    required String name,
    required String whenToApply,
    List<String>? skillNames,
    bool? buildsRoadmap,
    WorkflowKind? kind,
    WorkflowPolicy? policy,
    List<WorkflowCapability>? capabilities,
  }) => WorkflowsStore.instance.updateWorkflow(
    id,
    name: name,
    whenToApply: whenToApply,
    skillNames: skillNames,
    buildsRoadmap: buildsRoadmap,
    kind: kind,
    policy: policy,
    capabilities: capabilities,
  );
}

mixin WorkflowsService {
  static final ReactiveNotifier<WorkflowsViewModel> instance =
      ReactiveNotifier<WorkflowsViewModel>(() => WorkflowsViewModel());
}
