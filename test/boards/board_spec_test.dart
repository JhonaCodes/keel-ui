import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/integrations/genui/genui.dart';
import 'package:keel_ui/src/modules/boards/model/board.dart';

Map<String, dynamic> spec(String json) =>
    jsonDecode(json) as Map<String, dynamic>;

BoardSpec parse(String json) => parseBoardSpec(
  spec(json),
  projectId: 'p1',
  createdByProfileId: 'perfil',
  now: DateTime(2026, 8, 23),
);

void main() {
  group('leer la especificación de un tablero', () {
    test('un tablero completo entra entero', () {
      final result = parse('''
{
  "name": "Lanzar oferta",
  "note": "contra dev",
  "fields": [
    {"key": "producto", "label": "Producto", "default": "SKU-1183"},
    {"key": "ambiente", "kind": "opcion", "options": ["dev", "staging"]},
    {"key": "buyer", "kind": "secreto", "secret_name": "TOKEN_BUYER_DEV"}
  ],
  "actions": [
    {
      "label": "Lanzar",
      "steps": [
        {
          "kind": "http",
          "method": "post",
          "url": "https://{{ambiente}}.api/v1/offers",
          "headers": {"Authorization": "Bearer {{buyer}}"},
          "body": "{\\"sku\\": \\"{{producto}}\\"}"
        }
      ]
    }
  ]
}
''');

      expect(result.errors, isEmpty);
      final board = result.board!;
      expect(board.name, 'Lanzar oferta');
      expect(board.projectId, 'p1');
      expect(board.createdByProfileId, 'perfil');
      expect(board.fields.map((f) => f.key), ['producto', 'ambiente', 'buyer']);
      expect(board.fields[1].options, ['dev', 'staging']);
      expect(board.actions.single.steps.single.method, 'POST');
    });

    test('una clave que no existe se nombra en vez de guardarse', () {
      final result = parse('''
{"name": "x", "fields": [{"key": "uno"}],
 "actions": [{"label": "y", "steps": [
   {"kind": "http", "url": "https://api/{{dos}}"}]}]}
''');

      expect(result.board, isNull);
      expect(result.errors.single, contains('{{dos}}'));
    });

    test('una captura queda disponible para el paso siguiente', () {
      final result = parse('''
{"name": "x",
 "actions": [{"label": "y", "steps": [
   {"kind": "comando", "command": "gcloud",
    "args": ["auth", "print-access-token"],
    "captures": [{"as": "token", "from": "salida"}]},
   {"kind": "http", "method": "POST", "url": "https://fcm/send",
    "headers": {"Authorization": "Bearer {{token}}"}}]}]}
''');

      expect(result.errors, isEmpty);
      expect(result.board!.actions.single.steps, hasLength(2));
    });

    test('pero no para el paso que la produce ni para los de antes', () {
      final result = parse('''
{"name": "x",
 "actions": [{"label": "y", "steps": [
   {"kind": "http", "url": "https://api/{{token}}"},
   {"kind": "comando", "command": "echo",
    "captures": [{"as": "token", "from": "salida"}]}]}]}
''');

      expect(result.board, isNull);
      expect(result.errors.single, contains('{{token}}'));
    });

    test('una captura no puede pisar un campo del tablero', () {
      final result = parse('''
{"name": "x", "fields": [{"key": "token"}],
 "actions": [{"label": "y", "steps": [
   {"kind": "comando", "command": "echo",
    "captures": [{"as": "token", "from": "salida"}]}]}]}
''');

      expect(result.errors.single, contains('pisa un campo'));
    });

    test('una captura de JSON sin ruta no pasa', () {
      final result = parse('''
{"name": "x", "actions": [{"label": "y", "steps": [
  {"kind": "http", "url": "https://api",
   "captures": [{"as": "id", "from": "json"}]}]}]}
''');

      expect(result.errors.single, contains('"path"'));
    });

    test('un campo de tipo opcion sin opciones no pasa', () {
      final result = parse('''
{"name": "x", "fields": [{"key": "a", "kind": "opcion"}],
 "actions": [{"label": "y", "steps": [{"kind":"http","url":"https://api"}]}]}
''');

      expect(result.errors.single, contains('options'));
    });

    test('un campo secreto tiene que decir de qué secret sale', () {
      final result = parse('''
{"name": "x", "fields": [{"key": "a", "kind": "secreto"}],
 "actions": [{"label": "y", "steps": [{"kind":"http","url":"https://api"}]}]}
''');

      expect(result.errors.single, contains('secret_name'));
    });

    test('un método que no existe se rechaza', () {
      final result = parse('''
{"name": "x", "actions": [{"label": "y", "steps": [
  {"kind": "http", "method": "SEND", "url": "https://api"}]}]}
''');

      expect(result.errors.single, contains('SEND'));
    });

    test('sin acciones no hay tablero', () {
      final result = parse('{"name": "x"}');

      expect(result.board, isNull);
      expect(result.errors.single, contains('actions'));
    });

    test('sin nombre tampoco', () {
      final result = parse(
        '{"actions": [{"label":"y","steps":[{"kind":"http","url":"https://a"}]}]}',
      );

      expect(result.errors.single, contains('name'));
    });

    test('dos campos con la misma clave se rechazan', () {
      final result = parse('''
{"name": "x", "fields": [{"key": "a"}, {"key": "a"}],
 "actions": [{"label": "y", "steps": [{"kind":"http","url":"https://api"}]}]}
''');

      expect(result.errors.single, contains('dos veces'));
    });

    test('actualizar conserva id, autor y fecha de creación', () {
      final existing = Board(
        id: 'viejo',
        projectId: 'p1',
        name: 'x',
        createdByProfileId: 'el-primero',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      final result = parseBoardSpec(
        spec(
          '{"name": "x", "actions": [{"label":"y","steps":'
          '[{"kind":"http","url":"https://a"}]}]}',
        ),
        projectId: 'p1',
        createdByProfileId: 'otro',
        existing: existing,
        now: DateTime(2026, 8, 23),
      );

      expect(result.board!.id, 'viejo');
      expect(result.board!.createdByProfileId, 'el-primero');
      expect(result.board!.createdAt, DateTime(2026, 1, 1));
      expect(result.board!.updatedAt, DateTime(2026, 8, 23));
    });

    test('una acción con comando se marca como tal', () {
      final result = parse('''
{"name": "x", "actions": [{"label": "y", "steps": [
  {"kind": "comando", "command": "adb", "args": ["logcat"]}]}]}
''');

      expect(result.board!.actions.single.runsCommands, isTrue);
    });
  });
}
