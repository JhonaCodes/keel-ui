import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/modules/agent_profiles/model/agent_profile.dart';
import 'package:keel_ui/src/modules/projects/model/project.dart';
import 'package:keel_ui/src/modules/projects/model/resolution_case.dart';
import 'package:keel_ui/src/modules/projects/model/resolution_preflight.dart';
import 'package:keel_ui/src/modules/projects/model/session.dart';
import 'package:keel_ui/src/modules/projects/model/work_node.dart';
import 'package:keel_ui/src/modules/projects/ui/widget/workflow_progress_panel.dart';
import 'package:keel_ui/src/modules/workflows/model/workflow.dart';

final _epoch = DateTime(2026, 8, 24);

void main() {
  testWidgets('muestra los agentes y el contexto configurado del workflow', (
    tester,
  ) async {
    await _useTallPanelSurface(tester);
    final workflow = Workflow(
      id: 'nuiapp-tdd',
      name: 'nuiapp-tdd',
      whenToApply: 'Cambios en NUI.',
      createdAt: _epoch,
      policy: const WorkflowPolicy(
        resolutionRole: 'resolver',
        requiredSkillNames: ['flutter-dart-expert'],
        requiredRuleNames: ['nui-rules'],
        requiredKnowledgeBaseNames: ['NUI'],
      ),
    );
    final project = Project(
      id: 'nui',
      name: 'nui-app',
      purpose: '',
      workingDirectory: '/tmp/nui',
      createdAt: _epoch,
      ruleNames: ['project-rules'],
      knowledgeBaseNames: ['NUI Docs'],
    );
    final members = [
      AgentProfile(
        id: 'resolver',
        name: 'flutter-expert',
        role: 'resolver',
        systemPrompt: '',
        model: 'sonnet',
        effort: 'normal',
        createdAt: _epoch,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 272,
            child: WorkflowProgressPanel(
              project: project,
              session: Session(
                id: 's',
                title: 'Nueva sesión',
                createdAt: _epoch,
                resolutionCase: const ResolutionCase(
                  id: 'case',
                  ownerRole: 'resolver',
                  status: ResolutionCaseStatus.active,
                  nodes: [
                    WorkNode(
                      id: 'triage',
                      kind: WorkNodeKind.triage,
                      ownerRole: 'resolver',
                      status: WorkNodeStatus.running,
                    ),
                  ],
                ),
              ),
              workflow: workflow,
              members: members,
            ),
          ),
        ),
      ),
    );

    expect(find.text('WORKFLOW EN CURSO'), findsOneWidget);
    expect(find.text('Triage y contrato'), findsOneWidget);
    expect(find.text('flutter-expert'), findsWidgets);
    expect(find.textContaining('Sonnet 5'), findsWidgets);
    expect(find.text('ahora'), findsOneWidget);
    expect(find.text('Skills'), findsOneWidget);
    expect(find.text('flutter-dart-expert'), findsOneWidget);
    expect(find.text('Reglas'), findsOneWidget);
    expect(find.text('nui-rules'), findsOneWidget);
    expect(find.text('project-rules'), findsOneWidget);
    expect(find.text('Conocimiento y documentación'), findsOneWidget);
    expect(find.text('NUI'), findsOneWidget);
    expect(find.text('NUI Docs'), findsOneWidget);
  });

  testWidgets('distingue bloqueo y capacidad opcional disponible', (
    tester,
  ) async {
    await _useTallPanelSurface(tester);
    final workflow = Workflow(
      id: 'adaptive',
      name: 'adaptive',
      whenToApply: '',
      createdAt: _epoch,
      capabilities: const [
        WorkflowCapability(
          id: 'implementation',
          title: 'Implementar',
          instruction: 'Corregir.',
          role: 'resolver',
        ),
        WorkflowCapability(
          id: 'audit',
          title: 'Auditar',
          instruction: 'Revisar.',
          role: 'resolver',
          dependencyIds: ['implementation'],
          activation: WorkflowCapabilityActivation.optional,
        ),
      ],
    );
    final project = Project(
      id: 'p',
      name: 'nui-app',
      purpose: '',
      workingDirectory: '/tmp',
      createdAt: _epoch,
    );
    final member = AgentProfile(
      id: 'resolver',
      name: 'resolver',
      role: 'resolver',
      systemPrompt: '',
      model: 'sonnet',
      effort: 'medium',
      createdAt: _epoch,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 272,
            child: WorkflowProgressPanel(
              project: project,
              session: Session(
                id: 's',
                title: 's',
                createdAt: _epoch,
                resolutionCase: const ResolutionCase(
                  id: 'case',
                  ownerRole: 'resolver',
                  status: ResolutionCaseStatus.blocked,
                  nodes: [
                    WorkNode(
                      id: 'implementation',
                      kind: WorkNodeKind.implementation,
                      ownerRole: 'resolver',
                      ownerProfileId: 'resolver',
                      title: 'Implementar',
                      status: WorkNodeStatus.blocked,
                    ),
                  ],
                ),
              ),
              workflow: workflow,
              members: [member],
            ),
          ),
        ),
      ),
    );
    expect(find.text('bloqueado'), findsOneWidget);
    expect(find.text('disponible'), findsOneWidget);
  });

  testWidgets('al cerrar marca la capacidad opcional como no requerida', (
    tester,
  ) async {
    await _useTallPanelSurface(tester);
    final workflow = Workflow(
      id: 'adaptive',
      name: 'adaptive',
      whenToApply: '',
      createdAt: _epoch,
      capabilities: const [
        WorkflowCapability(
          id: 'implementation',
          title: 'Implementar',
          instruction: 'Corregir.',
          role: 'resolver',
        ),
        WorkflowCapability(
          id: 'audit',
          title: 'Auditar',
          instruction: 'Revisar.',
          role: 'resolver',
          activation: WorkflowCapabilityActivation.optional,
        ),
      ],
    );
    final project = Project(
      id: 'p',
      name: 'nui-app',
      purpose: '',
      workingDirectory: '/tmp',
      createdAt: _epoch,
    );
    final member = AgentProfile(
      id: 'resolver',
      name: 'resolver',
      role: 'resolver',
      systemPrompt: '',
      model: 'sonnet',
      effort: 'medium',
      createdAt: _epoch,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 272,
            child: WorkflowProgressPanel(
              project: project,
              session: Session(
                id: 's',
                title: 's',
                createdAt: _epoch,
                resolutionCase: const ResolutionCase(
                  id: 'case',
                  ownerRole: 'resolver',
                  status: ResolutionCaseStatus.completed,
                  nodes: [
                    WorkNode(
                      id: 'implementation',
                      kind: WorkNodeKind.implementation,
                      ownerRole: 'resolver',
                      ownerProfileId: 'resolver',
                      title: 'Implementar',
                      status: WorkNodeStatus.done,
                    ),
                  ],
                ),
              ),
              workflow: workflow,
              members: [member],
            ),
          ),
        ),
      ),
    );
    expect(find.text('listo'), findsOneWidget);
    expect(find.text('no requerido'), findsOneWidget);
  });

  testWidgets('muestra contexto faltante y bloqueo persistido del preflight', (
    tester,
  ) async {
    await _useTallPanelSurface(tester);
    final workflow = Workflow(
      id: 'blocked',
      name: 'workflow-bloqueado',
      whenToApply: '',
      createdAt: _epoch,
      policy: const WorkflowPolicy(
        resolutionRole: 'resolver',
        requiredSkillNames: ['skill-ausente'],
        requiredRuleNames: ['regla-ausente'],
        requiredKnowledgeBaseNames: ['docs-ausentes'],
      ),
    );
    final project = Project(
      id: 'p',
      name: 'nui-app',
      purpose: '',
      workingDirectory: '/tmp',
      createdAt: _epoch,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 272,
            child: WorkflowProgressPanel(
              project: project,
              session: Session(
                id: 's',
                title: 's',
                createdAt: _epoch,
                resolutionCase: const ResolutionCase(
                  id: 'case',
                  ownerRole: 'resolver',
                  status: ResolutionCaseStatus.blocked,
                  preflight: ResolutionPreflight(
                    performed: true,
                    missingSkills: ['skill-ausente'],
                    missingRules: ['regla-ausente'],
                    missingKnowledge: ['docs-ausentes'],
                  ),
                ),
              ),
              workflow: workflow,
              members: const [],
            ),
          ),
        ),
      ),
    );

    expect(find.textContaining('Preflight bloqueado:'), findsOneWidget);
    expect(find.text('skill-ausente'), findsOneWidget);
    expect(find.text('regla-ausente'), findsOneWidget);
    expect(find.text('docs-ausentes'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsNWidgets(3));
  });
}

Future<void> _useTallPanelSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(320, 1800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}
