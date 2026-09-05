import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/integrations/llm/codex/codex_arguments.dart';

void main() {
  group('buildCodexPrompt', () {
    test('primer turno con instrucciones de rol: antepone el preámbulo', () {
      final prompt = buildCodexPrompt(
        prompt: 'Revisá este PR',
        sessionId: null,
        additionalSystemPrompt: 'Sos el auditor de código.',
        planMode: false,
      );

      expect(
        prompt,
        '### Instrucciones de tu rol (fijas para toda la conversación)\n'
        'Sos el auditor de código.\n'
        '### Fin de instrucciones\n\n'
        'Revisá este PR',
      );
    });

    test('turno con resume: repite el preámbulo que le pasen (el compacto)',
        () {
      // Antes se descartaba: la identidad, las reglas y el protocolo de
      // cierre vivían solo en el turno 1 y se perdían en cada resume. El
      // ViewModel manda una versión compacta; acá se antepone igual.
      final prompt = buildCodexPrompt(
        prompt: 'Seguí con lo anterior',
        sessionId: 'thread-123',
        additionalSystemPrompt: 'Sos el auditor de código.',
        planMode: false,
      );

      expect(prompt, startsWith('### Instrucciones de tu rol'));
      expect(prompt, endsWith('Seguí con lo anterior'));
    });

    test('sin instrucciones de rol: el prompt queda tal cual', () {
      final prompt = buildCodexPrompt(
        prompt: 'Hola',
        sessionId: null,
        additionalSystemPrompt: null,
        planMode: false,
      );

      expect(prompt, 'Hola');
    });

    test('instrucciones de rol vacías: el prompt queda tal cual', () {
      final prompt = buildCodexPrompt(
        prompt: 'Hola',
        sessionId: null,
        additionalSystemPrompt: '',
        planMode: false,
      );

      expect(prompt, 'Hola');
    });
  });

  group('modo plan en codex', () {
    test('el sandbox pasa a read-only', () {
      final args = buildCodexArguments(
        prompt: 'Planificá',
        sessionId: null,
        model: 'gpt-5-codex',
        fullFileSystemAccess: false,
        codexProfileName: null,
        planMode: true,
      );

      expect(args, containsAllInOrder(['-s', 'read-only']));
    });

    test('le gana al acceso total al disco', () {
      // Si el turno solo planifica, no hay lectura que justifique dejarlo
      // escribir en todo el disco.
      final args = buildCodexArguments(
        prompt: 'Planificá',
        sessionId: null,
        model: 'gpt-5-codex',
        fullFileSystemAccess: true,
        codexProfileName: null,
        planMode: true,
      );

      expect(args, containsAllInOrder(['-s', 'read-only']));
      expect(args.contains('danger-full-access'), isFalse);
    });

    test('al reanudar el sandbox viaja por -c, que resume sí acepta', () {
      // `exec resume` no acepta `-s`, pero acepta `-c clave=valor`
      // (verificado en codex 0.149.1): el modo plan sigue teniendo freno.
      final args = buildCodexArguments(
        prompt: 'Planificá',
        sessionId: 'thread-1',
        model: 'gpt-5-codex',
        fullFileSystemAccess: false,
        codexProfileName: null,
        planMode: true,
      );

      expect(args.contains('-s'), isFalse);
      expect(args, containsAllInOrder(['-c', 'sandbox_mode="read-only"']));
    });

    test('el texto del modo plan viaja adentro del prompt', () {
      // Adentro del prompt y no en el preámbulo, porque el preámbulo se
      // descarta al reanudar: es lo único que llega en los dos casos.
      for (final sessionId in [null, 'thread-1']) {
        final prompt = buildCodexPrompt(
          prompt: 'Agregá manejo de errores',
          sessionId: sessionId,
          additionalSystemPrompt: 'Sos el auditor.',
          planMode: true,
        );

        expect(prompt, contains('PLAN MODE'));
        expect(prompt, contains('Agregá manejo de errores'));
      }
    });

    test('apagado no mete el texto en el prompt', () {
      final prompt = buildCodexPrompt(
        prompt: 'Agregá manejo de errores',
        sessionId: null,
        additionalSystemPrompt: null,
        planMode: false,
      );

      expect(prompt, 'Agregá manejo de errores');
    });
  });

  group('buildCodexArguments', () {
    test('turno nuevo, sin perfil, con acceso restringido', () {
      final args = buildCodexArguments(
        prompt: 'Hola',
        sessionId: null,
        model: '',
        fullFileSystemAccess: false,
        codexProfileName: null,
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
        codexProfileName: null,
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
        codexProfileName: null,
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
        codexProfileName: null,
        planMode: false,
      );

      final index = args.indexOf('-m');
      expect(index, isNot(-1));
      expect(args[index + 1], 'gpt-5-codex');
    });

    test('acceso completo pide danger-full-access', () {
      final args = buildCodexArguments(
        prompt: 'Hola',
        sessionId: null,
        model: '',
        fullFileSystemAccess: true,
        codexProfileName: null,
        planMode: false,
      );

      expect(args[args.indexOf('-s') + 1], 'danger-full-access');
    });

    test('con perfil de hooks agrega -p <perfil>', () {
      final args = buildCodexArguments(
        prompt: 'Hola',
        sessionId: null,
        model: '',
        fullFileSystemAccess: false,
        codexProfileName: 'keel-turn123',
        planMode: false,
      );

      final index = args.indexOf('-p');
      expect(index, isNot(-1));
      expect(args[index + 1], 'keel-turn123');
    });

    test('el prompt siempre es el último argumento', () {
      final args = buildCodexArguments(
        prompt: 'Este es el prompt',
        sessionId: 'thread-1',
        model: 'gpt-5-codex',
        fullFileSystemAccess: true,
        codexProfileName: 'keel-turn1',
        planMode: false,
      );

      expect(args.last, 'Este es el prompt');
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
      expect(output, contains('--skip-git-repo-check'));
      expect(output, isNot(contains('--sandbox')));
      expect(output, isNot(contains('--profile')));
      expect(output, isNot(contains('--color')));

      final argv = buildCodexArguments(
        prompt: 'seguí',
        sessionId: 'thread-real-help',
        model: 'gpt-5.5',
        fullFileSystemAccess: true,
        codexProfileName: 'keel',
        planMode: false,
      );
      expect(argv, isNot(contains('-s')));
      expect(argv, isNot(contains('-p')));
      expect(argv, isNot(contains('--color')));
    },
  );

  test('al reanudar con perfil de hooks, el perfil viaja por -c', () {
    final args = buildCodexArguments(
      prompt: 'Seguí',
      sessionId: 'thread-abc',
      model: '',
      fullFileSystemAccess: true,
      codexProfileName: 'keel-turn9',
      planMode: false,
    );

    expect(args.contains('-p'), isFalse);
    expect(args, containsAllInOrder(['-c', 'profile="keel-turn9"']));
    expect(args, containsAllInOrder(['-c', 'sandbox_mode="danger-full-access"']));
  });

}
