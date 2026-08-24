import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/core/services/local_database.dart';
import 'package:keel_ui/src/modules/projects/model/project.dart';
import 'package:keel_ui/src/modules/agent_profiles/model/agent_profile.dart';
import 'package:keel_ui/src/modules/agent_profiles/viewmodel/agent_profiles_viewmodel.dart';
import 'package:keel_ui/src/modules/projects/model/resolution_case.dart';
import 'package:keel_ui/src/modules/projects/model/session.dart';
import 'package:keel_ui/src/modules/projects/model/work_node.dart';
import 'package:keel_ui/src/modules/projects/viewmodel/projects_viewmodel.dart';
import 'package:keel_ui/src/modules/workflows/model/workflow.dart';
import 'package:keel_ui/src/modules/workflows/viewmodel/workflows_viewmodel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  LocalDatabase.markUnavailable();

  test('conserva overrides concretos de agente por workflow y nodo', () {
    final project = Project.fromJson({
      'id': 'p',
      'name': 'nui-app',
      'purpose': '',
      'workingDirectory': '/tmp/nui',
      'createdAt': DateTime(2026).toIso8601String(),
      'workflowNodeAssignments': {
        'migration': {'implementation': 'flutter-expert'},
      },
    });

    expect(project.toJson()['workflowNodeAssignments'], {
      'migration': {'implementation': 'flutter-expert'},
    });
  });

  test('cambia pendientes del proyecto y bloquea el nodo que corre', () {
    final viewmodel = ProjectsViewModel();
    final project = Project(
      id: 'p',
      name: 'nui-app',
      purpose: '',
      workingDirectory: '/tmp/nui',
      createdAt: DateTime(2026),
      activeSessionId: 's',
      sessions: [
        Session(
          id: 's',
          title: 's',
          workflowId: 'workflow',
          createdAt: DateTime(2026),
          resolutionCase: const ResolutionCase(
            id: 'case',
            ownerRole: 'resolver',
            status: ResolutionCaseStatus.active,
            nodes: [
              WorkNode(
                id: 'diagnose',
                kind: WorkNodeKind.custom,
                ownerRole: 'diagnosticador',
              ),
              WorkNode(
                id: 'implement',
                kind: WorkNodeKind.custom,
                ownerRole: 'implementador',
                status: WorkNodeStatus.running,
              ),
            ],
          ),
        ),
      ],
    );
    viewmodel.updateState(
      ProjectsState(projects: [project], selectedProjectId: project.id),
    );

    expect(
      viewmodel.setWorkflowNodeAssignment(
        'p',
        'workflow',
        'diagnose',
        'profile-diagnose',
      ),
      isTrue,
    );
    expect(
      viewmodel.data.projects.single.assignedProfileId('workflow', 'diagnose'),
      'profile-diagnose',
    );
    expect(
      viewmodel
          .data
          .projects
          .single
          .activeSession!
          .resolutionCase!
          .nodes
          .first
          .ownerProfileId,
      'profile-diagnose',
    );
    expect(
      viewmodel.setWorkflowNodeAssignment(
        'p',
        'workflow',
        'implement',
        'profile-other',
      ),
      isFalse,
    );
  });

  test(
    'activa una capacidad opcional con el agente concreto del proyecto',
    () async {
      final now = DateTime(2026);
      final workflow = Workflow(
        id: 'workflow',
        name: 'adaptive',
        whenToApply: '',
        createdAt: now,
        capabilities: const [
          WorkflowCapability(
            id: 'implementation',
            title: 'Implementar',
            instruction: 'Implementar.',
            role: 'resolver',
          ),
          WorkflowCapability(
            id: 'audit',
            title: 'Auditar',
            instruction: 'Auditar.',
            role: 'auditor',
            dependencyIds: ['implementation'],
            activation: WorkflowCapabilityActivation.optional,
          ),
        ],
      );
      final auditor = AgentProfile(
        id: 'profile-auditor',
        name: 'auditor',
        role: 'auditor',
        systemPrompt: '',
        model: 'sonnet',
        effort: 'medium',
        createdAt: now,
      );
      await WorkflowsService.instance.notifier.ready;
      await AgentProfilesService.instance.notifier.ready;
      WorkflowsService.instance.notifier.updateState(
        WorkflowsState(workflows: [workflow]),
      );
      AgentProfilesService.instance.notifier.updateState(
        AgentProfilesState(profiles: [auditor]),
      );
      final project = Project(
        id: 'p',
        name: 'nui-app',
        purpose: '',
        workingDirectory: '/tmp',
        profileIds: [auditor.id],
        workflowIds: [workflow.id],
        activeWorkflowId: workflow.id,
        activeSessionId: 's',
        sessions: [
          Session(
            id: 's',
            title: 's',
            workflowId: workflow.id,
            createdAt: now,
            resolutionCase: const ResolutionCase(
              id: 'case',
              ownerRole: 'auditor',
              status: ResolutionCaseStatus.active,
              nodes: [
                WorkNode(
                  id: 'implementation',
                  kind: WorkNodeKind.implementation,
                  ownerRole: 'resolver',
                  status: WorkNodeStatus.done,
                ),
              ],
            ),
          ),
        ],
        createdAt: now,
      );
      final viewmodel = ProjectsViewModel();
      await viewmodel.ready;
      viewmodel.updateState(ProjectsState(projects: [project]));

      expect(
        await viewmodel.activateWorkflowCapability('p', 's', 'audit'),
        isNull,
      );
      final activated = viewmodel
          .data
          .projects
          .single
          .activeSession!
          .resolutionCase!
          .nodes
          .last;
      expect(activated.id, 'audit');
      expect(activated.ownerProfileId, auditor.id);
      expect(activated.dependencyIds, ['implementation']);
    },
  );

  test(
    'rechaza una auditoría independiente asignada al autor de su dependencia',
    () async {
      final now = DateTime(2026);
      final workflow = Workflow(
        id: 'workflow-independent',
        name: 'independent-audit',
        whenToApply: '',
        createdAt: now,
        capabilities: const [
          WorkflowCapability(
            id: 'implementation',
            title: 'Implementar',
            instruction: 'Implementar.',
            role: 'resolver',
          ),
          WorkflowCapability(
            id: 'audit',
            title: 'Auditar',
            instruction: 'Auditar con contexto limpio.',
            role: 'resolver',
            dependencyIds: ['implementation'],
            activation: WorkflowCapabilityActivation.optional,
            requiresIndependentOwner: true,
          ),
        ],
      );
      final writer = AgentProfile(
        id: 'profile-writer',
        name: 'writer',
        role: 'resolver',
        systemPrompt: '',
        model: 'sonnet',
        effort: 'medium',
        createdAt: now,
      );
      await WorkflowsService.instance.notifier.ready;
      await AgentProfilesService.instance.notifier.ready;
      WorkflowsService.instance.notifier.updateState(
        WorkflowsState(workflows: [workflow]),
      );
      AgentProfilesService.instance.notifier.updateState(
        AgentProfilesState(profiles: [writer]),
      );
      final project = Project(
        id: 'p-independent',
        name: 'generic-project',
        purpose: '',
        workingDirectory: '/tmp',
        profileIds: [writer.id],
        workflowIds: [workflow.id],
        activeWorkflowId: workflow.id,
        activeSessionId: 's-independent',
        sessions: [
          Session(
            id: 's-independent',
            title: 's',
            workflowId: workflow.id,
            createdAt: now,
            resolutionCase: ResolutionCase(
              id: 'case-independent',
              ownerRole: writer.role,
              status: ResolutionCaseStatus.active,
              nodes: [
                WorkNode(
                  id: 'implementation',
                  kind: WorkNodeKind.implementation,
                  ownerRole: writer.role,
                  ownerProfileId: writer.id,
                  status: WorkNodeStatus.done,
                ),
              ],
            ),
          ),
        ],
        createdAt: now,
      );
      final viewmodel = ProjectsViewModel();
      await viewmodel.ready;
      viewmodel.updateState(ProjectsState(projects: [project]));

      expect(
        await viewmodel.activateWorkflowCapability(
          project.id,
          's-independent',
          'audit',
        ),
        contains('independiente'),
      );
    },
  );
}
