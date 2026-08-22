import 'package:keel_ui/src/core/services/local_database.dart';
import 'package:keel_ui/src/integrations/mcp_probe/mcp_probe.dart';

/// Guarda el último probe de cada servidor, con su id como clave.
///
/// Es un repositorio aparte y no un campo de [McpServerConfig] a propósito:
/// el probe es estado de esta máquina en este momento, no configuración. Por
/// eso `mcp_servers` viaja en el respaldo y esto no — restaurar en otra
/// máquina un "conectó, 42 tools" que nunca se verificó ahí sería una
/// mentira prolija.
class McpProbesRepository {
  static const _prefix = 'mcpprobe_';

  String _keyFor(String serverId) => '$_prefix$serverId';

  Future<Map<String, McpProbeResult>> load() async {
    final records = await LocalDatabase.entriesWithPrefix(_prefix);
    return {
      for (final record in records)
        record.key.substring(_prefix.length): McpProbeResult.fromJson(
          record.data,
        ),
    };
  }

  Future<void> save(String serverId, McpProbeResult result) =>
      LocalDatabase.put(_keyFor(serverId), result.toJson());

  Future<void> forget(String serverId) =>
      LocalDatabase.delete(_keyFor(serverId));
}
