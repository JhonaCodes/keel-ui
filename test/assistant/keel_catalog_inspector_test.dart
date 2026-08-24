import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/integrations/assistant_mcp/keel_catalog_inspector.dart';
import 'package:keel_ui/src/modules/agent_profiles/model/agent_profile.dart';
import 'package:keel_ui/src/modules/agents/model/agent_provider.dart';
import 'package:keel_ui/src/modules/projects/model/member_tuning.dart';
import 'package:keel_ui/src/modules/projects/model/project.dart';
import 'package:keel_ui/src/modules/projects/model/session.dart';
import 'package:keel_ui/src/modules/workflows/model/workflow.dart';

void main() {
  final now = DateTime(2026);
  final writer = AgentProfile(
    id: 'writer-id',
    name: 'writer',
    role: 'implementer',
    systemPrompt: 'Resolve work in the detected domain.',
    skills: const ['domain-skill'],
    rules: const ['safe-change'],
    tools: const ['focused-test'],
    mcpServers: const ['source-control'],
    hooks: const ['no-secrets'],
    knowledgeBaseNames: const ['product-docs'],
    model: 'sonnet',
    effort: 'high',
    createdAt: now,
  );
  final auditor = AgentProfile(
    id: 'auditor-id',
    name: 'auditor',
    role: 'auditor',
    systemPrompt: 'Audit evidence independently.',
    model: 'deepseek-chat',
    effort: 'medium',
    provider: AgentProvider.deepSeek,
    createdAt: now,
  );
  final workflow = Workflow(
    id: 'workflow-id',
    name: 'adaptive-change',
    whenToApply: 'Changes that need implementation and evidence.',
    kind: WorkflowKind.general,
    skillNames: const ['turn-skill'],
    buildsRoadmap: true,
    policy: const WorkflowPolicy(
      resolutionRole: 'implementer',
      requiredSkillNames: ['domain-skill'],
      requiredRuleNames: ['safe-change'],
      requiredKnowledgeBaseNames: ['product-docs'],
      qualityGates: [
        WorkflowQualityGate.analysis,
        WorkflowQualityGate.regression,
      ],
      maxReplans: 1,
      maxSubagents: 1,
    ),
    capabilities: const [
      WorkflowCapability(
        id: 'implementation',
        title: 'Implement',
        instruction: 'Produce the smallest integrated change.',
        role: 'implementer',
      ),
      WorkflowCapability(
        id: 'audit',
        title: 'Audit',
        instruction: 'Challenge the evidence with clean context.',
        role: 'auditor',
        dependencyIds: ['implementation'],
        activation: WorkflowCapabilityActivation.optional,
        requiresIndependentOwner: true,
      ),
    ],
    createdAt: now,
  );

  test('describe workflow exposes the complete adaptive contract', () {
    final inspector = KeelCatalogInspector(
      profiles: [writer, auditor],
      workflows: [workflow],
      projects: const [],
      skillNames: const {'turn-skill', 'domain-skill'},
      ruleNames: const {'safe-change'},
      knowledgeBaseNames: const {'product-docs'},
      hookNames: const {'no-secrets'},
    );

    final text = inspector.describeWorkflow(workflow);

    expect(text, contains('ID: workflow-id'));
    expect(text, contains('Skills por turno: turn-skill'));
    expect(text, contains('Skills obligatorias: domain-skill'));
    expect(text, contains('Reglas obligatorias: safe-change'));
    expect(text, contains('Conocimiento obligatorio: product-docs'));
    expect(text, contains('Reformulaciones máximas: 1'));
    expect(text, contains('Subagentes máximos: 1'));
    expect(text, contains('Construye roadmap: sí'));
    expect(text, contains('independiente: sí'));
    expect(text, contains('Challenge the evidence with clean context.'));
  });

  test(
    'complete workflow inventory returns every contract deterministically',
    () {
      final secondWorkflow = workflow.copyWith(name: 'a-second-workflow');
      final inspector = KeelCatalogInspector(
        profiles: [writer, auditor],
        workflows: [workflow, secondWorkflow],
        projects: const [],
        skillNames: const {'turn-skill', 'domain-skill'},
        ruleNames: const {'safe-change'},
        knowledgeBaseNames: const {'product-docs'},
        hookNames: const {'no-secrets'},
      );

      final all = inspector.describeWorkflows();
      expect(all, contains('Workflows completos (2)'));
      expect(all, contains('Workflow "a-second-workflow"'));
      expect(all, contains('Workflow "adaptive-change"'));
      expect(
        all.indexOf('Workflow "a-second-workflow"'),
        lessThan(all.indexOf('Workflow "adaptive-change"')),
      );
      expect(all, contains('Challenge the evidence with clean context.'));

      final filtered = inspector.describeWorkflows(
        names: const ['adaptive-change', 'missing-workflow'],
      );
      expect(filtered, contains('Workflows completos (1)'));
      expect(filtered, contains('Workflow "adaptive-change"'));
      expect(filtered, isNot(contains('Workflow "a-second-workflow"')));
      expect(filtered, contains('No encontrados: missing-workflow'));
    },
  );

  test('describe agent and project includes effective runtime assignments', () {
    final project = Project(
      id: 'project-id',
      name: 'generic-project',
      purpose: 'Any technology selected by its own context.',
      workingDirectory: '/workspace/generic',
      profileIds: [writer.id, auditor.id],
      workflowIds: [workflow.id, 'missing-workflow'],
      ruleNames: const ['safe-change'],
      hookNames: const ['no-secrets'],
      knowledgeBaseNames: const ['product-docs'],
      memberTuning: const {
        'writer-id': MemberTuning(
          provider: AgentProvider.openRouter,
          model: 'vendor/model',
        ),
      },
      workflowNodeAssignments: const {
        'workflow-id': {'audit': 'auditor-id'},
      },
      activeWorkflowId: workflow.id,
      sessions: [
        Session(
          id: 'legacy-session',
          title: 'Legacy session',
          workflowId: 'retired-workflow-id',
          createdAt: now,
        ),
      ],
      createdAt: now,
    );
    final inspector = KeelCatalogInspector(
      profiles: [writer, auditor],
      workflows: [workflow],
      projects: [project],
      skillNames: const {'turn-skill', 'domain-skill'},
      ruleNames: const {'safe-change'},
      knowledgeBaseNames: const {'product-docs'},
      hookNames: const {'no-secrets'},
    );

    expect(
      inspector.describeAgent(writer),
      contains('Conocimiento: product-docs'),
    );
    expect(inspector.describeAgent(writer), contains('Hooks: no-secrets'));
    final text = inspector.describeProject(project);
    expect(
      text,
      contains('@writer · implementer · openrouter/vendor/model/high'),
    );
    expect(text, contains('missing-workflow [REFERENCIA INVÁLIDA]'));
    expect(text, contains('adaptive-change/audit → @auditor'));
    expect(text, contains('Hooks: no-secrets'));

    final inventory = inspector.describeProjects(
      names: const ['generic-project', 'missing-project'],
    );
    expect(inventory, contains('Proyectos completos (1)'));
    expect(inventory, contains('Proyecto "generic-project"'));
    expect(inventory, contains('missing-workflow [REFERENCIA INVÁLIDA]'));
    expect(inventory, contains('retired-workflow-id [REFERENCIA INVÁLIDA]'));
    expect(inventory, contains('No encontrados: missing-project'));
  });

  test('catalog integrity reports every dangling or missing requirement', () {
    final brokenWorkflow = workflow.copyWith(
      policy: workflow.policy.copyWith(
        requiredSkillNames: const ['missing-skill'],
      ),
    );
    final brokenProject = Project(
      id: 'broken-project-id',
      name: 'broken-project',
      purpose: '',
      workingDirectory: '/workspace/broken',
      profileIds: const ['missing-profile'],
      workflowIds: const ['missing-workflow'],
      ruleNames: const ['missing-rule'],
      hookNames: const ['missing-hook'],
      knowledgeBaseNames: const ['missing-docs'],
      workflowNodeAssignments: const {
        'workflow-id': {'missing-node': 'missing-profile'},
      },
      activeWorkflowId: 'missing-workflow',
      createdAt: now,
    );
    final inspector = KeelCatalogInspector(
      profiles: [writer, auditor],
      workflows: [brokenWorkflow],
      projects: [brokenProject],
      skillNames: const {'turn-skill'},
      ruleNames: const {'safe-change'},
      knowledgeBaseNames: const {'product-docs'},
      hookNames: const {'no-secrets'},
    );

    final issues = inspector.integrityIssues.join('\n');
    expect(issues, contains('missing-skill'));
    expect(issues, contains('missing-profile'));
    expect(issues, contains('missing-workflow'));
    expect(issues, contains('missing-rule'));
    expect(issues, contains('missing-hook'));
    expect(issues, contains('missing-docs'));
    expect(issues, contains('missing-node'));
  });

  test('catalog integrity reports a missing project resolution owner', () {
    final project = Project(
      id: 'ownerless-project-id',
      name: 'ownerless-project',
      purpose: '',
      workingDirectory: '/workspace/ownerless',
      profileIds: [auditor.id],
      workflowIds: [workflow.id],
      createdAt: now,
    );
    final inspector = KeelCatalogInspector(
      profiles: [writer, auditor],
      workflows: [workflow],
      projects: [project],
      skillNames: const {'turn-skill', 'domain-skill'},
      ruleNames: const {'safe-change'},
      knowledgeBaseNames: const {'product-docs'},
      hookNames: const {'no-secrets'},
    );

    expect(
      inspector.integrityIssues.join('\n'),
      contains('no resuelve al responsable implementer'),
    );
  });

  test('project identity includes hook assignments', () {
    final project = Project(
      id: 'identity-project',
      name: 'identity-project',
      purpose: '',
      workingDirectory: '/workspace',
      createdAt: now,
    );

    expect(project.copyWith(hookNames: const ['guard']), isNot(project));
  });
}
