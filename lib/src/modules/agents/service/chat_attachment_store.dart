import 'dart:io';

import 'package:logger_rs/logger_rs.dart';
import 'package:path_provider/path_provider.dart';

import 'package:keel_ui/src/shared/shared.dart';

/// Copies attachments OUT of wherever they were dragged from and INTO app
/// storage, then hands back the new path.
///
/// The copy is the point: a screenshot is dropped straight from a temp
/// folder the OS wipes on its own schedule, and a file picked from Desktop
/// gets renamed or moved by its owner. A chat message that outlives its
/// image would render a broken box forever, so the app takes its own copy
/// the moment the file is attached and never refers to the original again.
class ChatAttachmentStore {
  const ChatAttachmentStore._();

  static const _folderName = 'chat_attachments';

  /// What the chat accepts. Kept to what Flutter can decode AND what the
  /// model's Read tool understands, so a preview in the bubble always means
  /// the agent can see the same thing.
  static const supportedExtensions = <String>{
    'png',
    'jpg',
    'jpeg',
    'gif',
    'webp',
    'bmp',
  };

  /// File-picker filter and drop filter in one place.
  static bool isSupportedImage(String path) =>
      supportedExtensions.contains(extensionOf(path));

  /// Lowercase extension without the dot, empty when there is none.
  static String extensionOf(String path) {
    final name = path.split(Platform.pathSeparator).last;
    final dot = name.lastIndexOf('.');
    if (dot <= 0 || dot == name.length - 1) return '';
    return name.substring(dot + 1).toLowerCase();
  }

  /// Copies [sourcePath] into app storage under a fresh name. Returns the
  /// stored path, or null when the file could not be read — an attachment
  /// that failed to copy is dropped, never referenced at its original path.
  static Future<String?> adopt(String sourcePath) async {
    try {
      final support = await getApplicationSupportDirectory();
      final directory = Directory(
        '${support.path}${Platform.pathSeparator}$_folderName',
      );
      await directory.create(recursive: true);

      final extension = extensionOf(sourcePath);
      final name = extension.isEmpty
          ? generateUuidV4()
          : '${generateUuidV4()}.$extension';
      final target = '${directory.path}${Platform.pathSeparator}$name';
      await File(sourcePath).copy(target);
      return target;
    } catch (error) {
      Log.e('Failed to store chat attachment', error: error);
      return null;
    }
  }

  /// [adopt] over a list, keeping only what could be stored and only what is
  /// a supported image — a drop can carry folders and PDFs too.
  static Future<List<String>> adoptImages(List<String> sourcePaths) async {
    final stored = <String>[];
    for (final path in sourcePaths.where(isSupportedImage)) {
      final adopted = await adopt(path);
      if (adopted != null) stored.add(adopted);
    }
    return stored;
  }

  /// Removes a stored attachment the user detached before sending. Silent
  /// on failure: a leftover file is not worth interrupting the composer.
  static Future<void> discard(String storedPath) async {
    try {
      final file = File(storedPath);
      if (await file.exists()) await file.delete();
    } catch (error) {
      Log.w('Failed to discard chat attachment: $error');
    }
  }
}
