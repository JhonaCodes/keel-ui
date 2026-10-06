import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/core/services/local_database.dart';
import 'package:keel_core/core/store/keel_store.dart';
import 'package:keel_ui/src/core/services/flutter_local_db_store.dart';
import 'package:keel_ui/src/modules/workflows/model/e2e_device_workflow.dart';
import 'package:keel_core/modules/workflows/model/workflow_capability.dart';
import 'package:keel_ui/src/modules/workflows/viewmodel/workflows_viewmodel.dart';

void main() {
  setUpAll(LocalDatabase.markUnavailable);
  setUpAll(() => KeelStore.instance = const FlutterLocalDbStore());

  test(
    'el workflow sembrado de keel-e2e registra, usa keel-e2e y pasa el lint',
    () async {
      // RED antes del fix: `seedE2eDeviceWorkflow` no existía, o su lista de
      // capacidades disparaba el lint de auditoría existente (`diagnosis`
      // readOnly dependiendo de un nodo que escribe) y `createWorkflow`
      // rechazaba el registro en silencio.
      await seedE2eDeviceWorkflow();

      final workflows = WorkflowsService.instance.notifier;
      final seeded = workflows.data.workflows
          .where((workflow) => workflow.name == kE2eDeviceWorkflowName)
          .firstOrNull;

      expect(seeded, isNotNull, reason: 'el lint lo debe haber dejado pasar');
      expect(seeded!.usesKeelE2e, isTrue);
      expect(
        seeded.capabilities.map((c) => c.id),
        ['e2e-run', 'diagnosis', 'fix', 'e2e-verify'],
      );
      expect(seeded.capabilities.first.dependencyIds, isEmpty);
      expect(
        seeded.capabilities.first.outputContract,
        isNot('audit-feedback'),
      );
      expect(
        seeded.capabilities.last.outputContract,
        'audit-feedback',
      );
      expect(seeded.capabilities.last.requiresIndependentOwner, isTrue);

      // Re-sembrar no duplica el registro.
      await seedE2eDeviceWorkflow();
      expect(
        workflows.data.workflows
            .where((workflow) => workflow.name == kE2eDeviceWorkflowName),
        hasLength(1),
      );
    },
  );

  test('lintWorkflowCapabilities no rechaza las capacidades sembradas', () {
    final lints = lintWorkflowCapabilities(e2eDeviceWorkflowCapabilities());
    expect(
      lints.where((lint) => lint.severity == WorkflowLintSeverity.error),
      isEmpty,
    );
  });
}
