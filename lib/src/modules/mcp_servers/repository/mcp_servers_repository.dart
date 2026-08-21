import 'package:keel_ui/src/core/services/local_database.dart';
import 'package:keel_ui/src/modules/mcp_servers/model/mcp_server_config.dart';

class McpServersRepository {
  static const _prefix = 'mcpserver_';

  Future<List<McpServerConfig>> load() async {
    final records = await LocalDatabase.getAllWithPrefix(_prefix);
    return records.map(McpServerConfig.fromJson).toList();
  }

  Future<void> save(List<McpServerConfig> servers) async {
    await LocalDatabase.replaceAllWithPrefix(
      _prefix,
      servers.map((server) => server.toJson()).toList(),
    );
  }
}
