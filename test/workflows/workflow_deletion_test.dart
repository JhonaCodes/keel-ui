import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/core/services/local_database.dart';
import 'package:keel_ui/src/modules/projects/model/project.dart';
import 'package:keel_ui/src/modules/projects/model/resolution_case.dart';
import 'package:keel_ui/src/modules/projects/model/session.dart';
import 'package:keel_ui/src/modules/projects/model/work_node.dart';
import 'package:keel_ui/src/modules/projects/viewmodel/projects_viewmodel.dart';
import 'package:keel_ui/src/modules/workflows/model/workflow.dart';
import 'package:keel_ui/src/modules/workflows/service/workflow_deletion_service.dart';
import 'package:keel_ui/src/modules/workflows/viewmodel/workflows_viewmodel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  LocalDatabase.markUnavailable();

  final createdAt = DateTime(2026, 8, 25);

  Workflow workflow(String id) => Workflow(
    id: id,
    name: id,
    whenToApply: 'Cuando corresponda.',
    createdAt: createdAt,
  );

  setUp(() async {
    await Future.wait([
      WorkflowsService.instance.notifier.ready,
      ProjectsService.instance.notifier.ready,
    ]);
  });

  test('eliminar un workflow limpia todas sus referencias de proyectos', () {
    final workflows = WorkflowsService.instance.notifier;
    final projects = ProjectsService.instance.notifier;
    final deleted = workflow('workflow-deleted');
    final retained = workflow('workflow-retained');
    workflows.updateState(WorkflowsState(workflows: [deleted, retained]));

    final historicalCase = ResolutionCase(
      id: 'case-1',
      ownerRole: 'resolver',
      status: ResolutionCaseStatus.completed,
      nodes: const [
        WorkNode(
          id: 'implementation',
          kind: WorkNodeKind.implementation,
          ownerRole: 'resolver',
          status: WorkNodeStatus.done,
        ),
      ],
    );
    final affected = Project(
      id: 'project-1',
      name: 'affected',
      purpose: '',
      workingDirectory: '/tmp/affected',
      createdAt: createdAt,
      workflowIds: [deleted.id, retained.id],
      activeWorkflowId: deleted.id,
      workflowNodeAssignments: {
        deleted.id: const {'implementation': 'profile-deleted'},
        retained.id: const {'verification': 'profile-retained'},
      },
      sessions: [
        Session(
          id: 'session-deleted',
          title: 'Histórica',
          createdAt: createdAt,
          workflowId: deleted.id,
          resolutionCase: historicalCase,
        ),
        Session(
          id: 'session-retained',
          title: 'Vigente',
          createdAt: createdAt,
          workflowId: retained.id,
        ),
      ],
    );
    final onlyDeleted = Project(
      id: 'project-2',
      name: 'only-deleted',
      purpose: '',
      workingDirectory: '/tmp/only-deleted',
      createdAt: createdAt,
      workflowIds: [deleted.id],
      activeWorkflowId: deleted.id,
      workflowNodeAssignments: {
        deleted.id: const {'implementation': 'profile-deleted'},
      },
    );
    final untouched = Project(
      id: 'project-3',
      name: 'untouched',
      purpose: '',
      workingDirectory: '/tmp/untouched',
      createdAt: createdAt,
      workflowIds: [retained.id],
      activeWorkflowId: retained.id,
    );
    projects.updateState(
      ProjectsState(
        projects: [affected, onlyDeleted, untouched],
        selectedProjectId: affected.id,
      ),
    );

    workflowDeletionService.deleteWorkflow(deleted.id);

    expect(workflows.data.workflows, [retained]);
    final updatedAffected = projects.data.projects[0];
    expect(updatedAffected.workflowIds, [retained.id]);
    expect(updatedAffected.activeWorkflowId, retained.id);
    expect(updatedAffected.workflowNodeAssignments, {
      retained.id: {'verification': 'profile-retained'},
    });
    expect(updatedAffected.sessions[0].workflowId, isEmpty);
    expect(updatedAffected.sessions[0].resolutionCase, historicalCase);
    expect(updatedAffected.sessions[1].workflowId, retained.id);

    final updatedOnlyDeleted = projects.data.projects[1];
    expect(updatedOnlyDeleted.workflowIds, isEmpty);
    expect(updatedOnlyDeleted.activeWorkflowId, isNull);
    expect(updatedOnlyDeleted.workflowNodeAssignments, isEmpty);
    expect(projects.data.projects[2], untouched);

    final persistedProjects = jsonEncode(
      projects.data.projects.map((project) => project.toJson()).toList(),
    );
    expect(persistedProjects, isNot(contains(deleted.id)));
  });

  test('eliminar un id inexistente no modifica proyectos ni catálogo', () {
    final workflows = WorkflowsService.instance.notifier;
    final projects = ProjectsService.instance.notifier;
    final retained = workflow('workflow-retained');
    final project = Project(
      id: 'project',
      name: 'project',
      purpose: '',
      workingDirectory: '/tmp/project',
      createdAt: createdAt,
      workflowIds: [retained.id],
      activeWorkflowId: retained.id,
    );
    workflows.updateState(WorkflowsState(workflows: [retained]));
    projects.updateState(ProjectsState(projects: [project]));

    workflowDeletionService.deleteWorkflow('missing');

    expect(workflows.data.workflows, [retained]);
    expect(projects.data.projects, [project]);
  });

  test('repara referencias rotas guardadas por versiones anteriores', () {
    final retained = workflow('workflow-retained');
    final project = Project(
      id: 'project',
      name: 'project',
      purpose: '',
      workingDirectory: '/tmp/project',
      createdAt: createdAt,
      workflowIds: const ['missing', 'workflow-retained'],
      activeWorkflowId: 'missing',
      workflowNodeAssignments: const {
        'missing': {'implementation': 'profile'},
      },
      sessions: [
        Session(
          id: 'session',
          title: 'session',
          createdAt: createdAt,
          workflowId: 'missing',
        ),
      ],
    );

    final repaired = ProjectsViewModel.repairWorkflowReferences(
      [project],
      {retained.id},
    ).single;

    expect(repaired.workflowIds, [retained.id]);
    expect(repaired.activeWorkflowId, retained.id);
    expect(repaired.workflowNodeAssignments, isEmpty);
    expect(repaired.sessions.single.workflowId, isEmpty);
    expect(jsonEncode(repaired.toJson()), isNot(contains('missing')));
  });
}
