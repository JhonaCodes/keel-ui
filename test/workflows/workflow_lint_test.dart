import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/modules/workflows/model/workflow.dart';

void main() {
  /// La plantilla vieja, en su forma: once nodos, dos auditorías con el mismo
  /// contrato y una aprobación manual opcional que nunca se instanciaba.
  List<WorkflowCapability> legacyEleven() => const [
    WorkflowCapability(id: 'planner', title: 'Plan', instruction: 'Definir alcance, riesgos y criterios de aceptación.', role: 'dev', readOnly: true, maxAgenticTurns: 4),
    WorkflowCapability(id: 'implementation', title: 'Implement', instruction: 'Aplicar la corrección mínima integrada y verificable.', role: 'dev', dependencyIds: ['planner']),
    WorkflowCapability(id: 'code-audit', title: 'Audit code', instruction: 'Revisar calidad, invariantes y riesgos del cambio.', role: 'auditor', dependencyIds: ['implementation'], readOnly: true, outputContract: 'audit-feedback', requiresIndependentOwner: true),
    WorkflowCapability(id: 'code-correction', title: 'Fix', instruction: 'Resolver los hallazgos válidos de la auditoría.', role: 'dev', dependencyIds: ['code-audit'], executor: WorkflowExecutor.resumeParent, parentCapabilityId: 'implementation'),
    WorkflowCapability(id: 'tests', title: 'Tests', instruction: 'Crear o ajustar pruebas de la implementación.', role: 'dev', dependencyIds: ['code-correction'], executor: WorkflowExecutor.resumeParent, parentCapabilityId: 'implementation'),
    WorkflowCapability(id: 'test-audit', title: 'Audit tests', instruction: 'Revisar calidad, invariantes y riesgos del cambio.', role: 'auditor', dependencyIds: ['tests'], readOnly: true, outputContract: 'audit-feedback', requiresIndependentOwner: true),
    WorkflowCapability(id: 'test-correction', title: 'Fix tests', instruction: 'Resolver los hallazgos válidos de la auditoría de pruebas.', role: 'dev', dependencyIds: ['test-audit'], executor: WorkflowExecutor.resumeParent, parentCapabilityId: 'implementation'),
    WorkflowCapability(id: 'device-e2e', title: 'E2E', instruction: 'Validar el comportamiento completo en el entorno real.', role: 'verifier', dependencyIds: ['test-correction'], activation: WorkflowCapabilityActivation.optional, requiresIndependentOwner: true),
    WorkflowCapability(id: 'verification', title: 'Verify', instruction: 'Ejecutar gates y cerrar solo con evidencia suficiente.', role: 'dev', dependencyIds: ['test-correction'], executor: WorkflowExecutor.resumeParent, parentCapabilityId: 'implementation'),
    WorkflowCapability(id: 'publish-approval', title: 'Approve', instruction: 'Esperar aprobación explícita antes de publicar.', role: 'dev', dependencyIds: ['verification'], executor: WorkflowExecutor.manualApproval, activation: WorkflowCapabilityActivation.optional, readOnly: true),
    WorkflowCapability(id: 'publish', title: 'Publish', instruction: 'Publicar únicamente después de aprobación explícita.', role: 'dev', dependencyIds: ['publish-approval'], executor: WorkflowExecutor.resumeParent, parentCapabilityId: 'implementation'),
  ];

  test('la plantilla vieja da error por cantidad y por aprobación opcional, '
      'y warning por auditorías duplicadas y por nodos sin tope', () {
    final lints = lintWorkflowCapabilities(legacyEleven());
    final errors = lints
        .where((lint) => lint.severity == WorkflowLintSeverity.error)
        .map((lint) => lint.message)
        .toList();
    final warnings = lints
        .where((lint) => lint.severity == WorkflowLintSeverity.warning)
        .map((lint) => lint.message)
        .toList();

    expect(errors, anyElement(contains('8')));
    expect(errors, anyElement(contains('publish-approval')));
    expect(warnings, anyElement(contains('code-audit')));
    expect(warnings, anyElement(contains('test-audit')));
    expect(warnings, anyElement(contains('implementation')));
  });

  test('la plantilla nueva pasa limpia', () {
    final lints = lintWorkflowCapabilities(
      defaultWorkflowCapabilities(WorkflowKind.general, 'dev'),
    );

    expect(
      lints.where((lint) => lint.severity != WorkflowLintSeverity.info),
      isEmpty,
    );
  });

  test('la plantilla nueva son cuatro nodos: plan, implement, audit, deliver '
      'con aprobación', () {
    final capabilities = defaultWorkflowCapabilities(WorkflowKind.bug, 'dev');

    expect(
      capabilities.map((c) => c.id),
      ['plan', 'implement', 'audit', 'deliver'],
    );
    final audit = capabilities.firstWhere((c) => c.id == 'audit');
    expect(audit.outputContract, 'audit-feedback');
    expect(audit.requiresIndependentOwner, isTrue);
    expect(audit.executor, WorkflowExecutor.newSession);
    final deliver = capabilities.firstWhere((c) => c.id == 'deliver');
    expect(deliver.approvalRequired, isTrue);
    expect(deliver.executor, WorkflowExecutor.resumeParent);
    expect(deliver.parentCapabilityId, 'implement');
  });

  test('un nodo de auditoría sin contrato de salida es error', () {
    final lints = lintWorkflowCapabilities(const [
      WorkflowCapability(id: 'implement', title: 'I', instruction: 'Implementar.', role: 'dev'),
      WorkflowCapability(id: 'review', title: 'R', instruction: 'Revisar.', role: 'revisor', dependencyIds: ['implement'], readOnly: true),
    ]);

    expect(
      lints.where((lint) => lint.severity == WorkflowLintSeverity.error).map((l) => l.message),
      anyElement(contains('review')),
    );
  });
}
