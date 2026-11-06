import 'dart:io';

import 'package:keel_ui/src/integrations/catalog_bridge/catalog_bridge_core.dart';

/// El proceso que lanza un cliente MCP de escritorio —ChatGPT desktop— para
/// trabajar sobre el catálogo de Keel.
///
/// Se compila con `scripts/build_catalog_mcp_worker.sh`, que usa
/// `dart build cli`, igual que el worker de LiteRT. Por eso importa
/// `catalog_bridge_core.dart` y no el barril `catalog_bridge.dart`: ese
/// último arrastra Flutter y acá no hay engine.
///
/// **Nada va a stdout que no sea el protocolo.** stdout ES el canal: una
/// línea de log ahí rompe el handshake del cliente. Los errores de uso van
/// a stderr, que el cliente muestra aparte.
Future<void> main(List<String> arguments) async {
  final endpointPath = _endpointPathFrom(arguments);
  if (endpointPath == null) {
    stderr.writeln(
      'Usage: $kCatalogWorkerExecutableName --endpoint '
      '<path to ${CatalogEndpointFile.fileName}>\n'
      'Keel shows the full command in Settings, ready to copy.',
    );
    exitCode = 64;
    return;
  }
  await CatalogMcpBridge.serve(endpointPath: endpointPath);
}

/// La ruta del archivo de enganche viene por argumento y no se adivina: la
/// carpeta de datos de la app la sabe la app (corre con `path_provider`),
/// y replicar esa regla por sistema operativo en un binario suelto es
/// exactamente la clase de segunda verdad que se desincroniza.
String? _endpointPathFrom(List<String> arguments) {
  final index = arguments.indexOf('--endpoint');
  if (index == -1 || index + 1 >= arguments.length) return null;
  final path = arguments[index + 1];
  return path.isEmpty ? null : path;
}
