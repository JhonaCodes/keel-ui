import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/modules/workflows/model/workflow.dart';
import 'package:keel_ui/src/modules/workflows/repository/workflows_repository.dart';

void main() {
  group('Workflow adaptativo', () {
    test('el cupo de subagentes sobrevive al viaje por disco', () {
      final policy = WorkflowPolicy.fromJson({
        'maxSubagents': kMaxSubagentsPerNode,
      });

      // Estaba recortado a 1 al LEER: el valor que el usuario elegía en la UI
      // se guardaba bien y se perdía en silencio al recargar la app.
      expect(policy.maxSubagents, kMaxSubagentsPerNode);
    });

    test('el cupo de subagentes sigue teniendo techo', () {
      expect(
        WorkflowPolicy.fromJson({'maxSubagents': 99}).maxSubagents,
        kMaxSubagentsPerNode,
      );
      expect(WorkflowPolicy.fromJson({'maxSubagents': -1}).maxSubagents, 0);
    });

    test('descarta la cadena ordenada al leer un registro anterior', () {
      final workflow = Workflow.fromJson({
        'id': 'legacy',
        'name': 'cadena anterior',
        'whenToApply': 'tickets',
        'createdAt': DateTime(2026).toIso8601String(),
        'steps': [
          {
            'id': '1',
            'title': 'analizar',
            'role': 'analista',
            'instruction': 'posición fija',
          },
        ],
      });

      expect(workflow.toJson(), isNot(contains('steps')));
    });

    test('conserva sus capacidades adaptativas y dependencias', () {
      final workflow = Workflow.fromJson({
        'id': 'migration',
        'name': 'migración',
        'whenToApply': 'migraciones',
        'createdAt': DateTime(2026).toIso8601String(),
        'capabilities': [
          {
            'id': 'diagnosis',
            'title': 'Mapa de dependencias',
            'instruction': 'Inventariar impacto.',
            'role': 'diagnosticador',
            'dependencyIds': <String>[],
            'activation': 'required',
          },
          {
            'id': 'device-e2e',
            'title': 'Verificación end-to-end',
            'instruction': 'Validar en dispositivo.',
            'role': 'mcp-e2e-tester',
            'dependencyIds': ['implementation'],
            'activation': 'optional',
            'requiresIndependentOwner': true,
          },
        ],
      });

      expect(workflow.toJson()['capabilities'], [
        {
          'id': 'diagnosis',
          'title': 'Mapa de dependencias',
          'instruction': 'Inventariar impacto.',
          'role': 'diagnosticador',
          'dependencyIds': <String>[],
          'activation': 'required',
          'executor': 'newSession',
          'parentCapabilityId': '',
          'maxAgenticTurns': 0,
          'readOnly': false,
          'outputContract': '',
          'requiresIndependentOwner': false,
          'approvalRequired': false,
        },
        {
          'id': 'device-e2e',
          'title': 'Verificación end-to-end',
          'instruction': 'Validar en dispositivo.',
          'role': 'mcp-e2e-tester',
          'dependencyIds': ['implementation'],
          'activation': 'optional',
          'executor': 'newSession',
          'parentCapabilityId': '',
          'maxAgenticTurns': 0,
          'readOnly': false,
          'outputContract': '',
          'requiresIndependentOwner': true,
          'approvalRequired': false,
        },
      ]);
    });

    test('migra filas registradas conservando agentes sin ejecutar ocho', () {
      final workflow = migrateWorkflowRecord({
        'id': 'migration-riverpod',
        'name': 'migracion-riverpod-rn',
        'whenToApply': 'Migraciones complejas.',
        'createdAt': DateTime(2026).toIso8601String(),
        'steps': [
          {
            'id': 'map',
            'title': 'Mapa de dependencias',
            'role': 'diagnosticador',
            'instruction': 'Inventariar.',
          },
          {
            'id': 'design',
            'title': 'Diseño de entrada',
            'role': 'planificador',
            'instruction': 'Diseñar.',
          },
          {
            'id': 'implementation',
            'title': 'Implementar capa por capa',
            'role': 'flutter-expert',
            'instruction': 'Implementar.',
          },
          {
            'id': 'audit',
            'title': 'Auditar código',
            'role': 'auditor-codigo',
            'instruction': 'Auditar.',
          },
          {
            'id': 'verification',
            'title': 'Verificación de cierre',
            'role': 'verificador',
            'instruction': 'Verificar.',
          },
        ],
      });

      expect(workflow.name, 'migracion-riverpod-rn');
      expect(workflow.kind, WorkflowKind.migration);
      expect(workflow.capabilities, hasLength(5));
      expect(
        workflow.capabilities.map((entry) => entry.role),
        containsAll([
          'diagnosticador',
          'planificador',
          'flutter-expert',
          'auditor-codigo',
          'verificador',
        ]),
      );
      expect(
        workflow.capabilities
            .where(
              (entry) =>
                  entry.activation == WorkflowCapabilityActivation.required,
            )
            .map((entry) => entry.id),
        ['map', 'implementation', 'verification'],
      );
      expect(
        workflow.capabilities
            .firstWhere((entry) => entry.id == 'audit')
            .activation,
        WorkflowCapabilityActivation.optional,
      );
      expect(
        workflow.capabilities
            .firstWhere((entry) => entry.id == 'audit')
            .requiresIndependentOwner,
        isTrue,
      );
      expect(workflow.toJson(), isNot(contains('steps')));
    });

    test(
      'reescribe capacidades adaptativas previas con independencia explícita',
      () {
        final workflow = migrateWorkflowRecord({
          'id': 'adaptive-v1',
          'name': 'adaptive-v1',
          'whenToApply': 'Cambios generales.',
          'kind': 'general',
          'policy': const <String, Object?>{},
          'createdAt': DateTime(2026).toIso8601String(),
          'capabilities': const [
            {
              'id': 'implementation',
              'title': 'Implementar',
              'instruction': 'Cambiar.',
              'role': 'implementer',
              'dependencyIds': <String>[],
              'activation': 'required',
            },
            {
              'id': 'audit',
              'title': 'Auditar evidencia',
              'instruction': 'Revisar.',
              'role': 'auditor',
              'dependencyIds': ['implementation'],
              'activation': 'optional',
            },
          ],
        });

        expect(workflow.capabilities, hasLength(2));
        expect(workflow.capabilities.first.requiresIndependentOwner, isFalse);
        expect(workflow.capabilities.last.requiresIndependentOwner, isTrue);
        expect(
          workflow.toJson()['capabilities'],
          everyElement(contains('requiresIndependentOwner')),
        );
      },
    );

    test('las auditorías default exigen un dueño independiente', () {
      final capabilities = defaultWorkflowCapabilities(
        WorkflowKind.bug,
        'implementador',
      );

      expect(
        capabilities
            .where(
              (entry) => entry.id == 'code-audit' || entry.id == 'test-audit',
            )
            .every((entry) => entry.requiresIndependentOwner),
        isTrue,
      );
      expect(
        capabilities
            .firstWhere((entry) => entry.id == 'implementation')
            .requiresIndependentOwner,
        isFalse,
      );
    });
  });

  test('rechaza dependencias inexistentes y ciclos de capacidades', () {
    expect(
      validateWorkflowCapabilities(const [
        WorkflowCapability(
          id: 'audit',
          title: 'Audit',
          instruction: 'Audit with clean context.',
          role: 'auditor',
          requiresIndependentOwner: true,
        ),
      ]),
      contains('dependencia'),
    );
    expect(
      validateWorkflowCapabilities(const [
        WorkflowCapability(
          id: 'a',
          title: 'A',
          instruction: 'A',
          role: 'resolver',
          dependencyIds: ['missing'],
        ),
      ]),
      contains('inexistente'),
    );
    expect(
      validateWorkflowCapabilities(const [
        WorkflowCapability(
          id: 'a',
          title: 'A',
          instruction: 'A',
          role: 'resolver',
          dependencyIds: ['b'],
        ),
        WorkflowCapability(
          id: 'b',
          title: 'B',
          instruction: 'B',
          role: 'resolver',
          dependencyIds: ['a'],
        ),
      ]),
      contains('ciclo'),
    );
  });

  group('topes por defecto', () {
    test('un nodo de escritura sin tope declarado corre con el default', () {
      // 26 de 31 workflows guardados tenían `maxAgenticTurns: 0`: "sin
      // tope" significaba turnos ilimitados, no "el default".
      const writes = WorkflowCapability(
        id: 'implement',
        title: 'Implementar',
        instruction: 'Implementar.',
        role: 'implementador',
      );
      const reads = WorkflowCapability(
        id: 'plan',
        title: 'Planificar',
        instruction: 'Planificar.',
        role: 'planificador',
        readOnly: true,
      );
      const explicit = WorkflowCapability(
        id: 'audit',
        title: 'Auditar',
        instruction: 'Auditar.',
        role: 'auditor',
        maxAgenticTurns: 3,
      );

      expect(writes.effectiveMaxAgenticTurns, kDefaultWriteNodeTurns);
      expect(reads.effectiveMaxAgenticTurns, kDefaultReadOnlyNodeTurns);
      expect(explicit.effectiveMaxAgenticTurns, 3);
    });

    test('la policy trae plazos y techo de costo, y sobreviven al disco', () {
      const policy = WorkflowPolicy();
      expect(policy.idleTimeoutMinutes, 10);
      expect(policy.nodeTimeoutMinutes, 45);
      expect(policy.maxSessionCostUsd, 20);

      final custom = policy.copyWith(
        idleTimeoutMinutes: 3,
        nodeTimeoutMinutes: 90,
        maxSessionCostUsd: 5.5,
      );
      expect(WorkflowPolicy.fromJson(custom.toJson()), custom);

      // Un registro anterior a estos campos lee los defaults, no cero.
      expect(WorkflowPolicy.fromJson({'maxReplans': 1}).idleTimeoutMinutes, 10);
    });

    test('la policy trae reuso de sesión, umbral de compactación y tope de '
        'prompt, con defaults al leer registros viejos', () {
      const policy = WorkflowPolicy();
      expect(policy.reuseOwnerSession, isTrue);
      expect(policy.compactAtContextRatio, 0.7);
      expect(policy.systemPromptMaxChars, kDefaultSystemPromptMaxChars);

      final custom = policy.copyWith(
        reuseOwnerSession: false,
        compactAtContextRatio: 0.5,
        systemPromptMaxChars: 20000,
      );
      expect(WorkflowPolicy.fromJson(custom.toJson()), custom);
      expect(WorkflowPolicy.fromJson({}).reuseOwnerSession, isTrue);
    });
  });
}
