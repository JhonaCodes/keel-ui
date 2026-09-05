import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/modules/agents/model/chat_message.dart';
import 'package:keel_ui/src/modules/projects/model/session_subagent.dart';
import 'package:keel_ui/src/modules/projects/model/thread_entry.dart';
import 'package:keel_ui/src/modules/workflows/model/workflow.dart';

void main() {
  final t0 = DateTime(2026, 9, 5, 10);
  ChatMessage msg(String author, String text, int minute, {String? node}) =>
      ChatMessage(
        role: ChatRole.assistant,
        text: text,
        timestamp: t0.add(Duration(minutes: minute)),
        authorProfileId: author,
        workNodeId: node,
      );
  final messages = [
    ChatMessage(role: ChatRole.user, text: 'pedido', timestamp: t0),
    msg('dev', 'A-1', 1, node: 'implement'),
    ChatMessage(
      role: ChatRole.system,
      text: 'preflight',
      timestamp: t0.add(const Duration(minutes: 2)),
    ),
    msg('auditor', 'B-1', 3, node: 'audit'),
    msg('dev', 'A-2', 5, node: 'implement'),
  ];
  final subagent = SessionSubagent(
    id: 'task-1',
    parentProfileId: 'auditor',
    parentWorkNodeId: 'audit',
    agentType: 'Explore',
    ask: 'buscar usos de unwrap',
    prompt: '...',
    startedAt: t0.add(const Duration(minutes: 4)),
    phase: SubagentPhase.done,
    result: 'tres usos',
  );
  final workflow = Workflow(
    id: 'w',
    name: 'resolver',
    whenToApply: '',
    createdAt: t0,
    capabilities: const [
      WorkflowCapability(id: 'implement', title: 'Implementar', instruction: 'x', role: 'dev'),
      WorkflowCapability(id: 'audit', title: 'Auditar', instruction: 'x', role: 'auditor', dependencyIds: ['implement']),
    ],
  );

  List<String> texts(List<ThreadEntry> entries) => [
    for (final entry in entries)
      switch (entry) {
        ThreadMessage(message: final m) => m.text,
        ThreadHandoff(label: final l) => '<$l>',
        ThreadSubagent(subagent: final s) => '[${s.ask}]',
      },
  ];

  test('sin filtro, el hilo es el de siempre más los divisores', () {
    final entries = buildThreadEntries(messages: messages, workflow: workflow);

    expect(texts(entries), contains('A-1'));
    expect(texts(entries), contains('B-1'));
    expect(texts(entries), contains('preflight'));
    expect(texts(entries).where((t) => t.startsWith('[')), isEmpty);
  });

  test('filtrar por autor deja solo sus mensajes y los del usuario', () {
    final entries = buildThreadEntries(
      messages: messages,
      workflow: workflow,
      filter: const ThreadFilter(authorIds: {'dev'}),
    );
    final visible = texts(entries).where((t) => !t.startsWith('<')).toList();

    expect(visible, ['pedido', 'A-1', 'A-2']);
  });

  test('filtrar por nodo deja los mensajes de ese nodo', () {
    final entries = buildThreadEntries(
      messages: messages,
      workflow: workflow,
      filter: const ThreadFilter(nodeIds: {'audit'}, showSystem: false),
    );
    final visible = texts(entries).where((t) => !t.startsWith('<')).toList();

    expect(visible, ['pedido', 'B-1']);
  });

  test('con subagentes, la tarea se intercala entre los mensajes que la '
      'rodean en el tiempo', () {
    final entries = buildThreadEntries(
      messages: messages,
      workflow: workflow,
      subagents: [subagent],
      filter: const ThreadFilter(showSubagents: true),
    );
    final visible = texts(entries).where((t) => !t.startsWith('<')).toList();

    expect(
      visible.indexOf('[buscar usos de unwrap]'),
      greaterThan(visible.indexOf('B-1')),
    );
    expect(
      visible.indexOf('[buscar usos de unwrap]'),
      lessThan(visible.indexOf('A-2')),
    );
  });

  test('el título del nodo sale de la capacidad, con alias viejos', () {
    expect(nodeTitleFor(workflow, 'audit'), 'Auditar');
    expect(nodeTitleFor(workflow, 'desconocido'), 'desconocido');
    expect(nodeTitleFor(null, 'implement'), 'implement');
  });
}
