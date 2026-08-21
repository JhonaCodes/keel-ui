import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

Future<Uint8List> renderMermaidPng(
  String diagram, {
  required bool dark,
  required String backgroundHex,
}) async {
  final encoded = base64Url.encode(utf8.encode(diagram));
  final theme = dark ? 'dark' : 'default';
  final uri = Uri.parse(
    'https://mermaid.ink/img/$encoded?type=png&theme=$theme&bgColor=$backgroundHex',
  );

  final response = await http.get(uri);
  if (response.statusCode != 200) {
    throw Exception('mermaid.ink respondió ${response.statusCode}');
  }
  return response.bodyBytes;
}
