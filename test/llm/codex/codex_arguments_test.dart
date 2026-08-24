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
      );

      expect(
        prompt,
        '### Instrucciones de tu rol (fijas para toda la conversación)\n'
        'Sos el auditor de código.\n'
        '### Fin de instrucciones\n\n'
        'Revisá este PR',
      );
    });

    test('turno con resume: no repite el preámbulo aunque haya rol', () {
      final prompt = buildCodexPrompt(
        prompt: 'Seguí con lo anterior',
        sessionId: 'thread-123',
        additionalSystemPrompt: 'Sos el auditor de código.',
      );

      expect(prompt, 'Seguí con lo anterior');
    });

    test('sin instrucciones de rol: el prompt queda tal cual', () {
      final prompt = buildCodexPrompt(
        prompt: 'Hola',
        sessionId: null,
        additionalSystemPrompt: null,
      );

      expect(prompt, 'Hola');
    });

    test('instrucciones de rol vacías: el prompt queda tal cual', () {
      final prompt = buildCodexPrompt(
        prompt: 'Hola',
        sessionId: null,
        additionalSystemPrompt: '',
      );

      expect(prompt, 'Hola');
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
      );

      expect(args, [
        'exec',
        'resume',
        'thread-abc',
        '--json',
        '--skip-git-repo-check',
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
      );

      expect(args.last, 'Este es el prompt');
    });
  });

  test('el argv de resume coincide con la ayuda del binario instalado', () async {
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
    );
    expect(argv, isNot(contains('-s')));
    expect(argv, isNot(contains('-p')));
    expect(argv, isNot(contains('--color')));
  });
}
