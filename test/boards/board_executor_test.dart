import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:keel_ui/src/integrations/genui/genui.dart';
import 'package:keel_ui/src/modules/boards/model/board.dart';

Board boardWith(List<BoardStep> steps) => Board(
  id: 'b1',
  projectId: 'p1',
  name: 'prueba',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  actions: [BoardAction(id: 'a1', label: 'Disparar', steps: steps)],
);

void main() {
  group('correr una acción', () {
    test('un paso HTTP devuelve estado, cuerpo y tiempo', () async {
      final board = boardWith([
        const BoardStep(
          kind: BoardStepKind.http,
          method: 'POST',
          url: 'https://api/v1/offers',
          body: '{"sku": "{{producto}}"}',
        ),
      ]);

      late http.Request seen;
      final run = await runBoardAction(
        board: board,
        action: board.actions.single,
        values: const {'producto': 'SKU-1'},
        client: MockClient((request) async {
          seen = request;
          return http.Response('{"offerId": "of_1"}', 201);
        }),
      );

      expect(run.ok, isTrue);
      expect(run.steps.single.status, 201);
      expect(run.steps.single.output, contains('of_1'));
      expect(seen.body, '{"sku": "SKU-1"}');
      expect(seen.headers['content-type'], startsWith('application/json'));
    });

    test('un 4xx corta y queda como error, con el cuerpo adentro', () async {
      final board = boardWith([
        const BoardStep(kind: BoardStepKind.http, url: 'https://api/x'),
        const BoardStep(kind: BoardStepKind.http, url: 'https://api/y'),
      ]);

      final run = await runBoardAction(
        board: board,
        action: board.actions.single,
        values: const {},
        client: MockClient(
          (request) async => http.Response('{"error": "sin stock"}', 422),
        ),
      );

      expect(run.ok, isFalse);
      expect(run.steps, hasLength(1), reason: 'el segundo no tiene que correr');
      expect(run.failure!.error, contains('sin stock'));
    });

    test('lo que captura un paso llega al siguiente', () async {
      final board = boardWith([
        const BoardStep(
          kind: BoardStepKind.http,
          method: 'POST',
          url: 'https://auth/token',
          captures: [
            StepCapture(as: 'token', from: CaptureFrom.json, path: 'access'),
          ],
        ),
        const BoardStep(
          kind: BoardStepKind.http,
          method: 'POST',
          url: 'https://fcm/send',
          headers: {'Authorization': 'Bearer {{token}}'},
        ),
      ]);

      final vistos = <String, String?>{};
      final run = await runBoardAction(
        board: board,
        action: board.actions.single,
        values: const {},
        client: MockClient((request) async {
          vistos[request.url.host] = request.headers['Authorization'];
          if (request.url.host == 'auth') {
            return http.Response(jsonEncode({'access': 'ya29.abc'}), 200);
          }
          return http.Response('{}', 200);
        }),
      );

      expect(run.ok, isTrue);
      expect(run.steps.first.captured, {'token': 'ya29.abc'});
      expect(vistos['fcm'], 'Bearer ya29.abc');
    });

    test(
      'una captura de un header sale por nombre, sin importar el caso',
      () async {
        final board = boardWith([
          const BoardStep(
            kind: BoardStepKind.http,
            url: 'https://api/x',
            captures: [
              StepCapture(
                as: 'sesion',
                from: CaptureFrom.header,
                path: 'Mcp-Session-Id',
              ),
            ],
          ),
        ]);

        final run = await runBoardAction(
          board: board,
          action: board.actions.single,
          values: const {},
          client: MockClient(
            (request) async =>
                http.Response('', 200, headers: {'mcp-session-id': 's-9'}),
          ),
        );

        expect(run.steps.single.captured, {'sesion': 's-9'});
      },
    );

    test('una captura que no encuentra nada no voltea la corrida', () async {
      final board = boardWith([
        const BoardStep(
          kind: BoardStepKind.http,
          url: 'https://api/x',
          captures: [
            StepCapture(as: 'id', from: CaptureFrom.json, path: 'no.existe'),
          ],
        ),
      ]);

      final run = await runBoardAction(
        board: board,
        action: board.actions.single,
        values: const {},
        client: MockClient((request) async => http.Response('{}', 200)),
      );

      expect(run.ok, isTrue);
      expect(run.steps.single.captured, isEmpty);
    });

    test('una clave sin valor corta antes de salir a la red', () async {
      final board = boardWith([
        const BoardStep(kind: BoardStepKind.http, url: 'https://api/{{falta}}'),
      ]);

      var salio = false;
      final run = await runBoardAction(
        board: board,
        action: board.actions.single,
        values: const {},
        client: MockClient((request) async {
          salio = true;
          return http.Response('', 200);
        }),
      );

      expect(salio, isFalse);
      expect(run.ok, isFalse);
      expect(run.failure!.error, contains('{{falta}}'));
    });

    test('un comando devuelve su salida y la deja capturada', () async {
      final board = boardWith([
        const BoardStep(
          kind: BoardStepKind.comando,
          command: 'echo',
          args: ['{{mensaje}}'],
          captures: [StepCapture(as: 'eco', from: CaptureFrom.salida)],
        ),
      ]);

      final run = await runBoardAction(
        board: board,
        action: board.actions.single,
        values: const {'mensaje': 'hola'},
      );

      expect(run.ok, isTrue);
      expect(run.steps.single.output.trim(), 'hola');
      expect(run.steps.single.captured, {'eco': 'hola'});
    });

    test('un comando que falla corta con su código de salida', () async {
      final board = boardWith([
        const BoardStep(
          kind: BoardStepKind.comando,
          command: 'sh',
          args: ['-c', 'echo se rompio >&2; exit 3'],
        ),
        const BoardStep(kind: BoardStepKind.comando, command: 'echo'),
      ]);

      final run = await runBoardAction(
        board: board,
        action: board.actions.single,
        values: const {},
      );

      expect(run.ok, isFalse);
      expect(run.steps, hasLength(1));
      expect(run.steps.single.status, 3);
      expect(run.steps.single.error, contains('se rompio'));
    });
  });
}
