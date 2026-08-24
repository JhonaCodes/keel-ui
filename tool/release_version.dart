import 'dart:convert';
import 'dart:io';

import 'package:keel_ui/src/integrations/app_update/release_version.dart';

void main(List<String> arguments) {
  try {
    switch (arguments.firstOrNull) {
      case 'next':
        if (arguments.length != 2) _usage();
        stdout.writeln(ReleaseVersion.parse(arguments[1]).next());
        return;
      case 'bump':
        if (arguments.length != 2) _usage();
        final file = File(arguments[1]);
        final source = file.readAsStringSync();
        final current = _readPubspecVersion(source);
        final next = current.next();
        file.writeAsStringSync(withPubspecVersion(source, next));
        stdout.writeln(next.pubspecValue);
        return;
      case 'manifest':
        if (arguments.length != 6) _usage();
        final manifest = KeelReleaseManifest(
          release: ReleaseVersion.parse(arguments[1]),
          downloadUrl: Uri.parse(arguments[2]),
          sha256: arguments[3],
          publishedAt: DateTime.parse(arguments[4]),
        );
        const encoder = JsonEncoder.withIndent('  ');
        File(
          arguments[5],
        ).writeAsStringSync('${encoder.convert(manifest.toJson())}\n');
        return;
      default:
        _usage();
    }
  } on Object catch (error) {
    stderr.writeln(error);
    exitCode = 64;
  }
}

ReleaseVersion _readPubspecVersion(String source) {
  final match = RegExp(
    r'^version:\s*(\d+\.\d+\.\d+\+\d+)\s*$',
    multiLine: true,
  ).firstMatch(source);
  if (match == null) {
    throw const FormatException('No se encontró la versión en pubspec.yaml.');
  }
  return ReleaseVersion.parse(match.group(1)!);
}

Never _usage() {
  stderr.writeln(
    'Uso:\n'
    '  dart run tool/release_version.dart next VERSION\n'
    '  dart run tool/release_version.dart bump PUBSPEC\n'
    '  dart run tool/release_version.dart manifest VERSION URL SHA FECHA SALIDA',
  );
  exit(64);
}
