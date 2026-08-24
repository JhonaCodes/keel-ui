import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/integrations/assistant_mcp/assistant_mcp_server.dart';

void main() {
  test('Keel AI exposes complete workflow read and write contracts', () {
    final registeredTools = keelAiTools.map((tool) => tool.name).toSet();
    final allowedTools = kKeelAiMcpToolNames.toSet();

    expect(
      registeredTools,
      containsAll(const {
        'list_workflows',
        'list_projects',
        'get_item',
        'create_workflow',
        'update_workflow',
      }),
    );
    expect(
      allowedTools,
      containsAll(const {
        'mcp__keelai-actions__list_workflows',
        'mcp__keelai-actions__list_projects',
        'mcp__keelai-actions__create_workflow',
        'mcp__keelai-actions__update_workflow',
      }),
    );
    expect(registeredTools.length, keelAiTools.length);
    expect(allowedTools.length, kKeelAiMcpToolNames.length);
    expect(
      allowedTools,
      equals({
        for (final toolName in registeredTools)
          'mcp__keelai-actions__$toolName',
      }),
    );
  });
}
