import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_core/integrations/mcp_catalog/mcp_catalog.dart';
import 'package:keel_core/modules/mcp_servers/model/mcp_server_config.dart';
import 'package:keel_core/modules/mcp_servers/service/mcp_servers_store.dart';
import 'package:keel_ui/src/core/services/store_mirror_view_model.dart';

/// Thin mirror over [McpServersStore] (keel_core): the real registration,
/// validation and probing logic lives there so keel-server can
/// run it without Flutter.
class McpServersViewModel extends StoreMirrorViewModel<McpServersState> {
  McpServersViewModel() : super(McpServersStore.instance);

  Future<void> get ready => McpServersStore.instance.ready;

  String? installFromCatalog(McpCatalogEntry entry) =>
      McpServersStore.instance.installFromCatalog(entry);

  Future<void> probeServer(String id) =>
      McpServersStore.instance.probeServer(id);

  List<McpServerConfig> serversByNames(List<String> names) =>
      McpServersStore.instance.serversByNames(names);

  McpServerConfig? serverNamed(String name) =>
      McpServersStore.instance.serverNamed(name);

  String? createServer({
    required String name,
    required McpTransport transport,
    required String command,
    required List<String> args,
    required Map<String, String> env,
    required Map<String, String> secretEnv,
    required String url,
    required Map<String, String> headers,
    String catalogId = '',
  }) => McpServersStore.instance.createServer(
    name: name,
    transport: transport,
    command: command,
    args: args,
    env: env,
    secretEnv: secretEnv,
    url: url,
    headers: headers,
    catalogId: catalogId,
  );

  String? updateServer(
    String id, {
    required String name,
    required McpTransport transport,
    required String command,
    required List<String> args,
    required Map<String, String> env,
    required Map<String, String> secretEnv,
    required String url,
    required Map<String, String> headers,
    String? catalogId,
  }) => McpServersStore.instance.updateServer(
    id,
    name: name,
    transport: transport,
    command: command,
    args: args,
    env: env,
    secretEnv: secretEnv,
    url: url,
    headers: headers,
    catalogId: catalogId,
  );

  void deleteServer(String id) => McpServersStore.instance.deleteServer(id);
}

mixin McpServersService {
  static final ReactiveNotifier<McpServersViewModel> instance =
      ReactiveNotifier<McpServersViewModel>(() => McpServersViewModel());
}
