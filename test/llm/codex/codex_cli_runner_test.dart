import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/integrations/llm/llm.dart';
import 'package:keel_ui/src/integrations/llm/codex/codex_cli_runner.dart';

import '../support/fake_cli_process.dart';

const _spec = LlmTurnSpec(
  prompt: 'hola',
  workingDirectory: '.',
  model: 'gpt-5-codex',
  fullFileSystemAccess: false,
  effort: 'medium',
);

void main() {
  group('CodexCliRunner — cancelación', () {
    late Directory fakeBin;

    tearDown(() {
      if (fakeBin.existsSync()) fakeBin.deleteSync(recursive: true);
    });

    test(
      'un cancel pedido apenas se empieza a escuchar el turno igual lo corta '
      '(no se pierde mientras el runner arma el workspace o levanta el proceso)',
      () async {
        fakeBin = createFakeCliBin('codex', '#!/bin/sh\nsleep 5\n');

        final cancelController = StreamController<void>.broadcast();
        addTearDown(cancelController.close);
        const runner = CodexCliRunner();
        final done = Completer<void>();

        final subscription = runner
            .run(
              _spec,
              userPath: fakeCliUserPath(fakeBin),
              cancel: cancelController.stream,
            )
            .listen((_) {}, onDone: done.complete, onError: done.completeError);

        // Un solo tick del event loop: alcanza para que el generador
        // `async*` arranque y llegue a la primera línea del cuerpo (donde
        // debe suscribirse al cancel), pero no alcanza para que terminen
        // las dos operaciones reales (crear el workspace, levantar el
        // proceso) detrás de las que el bug original recién se suscribía.
        await Future<void>.delayed(Duration.zero);
        cancelController.add(null);

        await expectLater(
          done.future.timeout(const Duration(seconds: 2)),
          completes,
          reason:
              'el proceso fake duerme 5s; si el cancel se perdió, el turno '
              'no termina antes del timeout de 2s',
        );
        await subscription.cancel();
      },
    );

    test('un cancel pedido mientras el proceso ya está corriendo lo corta sin '
        'esperar a que termine solo', () async {
      fakeBin = createFakeCliBin('codex', '#!/bin/sh\nsleep 5\n');

      final cancelController = StreamController<void>.broadcast();
      addTearDown(cancelController.close);
      const runner = CodexCliRunner();
      final done = Completer<void>();
      int? pid;

      final subscription = runner
          .run(
            _spec,
            userPath: fakeCliUserPath(fakeBin),
            cancel: cancelController.stream,
            onPidKnown: (p) => pid = p,
          )
          .listen((_) {}, onDone: done.complete, onError: done.completeError);

      final started = DateTime.now();
      while (pid == null) {
        if (DateTime.now().difference(started) > const Duration(seconds: 5)) {
          fail('el proceso fake nunca arrancó');
        }
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      cancelController.add(null);

      await expectLater(
        done.future.timeout(const Duration(seconds: 2)),
        completes,
      );
      await subscription.cancel();
    });
  });

  test(
    'resume reenvía el sandbox por -c y ya no avisa que no puede',
    () async {
      // `exec resume` no acepta `-s`, pero sí `-c sandbox_mode=...`: el
      // aviso de «reanudó sin sandbox» dejó de ser verdad y se fue.
      final fakeBin = createFakeCliBin(
        'codex',
        r'#!/bin/sh'
        '\n'
        r'printf "%s\n" "$@" > "$(dirname "$0")/argv.log"'
        '\nexit 0\n',
      );
      addTearDown(() {
        if (fakeBin.existsSync()) fakeBin.deleteSync(recursive: true);
      });
      const resumeSpec = LlmTurnSpec(
        prompt: 'seguí',
        workingDirectory: '.',
        model: 'gpt-5-codex',
        fullFileSystemAccess: true,
        effort: 'medium',
        sessionId: 'session-1',
      );

      final events = await const CodexCliRunner()
          .run(
            resumeSpec,
            userPath: fakeCliUserPath(fakeBin),
            cancel: const Stream<void>.empty(),
          )
          .toList();

      expect(events.where((event) => event['type'] == 'notice'), isEmpty);
      final argv = File('${fakeBin.path}/argv.log').readAsLinesSync();
      expect(argv, containsAllInOrder(['-c', 'sandbox_mode="danger-full-access"']));
      expect(argv.contains('-s'), isFalse);
    },
  );

  group('CodexCliRunner — configuración por -c (codex 0.153)', () {
    late Directory fakeBin;

    setUp(() {
      // El fake vuelca argv y entorno: el oráculo es lo que el binario
      // recibiría de verdad, no lo que el runner cree que manda.
      fakeBin = createFakeCliBin(
        'codex',
        r'#!/bin/sh'
        '\n'
        r'printf "%s\n" "$@" > "$(dirname "$0")/argv.log"'
        '\n'
        r'env > "$(dirname "$0")/env.log"'
        '\nexit 0\n',
      );
    });
    tearDown(() {
      if (fakeBin.existsSync()) fakeBin.deleteSync(recursive: true);
    });

    Future<({List<String> argv, Map<String, String> env})> run(
      LlmTurnSpec spec,
    ) async {
      await const CodexCliRunner()
          .run(
            spec,
            userPath: fakeCliUserPath(fakeBin),
            cancel: const Stream<void>.empty(),
          )
          .toList();
      final argv = File('${fakeBin.path}/argv.log').readAsLinesSync();
      final env = <String, String>{};
      for (final line in File('${fakeBin.path}/env.log').readAsLinesSync()) {
        final at = line.indexOf('=');
        if (at > 0) env[line.substring(0, at)] = line.substring(at + 1);
      }
      return (argv: argv, env: env);
    }

    test('con hooks, los pasa por -c y pide saltear el trust: sin el flag '
        'codex 0.153 los ignora en silencio', () async {
      final result = await run(
        const LlmTurnSpec(
          prompt: 'hola',
          workingDirectory: '.',
          model: 'gpt-5-codex',
          fullFileSystemAccess: false,
          effort: 'medium',
          hooksConfig:
              'hooks.PreToolUse=[{matcher="Bash",hooks=[{type="command",'
              'command="bash __KEEL_HOOK_DIR__/keel-decision-gate.sh",'
              'timeout=21600}]}]',
          hookFiles: {'keel-decision-gate.sh': 'exit 0'},
        ),
      );

      expect(result.argv, contains('--dangerously-bypass-hook-trust'));
      final override = result.argv.firstWhere(
        (arg) => arg.startsWith('hooks.PreToolUse='),
        orElse: () => '',
      );
      expect(override, isNotEmpty);
      expect(result.argv[result.argv.indexOf(override) - 1], '-c');
      expect(override, isNot(contains('__KEEL_HOOK_DIR__')));
      expect(result.argv.contains('-p'), isFalse);
    });

    test('sin hooks no pide saltear el trust', () async {
      final result = await run(_spec);

      expect(result.argv, isNot(contains('--dangerously-bypass-hook-trust')));
    });

    test('los MCP viajan por -c y el bearer va por el entorno, nunca en '
        'argv', () async {
      final mcpConfig = jsonEncode({
        'mcpServers': {
          'keel-decisions': {
            'type': 'http',
            'url': 'http://127.0.0.1:4321/ask/p/s/a',
            'headers': {'Authorization': 'Bearer secreto-123'},
          },
          'github': {
            'command': 'npx',
            'args': ['-y', 'gh-mcp'],
            'env': {'GITHUB_TOKEN': 'ghp-secreto'},
          },
        },
      });
      final result = await run(
        LlmTurnSpec(
          prompt: 'hola',
          workingDirectory: '.',
          model: 'gpt-5-codex',
          fullFileSystemAccess: false,
          effort: 'medium',
          mcpConfig: mcpConfig,
        ),
      );

      expect(
        result.argv,
        contains('mcp_servers.keel-decisions.url="http://127.0.0.1:4321/ask/p/s/a"'),
      );
      expect(result.argv.join('\n'), isNot(contains('secreto-123')));
      expect(result.argv.join('\n'), isNot(contains('ghp-secreto')));
      expect(result.env.values, contains('Bearer secreto-123'));
      expect(result.env['GITHUB_TOKEN'], 'ghp-secreto');
      expect(result.argv, contains('mcp_servers.github.env_vars=["GITHUB_TOKEN"]'));
    });

    test('el system prompt va como developer_instructions en el primer '
        'turno y no se repite al reanudar (el hilo ya lo tiene)', () async {
      final first = await run(
        const LlmTurnSpec(
          prompt: 'hola',
          workingDirectory: '.',
          model: 'gpt-5-codex',
          fullFileSystemAccess: false,
          effort: 'medium',
          additionalSystemPrompt: 'SOS @qa\ncon "comillas"',
        ),
      );
      expect(first.argv, contains(r'developer_instructions="SOS @qa\ncon \"comillas\""'));
      expect(first.argv.last, 'hola');

      final resumed = await run(
        const LlmTurnSpec(
          prompt: 'seguí',
          workingDirectory: '.',
          model: 'gpt-5-codex',
          fullFileSystemAccess: false,
          effort: 'medium',
          sessionId: 'thread-1',
          additionalSystemPrompt: 'SOS @qa',
        ),
      );
      expect(
        resumed.argv.any((arg) => arg.startsWith('developer_instructions=')),
        isFalse,
      );
      expect(resumed.argv.last, 'seguí');
    });
  });
}
