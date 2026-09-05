import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/l10n/generated/app_localizations.dart';

import 'package:keel_ui/src/core/services/local_database.dart';
import 'package:keel_ui/src/modules/projects/model/project.dart';
import 'package:keel_ui/src/modules/projects/model/session.dart';
import 'package:keel_ui/src/modules/projects/model/session_decision.dart';
import 'package:keel_ui/src/modules/projects/model/session_live_turn.dart';
import 'package:keel_ui/src/modules/requirements/service/requirement_target_activity.dart';
import 'package:keel_ui/src/modules/projects/viewmodel/projects_viewmodel.dart';
import 'package:keel_ui/src/modules/requirements/model/internal_requirement.dart';
import 'package:keel_ui/src/modules/requirements/ui/view/requirement_thread_view.dart';
import 'package:keel_ui/src/modules/workspace/model/workspace_lens.dart';
import 'package:keel_ui/src/modules/workspace/viewmodel/workspace_viewmodel.dart';

InternalRequirement _requerimiento({
  List<RequirementEntry> thread = const [],
  RequirementStatus status = RequirementStatus.abierto,
  String? takenInSessionId,
}) {
  final ahora = DateTime(2026, 8, 23, 17);
  return InternalRequirement(
    id: 'req-1',
    code: 'REQ-0001',
    title: 'Implementar soporte i18n: inglés + español colombiano',
    fromProjectId: 'p-origen',
    toProjectId: 'p-destino',
    need: 'Traducir toda la interfaz a dos idiomas.',
    context: 'Hay 665 strings en 315 archivos, todos en español.',
    openedByHandle: 'i18n-analista',
    openedInSessionId: 's-1',
    createdAt: ahora,
    updatedAt: ahora,
    thread: thread,
    status: status,
    takenInSessionId: takenInSessionId,
    takenByHandle: takenInSessionId == null ? null : 'i18n-traductor',
  );
}

/// El proyecto destino, con las sesiones que se le pasen.
void _conDestino({List<Session> sessions = const []}) {
  ProjectsService.instance.notifier.updateState(
    ProjectsState(
      projects: [
        Project(
          id: 'p-destino',
          name: 'keel-ui',
          purpose: '',
          workingDirectory: '/tmp',
          createdAt: DateTime(2026, 8, 23),
          sessions: sessions,
        ),
      ],
    ),
  );
}

Session _sesion(String id) =>
    Session(id: id, title: 'REQ-0001', createdAt: DateTime(2026, 8, 23));

void main() {
  LocalDatabase.markUnavailable();

  Future<void> abrir(
    WidgetTester tester,
    InternalRequirement requirement,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: RequirementThreadView(requirement: requirement)),
      ),
    );
    await tester.pump();
  }

  testWidgets('el hilo se abre sin reventar el layout', (tester) async {
    // El caso que colgaba la app: una franja del hilo dentro de un
    // scroll. La barra de color se estiraba a lo alto de una caja sin
    // alto, y eso tira una excepción de layout POR FRANJA Y POR FRAME —
    // con el volcado del árbol entero cada vez, que es lo que deja la
    // ventana sin responder.
    await abrir(
      tester,
      _requerimiento(
        thread: [
          for (var index = 0; index < 6; index++)
            RequirementEntry(
              id: 'e$index',
              side: index.isEven
                  ? RequirementSide.destino
                  : RequirementSide.origen,
              kind: RequirementEntryKind.avance,
              text: 'Entrada número $index del hilo.',
              authorHandle: 'i18n-traductor',
              createdAt: DateTime(2026, 8, 23, 17, index),
            ),
        ],
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('REQ-0001'), findsOneWidget);
    expect(find.text('Entrada número 5 del hilo.'), findsOneWidget);
  });

  testWidgets('sin entradas tampoco: el pedido ya es una franja', (
    tester,
  ) async {
    await abrir(tester, _requerimiento());

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Traducir toda la interfaz'), findsOneWidget);
  });

  group('volver al trabajo que arrancó', () {
    setUp(() {
      WorkspaceService.instance.notifier.cleanState();
      ProjectsService.instance.notifier.updateState(const ProjectsState());
    });

    testWidgets('tomar y evaluar arranca la sesión y va hacia ella', (
      tester,
    ) async {
      _conDestino();
      await abrir(tester, _requerimiento());

      await tester.tap(find.text('Tomar y evaluar'));
      await tester.pump();

      final projects = ProjectsService.instance.notifier.data;
      final abierta = projects.selectedProject?.activeSession;
      expect(abierta, isNotNull);
      expect(abierta!.title, startsWith('REQ-0001 ·'));
      // Y la pantalla se movió: apretar y quedarte mirando el requerimiento
      // es quedarte mirando el lado que ya leíste.
      expect(
        WorkspaceService.instance.notifier.data.lens,
        WorkspaceLens.session,
      );
      expect(projects.selectedProjectId, 'p-destino');
    });

    testWidgets('tomado: hay una puerta a la sesión, y lleva ahí', (
      tester,
    ) async {
      _conDestino(sessions: [_sesion('s-req')]);
      await abrir(
        tester,
        _requerimiento(
          status: RequirementStatus.tomado,
          takenInSessionId: 's-req',
        ),
      );

      expect(find.text('Tomar y evaluar'), findsNothing);
      await tester.tap(find.text('Ir a la sesión'));
      await tester.pump();

      final workspace = WorkspaceService.instance.notifier;
      expect(workspace.data.lens, WorkspaceLens.session);
      // El PROYECTO también: el área central dibuja la sesión del proyecto
      // seleccionado, y el requerimiento apunta a otro.
      final projects = ProjectsService.instance.notifier.data;
      expect(projects.selectedProjectId, 'p-destino');
      expect(projects.selectedProject?.activeSessionId, 's-req');
    });

    testWidgets('si la sesión se borró, no se ofrece ir a ningún lado', (
      tester,
    ) async {
      _conDestino();
      await abrir(
        tester,
        _requerimiento(
          status: RequirementStatus.tomado,
          takenInSessionId: 's-que-ya-no-esta',
        ),
      );

      expect(find.text('Ir a la sesión'), findsNothing);
    });
  });

  group('actividad del destino', () {
    test('describe si la sesión que tomó el requerimiento está actuando', () {
      final base = Session(
        id: 's-req',
        title: 'REQ-0001',
        createdAt: DateTime(2026, 8, 23),
      );
      expect(requirementTargetActivity(null), isNull);
      expect(
        requirementTargetActivity(
          base.copyWith(
            isRunning: true,
            liveTurn: const SessionLiveTurn(
              profileId: 'p',
              phase: TurnPhase.thinking,
            ),
          ),
        ),
        contains('pensando'),
      );
      expect(
        requirementTargetActivity(
          base.copyWith(
            decisions: [
              SessionDecision(
                id: 'd',
                kind: SessionDecisionKind.question,
                profileId: 'p',
                workNodeId: '',
                title: 'x',
                createdAt: DateTime(2026),
              ),
            ],
          ),
        ),
        contains('esperándote'),
      );
      expect(
        requirementTargetActivity(
          base.copyWith(status: SessionStatus.finished),
        ),
        contains('terminó'),
      );
      expect(requirementTargetActivity(base), contains('sin turno'));
    });

    testWidgets('el header dice qué está haciendo la sesión destino', (
      tester,
    ) async {
      _conDestino(
        sessions: [
          _sesion('s-req').copyWith(
            isRunning: true,
            liveTurn: const SessionLiveTurn(
              profileId: 'p',
              phase: TurnPhase.working,
            ),
          ),
        ],
      );
      // Con localización de verdad: el header la usa, y el harness viejo
      // de este archivo no la trae (por eso otros tests suyos fallan).
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: RequirementThreadView(
              requirement: _requerimiento(
                status: RequirementStatus.tomado,
                takenInSessionId: 's-req',
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('trabajando'), findsOneWidget);
    });
  });

}
