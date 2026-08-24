import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'el dominio no contiene APIs lineales, deprecadas ni nombres alternos',
    () {
      final sourceFiles = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'));
      final source = sourceFiles
          .map((file) => file.readAsStringSync())
          .join('\n');

      final forbidden = [
        ['class Workflow', 'Step'].join(),
        ['current', 'Step', 'Index'].join(),
        ['@', 'Deprecated'].join(),
        ['play', 'book'].join(),
      ];
      for (final term in forbidden) {
        expect(source.toLowerCase(), isNot(contains(term.toLowerCase())));
      }
    },
  );
}
