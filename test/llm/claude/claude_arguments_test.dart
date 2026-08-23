import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/integrations/llm/claude/claude_arguments.dart';

void main() {
  group('buildClaudeArguments', () {
    List<String> minimal({
      String? mcpConfigPath,
      String? claudeSettingsPath,
      bool fullFileSystemAccess = false,
      String? sessionId,
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

    test('el prompt siempre va justo después de -p', () {
      final args = minimal();

      expect(args[0], '-p');
      expect(args[1], 'Hola');
    });
  });
}
