import 'package:flutter_test/flutter_test.dart';

import 'package:keel_core/modules/workflows/model/workflow.dart';
import 'package:keel_core/modules/workflows/repository/workflows_repository.dart';

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
          'mcpServers': <String>[],
          'e2eScenarios': {'kind': 'all'},
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
          'mcpServers': <String>[],
          'e2eScenarios': {'kind': 'all'},
        },
      ]);
    });

    test(
      'una capacidad parseada de un JSON anterior carga mcpServers y '
      'e2eScenarios por defecto',
      () {
        final capability = WorkflowCapability.fromJson({
          'id': 'implement',
          'title': 'Implementar',
          'instruction': 'Implementar.',
          'role': 'implementador',
        });

        // RED antes del fix: el campo no existía, así que esto fallaba en
        // compilación/lectura. El oráculo es el valor leído, no solo que no
        // reviente.
        expect(capability.mcpServers, isEmpty);
        expect(capability.e2eScenarios, const AllScenarios());
        expect(capability.usesKeelE2e, isFalse);
      },
    );

    test('mcpServers y e2eScenarios sobreviven al viaje por disco', () {
      const capability = WorkflowCapability(
        id: 'e2e-run',
        title: 'Correr E2E',
        instruction: 'Correr escenarios de e2e/.',
        role: 'verifier',
        mcpServers: [kKeelE2eMcpServerName],
        e2eScenarios: TaggedScenarios(['pedidos']),
      );

      final roundTripped = WorkflowCapability.fromJson(capability.toJson());

      expect(roundTripped.mcpServers, [kKeelE2eMcpServerName]);
      expect(roundTripped.usesKeelE2e, isTrue);
      expect(roundTripped.e2eScenarios, const TaggedScenarios(['pedidos']));
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

    test(
      'usesKeelE2e es true solo con una capacidad requerida que declare '
      'keel-e2e',
      () {
        final sinE2e = Workflow(
          id: 'w1',
          name: 'w1',
          whenToApply: '',
          createdAt: DateTime(2026),
          capabilities: const [
            WorkflowCapability(
              id: 'implement',
              title: 'Implementar',
              instruction: 'Implementar.',
              role: 'implementador',
            ),
          ],
        );
        expect(sinE2e.usesKeelE2e, isFalse);

        final conE2eOpcional = sinE2e.copyWith(
          capabilities: [
            ...sinE2e.capabilities,
            const WorkflowCapability(
              id: 'e2e',
              title: 'E2E',
              instruction: 'Correr E2E.',
              role: 'verifier',
              activation: WorkflowCapabilityActivation.optional,
              mcpServers: [kKeelE2eMcpServerName],
            ),
          ],
        );
        expect(
          conE2eOpcional.usesKeelE2e,
          isFalse,
          reason: 'un nodo OPCIONAL nunca se instancia solo',
        );

        final conE2eRequerido = sinE2e.copyWith(
          capabilities: [
            ...sinE2e.capabilities,
            const WorkflowCapability(
              id: 'e2e',
              title: 'E2E',
              instruction: 'Correr E2E.',
              role: 'verifier',
              mcpServers: [kKeelE2eMcpServerName],
            ),
          ],
        );
        expect(conE2eRequerido.usesKeelE2e, isTrue);
      },
    );

    test(
      'la plantilla de migración declara keel-e2e en su device-e2e opcional',
      () {
        final capabilities = defaultWorkflowCapabilities(
          WorkflowKind.migration,
          'verifier',
        );
        final deviceE2e = capabilities.firstWhere((c) => c.id == 'device-e2e');
        expect(deviceE2e.usesKeelE2e, isTrue);
        expect(deviceE2e.activation, WorkflowCapabilityActivation.optional);
      },
    );

    test('las auditorías default exigen un dueño independiente', () {
      final capabilities = defaultWorkflowCapabilities(
        WorkflowKind.bug,
        'implementador',
      );

      final audits = capabilities.where((entry) => entry.id == 'audit');
      expect(audits, isNotEmpty);
      expect(audits.every((entry) => entry.requiresIndependentOwner), isTrue);
      expect(
        capabilities
            .firstWhere((entry) => entry.id == 'implement')
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
    test('un nodo sin tope declarado corre SIN tope; el declarado se respeta', () {
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

        // 0 = SIN TOPE, por decisión explícita del usuario: un default de
        // turnos cortaba trabajo legítimo (un nodo real se pausó a los 200
        // turnos trabajando bien). El único freno es el techo de costo, si se
        // declara — no un contador.
        expect(writes.effectiveMaxAgenticTurns, 0);
        expect(reads.effectiveMaxAgenticTurns, 0);
        expect(explicit.effectiveMaxAgenticTurns, 3);
      },
    );

    test(
      'un workflow guardado con topes de reloj los pierde al volver a disco',
      () {
        // Registro real: los workflows creados con el default anterior quedaron
        // con 10 min de inactividad y 45 por paso, y seguían cortando pasos
        // largos aunque el default ya fuera «sin límite».
        final legacy = WorkflowPolicy.fromJson({
          'idleTimeoutMinutes': 10,
          'nodeTimeoutMinutes': 45,
          'maxSessionCostUsd': 5.5,
        });

        final saved = legacy.toJson();

        expect(saved, isNot(contains('idleTimeoutMinutes')));
        expect(saved, isNot(contains('nodeTimeoutMinutes')));
        expect(saved['maxSessionCostUsd'], 5.5);
      },
    );

    test('los topes altos sobreviven al disco: leer no los recorta', () {
      // Regresión: `fromJson` recortaba `maxReplans` a 0..2 y
      // `maxReviewCycles` a 1..4 con números escritos a mano, más bajos que
      // los que acepta el formulario. Un workflow guardado con los defaults
      // volvía del disco con otros valores, y el editor —cuyo slider llega
      // hasta el techo real— reventaba al renderizar el valor recortado.
      const policy = WorkflowPolicy();
      final leido = WorkflowPolicy.fromJson(policy.toJson());
      expect(leido.maxReplans, kDefaultMaxReplans);
      expect(leido.maxReviewCycles, kDefaultMaxReviewCycles);
      expect(leido.maxSubagents, kDefaultMaxSubagents);

      // Y el techo declarable entra entero, no recortado.
      final alTope = policy.copyWith(
        maxReplans: kMaxReplans,
        maxReviewCycles: kMaxReviewCycles,
      );
      expect(WorkflowPolicy.fromJson(alTope.toJson()), alTope);
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
