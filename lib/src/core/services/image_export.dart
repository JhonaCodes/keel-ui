import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

Future<void> savePngBytes(
  Uint8List bytes, {
  required String suggestedName,
}) async {
  final location = await getSaveLocation(
    suggestedName: suggestedName,
    acceptedTypeGroups: const [
      XTypeGroup(label: 'PNG', extensions: ['png']),
    ],
  );
  if (location == null) return;

  await File(location.path).writeAsBytes(bytes);
}
