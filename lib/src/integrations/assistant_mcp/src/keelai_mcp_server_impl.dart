part of '../assistant_mcp_server.dart';

/// One instance per incoming HTTP POST — see [AssistantMcpServer._handleRequest].
///
/// [willInitialize] must be true only when the incoming message's method is
/// literally `initialize`. In that case `ToolsSupport.initialize` (mixed in
/// below) registers the `tools/list`/`tools/call` handlers itself as part of
/// the real handshake; registering them again here would throw, since
/// `json_rpc_2` rejects a duplicate method name on the same peer. For every
/// other method this instance might actually receive (`tools/list` or
/// `tools/call` — the only two [AssistantMcpServer] ever constructs an
/// instance for besides `initialize`), that automatic registration will
/// never run on this instance, so registering them here instead is safe.
final class KeelAiMcpServer extends MCPServer with ToolsSupport {
  KeelAiMcpServer(
    super.channel, {
    required String agentId,
    required bool willInitialize,
  }) : super.fromStreamChannel(
         implementation: Implementation(
           name: 'keelai-actions',
           version: '1.0.0',
         ),
         instructions:
             'Tools to create and update Keel AI objects: skills, rules, '
             'agents, workflows and projects.',
       ) {
    for (final tool in keelAiTools) {
      registerTool(tool, (request) => dispatchKeelAiTool(agentId, request));
    }
    if (!willInitialize) {
      registerRequestHandler(ListToolsRequest.methodName, listTools);
      registerRequestHandler(CallToolRequest.methodName, callTool);
    }
  }
}
