import 'package:dart_mcp/server.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/core/services/local_database.dart';
import 'package:keel_ui/src/integrations/assistant_mcp/assistant_mcp_server.dart';
import 'package:keel_ui/src/modules/agent_profiles/model/agent_profile.dart';
import 'package:keel_ui/src/modules/agent_profiles/viewmodel/agent_profiles_viewmodel.dart';
import 'package:keel_ui/src/modules/projects/model/project.dart';
import 'package:keel_ui/src/modules/projects/model/resolution_case.dart';
import 'package:keel_ui/src/modules/projects/model/session.dart';
import 'package:keel_ui/src/modules/projects/model/work_node.dart';
import 'package:keel_ui/src/modules/projects/viewmodel/projects_viewmodel.dart';
import 'package:keel_ui/src/modules/workflows/model/workflow.dart';
import 'package:keel_ui/src/modules/workflows/viewmodel/workflows_viewmodel.dart';

final _epoch = DateTime(2026, 8, 28);

/// El workflow tal como quedó: `planificar` ya NO es una de sus capacidades.
/// Así nace la fila huérfana — el nodo se sacó del flujo y el override del
/// proyecto quedó apuntando a un destino que no existe.
final _workflow = Workflow(
  id: 'workflow',
  name: 'keel-ui-bug-solver',
  whenToApply: '',
  createdAt: _epoch,
  capabilities: const [
    WorkflowCapability(
      id: 'resolver',
      title: 'Resolver',
      instruction: 'Resolver.',
      role: 'resolver',
    ),
  ],
);

final _resolver = AgentProfile(
  id: 'profile-resolver',
  name: 'keel-flutter-dev',
  role: 'resolver',
  systemPrompt: '',
  model: 'sonnet',
  effort: 'medium',
  createdAt: _epoch,
);

/// El proyecto con la fila huérfana y una sesión que dejó ese nodo cerrado:
/// las dos condiciones que se tapaban una a la otra.
Project _orphanedProject() => Project(
  id: 'project',
  name: 'keel-ui',
  purpose: '',
  workingDirectory: '/tmp/keel',
  createdAt: _epoch,
  profileIds: [_resolver.id],
  workflowIds: [_workflow.id],
  activeWorkflowId: _workflow.id,
  activeSessionId: 'session',
  workflowNodeAssignments: const {
    'workflow': {'planificar': 'profile-resolver'},
  },
  sessions: [
    Session(
      id: 'session',
      title: 'Sesión terminada',
      createdAt: _epoch,
      workflowId: _workflow.id,
      status: SessionStatus.finished,
      resolutionCase: const ResolutionCase(
        id: 'case',
        ownerRole: 'resolver',
        status: ResolutionCaseStatus.completed,
        nodes: [
          WorkNode(
            id: 'planificar',
            kind: WorkNodeKind.custom,
            ownerRole: 'resolver',
            ownerProfileId: 'profile-resolver',
            status: WorkNodeStatus.done,
          ),
        ],
      ),
    ),
  ],
);

Future<String> _updateNodeAssignment({required String handle}) async {
  final result = await dispatchKeelAiTool(
    'agent',
    CallToolRequest(
      name: 'update_project',
      arguments: {
        'name': 'keel-ui',
        'node_assignments': [
          {
            'workflow': 'keel-ui-bug-solver',
            'node_id': 'planificar',
            'handle': handle,
          },
        ],
      },
    ),
  );
  return (result.content.single as TextContent).text;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  LocalDatabase.markUnavailable();

  setUp(() async {
    final workflows = WorkflowsService.instance.notifier;
    final profiles = AgentProfilesService.instance.notifier;
    final projects = ProjectsService.instance.notifier;
    await workflows.ready;
    await profiles.ready;
    await projects.ready;
    workflows.updateState(WorkflowsState(workflows: [_workflow]));
    profiles.updateState(AgentProfilesState(profiles: [_resolver]));
    projects.updateState(ProjectsState(projects: [_orphanedProject()]));
  });

  test('un handle vacío borra la asignación de un nodo que ya no existe', () async {
    final message = await _updateNodeAssignment(handle: '');

    expect(message, isNot(contains('asignación inválida')));
    expect(message, isNot(contains('ya está corriendo o cerrado')));
    expect(
      ProjectsService.instance.notifier.data.projects.single
          .workflowNodeAssignments,
      isEmpty,
    );
  });

  test('asignar a un nodo que ya no existe sigue rechazado', () async {
    final message = await _updateNodeAssignment(handle: 'keel-flutter-dev');

    expect(message, contains('asignación inválida'));
    expect(
      ProjectsService.instance.notifier.data.projects.single
          .assignedProfileId('workflow', 'planificar'),
      _resolver.id,
    );
  });
}
