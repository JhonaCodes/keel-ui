import 'dart:io';

import 'package:logger_rs/logger_rs.dart';

import 'package:keel_ui/src/modules/agents/model/file_edit.dart';

/// Captures before/after snapshots of the files a CLI turn touches, so the
/// chat can render a real diff for each one. Shared by the 1:1 agent chat and
/// by workstation tasks — both drive the same CLI and see the same tool-use
/// events.
class FileEditCollector {
  static const _maxDiffableFileBytes = 300000;

  final Map<String, String?> _beforeContentByPath = {};

  /// The file a tool-use event is about to modify, or null when the tool
  /// doesn't touch a file.
  static String? filePathFor(String toolName, Map<String, dynamic>? input) {
    return switch (toolName) {
      'Write' || 'Edit' || 'MultiEdit' => input?['file_path'] as String?,
      'NotebookEdit' => input?['notebook_path'] as String?,
      _ => null,
    };
  }

  /// Records the current contents of [path] before the tool runs. Ignores a
  /// path already recorded in this turn, so the "before" stays the state at
  /// the start of the turn even across several edits to the same file.
  Future<void> noteBeforeEdit(String path) async {
    if (_beforeContentByPath.containsKey(path)) return;
    _beforeContentByPath[path] = await readTextSafely(path);
  }

  /// Reads the after-state of every recorded path and pairs it with its
  /// snapshot, then clears the buffer for the next turn.
  Future<List<FileEdit>> collect() async {
    final edits = <FileEdit>[];
    for (final path in _beforeContentByPath.keys) {
      final after = await readTextSafely(path);
      edits.add(
        FileEdit(
          path: path,
          beforeContent: _beforeContentByPath[path],
          afterContent: after ?? '',
        ),
      );
    }
    _beforeContentByPath.clear();
    return edits;
  }

  void clear() => _beforeContentByPath.clear();

  /// Reads [path], or returns null when it doesn't exist, is too large to
  /// diff without stalling the UI, or can't be read as text.
  static Future<String?> readTextSafely(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return null;
      final stat = await file.stat();
      if (stat.size > _maxDiffableFileBytes) return null;
      return await file.readAsString();
    } catch (error) {
      Log.w('Could not read $path for diff capture: $error');
      return null;
    }
  }
}
