import 'dart:io';

class LocalFileService {
  Future<String> readText(String path) => File(path).readAsString();

  Future<void> writeText(String path, String content) =>
      File(path).writeAsString(content);
}
