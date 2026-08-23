part of '../mcp_probe.dart';

/// Levanta el comando, habla JSON-RPC por su stdin/stdout y lo mata.
///
/// `runInShell` es lo que hace que `npx` se resuelva contra el PATH que se le
/// pasa —el del usuario, no el mínimo que hereda una app abierta desde el
/// Finder—. Como es un solo comando, `sh -c` termina haciendo `exec`, así que
/// el pid que queda ES el del servidor y matarlo lo mata de verdad.
Future<McpProbeResult> _probeStdio(
  McpServerConfig config,
  Map<String, String> secretValues,
) async {
  // El PATH del usuario va primero: lo que declare el servidor gana, porque
  // un servidor que fija su propio PATH lo hace a propósito.
  final environment = <String, String>{
    ...await UserShellPath.environment(),
    ...config.env,
    for (final entry in config.secretEnv.entries)
      entry.key: ?secretValues[entry.value],
  };

  final process = await Process.start(
    config.command,
    config.args,
    environment: environment,
    runInShell: true,
  );

  // stderr se escucha aunque no se use: un servidor que escribe ahí y nadie
  // lee llena el buffer del pipe y se traba, que se ve igual que "no
  // contesta" y manda a buscar el problema al lado equivocado.
  final complaints = <String>[];
  final stderrSubscription = process.stderr
      .transform(utf8.decoder)
      .listen(complaints.add);

  final client = MCPClient(Implementation(name: 'keel-ui', version: '1.0.0'));

  try {
    final connection = client.connectServer(
      stdioChannel(input: process.stdout, output: process.stdin),
    );
    final result = await _handshake(connection);
    return result;
  } on Object catch (error) {
    final complaint = complaints.join().trim();
    final detail = complaint.isEmpty ? _readableError(error) : complaint;
    return McpProbeResult.failed(detail);
  } finally {
    unawaited(stderrSubscription.cancel());
    process.kill();
    // `initialize` ya cierra la conexión cuando el servidor rechaza la
    // versión del protocolo, así que este segundo cierre puede ser un
    // no-op ruidoso. Que lo sea en silencio.
    unawaited(client.shutdown().catchError((Object _) {}));
  }
}

/// `initialize` + `notifications/initialized` + `tools/list`, que es
/// exactamente lo que hace el CLI al abrir un turno.
Future<McpProbeResult> _handshake(ServerConnection connection) async {
  final initialized = await connection.initialize(
    InitializeRequest(
      protocolVersion: ProtocolVersion.latestSupported,
      capabilities: ClientCapabilities(),
      clientInfo: Implementation(name: 'keel-ui', version: '1.0.0'),
    ),
  );
  connection.notifyInitialized();

  final tools = await connection.listTools();
  return McpProbeResult(
    ok: true,
    at: DateTime.now(),
    serverName: initialized.serverInfo.name,
    serverVersion: initialized.serverInfo.version,
    tools: [for (final tool in tools.tools) tool.name],
  );
}
