/// Conectarse a un MCP externo y preguntarle qué tools tiene.
///
/// Existe porque hasta ahora no había forma de saber si un servidor
/// registrado levanta. Te enterabas tres turnos después, cuando el agente
/// "no usó la tool", sin poder distinguir si no quiso o si nunca la tuvo.
///
/// Hace exactamente el apretón de manos que hace el CLI —`initialize` y
/// `tools/list`— así que lo que devuelve es lo que el agente va a ver. Un
/// comando que no existe, un token rechazado o un servidor que no arranca
/// aparecen acá en segundos.
///
/// El resultado NO es configuración: es el estado de esta máquina en este
/// momento. Se guarda aparte y no viaja en el respaldo, por la misma razón
/// por la que las tomas de tareas tampoco viajan.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_mcp/client.dart';
import 'package:dart_mcp/stdio.dart';
import 'package:http/http.dart' as http;
import 'package:logger_rs/logger_rs.dart';

import 'package:keel_ui/src/core/services/user_shell_path.dart';

import 'package:keel_ui/src/modules/mcp_servers/model/mcp_probe_result.dart';
import 'package:keel_ui/src/modules/mcp_servers/model/mcp_server_config.dart';

export 'package:keel_ui/src/modules/mcp_servers/model/mcp_probe_result.dart';

part 'src/probe_stdio.dart';
part 'src/probe_remote.dart';

/// Cuánto se espera antes de darlo por muerto. Un `npx` que baja el paquete
/// la primera vez es lo más lento que puede pasar legítimamente.
const kMcpProbeTimeout = Duration(seconds: 25);

/// Se conecta a [config] y devuelve qué contestó. Nunca tira: todo error se
/// devuelve adentro del resultado, porque "no se pudo" es justamente la
/// respuesta que se está buscando.
Future<McpProbeResult> probeMcpServer(
  McpServerConfig config, {
  required Map<String, String> secretValues,
}) async {
  final missing = [
    for (final name in config.secretNames)
      if (!secretValues.containsKey(name) || secretValues[name]!.isEmpty) name,
  ];
  if (missing.isNotEmpty) {
    return McpProbeResult.failed(
      'Falta el valor de ${missing.join(', ')}. Sin eso el servidor va a '
      'rechazar la conexión, así que ni se intenta.',
    );
  }

  final started = DateTime.now();
  final attempt = switch (config.transport) {
    McpTransport.stdio => _probeStdio(config, secretValues),
    McpTransport.http || McpTransport.sse => _probeRemote(config, secretValues),
  };

  try {
    final result = await attempt.timeout(
      kMcpProbeTimeout,
      onTimeout: () => McpProbeResult.failed(
        'No contestó en ${kMcpProbeTimeout.inSeconds} segundos.',
      ),
    );
    return result.withElapsed(DateTime.now().difference(started));
  } catch (error) {
    Log.w('Probe de MCP falló para ${config.name}: $error');
    return McpProbeResult.failed(
      _readableError(error),
    ).withElapsed(DateTime.now().difference(started));
  }
}

/// Un error de red o de proceso, en palabras. El `toString()` de una
/// excepción de `dart:io` trae la clase y el errno adentro, que no le dice
/// nada a nadie.
String _readableError(Object error) => switch (error) {
  ProcessException(:final executable) =>
    'No se pudo ejecutar "$executable". ¿Está instalado en esta máquina?',
  SocketException(:final message) => 'No se pudo conectar: $message',
  HandshakeException() => 'Falló el TLS con ese servidor.',
  TimeoutException() => 'No contestó a tiempo.',
  FormatException() => 'Contestó algo que no es JSON-RPC.',
  _ => error.toString(),
};
