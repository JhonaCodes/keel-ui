import 'package:keel_core/modules/agents/service/chat_attachment_store.dart';
import 'package:path_provider/path_provider.dart';

import 'package:keel_ui/src/core/services/local_database.dart';

/// Lo que el engine de la ventana Keel AI necesita antes de `runApp`.
///
/// Es otro engine de Flutter: no hereda nada de lo que el arranque de la
/// ventana principal dejó listo.
Future<void> prepareAssistantEngine() async {
  // Sin base en este engine, y dicho explícitamente: los ViewModels que
  // toque esta ventana (el de settings, vía el font scale de las burbujas)
  // tienen que leer "no hay nada guardado", no reventar.
  LocalDatabase.markUnavailable();
  // Su chat adjunta imágenes (arrastradas o elegidas) y las copia al mismo
  // almacenamiento que la ventana principal, que es quien después las lee
  // al mandar el turno. Sin esta ruta cada copia fallaba y el adjunto se
  // descartaba sin aviso: el drop parecía no hacer nada.
  ChatAttachmentStore.appSupportDirectoryPath =
      (await getApplicationSupportDirectory()).path;
}
