import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:keel_core/integrations/llm/llm.dart';
import 'package:keel_core/integrations/llm/opencode/opencode_serve_session.dart';

/// The REAL `opencode` binary and a free model (`opencode/big-pickle`),
/// with a stand-in for Keel's gate that allows. Network, no paid tokens:
/// run it with test/run_opencode_real_binary.sh.
void main() {
  test(
    'a real opencode turn asks the gate, runs the command and answers',
    () async {
      final asked = <Map<String, dynamic>>[];
      final gate = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => gate.close(force: true));
      gate.listen((request) async {
        asked.add(
          jsonDecode(await utf8.decoder.bind(request).join())
              as Map<String, dynamic>,
        );
        request.response
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({'decision': 'allow', 'reason': ''}));
        await request.response.close();
      });
      final work = Directory.systemTemp.createTempSync('keel-opencode-real-');
      addTearDown(() => work.deleteSync(recursive: true));

      final session = await OpenCodeServeSession.start(
        LlmTurnSpec(
          prompt: '',
          workingDirectory: work.path,
          model: 'opencode/big-pickle',
          fullFileSystemAccess: false,
          effort: '',
          additionalSystemPrompt: 'Eres un agente de prueba de Keel.',
          permissionGateUrl: 'http://127.0.0.1:${gate.port}/agent-gate/test',
          permissionGateToken: 'token',
        ),
        userPath: Platform.environment['PATH'] ?? '',
      );
      final events = <LlmEvent>[];
      final ended = Completer<void>();
      session.events.listen((event) {
        events.add(event);
        if (event['type'] == 'turnEnded' && !ended.isCompleted) {
          ended.complete();
        }
      });
      session.send(
        'Ejecuta con la herramienta bash exactamente: echo hola > saludo.txt '
        '. Luego responde solo LISTO.',
      );
      await ended.future.timeout(const Duration(minutes: 3));
      await session.close();

      expect(asked.map((ask) => ask['tool_name']), contains('Bash'));
      expect(File('${work.path}/saludo.txt').existsSync(), isTrue);
      expect(
        events.where((event) => event['type'] == 'toolUse').map(
          (event) => event['name'],
        ),
        contains('Bash'),
      );
      expect(events.any((event) => event['type'] == 'turnCompleted'), isTrue);
    },
    skip: Platform.environment['KEEL_REAL_OPENCODE'] != '1',
    timeout: const Timeout(Duration(minutes: 4)),
  );
}
