import 'dart:async';

import 'package:logger_rs/logger_rs.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/src/integrations/mcp_catalog/mcp_catalog.dart';
import 'package:keel_ui/src/integrations/mcp_probe/mcp_probe.dart';
import 'package:keel_ui/src/modules/mcp_servers/model/mcp_server_config.dart';
import 'package:keel_ui/src/modules/mcp_servers/repository/mcp_probes_repository.dart';
import 'package:keel_ui/src/modules/mcp_servers/repository/mcp_servers_repository.dart';
import 'package:keel_ui/src/modules/secrets/viewmodel/secrets_viewmodel.dart';
import 'package:keel_ui/src/shared/shared.dart';

class McpServersViewModel extends ViewModel<McpServersState> {
  McpServersViewModel() : super(const McpServersState());

  McpServersRepository get _repository => McpServersRepository();
  McpProbesRepository get _probes => McpProbesRepository();

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
      final probes = await _probes.load();
      updateState(data.copyWith(servers: servers, probes: probes));
    } catch (error) {
      Log.e('Failed to load persisted MCP servers', error: error);
    }
  }

  /// Instala una ficha del catálogo. Es idempotente por NOMBRE, igual que
  /// `register_mcp_server`: pedirla dos veces actualiza la que hay en vez de
  /// dejar dos servidores con el mismo prefijo de tools.
  ///
  /// No crea los secrets: solo puede hacerlo el usuario, desde Secrets. Lo
  /// que sí hace es dejar la referencia puesta, así el badge de "falta el
  /// secret" aparece solo y dice cuál.
  String? installFromCatalog(McpCatalogEntry entry) {
    final existing = serverNamed(entry.serverName);
    if (existing != null) {
      return updateServer(
        existing.id,
        name: entry.serverName,
        transport: entry.transport,
        command: entry.command,
        args: entry.args,
        env: entry.env,
        secretEnv: entry.secretEnv,
        url: entry.url,
        headers: entry.headers,
        catalogId: entry.id,
      );
    }
    return createServer(
      name: entry.serverName,
      transport: entry.transport,
      command: entry.command,
      args: entry.args,
      env: entry.env,
      secretEnv: entry.secretEnv,
      url: entry.url,
      headers: entry.headers,
      catalogId: entry.id,
    );
  }

  /// Se conecta al servidor y guarda qué contestó.
  ///
  /// Los valores de los secrets se leen ACÁ y no salen de acá: van al
  /// proceso o al header y se descartan con la respuesta.
  Future<void> probeServer(String id) async {
    final server = data.servers.where((s) => s.id == id).firstOrNull;
    if (server == null || data.probing.contains(id)) return;

    updateState(data.copyWith(probing: {...data.probing, id}));
    try {
      final result = await probeMcpServer(
        server,
        secretValues: SecretsService.instance.notifier.valuesFor(
          server.secretNames,
        ),
      );
      updateState(
        data.copyWith(
          probes: {...data.probes, id: result},
          probing: {...data.probing}..remove(id),
        ),
      );
      unawaited(_probes.save(id, result));
    } catch (error) {
      // `probeMcpServer` no tira; si igual llegó algo acá, el estado no
      // puede quedar diciendo que todavía se está probando.
      Log.e('Probe de MCP explotó fuera de su propio try', error: error);
      updateState(data.copyWith(probing: {...data.probing}..remove(id)));
    }
  }

  /// The subset of the catalog whose names appear in [names], in catalog
  /// order — deleted references are silently skipped.
  List<McpServerConfig> serversByNames(List<String> names) =>
      data.servers.where((server) => names.contains(server.name)).toList();

  /// The registered server with this exact [name], or null.
  McpServerConfig? serverNamed(String name) =>
      data.servers.where((server) => server.name == name).firstOrNull;

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
    String catalogId = '',
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
      catalogId: catalogId,
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
    String? catalogId,
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
                  catalogId: catalogId,
                )
              : server,
        )
        .toList();
    // Cambió la configuración: lo que contestó la última vez ya no describe
    // a este servidor. Mostrarlo igual sería el peor de los dos mundos.
    updateState(
      data.copyWith(servers: servers, probes: {...data.probes}..remove(id)),
    );
    unawaited(_repository.save(servers));
    unawaited(_probes.forget(id));
    return null;
  }

  void deleteServer(String id) {
    final servers = data.servers.where((server) => server.id != id).toList();
    updateState(
      data.copyWith(servers: servers, probes: {...data.probes}..remove(id)),
    );
    unawaited(_repository.save(servers));
    unawaited(_probes.forget(id));
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
    if (transport != McpTransport.stdio && url.trim().isEmpty) {
      return 'Un MCP remoto necesita la URL.';
    }
    return null;
  }
}

mixin McpServersService {
  static final ReactiveNotifier<McpServersViewModel> instance =
      ReactiveNotifier<McpServersViewModel>(() => McpServersViewModel());
}
