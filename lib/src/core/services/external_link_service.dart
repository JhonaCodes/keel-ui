import 'dart:io';

import 'package:logger_rs/logger_rs.dart';

/// Abre [url] en el navegador del sistema.
///
/// Con el abridor que trae cada sistema y no con un paquete: es un comando
/// que ya está instalado en los tres, y una dependencia más para tres líneas
/// es una dependencia más para mantener.
///
/// Solo `http(s)`: la lista de esquemas la escribe un modelo cuando pega un
/// enlace, y `file://` o `x-apple-…` desde un mensaje del chat abriría cosas
/// que nadie pidió.
Future<void> openExternalUrl(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
    Log.w('Enlace descartado por esquema no permitido: $url');
    return;
  }

  final (command, arguments) = _opener(uri.toString());
  final result = await Process.run(command, arguments);
  if (result.exitCode == 0) return;
  Log.w('No pude abrir $url: ${(result.stderr as String).trim()}');
}

/// Con qué se abre un enlace en cada sistema.
///
/// En Windows va por `cmd /c start`, y el argumento vacío del medio no sobra:
/// `start` toma el primer texto entre comillas como el TÍTULO de la ventana,
/// así que sin ese hueco se comería la URL.
(String, List<String>) _opener(String url) => switch (Platform.operatingSystem) {
  'macos' => ('open', [url]),
  'windows' => ('cmd', ['/c', 'start', '', url]),
  // `xdg-open` es lo que respetan los escritorios de Linux para saber cuál es
  // tu navegador; lo trae xdg-utils, que está en cualquier instalación con
  // entorno gráfico.
  _ => ('xdg-open', [url]),
};
