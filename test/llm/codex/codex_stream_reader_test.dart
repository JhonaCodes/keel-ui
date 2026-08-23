import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/integrations/llm/codex/codex_stream_reader.dart';

void main() {
  late CodexStreamReader reader;

  setUp(() {
    reader = CodexStreamReader();
  });

  test('thread.started con thread_id emite sessionStarted', () {
    final messages = reader.read({
      'type': 'thread.started',
      'thread_id': 'thread-abc',
    });

    expect(messages, [
      {'type': 'sessionStarted', 'sessionId': 'thread-abc'},
    ]);
  });

  test('thread.started sin thread_id no emite nada', () {
    expect(reader.read({'type': 'thread.started'}), isEmpty);
  });

  test('agent_message completo con texto emite assistantText', () {
    final messages = reader.read({
      'type': 'item.completed',
      'item': {'type': 'agent_message', 'text': 'Hola, ya lo reviso.'},
    });

    expect(messages, [
      {'type': 'assistantText', 'text': 'Hola, ya lo reviso.'},
    ]);
  });

  test('agent_message a mitad de stream (item.updated) no emite nada', () {
    final messages = reader.read({
      'type': 'item.updated',
      'item': {'type': 'agent_message', 'text': 'todavía escribiendo'},
    });

    expect(messages, isEmpty);
  });

  test('reasoning completo con texto emite reasoningChunk', () {
    final messages = reader.read({
      'type': 'item.completed',
      'item': {'type': 'reasoning', 'text': 'pensando el plan'},
    });

    expect(messages, [
      {'type': 'reasoningChunk', 'text': 'pensando el plan'},
    ]);
  });

  test('command_execution al empezar emite toolUse Bash con el comando', () {
    final messages = reader.read({
      'type': 'item.started',
      'item': {'type': 'command_execution', 'command': 'ls -la'},
    });

    expect(messages, [
      {
        'type': 'toolUse',
        'name': 'Bash',
        'input': {'command': 'ls -la'},
      },
    ]);
  });

  test('command_execution al completarse no vuelve a emitir', () {
    final messages = reader.read({
      'type': 'item.completed',
      'item': {'type': 'command_execution', 'command': 'ls -la'},
    });

    expect(messages, isEmpty);
  });

  test('file_change al empezar emite toolUse Edit sin input', () {
    final messages = reader.read({
      'type': 'item.started',
      'item': {'type': 'file_change'},
    });

    expect(messages, [
      {'type': 'toolUse', 'name': 'Edit', 'input': null},
    ]);
  });

  test('mcp_tool_call al empezar usa el nombre de la tool si viene', () {
    final messages = reader.read({
      'type': 'item.started',
      'item': {'type': 'mcp_tool_call', 'tool': 'roadmap.list_tasks'},
    });

    expect(messages, [
      {'type': 'toolUse', 'name': 'roadmap.list_tasks', 'input': null},
    ]);
  });

  test('mcp_tool_call al empezar sin nombre cae a "mcp"', () {
    final messages = reader.read({
      'type': 'item.started',
      'item': {'type': 'mcp_tool_call'},
    });

    expect(messages, [
      {'type': 'toolUse', 'name': 'mcp', 'input': null},
    ]);
  });

  test('web_search al empezar emite toolUse WebSearch', () {
    final messages = reader.read({
      'type': 'item.started',
      'item': {'type': 'web_search'},
    });

    expect(messages, [
      {'type': 'toolUse', 'name': 'WebSearch', 'input': null},
    ]);
  });

  test('item de tipo desconocido no emite nada', () {
    final messages = reader.read({
      'type': 'item.started',
      'item': {'type': 'algo_nuevo_que_todavia_no_mapeamos'},
    });

    expect(messages, isEmpty);
  });

  test('turn.completed emite turnCompleted sin error', () {
    final messages = reader.read({'type': 'turn.completed'});

    expect(messages, [
      {
        'type': 'turnCompleted',
        'isError': false,
        'costUsd': 0.0,
        'durationMs': 0,
      },
    ]);
  });

  test('turn.failed con mensaje emite failure y turnCompleted con error', () {
    final messages = reader.read({
      'type': 'turn.failed',
      'error': {'message': 'se cortó la conexión'},
    });

    expect(messages, [
      {'type': 'failure', 'message': 'se cortó la conexión'},
      {
        'type': 'turnCompleted',
        'isError': true,
        'costUsd': 0.0,
        'durationMs': 0,
      },
    ]);
  });

  test('turn.failed sin mensaje solo emite turnCompleted con error', () {
    final messages = reader.read({'type': 'turn.failed'});

    expect(messages, [
      {
        'type': 'turnCompleted',
        'isError': true,
        'costUsd': 0.0,
        'durationMs': 0,
      },
    ]);
  });

  test('error de nivel turno emite failure', () {
    final messages = reader.read({
      'type': 'error',
      'message': 'codex no pudo resolver el proyecto',
    });

    expect(messages, [
      {'type': 'failure', 'message': 'codex no pudo resolver el proyecto'},
    ]);
  });

  test('un tipo de evento desconocido no rompe nada, no emite nada', () {
    expect(reader.read({'type': 'algo_futuro_del_cli'}), isEmpty);
  });
}
