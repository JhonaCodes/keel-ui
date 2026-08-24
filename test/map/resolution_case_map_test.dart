import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/modules/agent_profiles/model/agent_profile.dart';
import 'package:keel_ui/src/modules/projects/model/resolution_case.dart';
import 'package:keel_ui/src/modules/projects/model/session.dart';
import 'package:keel_ui/src/modules/projects/model/session_map.dart';
import 'package:keel_ui/src/modules/projects/model/work_node.dart';
import 'package:keel_ui/src/modules/workflows/model/workflow.dart';

final _epoch = DateTime(2026, 8, 24);

AgentProfile _member(String name) => AgentProfile(
  id: name,
  name: name,
  role: name,
  systemPrompt: '',
  model: 'sonnet',
  effort: 'normal',
  createdAt: _epoch,
);

void main() {
  test('el mapa representa el grafo adaptativo y su nodo en ejecución', () {
    final session = Session(
      id: 's',
      title: 'resolver',
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
            status: WorkNodeStatus.done,
          ),
          WorkNode(
            id: 'impact',
            kind: WorkNodeKind.impact,
            ownerRole: 'resolver',
            dependencyIds: ['triage'],
            status: WorkNodeStatus.pending,
          ),
          WorkNode(
            id: 'implementation',
            kind: WorkNodeKind.implementation,
            ownerRole: 'resolver',
            dependencyIds: ['triage'],
            status: WorkNodeStatus.running,
          ),
        ],
      ),
    );

    final map = SessionMap.from(
      session: session,
      members: [_member('resolver')],
      workflow: Workflow(
        id: 'workflow',
        name: 'bug',
        whenToApply: '',
        createdAt: _epoch,
        kind: WorkflowKind.bug,
      ),
    );

    final nodes = map.nodes.where((node) => node.kind == MapNodeKind.work);
    expect(nodes.map((node) => node.nodeTitle), [
      'triage',
      'impact',
      'implementation',
    ]);
    expect(nodes.map((node) => node.workNodeId), [
      'triage',
      'impact',
      'implementation',
    ]);
    final byId = {for (final node in nodes) node.workNodeId!: node};
    expect(byId['impact']!.column, byId['implementation']!.column);
    expect(
      map.edges.any(
        (edge) =>
            edge.fromId == 'node:triage' &&
            edge.toId == 'node:implementation' &&
            edge.kind == MapEdgeKind.forward,
      ),
      isTrue,
    );
  });

  test('el mapa dibuja el agente concreto persistido por cada nodo', () {
    final session = Session(
      id: 'owners',
      title: 'owners',
      createdAt: _epoch,
      resolutionCase: const ResolutionCase(
        id: 'case-owners',
        ownerRole: 'resolver',
        status: ResolutionCaseStatus.active,
        nodes: [
          WorkNode(
            id: 'implementation',
            kind: WorkNodeKind.implementation,
            ownerRole: 'resolver',
            ownerProfileId: 'implementer',
            title: 'Implementar por capa',
            instruction: 'Aplicar TDD.',
          ),
        ],
      ),
    );

    final map = SessionMap.from(
      session: session,
      members: [_member('resolver'), _member('implementer')],
      workflow: Workflow(
        id: 'workflow',
        name: 'bug',
        whenToApply: '',
        createdAt: _epoch,
      ),
    );
    final node = map.nodes.singleWhere(
      (entry) => entry.workNodeId == 'implementation',
    );
    expect(node.profileId, 'implementer');
    expect(node.label, 'implementer');
    expect(node.nodeTitle, 'Implementar por capa');
    expect(node.nodeInstruction, 'Aplicar TDD.');
  });
}
