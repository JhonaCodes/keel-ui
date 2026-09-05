import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/l10n/generated/app_localizations.dart';
import 'package:keel_ui/src/core/ui/app_theme.dart';
import 'package:keel_ui/src/modules/agent_profiles/model/agent_profile.dart';
import 'package:keel_ui/src/modules/agent_profiles/viewmodel/agent_profiles_viewmodel.dart';
import 'package:keel_ui/src/modules/knowledge/model/knowledge_base.dart';
import 'package:keel_ui/src/modules/knowledge/viewmodel/knowledge_viewmodel.dart';
import 'package:keel_ui/src/modules/projects/model/project.dart';
import 'package:keel_ui/src/modules/projects/model/resolution_case.dart';
import 'package:keel_ui/src/modules/projects/model/session.dart';
import 'package:keel_ui/src/modules/projects/model/session_subagent.dart';
import 'package:keel_ui/src/modules/projects/model/work_node.dart';
import 'package:keel_ui/src/modules/projects/ui/view/session_map_view.dart';
import 'package:keel_ui/src/modules/projects/ui/view/session_chat_view.dart';
import 'package:keel_ui/src/modules/projects/ui/widget/workflow_progress_panel.dart';
import 'package:keel_ui/src/modules/agents/model/chat_message.dart';
import 'package:keel_ui/src/modules/agents/ui/screen/agents_screen.dart';
import 'package:keel_ui/src/modules/projects/viewmodel/projects_viewmodel.dart';
import 'package:keel_ui/src/modules/rules/model/rule.dart';
import 'package:keel_ui/src/modules/rules/viewmodel/rules_viewmodel.dart';
import 'package:keel_ui/src/modules/sidebar_layout/model/sidebar_layout.dart';
import 'package:keel_ui/src/modules/sidebar_layout/viewmodel/sidebar_layout_viewmodel.dart';
import 'package:keel_ui/src/modules/workflows/model/workflow.dart';
import 'package:keel_ui/src/modules/workflows/ui/screen/workflow_form_screen.dart';
import 'package:keel_ui/src/modules/workflows/viewmodel/workflows_viewmodel.dart';
import 'package:keel_ui/src/modules/workspace/model/workspace_lens.dart';
import 'package:keel_ui/src/modules/workspace/viewmodel/workspace_viewmodel.dart';
import 'package:keel_ui/src/core/services/local_database.dart';

final _date = DateTime.utc(2026, 8, 31, 12);
final _productFont = File('/System/Library/Fonts/Supplemental/Arial.ttf');
final _materialIconsFont = File(
  '/Users/jhonacode/.pub-cache/hosted/pub.dev/provider-6.1.2/'
  'extension/devtools/build/assets/fonts/MaterialIcons-Regular.otf',
);

/// Real PNG returned by mermaid.ink for the small handoff graph in [_session].
/// Keeping the response local makes the golden deterministic and prevents an
/// external HTTP request from holding a widget test open.
/* const _handoffMermaidPng =
    'iVBORw0KGgoAAAANSUhEUgAAA1IAAABGCAIAAABJ6zJAAAAQAElEQVR4nOydB1gUVxeGLwj2FntDwYIFNfaGvfcS+bHFHmsUW+y9xBI1alSMvWs01hi7RqOigCZGBRRBwQJYYwVBQP6PuWGyLuyIIbAb9nsfHpydncbOOed+55w7q1VuWwdBCCGEEEJSO5aCEEIIIYSYAZR9hBBCCCFmAWUfIYQQQohZQNlHCCGEEGIWUPYRQgghhJgFlH2EEEIIIWYBZR8hhBBCiFlA2UcIIYQQYhZQ9hFCCCGEmAWUfYQQQgghZgFlHyGEEEKIWUDZRwghhBBiFlD2EUIIIYSYBZR9hBBCCCFmAWUfIYQQQohZQNlHCCGEEGIWUPYRQgghhJgFlH2EEEIIIWYBZR8hhBBCiFlA2UcIIYQQYhZQ9hFCCCGEmAWUfYQQQgghZgFlHyGEEEKIWUDZRwghhBBiFlgZc7ly5bK1tVWkSBEUFORs7Ny7d8/y5cu0d27dv37Xrl2dO3fC8vhw4zJmzDhy0pT4m32HZskNX19XV1dBjMHmTZtwb9SXbyMjQ4KDg58+ferq6r5+/aq9c8eOHd++fWvXrt0xY4YgRkX3Zklz59+1SxfnTp2wPH7cuIwZM06eMiX+Zt8tWXLD19fV1VUQY7B50ybcGvXl28jIkODgixcvbv/hB/HvUa9ePZehQ/t+8cUHzSaRaFhU8jF48OBSJUu6DBuG5Y0bNhw7fnzr1q2CGBvdGAWio6OfPHni6+u7Zu3a0NBQQUySYsWKfTNv3vQZM65evSqIUen42Wddu3aNv37d+vUHDx4UJoZZaQbjyD7w6PHjVStXYiFzlizlypVr2LAhfo/66iuEV429/Pz8fjpwQBCT57fffjt8+LBczv7JJ9WqVu3QoUPadOk2btwoiAEOHTrke/OmXF6/bt3ESZOCg4MFMRJqjAIZMmasUKECzHjSxInjJ0wQxDDt2rUrVrTot4sWiRTn2bNn+/bte/TokSCmwcJvv30TFqa75t79++K/QxKN2c7ODtWE/gMGCFPCaLIvIjz88h9/yOWzZ88+fPAAmUHBggXv3r2rsZe3giAmz59//qneX3Dq1KnBgwY1a9p08+bN7969EyQhduzcKRfy5cuXNWtWQYyKbowC58+f96pbd5iLS1kHBy9GIcNgqBNGAmFn85YtgpgM165de/XqlfjPkkRjti9RQpgeRpN9erwJD8dv2T0pXbr0rJkzJ02efP36dfnuihUrfv/999WrV+s2eXXBvRny5Zf58+dHF2bX7t26byFG/8/ZGRu8evnyjytXtm3bJs+CQ7Vt02btunWI47/88sv3cWl9KmP3ppVnLrj/sPvAw0dPhFGBoE+XLl2OHDnQLMNLSMDGjRtD6KPF7+7ujha/3CxTpkzoDpQrX75ggQIvXr7EfYdSDFfMA/Tt06d27drhERHn3dyCQ0I0Tle4cOH+/frZ2tqifowtd+7cefnyZawfN3ZsTEzMmbNnBw0ciOu5HRCwZcsW3VwiQ4YMa9asU6dO3b8lSxZUr16dUFMkmLFiv0zb970GTNuXr0qiFHp+NlnXbt2jb9+3fr1Bw8eFCaGWWkG48g+8Ojx41UrV2Ihc5Ys5cqV69iwIX6P+uorhFeNvfz8/H46cEAQkue33347fPiwXM7+6SfVqlbt0KFD2nTpNm7cKIhBjh071nvzplxe v27dxEmTgoODhTESao wCGT JmrFChAsx40sSJ4ydMEMQw7dq1K1a s6LeLFokU59mzZ/v27bv06ZMgRkHCb7/9Eh amuuf f+/fv i v0MSjdnOz s4O1YT+AwYIU8Jos i8iPPzyH3/I5bNmyZc2aNRM nTtW rUqVKlWqVKkS/D3r17dv2Hdu3dFMRJqjAIZMmasUKECzHjSxInjJ0wQxDDt2rUrVrTot4sWiRTn2bNn+/bte/TokSCmwcJvv30TFqa75t79++K/QxKN2c7ODtWE/gMGCFPCaLIvIjz88h9/yOWzZ88+fPAAmUHBggXv3r2rsZe3giAmz59//qneX3Dq1KnBgwY1a9p08+bN7969EyQhduzcKRfy5cuXNWtWQYyKbowC58+f96pbd5iLS1kHBy9GIcNgqBNGAmFn85YtgpgM165de/XqlfjPkkRjti9RQpgeRpN9erwJD8dv2T0pXbr0rJkzJ02efP36dfnuihUrfv/999WrV+s2eXXBvRny5Zf58+dHF2bX7t26byFG/8/ZGRu8evnyjytXtm3bJs+CQ7Vt02btunWI47/88sv3cWl9KmP3ppVnLrj/sPvAw0dPhFGBoE+XLl2OHDnQLMNLSMDGjRtD6KPF7+7ujha/3CxTpkzoDpQrX75ggQIvXr7EfYdSDFfMA/Tt06d27drhERHn3dyCQ0I0Tle4cOH+/frZ2tqifowtd+7cefnyZawfN3ZsTEzMmbNnBw0ciOu5HRCwZcsW3VwiQ4YMa9asU6dO3b8lSxZUr16dUFMkmLFiv0zb970GTNuXr0qiFHp+NlnXbt2jb9+3fr1Bw8eFCaGWWkG48g+8Ojx41UrV2Ihc5Ys5cqV69iwIX6P+uorhFeNvfz8/H46cEAQkue33347fPiwXM7+6SfVqlbt0KFD2nTpNm7cKIhBjh071nvzplxe v27dxEmTgoODhTESao wCGT JmrFChAsx40sSJ4ydMEMQw7dq1K1a s6LeLFokU59mzZ/v27bv06ZMgRkHCb7/9Eh amuuf f+/fv i v0MSjdnOz s4O1YT+AwYIU8Jos i8iPPzyH3/I5bNmyZc2aNRM nTtW rUqVKlWqVKkS/D3r17dv2Hdu3dFMRJqjAIZMmasUKECzHjSxInjJ0wQxDDt2rUrVrTot4sWiRTn2bNn+/bte/TokSCmwcJvv30TFqa75t79++K/QxKN2c7ODtWE/gMGCFPCaLIvIjz88h9/yOWzZ88+fPAAmUHBggXv3r2rsZe3giAmz59//qneX3Dq1KnBgwY1a9p08+bN7969EyQhduzcKRfy5Zf58+dHF2bX7t26byFG/8/ZGRu8evnyjytXtm3bJs+CQ7Vt02btunWI47/88sv3cWl9KmP3ppVnLrj/sPvAw0dPhFGBoE+XLl2OHDnQLMNLSMDGjRtD6KPF7+7ujha/3CxTpkzoDpQrX75ggQIvXr7EfYdSDFfMA/Tt06d27drhERHn3dyCQ0I0Tle4cOH+/frZ2tqifowtd+7cefnyZawfN3ZsTEzMmbNnBw0ciOu5HRCwZcsW3VwiQ4YMa9asU6dO3b8lSxZUrV2Ihc5Ys5cqV69iwIX6P+uorhFeNvfz8/H46cEAQkue33347fPiwXM7+6SfVqlbt0KFD2nTpNm7cKIhBjh071nvzplxe v27dxEmTgoODhTESao wCGT JmrFChAsx40sSJ4ydMEMQw7dq1K1a s6LeLFokU59mzZ/v27bv06ZMgRkHCb7/9Eh amuuf f+/fv i v0MSjdnOz s4O1YT+AwYIU8Jos i8iPPzyH3/I5bNmyZc2aNRM nTtW rUqVKlWqVKkS/D3r17dv2Hdu3dFMRJqjAIZMmasUKECzHjSxInjJ0wQxDDt2rUrVrTot4sWiRTn2bNn+/bte/TokSCmwcJvv30TFqa75t79++K/QxKN2c7ODtWE/gMGCFPCaLIvIjz88h9/yOWzZ88+fPAAmUHBggXv3r2rsZe3giAmz59//qneX3Dq1KnBgwY1a9p08+bN7969EyQhduzcKRfy5cuXNWtWQYyKbowC58+f96pbd5iLS1kHBy9GIcNgqBNGAmFn85YtgpgM165de/XqlfjPkkRjti9RQpgeRpN9erwJD8dv2T0pXbr0rJkzJ02efP36dfnuihUrfv/999WrV+s2eXXBvRny5Zf58+dHF2bX7t26byFG/8/ZGRu8evnyjytXtm3bJs+CQ7Vt02btunWI47/88sv3cWl9KmP3ppVnLrj/sPvAw0dPhFGBoE+XLl2OHDnQLMNLSMDGjRtD6KPF7+7ujha/3CxTpkzoDpQrX75ggQIvXr7EfYdSDFfMA/Tt06d27drhERHn3dyCQ0I0Tle4cOH+/frZ2tqifowtd+7cefnyZawfN3ZsTEzMmbNnBw0ciOu5HRCwZcsW3VwiQ4YMa9asU6dO3b8lSxZUrV2Ihc5Ys5cqV69iwIX6P+uorhFeNvfz8/H46cEAQkue33347fPiwXM7+6SfVqlbt0KFD2nTpNm7cKIhBjh071nvzplxe v27dxEmTgoODhTESao wCGT JmrFChAsx40sSJ4ydMEMQw7dq1K1a s6LeLFokU59mzZ/v27bv06ZMgRkHCb7/9Eh amuuf f+/fv i v0MSjdnOz s4O1YT+AwYIU8Jos i8iPPzyH3/I5bNmyZc2aNRM nTtW rUqVKlWqVKkS/D3r17dv2Hdu3dFMRJqjAIZMmasUKECzHjSxInjJ0wQxDDt2rUrVrTot4sWiRTn2bNn+/bte/TokSCmwcJvv30TFqa75t79++K/QxKN2c7ODtWE/gMGCFPCaLIvIjz88h9/yOWzZ88+fPAAmUHBggXv3r2rsZe3giAmz59//qneX3Dq1KnBgwY1a9p08+bN7969EyQhduzcKRfy5cuXNWtWQYyKbowC58+f96pbd5iLS1kHBy9GIcNgqBNGAmFn85YtgpgM165de/XqlfjPkkRjti9RQpgeRpN9erwJD8dv2T0pXbr0rJkzJ02efP36dfnuihUrfv/999WrV+s2eXXBvRny5Zf58+dHF2bX7t26byFG/8/ZGRu8evnyjytXtm3bJs+CQ7Vt02btunWI47/88sv3cWl9KmP3ppVnLrj/sPvAw0dPhFGBoE+XLl2OHDnQLMNLSMDGjRtD6KPF7+7ujha/3CxTpkzoDpQrX75ggQIvXr7EfYdSDFfMA/Tt06d27drhERHn3dyCQ0I0Tle4cOH+/frZ2tqifowtd+7cefnyZawfN3ZsTEzMmbNnBw0ciOu5HRCwZcsW3VwiQ4YyKbwAAAABJRU5ErkJggg==';

*/

bool get _goldenFontsAvailable =>
    _productFont.existsSync() && _materialIconsFont.existsSync();

/* const _renderedHandoffMermaidPng =
    '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';

*/

Widget _app(Widget child) {
  final theme = buildAppTheme();
  return MaterialApp(
    theme: theme.copyWith(
      textTheme: theme.textTheme.apply(fontFamily: 'GoldenArial'),
      primaryTextTheme: theme.primaryTextTheme.apply(fontFamily: 'GoldenArial'),
    ),
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

Future<void> _goldenSurface(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(1440, 960),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(_app(child));
  await tester.pump(const Duration(milliseconds: 350));
}

final _members = [
  AgentProfile(
    id: 'builder',
    name: 'nova-builder',
    role: 'builder',
    systemPrompt: 'Build carefully.',
    model: 'sonnet',
    effort: 'normal',
    createdAt: _date,
  ),
  AgentProfile(
    id: 'researcher',
    name: 'lumen-researcher',
    role: 'researcher',
    systemPrompt: 'Find the relevant evidence.',
    model: 'sonnet',
    effort: 'normal',
    createdAt: _date,
  ),
  AgentProfile(
    id: 'tester',
    name: 'pulse-tester',
    role: 'tester',
    systemPrompt: 'Prove behavior with tests.',
    model: 'sonnet',
    effort: 'normal',
    createdAt: _date,
  ),
  AgentProfile(
    id: 'auditor',
    name: 'orbit-auditor',
    role: 'auditor',
    systemPrompt: 'Review only.',
    model: 'sonnet',
    effort: 'normal',
    createdAt: _date,
  ),
];

final _workflow = Workflow(
  id: 'delivery-loop',
  name: 'delivery-loop',
  whenToApply: 'A contained product improvement needs planning and evidence.',
  createdAt: _date,
  policy: const WorkflowPolicy(
    resolutionRole: 'builder',
    maxSubagents: 1,
    maxReviewCycles: 4,
    requiredSkillNames: ['product-delivery', 'evidence-review'],
    requiredRuleNames: ['approval-gate', 'evidence-first'],
    requiredKnowledgeBaseNames: ['product-handbook', 'release-notes'],
  ),
  capabilities: const [
    WorkflowCapability(
      id: 'planner',
      title: 'Plan the delivery',
      instruction: 'Define scope, constraints, and acceptance evidence.',
      role: 'builder',
      maxAgenticTurns: 4,
      outputContract: 'A concise delivery plan with evidence.',
    ),
    WorkflowCapability(
      id: 'research',
      title: 'Explore product impact',
      instruction: 'Identify affected behavior and risks.',
      role: 'researcher',
      dependencyIds: ['planner'],
      maxAgenticTurns: 3,
      outputContract: 'Impact findings with source evidence.',
    ),
    WorkflowCapability(
      id: 'implementation',
      title: 'Implement with evidence',
      instruction: 'Make the smallest correct change.',
      role: 'builder',
      dependencyIds: ['planner'],
      maxAgenticTurns: 8,
      outputContract: 'Working change and focused evidence.',
    ),
    WorkflowCapability(
      id: 'code-audit',
      title: 'Audit code',
      instruction: 'Review the change without modifying files.',
      role: 'auditor',
      dependencyIds: ['implementation'],
      executor: WorkflowExecutor.providerSubagent,
      parentCapabilityId: 'implementation',
      maxAgenticTurns: 3,
      readOnly: true,
      outputContract: 'Verdict, findings, evidence, and next actions.',
    ),
    WorkflowCapability(
      id: 'code-correction',
      title: 'Resolve code findings',
      instruction: 'Resolve the complete audit report in the parent session.',
      role: 'builder',
      dependencyIds: ['code-audit'],
      executor: WorkflowExecutor.resumeParent,
      parentCapabilityId: 'implementation',
      maxAgenticTurns: 5,
      outputContract: 'Resolved findings and updated evidence.',
    ),
    WorkflowCapability(
      id: 'tests',
      title: 'Prove the outcome',
      instruction: 'Create and run focused tests.',
      role: 'tester',
      dependencyIds: ['code-correction'],
      executor: WorkflowExecutor.resumeParent,
      parentCapabilityId: 'implementation',
      maxAgenticTurns: 5,
      outputContract: 'Focused test evidence.',
    ),
    WorkflowCapability(
      id: 'test-audit',
      title: 'Audit tests',
      instruction: 'Review test coverage without modifying files.',
      role: 'auditor',
      dependencyIds: ['tests'],
      executor: WorkflowExecutor.providerSubagent,
      parentCapabilityId: 'implementation',
      maxAgenticTurns: 3,
      readOnly: true,
      outputContract: 'Test review verdict and findings.',
    ),
    WorkflowCapability(
      id: 'test-correction',
      title: 'Resolve test findings',
      instruction: 'Resolve findings in the parent implementation session.',
      role: 'builder',
      dependencyIds: ['test-audit'],
      executor: WorkflowExecutor.resumeParent,
      parentCapabilityId: 'implementation',
      maxAgenticTurns: 4,
      outputContract: 'Corrected tests and evidence.',
    ),
    WorkflowCapability(
      id: 'verification',
      title: 'Verify quality gates',
      instruction: 'Run required gates and record their evidence.',
      role: 'builder',
      dependencyIds: ['test-correction'],
      executor: WorkflowExecutor.resumeParent,
      parentCapabilityId: 'implementation',
      maxAgenticTurns: 4,
      outputContract: 'Quality-gate evidence.',
    ),
    WorkflowCapability(
      id: 'publish-approval',
      title: 'Approve publication',
      instruction: 'Wait for explicit user approval before external actions.',
      role: 'builder',
      dependencyIds: ['verification'],
      executor: WorkflowExecutor.manualApproval,
      outputContract: 'Explicit publication approval.',
    ),
    WorkflowCapability(
      id: 'publish',
      title: 'Publish',
      instruction: 'Publish only after explicit approval.',
      role: 'builder',
      dependencyIds: ['publish-approval'],
      executor: WorkflowExecutor.resumeParent,
      parentCapabilityId: 'implementation',
      maxAgenticTurns: 4,
      outputContract: 'Publication evidence.',
    ),
  ],
);

final _project = Project(
  id: 'atlas-workspace',
  name: 'atlas-workspace',
  purpose: 'A generalized product workspace.',
  workingDirectory: '/workspace/atlas',
  profileIds: const ['builder', 'auditor', 'researcher', 'tester'],
  workflowIds: const ['delivery-loop'],
  ruleNames: const ['approval-gate', 'evidence-first'],
  knowledgeBaseNames: const ['product-handbook', 'release-notes'],
  createdAt: _date,
);

final _session = Session(
  id: 'release-brief',
  title: 'Release brief',
  request: 'Improve the approval flow and preserve existing behavior.',
  workflowId: 'delivery-loop',
  createdAt: _date,
  isRunning: true,
  resolutionCase: const ResolutionCase(
    id: 'release-case',
    ownerRole: 'builder',
    status: ResolutionCaseStatus.active,
    nodes: [
      WorkNode(
        id: 'planner',
        kind: WorkNodeKind.triage,
        ownerRole: 'builder',
        ownerProfileId: 'builder',
        status: WorkNodeStatus.done,
        title: 'Plan and scope',
      ),
      WorkNode(
        id: 'research',
        kind: WorkNodeKind.impact,
        ownerRole: 'researcher',
        ownerProfileId: 'researcher',
        dependencyIds: ['planner'],
        status: WorkNodeStatus.done,
        title: 'Explore product impact',
      ),
      WorkNode(
        id: 'implementation',
        kind: WorkNodeKind.implementation,
        ownerRole: 'builder',
        ownerProfileId: 'builder',
        dependencyIds: ['planner'],
        status: WorkNodeStatus.running,
        title: 'Implement with evidence',
      ),
      WorkNode(
        id: 'code-audit',
        kind: WorkNodeKind.custom,
        ownerRole: 'auditor',
        ownerProfileId: 'auditor',
        dependencyIds: ['implementation'],
        status: WorkNodeStatus.pending,
        title: 'Audit code',
      ),
      WorkNode(
        id: 'tests',
        kind: WorkNodeKind.verification,
        ownerRole: 'tester',
        ownerProfileId: 'tester',
        dependencyIds: ['implementation'],
        status: WorkNodeStatus.pending,
        title: 'Prove the outcome',
      ),
    ],
  ),
  messages: [
    ChatMessage(
      role: ChatRole.user,
      text: 'Ship a clearer approval experience without losing safeguards.',
      timestamp: _date,
    ),
    ChatMessage(
      role: ChatRole.assistant,
      text:
          'I scoped the work into an approval path, audit evidence, and release checks.',
      timestamp: _date.add(const Duration(minutes: 1)),
      authorProfileId: 'builder',
      workNodeId: 'planner',
    ),
    ChatMessage(
      role: ChatRole.assistant,
      text:
          'The main risk is bypassing approval after a correction cycle. I mapped the affected states.',
      timestamp: _date.add(const Duration(minutes: 2)),
      authorProfileId: 'researcher',
      workNodeId: 'research',
    ),
    ChatMessage(
      role: ChatRole.assistant,
      text:
          '@orbit-auditor, which audit evidence must remain visible after resuming implementation?',
      timestamp: _date.add(const Duration(minutes: 3)),
      authorProfileId: 'builder',
      workNodeId: 'implementation',
    ),
    ChatMessage(
      role: ChatRole.assistant,
      text:
          'Keep the full report and show the review cycle counter beside the workflow.',
      timestamp: _date.add(const Duration(minutes: 4)),
      authorProfileId: 'auditor',
      workNodeId: 'code-audit',
      consultOfProfileId: 'builder',
    ),
    ChatMessage(
      role: ChatRole.assistant,
      text:
          'I will cover the approval gate, fallback audit, and resumed session behavior.',
      timestamp: _date.add(const Duration(minutes: 5)),
      authorProfileId: 'tester',
      workNodeId: 'tests',
      consultOfProfileId: 'researcher',
    ),
  ],
  subagents: [
    SessionSubagent(
      id: 'audit-1',
      parentProfileId: 'builder',
      parentWorkNodeId: 'implementation',
      agentType: 'code auditor',
      ask: 'Review the implementation for risk and missing evidence.',
      prompt: 'Use the focused audit contract.',
      reasoning: 'Inspecting changed modules and focused tests.',
      phase: SubagentPhase.working,
      startedAt: _date,
    ),
    for (final parent in ['planner', 'implementation', 'research'])
      for (final number in [2, 3])
        SessionSubagent(
          id: '$parent-audit-$number',
          parentProfileId: parent == 'research' ? 'researcher' : 'builder',
          parentWorkNodeId: parent,
          agentType: number == 2 ? 'risk reviewer' : 'evidence reviewer',
          ask: 'Inspect $parent for missing constraints and concrete evidence.',
          prompt: 'Return concise findings only.',
          reasoning: 'Comparing the proposed state with the workflow contract.',
          result: 'One actionable finding recorded.',
          phase: SubagentPhase.done,
          startedAt: _date,
          finishedAt: _date.add(const Duration(minutes: 1)),
        ),
  ],
);

final _rules = [
  Rule(
    id: 'approval-gate',
    name: 'approval-gate',
    content: 'Do not publish before explicit approval.',
    createdAt: _date,
  ),
  Rule(
    id: 'evidence-first',
    name: 'evidence-first',
    content: 'Record evidence for every completed workflow gate.',
    createdAt: _date,
  ),
];

final _knowledgeBases = [
  KnowledgeBase(
    id: 'product-handbook',
    name: 'product-handbook',
    description: 'Fictional product decisions and interaction standards.',
    source: KnowledgeSource.git,
    gitUrl: 'https://example.invalid/product-handbook.git',
    createdAt: _date,
  ),
  KnowledgeBase(
    id: 'release-notes',
    name: 'release-notes',
    description: 'Fictional delivery evidence and release checklist.',
    source: KnowledgeSource.git,
    gitUrl: 'https://example.invalid/release-notes.git',
    createdAt: _date,
  ),
];

final _completedSession = Session(
  id: 'discovery-notes',
  title: 'Discovery notes',
  workflowId: 'delivery-loop',
  createdAt: _date.subtract(const Duration(days: 1)),
  status: SessionStatus.finished,
  messages: [
    ChatMessage(
      role: ChatRole.assistant,
      text: 'The research brief is complete and its evidence is preserved.',
      timestamp: _date.subtract(const Duration(days: 1)),
      authorProfileId: 'researcher',
    ),
  ],
);

final _activeProject = _project.copyWith(
  sessions: [_completedSession, _session],
  activeSessionId: _session.id,
);

final _workspaceProjects = [
  Project(
    id: 'northstar-web',
    name: 'northstar-web',
    purpose: 'A fictional customer-facing workspace.',
    workingDirectory: '/workspace/northstar-web',
    profileIds: const ['builder', 'researcher'],
    workflowIds: const ['delivery-loop'],
    activeWorkflowId: 'delivery-loop',
    createdAt: _date,
  ),
  Project(
    id: 'horizon-api',
    name: 'horizon-api',
    purpose: 'A fictional service integration workspace.',
    workingDirectory: '/workspace/horizon-api',
    profileIds: const ['builder', 'auditor'],
    workflowIds: const ['delivery-loop'],
    activeWorkflowId: 'delivery-loop',
    createdAt: _date,
  ),
  _activeProject,
];

/// Seeds the catalogs the real screens read. Every service is already ready:
/// `setUpAll` resolved them outside any fake-async zone (see there for why).
void _seedProductWorkspace() {
  AgentProfilesService.instance.notifier.updateState(
    AgentProfilesState(profiles: _members),
  );
  WorkflowsService.instance.notifier.updateState(
    WorkflowsState(workflows: [_workflow]),
  );
  RulesService.instance.notifier.updateState(RulesState(rules: _rules));
  KnowledgeService.instance.notifier.updateState(
    KnowledgeState(bases: _knowledgeBases),
  );
  ProjectsService.instance.notifier.updateState(
    ProjectsState(
      projects: _workspaceProjects,
      selectedProjectId: _activeProject.id,
    ),
  );
  WorkspaceService.instance.notifier.updateState(
    const WorkspaceState(lens: WorkspaceLens.session),
  );
  SidebarLayoutService.instance.notifier.updateState(
    const SidebarLayoutState(
      layouts: {
        SidebarSectionKind.project: SidebarLayout(
          kind: SidebarSectionKind.project,
          slots: [
            SidebarGroupSlot(
              id: 'delivery-workspaces',
              name: 'DELIVERY WORKSPACES',
              memberIds: ['northstar-web', 'horizon-api', 'atlas-workspace'],
            ),
          ],
        ),
      },
      openSections: {'sessions:atlas-workspace'},
    ),
  );
}

void main() {
  late Directory supportRoot;

  setUpAll(() async {
    LocalDatabase.markUnavailable();
    // KnowledgeViewModel resolves Application Support through path_provider
    // before it reports ready. Under a widget test that channel has no
    // handler, so the reply never reaches the fake-async zone and every test
    // that awaits KnowledgeService.ready hangs until the runner times out.
    supportRoot = await Directory.systemTemp.createTemp('keel-goldens-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => supportRoot.path,
        );
    // Resolve every catalog HERE, outside the fake-async zone of a widget
    // test. Each ViewModel caches its `ready` future, and a future created
    // inside one test's FakeAsync zone propagates its completion through
    // that zone: the next test awaiting the same cached future never wakes
    // up, because that zone is no longer pumped. Resolved from the real zone,
    // the futures complete for every test that follows.
    await Future.wait([
      AgentProfilesService.instance.notifier.ready,
      WorkflowsService.instance.notifier.ready,
      ProjectsService.instance.notifier.ready,
      SidebarLayoutService.instance.notifier.ready,
      RulesService.instance.notifier.ready,
      KnowledgeService.instance.notifier.ready,
    ]);
    if (!await _productFont.exists() || !await _materialIconsFont.exists()) {
      return;
    }
    final bytes = ByteData.sublistView(await _productFont.readAsBytes());
    for (final family in ['GoldenArial', 'monospace']) {
      final loader = FontLoader(family)..addFont(Future.value(bytes));
      await loader.load();
    }
    final iconBytes = ByteData.sublistView(
      await _materialIconsFont.readAsBytes(),
    );
    final iconLoader = FontLoader('MaterialIcons')
      ..addFont(Future.value(iconBytes));
    await iconLoader.load();
  });

  tearDownAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    await supportRoot.delete(recursive: true);
  });

  testWidgets('workflow editor product golden', (tester) async {
    await _goldenSurface(
      tester,
      Center(
        child: SizedBox(
          width: 1040,
          height: 900,
          child: WorkflowFormScreen(initial: _workflow),
        ),
      ),
    );
    await expectLater(
      find.byType(WorkflowFormScreen),
      matchesGoldenFile('goldens/workflow_editor.png'),
    );
  }, skip: !_goldenFontsAvailable);

  testWidgets('workflow progress product golden', (tester) async {
    await _goldenSurface(
      tester,
      Center(
        child: SizedBox(
          width: 460,
          height: 900,
          child: WorkflowProgressPanel(
            project: _project,
            session: _session,
            workflow: _workflow,
            members: _members,
          ),
        ),
      ),
    );
    await expectLater(
      find.byType(WorkflowProgressPanel),
      matchesGoldenFile('goldens/workflow_progress.png'),
    );
  }, skip: !_goldenFontsAvailable);

  testWidgets('session map product golden', (tester) async {
    await _goldenSurface(
      tester,
      SizedBox.expand(
        child: SessionMapView(
          project: _project,
          session: _session,
          members: _members,
          workflow: _workflow,
          initiallyExpandedParents: const {
            'node:planner',
            'node:implementation',
            'node:research',
          },
        ),
      ),
    );
    await expectLater(
      find.byType(SessionMapView),
      matchesGoldenFile('goldens/session_map.png'),
    );
  }, skip: !_goldenFontsAvailable);

  testWidgets('multi-agent session chat product golden', (tester) async {
    _seedProductWorkspace();
    await _goldenSurface(
      tester,
      Center(
        child: SizedBox(
          width: 1160,
          height: 900,
          child: SessionChatView(project: _activeProject),
        ),
      ),
    );
    await expectLater(
      find.byType(SessionChatView),
      matchesGoldenFile('goldens/multi_agent_chat.png'),
    );
  }, skip: !_goldenFontsAvailable);

  testWidgets(
    'complete product workspace uses the real Keel screen',
    (tester) async {
      _seedProductWorkspace();
      await _goldenSurface(
        tester,
        const AgentsScreen(),
        size: const Size(2624, 1960),
      );
      await tester.pump(const Duration(seconds: 1));
      await expectLater(
        find.byType(AgentsScreen),
        matchesGoldenFile('goldens/product_workspace.png'),
      );
    },
    skip: !_goldenFontsAvailable,
  );
}
