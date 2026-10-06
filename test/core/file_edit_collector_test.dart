import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:keel_core/core/services/file_edit_collector.dart';

void main() {
  test(
    'an API provider edit (path, not file_path) still leaves its diff',
    () async {
      // OpenRouter/DeepSeek edit through Keel's own tool bridge, whose Edit
      // and Write take `path`. Claude's take `file_path`. Reading only the
      // latter lost every diff of an API turn.
      final dir = Directory.systemTemp.createTempSync('keel-edits-');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/nota.txt')..writeAsStringSync('antes\n');
      final collector = FileEditCollector(workingDirectory: dir.path);

      final path = FileEditCollector.filePathFor('Edit', {
        'path': 'nota.txt',
        'old_text': 'antes',
        'new_text': 'después',
      });
      expect(path, 'nota.txt');
      await collector.noteBeforeEdit(path!);
      file.writeAsStringSync('después\n');

      final edits = await collector.collect();
      expect(edits.single.beforeContent, 'antes\n');
      expect(edits.single.afterContent, 'después\n');
    },
  );
}
