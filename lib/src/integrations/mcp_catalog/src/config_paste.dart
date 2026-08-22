part of '../mcp_catalog.dart';

/// Un servidor leído de una configuración pegada.
class PastedMcpServer {
  final String name;
  final McpTransport transport;
  final String command;
  final List<String> args;
  final Map<String, String> env;
  final String url;
  final Map<String, String> headers;

  /// Claves de `env` cuyo valor parece una credencial escrita a mano.
  ///
  /// Se marcan porque un token pegado ahí queda como texto en la base, que
  /// es exactamente lo que la sección Secrets existe para evitar. No se
  /// bloquea —a veces es de mentira, o es una URL de desarrollo— pero se
  /// dice.
  final List<String> sensitiveEnvKeys;

  const PastedMcpServer({
    required this.name,
    required this.transport,
    this.command = '',
    this.args = const [],
    this.env = const {},
    this.url = '',
    this.headers = const {},
    this.sensitiveEnvKeys = const [],
  });

  String get detail => switch (transport) {
    McpTransport.stdio => '$command ${args.join(' ')}'.trim(),
    McpTransport.http || McpTransport.sse => url,
  };
}

/// El resultado de leer lo que alguien pegó.
class PastedMcpConfig {
  /// Los que se pudieron leer, en el orden en que venían.
  final List<PastedMcpServer> servers;

  /// Lo que no se pudo, con el nombre adelante para poder buscarlo.
  final List<String> problems;

  /// Por qué no se pudo leer nada. Vacío si el JSON estaba bien, aunque no
  /// haya traído servidores.
  final String error;

  const PastedMcpConfig({
    this.servers = const [],
    this.problems = const [],
    this.error = '',
  });
}

final RegExp _sensitiveKey = RegExp(
  r'TOKEN|KEY|SECRET|PASSWORD|PASSWD|CREDENTIAL|AUTH|DSN',
  caseSensitive: false,
);

/// Una cadena de conexión con usuario y clave adentro
/// (`postgres://usuario:clave@host/base`).
///
/// Mirar solo el nombre no alcanza y el caso más común lo demuestra:
/// `DATABASE_URL` no tiene una sola palabra sospechosa y lleva la
/// contraseña de la base escrita.
final RegExp _credentialInUrl = RegExp(r'://[^/\s:@]+:[^/\s@]+@');

bool _looksSensitive(String key, String value) {
  if (value.isEmpty) return false;
  return _sensitiveKey.hasMatch(key) || _credentialInUrl.hasMatch(value);
}

/// Lee el bloque `mcpServers` que publica cualquier servidor MCP en su
/// documentación.
///
/// Existe porque los hooks ya tenían importador y los MCP no: había que
/// traducir ese bloque al formulario campo por campo. Y es lo que vuelve al
/// catálogo robusto a quedarse viejo — si una ficha miente, la del README
/// del servidor gana.
///
/// Acepta las dos formas que se ven en la práctica: el objeto entero con su
/// clave `mcpServers`, y el mapa de nombre→configuración pelado.
PastedMcpConfig parseMcpServersJson(String raw) {
  if (raw.trim().isEmpty) {
    return const PastedMcpConfig();
  }

  final Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } on FormatException catch (error) {
    return PastedMcpConfig(error: 'Eso no es JSON: ${error.message}');
  }

  if (decoded is! Map<String, dynamic>) {
    return const PastedMcpConfig(
      error: 'Se esperaba un objeto JSON con los servidores adentro.',
    );
  }

  final block = decoded['mcpServers'] ?? decoded;
  if (block is! Map<String, dynamic>) {
    return const PastedMcpConfig(
      error:
          '"mcpServers" tendría que ser un objeto de nombre a '
          'configuración.',
    );
  }

  final servers = <PastedMcpServer>[];
  final problems = <String>[];

  for (final entry in block.entries) {
    final config = entry.value;
    if (config is! Map<String, dynamic>) {
      problems.add('${entry.key}: su configuración no es un objeto.');
      continue;
    }

    final nameError = validateMcpServerName(entry.key);
    if (nameError != null) {
      problems.add('${entry.key}: $nameError');
      continue;
    }

    final command = config['command'] as String? ?? '';
    final url = config['url'] as String? ?? '';

    if (command.isEmpty && url.isEmpty) {
      problems.add('${entry.key}: no dice ni comando ni URL.');
      continue;
    }

    final env = _stringMap(config['env']);
    if (command.isNotEmpty) {
      servers.add(
        PastedMcpServer(
          name: entry.key,
          transport: McpTransport.stdio,
          command: command,
          args: [
            for (final arg in config['args'] as List? ?? const [])
              arg.toString(),
          ],
          env: env,
          sensitiveEnvKeys: [
            for (final entry in env.entries)
              if (_looksSensitive(entry.key, entry.value)) entry.key,
          ],
        ),
      );
      continue;
    }

    final declared = config['type'] as String? ?? 'http';
    final transport = McpTransport.tryFromAlias(declared) ?? McpTransport.http;
    servers.add(
      PastedMcpServer(
        name: entry.key,
        transport: transport,
        url: url,
        headers: _stringMap(config['headers']),
      ),
    );
  }

  return PastedMcpConfig(servers: servers, problems: problems);
}

/// Un mapa de JSON pasado a strings. Los valores numéricos o booleanos que
/// se cuelan en un `env` se convierten en vez de descartarse: en el proceso
/// hijo van a ser texto igual.
Map<String, String> _stringMap(Object? value) {
  if (value is! Map) return const {};
  return {
    for (final entry in value.entries)
      entry.key.toString(): entry.value?.toString() ?? '',
  };
}
