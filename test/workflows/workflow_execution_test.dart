import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/modules/projects/model/session.dart';
import 'package:keel_ui/src/modules/projects/model/session_decision.dart';
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

  test('los workflows nuevos encadenan auditorías al implementador', () {
    final capabilities = defaultWorkflowCapabilities(
      WorkflowKind.bug,
      'implementador',
    );

    final implementation = capabilities.firstWhere(
      (capability) => capability.id == 'implementation',
    );
    final audit = capabilities.firstWhere(
      (capability) => capability.id == 'code-audit',
    );
    final correction = capabilities.firstWhere(
      (capability) => capability.id == 'code-correction',
    );

    expect(implementation.executor, WorkflowExecutor.newSession);
    expect(audit.executor, WorkflowExecutor.providerSubagent);
    expect(audit.parentCapabilityId, 'implementation');
    expect(correction.executor, WorkflowExecutor.resumeParent);
    expect(correction.parentCapabilityId, 'implementation');
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

}
