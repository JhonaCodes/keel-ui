import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/modules/workflows/model/workflow.dart';
import 'package:keel_ui/src/modules/workflows/repository/workflows_repository.dart';

/// El techo de costo por sesión no tiene default: un caso no se corta por
/// precio salvo que alguien lo declare. El default anterior (US$ 20) cortaba
/// trabajo a mitad de implementación sin que nadie lo hubiera elegido.
void main() {
  group('techo de costo por sesión', () {
    test('sin valor declarado, la policy corre sin techo', () {
      expect(kDefaultMaxSessionCostUsd, 0);
      expect(const WorkflowPolicy().maxSessionCostUsd, 0);
    });

    test('un registro anterior al campo se lee sin techo', () {
      expect(
        WorkflowPolicy.fromJson(const {'maxReplans': 1}).maxSessionCostUsd,
        0,
      );
      expect(WorkflowPolicy.fromJson(null).maxSessionCostUsd, 0);
    });

    test('un techo declarado a mano sobrevive al disco', () {
      const policy = WorkflowPolicy(maxSessionCostUsd: 5.5);
      expect(WorkflowPolicy.fromJson(policy.toJson()).maxSessionCostUsd, 5.5);
    });

    test('se retira el techo heredado del default viejo, no los elegidos', () {
      final normalized = normalizeLegacyCostCeilings([
        _workflow('heredado', kLegacyDefaultMaxSessionCostUsd),
        _workflow('elegido', 50),
        _workflow('sin-techo', 0),
      ]);

      expect(normalized[0].policy.maxSessionCostUsd, 0);
      expect(normalized[1].policy.maxSessionCostUsd, 50);
      expect(normalized[2].policy.maxSessionCostUsd, 0);
    });

    test('retirar el techo no toca el resto de la policy', () {
      final normalized = normalizeLegacyCostCeilings([
        _workflow('heredado', kLegacyDefaultMaxSessionCostUsd),
      ]).single;

      expect(normalized.policy.idleTimeoutMinutes, kDefaultIdleTimeoutMinutes);
      expect(normalized.policy.nodeTimeoutMinutes, kDefaultNodeTimeoutMinutes);
      expect(normalized.name, 'heredado');
    });
  });
}

Workflow _workflow(String id, double ceiling) => Workflow(
  id: id,
  name: id,
  whenToApply: '',
  createdAt: DateTime.utc(2026),
  policy: WorkflowPolicy(maxSessionCostUsd: ceiling),
);
