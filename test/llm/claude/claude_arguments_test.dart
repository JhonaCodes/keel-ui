import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/integrations/llm/claude/claude_arguments.dart';

void main() {
  group('buildClaudeArguments', () {
    List<String> minimal({
      String? mcpConfigPath,
      String? claudeSettingsPath,
      bool fullFileSystemAccess = false,
      String? sessionId,
      bool planMode = false,
    }) => buildClaudeArguments(
      prompt: 'Hola',
      model: 'sonnet',
      effort: 'high',
      allowedTools: const ['Read', 'Glob'],
      systemPrompt: 'hints del sistema',
      mcpConfigPath: mcpConfigPath,
      claudeSettingsPath: claudeSettingsPath,
      fullFileSystemAccess: fullFileSystemAccess,
      sessionId: sessionId,
      planMode: planMode,
    );

    test('turno mínimo: sin mcp, sin hooks, sin resume', () {
      expect(minimal(), [
        '-p',
        'Hola',
        '--output-format',
        'stream-json',
        '--verbose',
        '--forward-subagent-text',
        '--model',
        'sonnet',
        '--effort',
        'high',
        '--allowedTools',
        'Read,Glob',
        '--append-system-prompt',
        'hints del sistema',
      ]);
    });

    test('con mcp-config agrega --mcp-config y --strict-mcp-config', () {
      final args = minimal(mcpConfigPath: '/tmp/turn/mcp.json');

      expect(
        args,
        containsAllInOrder([
          '--mcp-config',
          '/tmp/turn/mcp.json',
          '--strict-mcp-config',
        ]),
      );
    });

    test('con settings de hooks agrega --settings', () {
      final args = minimal(claudeSettingsPath: '/tmp/turn/settings.json');

      expect(
        args,
        containsAllInOrder(['--settings', '/tmp/turn/settings.json']),
      );
    });

    test('acceso completo agrega --add-dir /', () {
      final args = minimal(fullFileSystemAccess: true);

      expect(args, containsAllInOrder(['--add-dir', '/']));
    });

    test('sin acceso completo no agrega --add-dir', () {
      expect(minimal().contains('--add-dir'), isFalse);
    });

    test('con sessionId agrega --resume <id> al final', () {
      final args = minimal(sessionId: 'sess-1');

      expect(args.sublist(args.length - 2), ['--resume', 'sess-1']);
    });

    test('sin sessionId no agrega --resume', () {
      expect(minimal().contains('--resume'), isFalse);
    });

    group('modo plan', () {
      test('agrega --permission-mode plan', () {
        expect(
          minimal(planMode: true),
          containsAllInOrder(['--permission-mode', 'plan']),
        );
      });

      test('apagado no nombra el flag en ningún lado', () {
        expect(minimal().contains('--permission-mode'), isFalse);
      });

      test('NO recorta las tools permitidas', () {
        // El modo plan frena las escrituras por su cuenta. Sacar `Write` de
        // la lista además de eso dejaría al turno que implementa —el mismo
        // `--resume`— con otra superficie de tools que la del turno que
        // planificó.
        final planning = minimal(planMode: true);
        final writing = minimal();

        expect(
          planning[planning.indexOf('--allowedTools') + 1],
          writing[writing.indexOf('--allowedTools') + 1],
        );
      });

      test('convive con el acceso total al disco', () {
        // Probado contra el CLI real: el modo plan le gana a `--add-dir /`.
        final args = minimal(planMode: true, fullFileSystemAccess: true);

        expect(args, containsAllInOrder(['--permission-mode', 'plan']));
        expect(args, containsAllInOrder(['--add-dir', '/']));
      });
    });

    test('el prompt siempre va justo después de -p', () {
      final args = minimal();

      expect(args[0], '-p');
      expect(args[1], 'Hola');
    });
  });
}
