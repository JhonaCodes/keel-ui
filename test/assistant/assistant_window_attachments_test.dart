import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:keel_core/modules/agents/service/chat_attachment_store.dart';
import 'package:keel_ui/src/modules/assistant/service/assistant_window_boot.dart';

/// La ventana Keel AI es otro engine: lo que arrastrás a su chat se copia al
/// almacenamiento de la app igual que en la ventana principal. Si su arranque
/// no deja dónde copiar, la imagen se descarta sin aviso y el chat parece no
/// aceptar el drop.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory support;
  late Directory dragSource;

  setUp(() {
    support = Directory.systemTemp.createTempSync('keel-ai-support-');
    dragSource = Directory.systemTemp.createTempSync('keel-ai-drag-');
    // Un engine recién creado: nada de lo que fijó la ventana principal.
    ChatAttachmentStore.appSupportDirectoryPath = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => support.path,
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    for (final dir in [support, dragSource]) {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    }
  });

  test('an image dropped on the Keel AI chat is stored', () async {
    await prepareAssistantEngine();
    final screenshot = File('${dragSource.path}/screenshot.png')
      ..writeAsBytesSync([0x89, 0x50, 0x4e, 0x47]);

    final stored = await ChatAttachmentStore.adoptImages([screenshot.path]);

    expect(stored, hasLength(1));
    expect(stored.single, startsWith(support.path));
    expect(File(stored.single).readAsBytesSync(), [0x89, 0x50, 0x4e, 0x47]);
  });
}
