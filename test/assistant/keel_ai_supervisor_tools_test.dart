import 'dart:convert';

import 'package:dart_mcp/server.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/core/services/local_database.dart';
import 'package:keel_ui/src/integrations/assistant_mcp/assistant_mcp_server.dart';
import 'package:keel_ui/src/modules/projects/model/project.dart';
import 'package:keel_ui/src/modules/projects/model/resolution_case.dart';
import 'package:keel_ui/src/modules/projects/model/session.dart';
import 'package:keel_ui/src/modules/projects/model/session_decision.dart';
import 'package:keel_ui/src/modules/projects/model/turn_outcome_report.dart';
import 'package:keel_ui/src/modules/projects/model/work_node.dart';
import 'package:keel_ui/src/modules/projects/viewmodel/projects_viewmodel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  LocalDatabase.markUnavailable();

  final now = DateTime(2026, 9, 5);

  Future<Map<String, Object?>> call(
    String name,
    Map<String, Object?> arguments,
  ) async {
    final result = await dispatchKeelAiTool(
      'keel-ai',
      CallToolRequest(name: name, arguments: arguments),
    );
    return jsonDecode((result.content.single as TextContent).text)
        as Map<String, Object?>;
  }

  setUp(() async {
    await ProjectsService.instance.notifier.ready;
    ProjectsService.instance.notifier.updateState(
      ProjectsState(
        projects: [
          Project(
            id: 'project',
            name: 'keel-ui',
            purpose: '',
            workingDirectory: '/tmp/keel-ui',
            createdAt: now,
            activeSessionId: 'session',
            sessions: [
              Session(
                id: 'session',
                title: 'Arreglar el parser',
                createdAt: now,
                request: 'Arreglar el parser de bloques',
                resolutionCase: const ResolutionCase(
                  id: 'case',
                  ownerRole: 'dev',
                  status: ResolutionCaseStatus.active,
                  nodes: [
                    WorkNode(
                      id: 'implement',
                      kind: WorkNodeKind.implementation,
                      ownerRole: 'dev',
                      title: 'Implementar',
                      status: WorkNodeStatus.done,
                      attempts: 1,
                      output: TurnOutcomeReport(
                        status: TurnOutcomeStatus.done,
                        summary: 'MARCADOR-CIERRE parser corregido',
                      ),
                    ),
                    WorkNode(
                      id: 'audit',
                      kind: WorkNodeKind.custom,
                      ownerRole: 'auditor',
                      title: 'Auditar',
                      status: WorkNodeStatus.paused,
                      dependencyIds: ['implement'],
                    ),
                  ],
                ),
                decisions: [
                  SessionDecision(
                    id: 'd-1',
                    kind: SessionDecisionKind.question,
                    profileId: 'auditor',
                    workNodeId: 'audit',
                    title: 'Necesita una decisión tuya',
                    detail: '¿main o develop?',
                    createdAt: now,
                  ),
                ],
              ),
            ],
          ),
        ],
        selectedProjectId: 'project',
      ),
    );
  });

  test('inspect_session cuenta el caso, los cierres y las decisiones', () async {
    final payload = await call('inspect_session', {'project': 'keel-ui'});

    expect(payload['ok'], isTrue);
    final text = payload['message'] as String;
    expect(text, contains('Implementar'));
    expect(text, contains('done'));
    expect(text, contains('MARCADOR-CIERRE'));
    expect(text, contains('Auditar'));
    expect(text, contains('paused'));
    expect(text, contains('ESPERANDO AL USUARIO'));
    expect(text, contains('id d-1'));
    expect(text, contains('¿main o develop?'));
  });

  test('answer_decision contesta la pregunta que el usuario decidió', () async {
    final payload = await call('answer_decision', {
      'project': 'keel-ui',
      'decision_id': 'd-1',
      'answer': 'develop',
    });

    expect(payload['ok'], isTrue, reason: payload['message'].toString());
    final session =
        ProjectsService.instance.notifier.data.projects.single.sessions.single;
    expect(session.waitingForUser, isFalse);
    expect(session.decisions.single.answer, 'develop');
  });

  test('lint_workflow señala una aprobación manual opcional', () async {
    final payload = await call('lint_workflow', {
      'capabilities': [
        {'id': 'implement', 'title': 'I', 'instruction': 'Implementar.', 'role': 'dev'},
        {
          'id': 'approve',
          'title': 'A',
          'instruction': 'Aprobar.',
          'role': 'dev',
          'dependencies': ['implement'],
          'activation': 'optional',
          'executor': 'manualApproval',
        },
      ],
    });

    expect(payload['message'], contains('HAY ERRORES'));
    expect(payload['message'], contains("'approve'"));
  });
}
