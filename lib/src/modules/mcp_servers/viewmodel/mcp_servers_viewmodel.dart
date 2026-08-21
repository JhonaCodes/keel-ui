import 'dart:async';

import 'package:logger_rs/logger_rs.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/src/modules/mcp_servers/model/mcp_server_config.dart';
import 'package:keel_ui/src/modules/mcp_servers/repository/mcp_servers_repository.dart';
import 'package:keel_ui/src/shared/shared.dart';

class McpServersViewModel extends ViewModel<McpServersState> {
  McpServersViewModel() : super(const McpServersState());

  McpServersRepository get _repository => McpServersRepository();

  Future<void>? _ready;
  Future<void> get ready => _ready ??= _loadPersistedServers();

  @override
  void init() {
    if (_ready == null) updateSilently(const McpServersState());
    unawaited(ready);
  }

  Future<void> _loadPersistedServers() async {
    try {
      final servers = await _repository.load();
      updateState(data.copyWith(servers: servers));
    } catch (error) {
      Log.e('Failed to load persisted MCP servers', error: error);
    }
  }

  /// The subset of the catalog whose names appear in [names], in catalog
  /// order — deleted references are silently skipped.
  List<McpServerConfig> serversByNames(List<String> names) =>
      data.servers.where((server) => names.contains(server.name)).toList();

  /// Registers a new external MCP server. Returns a user-facing error
  /// message on failure, or null on success.
  String? createServer({
    required String name,
    required McpTransport transport,
    required String command,
    required List<String> args,
    required Map<String, String> env,
    required Map<String, String> secretEnv,
    required String url,
    required Map<String, String> headers,
  }) {
    final error = _validate(
      name,
      transport: transport,
      command: command,
      url: url,
    );
    if (error != null) return error;

    final server = McpServerConfig(
      id: generateUuidV4(),
      name: name,
      transport: transport,
      command: command.trim(),
      args: args,
      env: env,
      secretEnv: secretEnv,
      url: url.trim(),
      headers: headers,
      createdAt: DateTime.now(),
    );
    final servers = [...data.servers, server];
    updateState(data.copyWith(servers: servers));
    unawaited(_repository.save(servers));
    return null;
  }

  /// Updates an existing server. Returns a user-facing error message on
  /// failure, or null on success.
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
  }) {
    final error = _validate(
      name,
      transport: transport,
      command: command,
      url: url,
      excludingId: id,
    );
    if (error != null) return error;

    final servers = data.servers
        .map(
          (server) => server.id == id
              ? server.copyWith(
                  name: name,
                  transport: transport,
                  command: command.trim(),
                  args: args,
                  env: env,
                  secretEnv: secretEnv,
                  url: url.trim(),
                  headers: headers,
                )
              : server,
        )
        .toList();
    updateState(data.copyWith(servers: servers));
    unawaited(_repository.save(servers));
    return null;
  }

  void deleteServer(String id) {
    final servers = data.servers.where((server) => server.id != id).toList();
    updateState(data.copyWith(servers: servers));
    unawaited(_repository.save(servers));
  }

  String? _validate(
    String name, {
    required McpTransport transport,
    required String command,
    required String url,
    String? excludingId,
  }) {
    final formatError = validateMcpServerName(name);
    if (formatError != null) return formatError;

    final isTaken = data.servers.any(
      (server) => server.name == name && server.id != excludingId,
    );
    if (isTaken) return 'Ya existe un MCP con ese nombre.';

    if (transport == McpTransport.stdio && command.trim().isEmpty) {
      return 'Un MCP stdio necesita el comando a ejecutar.';
    }
    if (transport == McpTransport.http && url.trim().isEmpty) {
      return 'Un MCP HTTP necesita la URL.';
    }
    return null;
  }
}

mixin McpServersService {
  static final ReactiveNotifier<McpServersViewModel> instance =
      ReactiveNotifier<McpServersViewModel>(() => McpServersViewModel());
}
