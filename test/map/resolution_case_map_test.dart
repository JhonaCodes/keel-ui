import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/modules/agent_profiles/model/agent_profile.dart';
import 'package:keel_ui/src/modules/agents/model/chat_message.dart';
import 'package:keel_ui/src/modules/projects/model/resolution_case.dart';
import 'package:keel_ui/src/modules/projects/model/session.dart';
import 'package:keel_ui/src/modules/projects/model/session_map.dart';
import 'package:keel_ui/src/modules/projects/model/session_map_layout.dart';
import 'package:keel_ui/src/modules/projects/model/session_live_turn.dart';
import 'package:keel_ui/src/modules/projects/model/session_subagent.dart';
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

  test('el tronco contiene solo nodos del workflow, no todo el elenco', () {
    final session = Session(
      id: 'trunk',
      title: 'trunk',
      createdAt: _epoch,
      resolutionCase: const ResolutionCase(
        id: 'case-trunk',
        ownerRole: 'resolver',
        status: ResolutionCaseStatus.active,
        nodes: [
          WorkNode(
            id: 'diagnosis',
            kind: WorkNodeKind.triage,
            ownerRole: 'resolver',
            ownerProfileId: 'resolver',
          ),
        ],
      ),
    );

    final map = SessionMap.from(
      session: session,
      members: [
        _member('resolver'),
        _member('consultable'),
        _member('otro-consultable'),
      ],
      workflow: Workflow(
        id: 'workflow',
        name: 'bug',
        whenToApply: '',
        createdAt: _epoch,
      ),
    );

    expect(map.nodes.where((node) => node.lane == 0).map((node) => node.id), [
      'you',
      'node:diagnosis',
      'end',
    ]);
    expect(map.nodes.any((node) => node.label == 'consultable'), isFalse);
    expect(map.nodes.any((node) => node.label == 'otro-consultable'), isFalse);
  });

  test('una consulta cuelga del nodo que la originó, fuera del tronco', () {
    final session = Session(
      id: 'consult-tree',
      title: 'consult-tree',
      createdAt: _epoch,
      messages: [
        ChatMessage(
          role: ChatRole.assistant,
          text: 'Necesito que @especialista revise el contrato.',
          timestamp: _epoch,
          authorProfileId: 'resolver',
          workNodeId: 'diagnosis',
        ),
        ChatMessage(
          role: ChatRole.assistant,
          text: 'El contrato conserva compatibilidad.',
          timestamp: _epoch.add(const Duration(seconds: 1)),
          authorProfileId: 'especialista',
          workNodeId: 'diagnosis',
          consultOfProfileId: 'resolver',
        ),
      ],
      resolutionCase: const ResolutionCase(
        id: 'case-consult-tree',
        ownerRole: 'resolver',
        status: ResolutionCaseStatus.active,
        nodes: [
          WorkNode(
            id: 'diagnosis',
            kind: WorkNodeKind.triage,
            ownerRole: 'resolver',
            ownerProfileId: 'resolver',
          ),
        ],
      ),
    );

    final map = SessionMap.from(
      session: session,
      members: [_member('resolver'), _member('especialista')],
      workflow: Workflow(
        id: 'workflow',
        name: 'bug',
        whenToApply: '',
        createdAt: _epoch,
      ),
    );
    final parent = map.nodes.singleWhere(
      (node) => node.workNodeId == 'diagnosis' && node.lane == 0,
    );
    final consult = map.nodes.singleWhere(
      (node) => node.label == 'especialista',
    );

    expect(consult.lane, greaterThan(0));
    expect(consult.nodeInstruction, contains('@especialista'));
    expect(consult.said, 'El contrato conserva compatibilidad.');
    expect(
      map.edges.any(
        (edge) =>
            edge.fromId == parent.id &&
            edge.toId == consult.id &&
            edge.kind == MapEdgeKind.back,
      ),
      isTrue,
    );

    final layout = MapLayout.of(map);
    expect(
      layout.rectOf(consult.id)!.top,
      greaterThan(layout.rectOf(parent.id)!.bottom),
    );
  });

  test('un subagente del consultado nace debajo de la rama de consulta', () {
    final session = Session(
      id: 'nested-tree',
      title: 'nested-tree',
      createdAt: _epoch,
      messages: [
        ChatMessage(
          role: ChatRole.assistant,
          text: 'Consulto a @especialista sobre persistencia.',
          timestamp: _epoch,
          authorProfileId: 'resolver',
          workNodeId: 'diagnosis',
        ),
        ChatMessage(
          role: ChatRole.assistant,
          text: 'La persistencia necesita migración.',
          timestamp: _epoch.add(const Duration(seconds: 2)),
          authorProfileId: 'especialista',
          workNodeId: 'diagnosis',
          consultOfProfileId: 'resolver',
        ),
      ],
      subagents: [
        SessionSubagent(
          id: 'explore-1',
          parentProfileId: 'especialista',
          parentWorkNodeId: 'diagnosis',
          agentType: 'Explore',
          ask: 'Localizar el almacenamiento.',
          prompt: 'Localizá el almacenamiento y devolvé evidencia.',
          result: 'Está en repository.dart.',
          phase: SubagentPhase.done,
          startedAt: _epoch,
          finishedAt: _epoch.add(const Duration(seconds: 2)),
        ),
      ],
      resolutionCase: const ResolutionCase(
        id: 'case-nested-tree',
        ownerRole: 'resolver',
        status: ResolutionCaseStatus.active,
        nodes: [
          WorkNode(
            id: 'diagnosis',
            kind: WorkNodeKind.triage,
            ownerRole: 'resolver',
            ownerProfileId: 'resolver',
          ),
        ],
      ),
    );

    final map = SessionMap.from(
      session: session,
      members: [_member('resolver'), _member('especialista')],
      workflow: Workflow(
        id: 'workflow',
        name: 'bug',
        whenToApply: '',
        createdAt: _epoch,
      ),
    );
    final consult = map.nodes.singleWhere(
      (node) => node.label == 'especialista',
    );
    final subagent = map.nodes.singleWhere(
      (node) => node.id == 'sub:explore-1',
    );

    expect(subagent.lane, greaterThan(consult.lane));
    expect(
      map.edges.any(
        (edge) => edge.fromId == consult.id && edge.toId == subagent.id,
      ),
      isTrue,
    );
  });

  test(
    'una consulta en vivo no enciende otro nodo principal del consultado',
    () {
      final session = Session(
        id: 'live-consult',
        title: 'live-consult',
        createdAt: _epoch,
        isRunning: true,
        liveTurn: const SessionLiveTurn(
          profileId: 'especialista',
          consultOfProfileId: 'resolver',
        ),
        messages: [
          ChatMessage(
            role: ChatRole.assistant,
            text: 'Consulto a @especialista sobre el contrato.',
            timestamp: _epoch,
            authorProfileId: 'resolver',
            workNodeId: 'diagnosis',
          ),
        ],
        resolutionCase: const ResolutionCase(
          id: 'case-live-consult',
          ownerRole: 'resolver',
          status: ResolutionCaseStatus.active,
          nodes: [
            WorkNode(
              id: 'diagnosis',
              kind: WorkNodeKind.triage,
              ownerRole: 'resolver',
              ownerProfileId: 'resolver',
              status: WorkNodeStatus.running,
            ),
            WorkNode(
              id: 'verification',
              kind: WorkNodeKind.verification,
              ownerRole: 'especialista',
              ownerProfileId: 'especialista',
              dependencyIds: ['diagnosis'],
            ),
          ],
        ),
      );

      final map = SessionMap.from(
        session: session,
        members: [_member('resolver'), _member('especialista')],
        workflow: Workflow(
          id: 'workflow',
          name: 'bug',
          whenToApply: '',
          createdAt: _epoch,
        ),
      );
      final main = map.nodes.singleWhere(
        (node) => node.workNodeId == 'verification' && node.lane == 0,
      );
      final consult = map.nodes.singleWhere(
        (node) => node.label == 'especialista' && node.lane > 0,
      );

      expect(main.isLive, isFalse);
      expect(consult.state, MapNodeState.replying);
      expect(consult.parentId, 'node:diagnosis');
    },
  );

  test('una consulta encadenada conserva la profundidad del árbol', () {
    final session = Session(
      id: 'nested-consult',
      title: 'nested-consult',
      createdAt: _epoch,
      messages: [
        ChatMessage(
          role: ChatRole.assistant,
          text: 'Consulto a @arquitecto por el contrato.',
          timestamp: _epoch,
          authorProfileId: 'resolver',
          workNodeId: 'diagnosis',
        ),
        ChatMessage(
          role: ChatRole.assistant,
          text: 'Necesito que @datos confirme la persistencia.',
          timestamp: _epoch.add(const Duration(seconds: 1)),
          authorProfileId: 'arquitecto',
          workNodeId: 'diagnosis',
          consultOfProfileId: 'resolver',
        ),
        ChatMessage(
          role: ChatRole.assistant,
          text: 'La persistencia conserva el identificador.',
          timestamp: _epoch.add(const Duration(seconds: 2)),
          authorProfileId: 'datos',
          workNodeId: 'diagnosis',
          consultOfProfileId: 'arquitecto',
        ),
      ],
      resolutionCase: const ResolutionCase(
        id: 'case-nested-consult',
        ownerRole: 'resolver',
        status: ResolutionCaseStatus.active,
        nodes: [
          WorkNode(
            id: 'diagnosis',
            kind: WorkNodeKind.triage,
            ownerRole: 'resolver',
            ownerProfileId: 'resolver',
          ),
        ],
      ),
    );

    final map = SessionMap.from(
      session: session,
      members: [_member('resolver'), _member('arquitecto'), _member('datos')],
      workflow: Workflow(
        id: 'workflow',
        name: 'bug',
        whenToApply: '',
        createdAt: _epoch,
      ),
    );
    final architect = map.nodes.singleWhere(
      (node) => node.label == 'arquitecto',
    );
    final data = map.nodes.singleWhere((node) => node.label == 'datos');
    final layout = MapLayout.of(map);

    expect(architect.parentId, 'node:diagnosis');
    expect(architect.lane, 1);
    expect(data.parentId, architect.id);
    expect(data.lane, 2);
    expect(data.nodeInstruction, contains('@datos'));
    expect(
      layout.rectOf(data.id)!.left,
      greaterThan(layout.rectOf(architect.id)!.left),
    );
  });
}
