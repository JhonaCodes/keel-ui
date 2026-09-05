import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/modules/projects/model/session.dart';
import 'package:keel_ui/src/modules/projects/model/session_decision.dart';
import 'package:keel_ui/src/modules/projects/model/session_live_turn.dart';
import 'package:keel_ui/src/modules/projects/model/project.dart';
import 'package:keel_ui/src/modules/projects/viewmodel/projects_viewmodel.dart';
import 'package:keel_ui/src/modules/workflows/model/workflow.dart';

void main() {
  test('persiste el contrato de ejecución de una capacidad', () {
    const capability = WorkflowCapability(
      id: 'code-audit',
      title: 'Auditar código',
      instruction: 'Devolvé todos los hallazgos estructurados.',
      role: 'auditor',
      dependencyIds: ['implementation'],
      executor: WorkflowExecutor.providerSubagent,
      parentCapabilityId: 'implementation',
      maxAgenticTurns: 3,
      readOnly: true,
      outputContract: 'audit-feedback',
    );

    expect(WorkflowCapability.fromJson(capability.toJson()), capability);
  });

  test('exige un padre para reanudar o delegar a un subagente', () {
    expect(
      validateWorkflowCapabilities(const [
        WorkflowCapability(
          id: 'implementation',
          title: 'Implementar',
          instruction: 'Implementar.',
          role: 'implementador',
        ),
        WorkflowCapability(
          id: 'audit',
          title: 'Auditar',
          instruction: 'Auditar.',
          role: 'auditor',
          dependencyIds: ['implementation'],
          executor: WorkflowExecutor.providerSubagent,
        ),
      ]),
      contains('padre'),
    );
  });

  test('los workflows nuevos auditan en sesión propia y entregan sobre la '
      'sesión del implementador, con aprobación', () {
    final capabilities = defaultWorkflowCapabilities(
      WorkflowKind.bug,
      'implementador',
    );

    final implement = capabilities.firstWhere(
      (capability) => capability.id == 'implement',
    );
    final audit = capabilities.firstWhere(
      (capability) => capability.id == 'audit',
    );
    final deliver = capabilities.firstWhere(
      (capability) => capability.id == 'deliver',
    );

    expect(implement.executor, WorkflowExecutor.newSession);
    // Sesión propia y no subagente: el subagente nativo fallaba en 149
    // corridas y el fallback era el que auditaba de verdad.
    expect(audit.executor, WorkflowExecutor.newSession);
    expect(audit.requiresIndependentOwner, isTrue);
    expect(audit.outputContract, 'audit-feedback');
    expect(deliver.executor, WorkflowExecutor.resumeParent);
    expect(deliver.parentCapabilityId, 'implement');
    expect(deliver.approvalRequired, isTrue);
  });

  test('migra sesiones antiguas de perfil a claves de ejecución', () {
    final session = Session.fromJson({
      'id': 'session',
      'title': 'Sesión',
      'createdAt': DateTime(2026).toIso8601String(),
      'sessionsByProfileId': {'profile-1': 'cli-1'},
    });

    expect(session.cliSessionsByExecutionId, {'member:profile-1': 'cli-1'});
    expect(session.toJson()['sessionsByExecutionId'], {
      'member:profile-1': 'cli-1',
    });
    expect(session.toJson().containsKey('sessionsByProfileId'), isFalse);
  });

  test('las decisiones pendientes sobreviven al disco y marcan la espera', () {
    final decision = SessionDecision(
      id: 'd1',
      kind: SessionDecisionKind.question,
      profileId: 'p1',
      workNodeId: 'implementation',
      title: 'Necesita una decisión tuya',
      detail: '¿main o develop?',
      createdAt: DateTime(2026),
    );
    final session = Session(
      id: 's',
      title: 'Sesión',
      createdAt: DateTime(2026),
      decisions: [decision],
    );

    final restored = Session.fromJson(session.toJson());

    expect(restored.decisions, [decision]);
    expect(restored.waitingForUser, isTrue);
    expect(
      restored
          .copyWith(
            decisions: [
              decision.copyWith(status: SessionDecisionStatus.answered),
            ],
          )
          .waitingForUser,
      isFalse,
    );
  });


  test('el turno vivo sobrevive al disco y al revivir queda como mensaje', () {
    const turn = SessionLiveTurn(
      profileId: 'p1',
      reasoning: 'estaba pensando en el parser',
      phase: TurnPhase.thinking,
    );
    final session = Session(
      id: 's',
      title: 'Sesión',
      createdAt: DateTime(2026),
      isRunning: true,
      liveTurn: turn,
    );

    final restored = Session.fromJson(session.toJson());
    expect(restored.liveTurn, turn);

    final project = Project(
      id: 'p',
      name: 'p',
      purpose: '',
      workingDirectory: '/tmp',
      createdAt: DateTime(2026),
    );
    final revived = ProjectsViewModel.revivedSession(restored, project, 'wf');
    expect(revived.liveTurn, isNull);
    expect(revived.isRunning, isFalse);
    expect(revived.messages.last.text, contains('se cortó al cerrar la app'));
    expect(revived.messages.last.text, contains('pensando'));
  });

}
