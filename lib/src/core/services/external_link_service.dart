import 'dart:io';

import 'package:logger_rs/logger_rs.dart';

/// Abre [url] en el navegador del sistema.
///
/// Con `open`, el mismo camino que ya usa la app para abrir un documento de
/// una base de saber: es una app de escritorio para macOS y el binario está
/// siempre, así que una dependencia más para esto no compra nada.
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

  final result = await Process.run('open', [uri.toString()]);
  if (result.exitCode == 0) return;
  Log.w('No pude abrir $url: ${(result.stderr as String).trim()}');
}
