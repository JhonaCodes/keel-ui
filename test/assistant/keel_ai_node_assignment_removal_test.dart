import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:dart_mcp/server.dart';

import 'package:keel_ui/src/core/services/local_database.dart';
import 'package:keel_ui/src/integrations/assistant_mcp/assistant_mcp_server.dart';
import 'package:keel_ui/src/integrations/catalog_shape/catalog_shape.dart';
import 'package:keel_ui/src/modules/agent_profiles/model/agent_profile.dart';
import 'package:keel_ui/src/modules/agent_profiles/viewmodel/agent_profiles_viewmodel.dart';
import 'package:keel_ui/src/modules/projects/model/project.dart';
import 'package:keel_ui/src/modules/projects/model/resolution_case.dart';
import 'package:keel_ui/src/modules/projects/model/session.dart';
import 'package:keel_ui/src/modules/projects/model/work_node.dart';
import 'package:keel_ui/src/modules/projects/viewmodel/projects_viewmodel.dart';
import 'package:keel_ui/src/modules/workflows/model/workflow.dart';
import 'package:keel_ui/src/modules/workflows/viewmodel/workflows_viewmodel.dart';

/// La segunda vía por la que una asignación de nodo queda sin poder
/// limpiarse: el nodo SIGUE existiendo en el workflow, pero una sesión
/// terminada lo dejó en `done`, y el bloqueo que protege la traza de un caso
/// en curso alcanzaba también al borrado.
///
/// Borrar es lo contrario de asignar: no le cambia el dueño a nada —el nodo
/// cerrado conserva el suyo—, solo deja de imponer uno para el próximo. Por
/// eso se abre el borrado sin tocar el bloqueo, que el último test fija.
///
/// La otra vía (el nodo ya no existe entre las capacidades) vive en
/// `test/projects/orphan_node_assignment_removal_test.dart`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  LocalDatabase.markUnavailable();

  final now = DateTime(2026, 8, 28);

  final workflow = Workflow(
    id: 'workflow',
    name: 'fix',
    whenToApply: '',
    createdAt: now,
    capabilities: const [
      WorkflowCapability(
        id: 'implementation',
        title: 'Implementar',
        instruction: 'Implementar.',
        role: 'implementador',
      ),
    ],
  );

  final dev = AgentProfile(
    id: 'profile-dev',
    name: 'keel-flutter-dev',
    role: 'implementador',
    systemPrompt: '',
    model: 'sonnet',
    effort: 'high',
    createdAt: now,
  );

  Future<String> callUpdateProject({
    required String nodeId,
    required String handle,
  }) async {
    final result = await dispatchKeelAiTool(
      'keel-ai',
      CallToolRequest(
        name: 'update_project',
        arguments: {
          'name': 'keel-ui',
          'node_assignments': [
            {'workflow': 'fix', 'node_id': nodeId, 'handle': handle},
          ],
        },
      ),
    );
    final payload =
        jsonDecode((result.content.single as TextContent).text)
            as Map<String, Object?>;
    return payload['message'] as String;
  }

  Future<void> seedProject({
    required Map<String, Map<String, String>> assignments,
    required WorkNodeStatus status,
    required String sessionNodeId,
  }) async {
    // Los mismos catálogos que espera la tool, esperados ANTES de sembrar: la
    // carga persistida termina en un `updateState` que pisa la lista de
    // proyectos (`projects_viewmodel.dart:203`), así que sembrar con una
    // carga en vuelo deja el seed pisado y la tool sin proyecto.
    await awaitCatalogsReady();
    WorkflowsService.instance.notifier.updateState(
      WorkflowsState(workflows: [workflow]),
    );
    AgentProfilesService.instance.notifier.updateState(
      AgentProfilesState(profiles: [dev]),
    );
    ProjectsService.instance.notifier.updateState(
      ProjectsState(
        projects: [
          Project(
            id: 'project',
            name: 'keel-ui',
            purpose: '',
            workingDirectory: '/tmp/keel-ui',
            profileIds: [dev.id],
            workflowIds: [workflow.id],
            activeWorkflowId: workflow.id,
            activeSessionId: 'session',
            workflowNodeAssignments: assignments,
            sessions: [
              Session(
                id: 'session',
                title: 'Sesión',
                workflowId: workflow.id,
                createdAt: now,
                resolutionCase: ResolutionCase(
                  id: 'case',
                  ownerRole: 'implementador',
                  status: ResolutionCaseStatus.active,
                  nodes: [
                    WorkNode(
                      id: sessionNodeId,
                      kind: WorkNodeKind.implementation,
                      ownerRole: 'implementador',
                      ownerProfileId: dev.id,
                      status: status,
                    ),
                  ],
                ),
              ),
            ],
            createdAt: now,
          ),
        ],
        selectedProjectId: 'project',
      ),
    );
  }

  test('borra la asignación de un nodo que una sesión dejó cerrado', () async {
    await seedProject(
      assignments: {
        'workflow': {'implementation': dev.id, 'diagnose': dev.id},
      },
      status: WorkNodeStatus.done,
      sessionNodeId: 'implementation',
    );

    final message = await callUpdateProject(
      nodeId: 'implementation',
      handle: '',
    );

    expect(message, isNot(contains('ya está corriendo o cerrado')));
    final project = ProjectsService.instance.notifier.data.projects.single;
    expect(project.assignedProfileId('workflow', 'implementation'), isNull);
    // Lo que no se pidió borrar no se toca.
    expect(project.assignedProfileId('workflow', 'diagnose'), dev.id);
  });

  test('asignar sobre un nodo cerrado sigue bloqueado', () async {
    // El contrafactual del test de arriba: lo que se abrió es el borrado, no
    // el bloqueo. Poner un dueño nuevo sobre un nodo ya cerrado le cambiaría
    // la traza a un caso terminado, y eso sigue rechazado.
    await seedProject(
      assignments: const {},
      status: WorkNodeStatus.done,
      sessionNodeId: 'implementation',
    );

    final message = await callUpdateProject(
      nodeId: 'implementation',
      handle: 'keel-flutter-dev',
    );

    expect(message, contains('ya está corriendo o cerrado'));
    expect(
      ProjectsService.instance.notifier.data.projects.single.assignedProfileId(
        'workflow',
        'implementation',
      ),
      isNull,
    );
  });
}
