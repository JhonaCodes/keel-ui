import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/modules/assistant/model/assistant_action.dart';
import 'package:keel_ui/src/modules/assistant/service/assistant_action_parser.dart';
import 'package:keel_ui/src/modules/workflows/model/workflow.dart';

void main() {
  test('el bloque workflow conserva todo su contexto obligatorio', () {
    final actions = parseAssistantActions('''
```workflow
nombre: nuiapp-tdd
cuando: Cambios Flutter en NUI.
tipo: bug
responsable: resolver
skills: flutter-dart-expert
reglas: nui-rules
conocimiento: NUI Docs
gates: analysis, focusedTests, regression
max_reformulaciones: 1
max_subagentes: 2
capacidades: diagnose|Diagnosticar|diagnosticador|required||shared|Aislar la causa ;; implement|Implementar|implementador|required|diagnose|shared|Corregir con pruebas ;; audit|Auditar|auditor|optional|implement|independent|Revisar evidencia
```
''');

    final workflow = actions.single as CreateWorkflowAction;
    expect(workflow.requiredRuleNames, ['nui-rules']);
    expect(workflow.requiredKnowledgeBaseNames, ['NUI Docs']);
    expect(workflow.qualityGates, [
      WorkflowQualityGate.analysis,
      WorkflowQualityGate.focusedTests,
      WorkflowQualityGate.regression,
    ]);
    expect(workflow.maxReplans, 1);
    expect(workflow.maxSubagents, 2);
    expect(workflow.capabilities, hasLength(3));
    expect(workflow.capabilities[1].dependencyIds, ['diagnose']);
    expect(
      workflow.capabilities.last.activation,
      WorkflowCapabilityActivation.optional,
    );
    expect(workflow.capabilities.last.requiresIndependentOwner, isTrue);
    expect(workflow.capabilities.first.requiresIndependentOwner, isFalse);
  });

  test('rechaza la forma anterior sin semántica de independencia', () {
    final workflow =
        parseAssistantActions('''
```workflow
nombre: compatible
capacidades: implement|Implementar|resolver|required||Corregir|aunque contenga pipes
```
''').single
            as CreateWorkflowAction;

    expect(workflow.capabilities, isEmpty);
  });

  test(
    'el fallback conserva hooks, conocimiento y alcance sin asumir stack',
    () {
      final actions = parseAssistantActions('''
```agente
handle: domain-worker
rol: implementer
proposito: Resolver en el dominio detectado.
instrucciones: Cargar el contexto declarado por el proyecto.
hooks: no-secrets
conocimiento: product-docs
proveedor: openrouter
modelo: vendor/model
esfuerzo: high
constructor: no
```
```workflow
nombre: generic-change
construye_roadmap: no
capacidades: implement|Implementar|implementer|required||shared|Resolver sin asumir tecnología
```
```proyecto
nombre: product-area
proposito: Un límite de trabajo definido por el usuario.
carpeta: /workspace/product
agentes: domain-worker
workflows: generic-change
hooks: no-secrets
mantenido: no
```
''');

      final agent = actions.whereType<CreateAgentAction>().single;
      final workflow = actions.whereType<CreateWorkflowAction>().single;
      final project = actions.whereType<CreateProjectAction>().single;
      expect(agent.hookNames, ['no-secrets']);
      expect(agent.knowledgeBaseNames, ['product-docs']);
      expect(agent.providerAlias, 'openrouter');
      expect(agent.model, 'vendor/model');
      expect(agent.effort, 'high');
      expect(agent.systemBuilder, isFalse);
      expect(workflow.buildsRoadmap, isFalse);
      expect(project.hookNames, ['no-secrets']);
      expect(project.maintained, isFalse);
    },
  );
}
