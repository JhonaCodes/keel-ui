import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/integrations/llm/codex/codex_arguments.dart';

void main() {
  group('buildCodexPrompt', () {
    test('sin modo plan, el prompt queda tal cual: el rol ya no viaja acá',
        () {
      expect(buildCodexPrompt(prompt: 'Hola', planMode: false), 'Hola');
    });

    test('el texto del modo plan viaja adentro del prompt', () {
      final prompt = buildCodexPrompt(
        prompt: 'Agregá manejo de errores',
        planMode: true,
      );

      expect(prompt, contains('PLAN MODE'));
      expect(prompt, endsWith('Agregá manejo de errores'));
    });
  });

  group('modo plan en codex', () {
    test('el sandbox pasa a read-only y le gana al acceso total', () {
      final args = buildCodexArguments(
        prompt: 'Planificá',
        sessionId: null,
        model: 'gpt-5-codex',
        fullFileSystemAccess: true,
        planMode: true,
      );

      expect(args, containsAllInOrder(['-s', 'read-only']));
      expect(args.contains('danger-full-access'), isFalse);
    });

    test('al reanudar el sandbox viaja por -c, que resume sí acepta', () {
      final args = buildCodexArguments(
        prompt: 'Planificá',
        sessionId: 'thread-1',
        model: 'gpt-5-codex',
        fullFileSystemAccess: false,
        planMode: true,
      );

      expect(args.contains('-s'), isFalse);
      expect(args, containsAllInOrder(['-c', 'sandbox_mode="read-only"']));
    });
  });

  group('buildCodexArguments', () {
    test('turno nuevo, sin nada extra, con acceso restringido', () {
      final args = buildCodexArguments(
        prompt: 'Hola',
        sessionId: null,
        model: '',
        fullFileSystemAccess: false,
        planMode: false,
      );

      expect(args, [
        'exec',
        '--json',
        '--skip-git-repo-check',
        '-s',
        'workspace-write',
        '--color',
        'never',
        'Hola',
      ]);
    });

    test('resume de sesión solo usa flags admitidos por su subcomando', () {
      final args = buildCodexArguments(
        prompt: 'Seguí',
        sessionId: 'thread-abc',
        model: '',
        fullFileSystemAccess: false,
        planMode: false,
      );

      expect(args, [
        'exec',
        'resume',
        'thread-abc',
        '--json',
        '--skip-git-repo-check',
        '-c',
        'sandbox_mode="workspace-write"',
        'Seguí',
      ]);
    });

    test('un alias de Claude no llega a -m: cae al config de codex', () {
      final args = buildCodexArguments(
        prompt: 'Hola',
        sessionId: null,
        model: 'sonnet',
        fullFileSystemAccess: false,
        planMode: false,
      );

      expect(args.contains('-m'), isFalse);
    });

    test('un modelo de codex sí llega a -m', () {
      final args = buildCodexArguments(
        prompt: 'Hola',
        sessionId: null,
        model: 'gpt-5-codex',
        fullFileSystemAccess: false,
        planMode: false,
      );

      expect(args[args.indexOf('-m') + 1], 'gpt-5-codex');
    });

    test('acceso completo pide danger-full-access', () {
      final args = buildCodexArguments(
        prompt: 'Hola',
        sessionId: null,
        model: '',
        fullFileSystemAccess: true,
        planMode: false,
      );

      expect(args[args.indexOf('-s') + 1], 'danger-full-access');
    });

    test('las instrucciones de rol van por developer_instructions solo en '
        'el primer turno, escapadas como cadena TOML', () {
      final first = buildCodexArguments(
        prompt: 'Hola',
        sessionId: null,
        model: '',
        fullFileSystemAccess: false,
        planMode: false,
        developerInstructions: 'Sos @qa.\nDecí "no" cuando haga falta.',
      );
      expect(
        first,
        containsAllInOrder([
          '-c',
          r'developer_instructions="Sos @qa.\nDecí \"no\" cuando haga falta."',
        ]),
      );

      final resumed = buildCodexArguments(
        prompt: 'Seguí',
        sessionId: 'thread-1',
        model: '',
        fullFileSystemAccess: false,
        planMode: false,
        developerInstructions: 'Sos @qa.',
      );
      expect(
        resumed.any((arg) => arg.startsWith('developer_instructions=')),
        isFalse,
      );
    });

    test('cada override es un -c, en exec y en resume, y con hooks pide '
        'saltear el trust', () {
      for (final sessionId in [null, 'thread-1']) {
        final args = buildCodexArguments(
          prompt: 'Hola',
          sessionId: sessionId,
          model: '',
          fullFileSystemAccess: false,
          planMode: false,
          configOverrides: const [
            'mcp_servers.keel.url="http://127.0.0.1:1/mcp"',
            'hooks.PreToolUse=[{hooks=[]}]',
          ],
          bypassHookTrust: true,
        );

        expect(
          args,
          containsAllInOrder([
            '-c',
            'mcp_servers.keel.url="http://127.0.0.1:1/mcp"',
            '-c',
            'hooks.PreToolUse=[{hooks=[]}]',
            '--dangerously-bypass-hook-trust',
          ]),
        );
        expect(args.contains('-p'), isFalse);
        expect(args.last, 'Hola');
      }
    });

    test('sin hooks no pide saltear el trust', () {
      final args = buildCodexArguments(
        prompt: 'Hola',
        sessionId: null,
        model: '',
        fullFileSystemAccess: false,
        planMode: false,
      );

      expect(args, isNot(contains('--dangerously-bypass-hook-trust')));
    });
  });

  test(
    'el argv de resume coincide con la ayuda del binario instalado',
    () async {
      final lookup = await Process.run('/bin/sh', ['-c', 'command -v codex']);
      if (lookup.exitCode != 0) return;
      final help = await Process.run('codex', ['exec', 'resume', '--help']);
      expect(help.exitCode, 0);
      final output = '${help.stdout}\n${help.stderr}';
      expect(output, contains('--model'));
      expect(output, contains('--json'));
      expect(output, contains('--config'));
      expect(output, contains('--dangerously-bypass-hook-trust'));
      expect(output, isNot(contains('--sandbox')));
      expect(output, isNot(contains('--profile')));
      expect(output, isNot(contains('--color')));

      final argv = buildCodexArguments(
        prompt: 'seguí',
        sessionId: 'thread-real-help',
        model: 'gpt-5.5',
        fullFileSystemAccess: true,
        planMode: false,
        configOverrides: const ['hooks.PreToolUse=[]'],
        bypassHookTrust: true,
      );
      expect(argv, isNot(contains('-s')));
      expect(argv, isNot(contains('-p')));
      expect(argv, isNot(contains('--color')));
    },
  );
}
