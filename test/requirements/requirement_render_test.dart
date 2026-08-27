import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/integrations/requirements_mcp/requirements_mcp.dart';
import 'package:keel_ui/src/modules/requirements/model/internal_requirement.dart';

final _epoch = DateTime.utc(2026, 8, 27);

InternalRequirement _requirement({List<RequirementEntry> thread = const []}) =>
    InternalRequirement(
      id: 'req-1',
      code: 'REQ-0003',
      title: 'Falta el CRUD de personal',
      fromProjectId: 'p-portal',
      toProjectId: 'p-api',
      need: 'Endpoints bajo /school/institutions/{id}/staff.',
      context: 'La doc del contrato dice que es del colegio.',
      blocking: true,
      openedByHandle: 'flutter-expert',
      openedInSessionId: 's-1',
      status: RequirementStatus.abierto,
      thread: thread,
      createdAt: _epoch,
      updatedAt: _epoch,
    );

String _render(
  RequirementTurnPurpose purpose, {
  List<RequirementEntry> thread = const [],
}) => renderRequirementForTurn(
  _requirement(thread: thread),
  fromProject: 'aulamas-portal',
  toProject: 'aulamas-api',
  purpose: purpose,
);

void main() {
  group('lo que se le pide al turno', () {
    test('evaluando: dictaminá y convertí', () {
      final texto = _render(RequirementTurnPurpose.evaluar);

      expect(texto, contains('record_verdict'));
      expect(texto, contains('convert_to_task'));
    });

    test('consultando: ni dictamines ni conviertas', () {
      final texto = _render(RequirementTurnPurpose.consultar);

      // Pedirle un veredicto a un turno que no tiene esa tool es pedirle algo
      // imposible y después leer una disculpa.
      expect(texto, isNot(contains('record_verdict')));
      expect(texto, isNot(contains('convert_to_task')));
      expect(texto, contains('No es un pedido de trabajo'));
    });

    test('evaluar es el default: quien no elige, evalúa', () {
      final texto = renderRequirementForTurn(
        _requirement(),
        fromProject: 'aulamas-portal',
        toProject: 'aulamas-api',
      );

      expect(texto, contains('record_verdict'));
    });
  });

  group('la frontera', () {
    test('cruza lo que tiene que cruzar', () {
      final texto = _render(RequirementTurnPurpose.consultar);

      expect(texto, contains('REQ-0003'));
      expect(texto, contains('Endpoints bajo'));
      expect(texto, contains('La doc del contrato'));
      expect(texto, contains('aulamas-portal'));
      expect(texto, contains('Está frenado esperando esto.'));
    });

    test('el hilo compartido viaja con quién dijo cada cosa', () {
      final texto = _render(
        RequirementTurnPurpose.consultar,
        thread: [
          RequirementEntry(
            id: 'e-1',
            side: RequirementSide.usuario,
            kind: RequirementEntryKind.correccion,
            text: 'verificá si aplica',
            createdAt: _epoch,
          ),
          RequirementEntry(
            id: 'e-2',
            side: RequirementSide.destino,
            kind: RequirementEntryKind.avance,
            text: 'lo miro',
            createdAt: _epoch,
            authorHandle: 'api-dev',
          ),
        ],
      );

      expect(texto, contains('el usuario: verificá si aplica'));
      expect(texto, contains('api-dev: lo miro'));
    });

    test('y NADA del contexto privado del origen', () {
      // Si algo de esto se cuela, la frontera se cae en silencio: no hay
      // error, solo dos proyectos que empiezan a saber cosas del otro.
      for (final purpose in RequirementTurnPurpose.values) {
        final texto = _render(purpose).toLowerCase();
        for (final prohibido in const [
          'tasks/',
          'workingdirectory',
          '/users/',
          'plan de la sesión',
          'cliSessionsByProfileId',
        ]) {
          expect(
            texto,
            isNot(contains(prohibido.toLowerCase())),
            reason: prohibido,
          );
        }
      }
    });
  });
}
