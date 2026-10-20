part of '../catalog_bridge_core.dart';

/// Dónde está escuchando el catálogo MCP de la app que está corriendo
/// AHORA: puerto efímero, token del arranque, y el pid que lo publicó.
///
/// No es parte del catálogo ni se versiona: el servidor saca puerto y token
/// nuevos en cada arranque, así que un archivo de ayer ya apunta a un
/// puerto muerto. Lo que lo descarta es que no conteste, no su forma — por
/// eso [fromJson] es tolerante y devuelve ceros en vez de reventar.
class CatalogEndpoint {
  const CatalogEndpoint({
    required this.port,
    required this.token,
    required this.pid,
  });

  /// Puerto de loopback donde el host montó `/catalog`.
  final int port;

  /// Bearer del arranque actual. Quien lo tiene puede leer y escribir el
  /// catálogo entero, así que el archivo se guarda solo para su dueño.
  final String token;

  /// Pid del proceso de Keel que lo publicó. No se usa para decidir nada —
  /// el único juez es si el puerto contesta— pero cuando algo sale raro es
  /// la diferencia entre "quedó un archivo viejo" y "hay dos Keel abiertos".
  final int pid;

  /// Cierto cuando el archivo trae lo mínimo para intentar una conexión.
  bool get isUsable => port > 0 && token.isNotEmpty;

  Uri get uri => Uri(
    scheme: 'http',
    host: InternetAddress.loopbackIPv4.address,
    port: port,
    pathSegments: const ['catalog'],
  );

  CatalogEndpoint copyWith({int? port, String? token, int? pid}) =>
      CatalogEndpoint(
        port: port ?? this.port,
        token: token ?? this.token,
        pid: pid ?? this.pid,
      );

  factory CatalogEndpoint.fromJson(Map<String, dynamic> json) =>
      CatalogEndpoint(
        port: json['port'] as int? ?? 0,
        token: json['token'] as String? ?? '',
        pid: json['pid'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
    'port': port,
    'token': token,
    'pid': pid,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CatalogEndpoint &&
          runtimeType == other.runtimeType &&
          port == other.port &&
          token == other.token &&
          pid == other.pid;

  @override
  int get hashCode => Object.hash(port, token, pid);

  // El token queda afuera a propósito: los estados se loguean.
  @override
  String toString() => 'CatalogEndpoint(port: $port, pid: $pid)';
}

/// El archivo con el que la app le pasa su [CatalogEndpoint] al worker.
///
/// Es un archivo y no una variable de entorno ni un puerto fijo porque el
/// worker lo lanza ChatGPT, no Keel: no hay cómo heredarle nada, y el
/// puerto cambia en cada arranque. La ruta absoluta viaja en los `args` del
/// comando que el usuario copia, así que el worker nunca tiene que adivinar
/// dónde guarda sus cosas la app — eso lo sabe la app, que corre con
/// `path_provider`, y no un binario suelto replicando la regla por sistema
/// operativo.
abstract final class CatalogEndpointFile {
  static const fileName = 'catalog_mcp_endpoint.json';

  static String pathIn(String directory) => p.join(directory, fileName);

  /// Escribe el enganche, creando la carpeta si hace falta.
  ///
  /// Después del write le baja los permisos a 0600: adentro hay un token
  /// que abre el catálogo entero, y en una máquina con más de un usuario el
  /// `644` por defecto lo deja leer a cualquiera.
  static Future<void> publish(String path, CatalogEndpoint endpoint) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(endpoint.toJson()));
    if (!Platform.isWindows) {
      await Process.run('chmod', ['600', path]);
    }
  }

  /// Lee el enganche, o null si no hay, no se puede leer, está a medio
  /// escribir o le falta lo mínimo.
  ///
  /// Todos esos casos son el mismo para quien llama —no hay con quién
  /// hablar— y ninguno es excepcional: el caso normal de "Keel está
  /// cerrado" es exactamente este.
  static Future<CatalogEndpoint?> read(String path) async {
    final file = File(path);
    if (!file.existsSync()) return null;
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) return null;
      final endpoint = CatalogEndpoint.fromJson(decoded);
      return endpoint.isUsable ? endpoint : null;
    } on FormatException {
      return null;
    } on FileSystemException {
      return null;
    }
  }
}
