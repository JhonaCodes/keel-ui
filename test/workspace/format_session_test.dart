import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/core/services/local_database.dart';
import 'package:keel_ui/src/core/ui/app_theme.dart';
import 'package:keel_ui/src/modules/projects/model/project.dart';
import 'package:keel_ui/src/modules/projects/model/session.dart';
import 'package:keel_ui/src/modules/projects/ui/view/project_state_view.dart';
import 'package:keel_ui/src/modules/projects/viewmodel/projects_viewmodel.dart';
import 'package:keel_ui/src/modules/workspace/model/workspace_lens.dart';
import 'package:keel_ui/src/modules/workspace/viewmodel/workspace_viewmodel.dart';

ProjectsViewModel get _projects => ProjectsService.instance.notifier;
WorkspaceViewModel get _workspace => WorkspaceService.instance.notifier;

/// Un proyecto con UNA sesión en el estado que se quiera probar.
Project _conFormato(SessionStatus status, {bool formato = true}) => Project(
  id: 'p',
  name: 'p',
  purpose: '',
  workingDirectory: '/tmp',
  createdAt: DateTime(2026, 8, 23),
  sessions: [
    Session(
      id: 's',
      title: 'Definir el formato',
      createdAt: DateTime(2026, 8, 23),
      status: status,
      isFormatSession: formato,
    ),
  ],
);

void main() {
  late Directory tmp;
  late String projectId;

  setUpAll(LocalDatabase.markUnavailable);

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('keel-formato');
    await _projects.ready;
    for (final project in [..._projects.data.projects]) {
      _projects.deleteProject(project.id);
    }
    // Una carpeta sin `TASKS/`: el formato no cierra y la pantalla de Estado
    // ofrece la sesión que lo arregla.
    _projects.createProject(
      name: 'sin-formato',
      purpose: 'probar',
      workingDirectory: tmp.path,
      profileIds: const [],
      workflowIds: const [],
      ruleNames: const [],
      knowledgeBaseNames: const [],
    );
    projectId = _projects.data.projects.single.id;
    _workspace.openProjectState(projectId);
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  Session? formatSessionOf(String id) => _projects.data.projects
      .firstWhere((project) => project.id == id)
      .sessions
      .where((session) => session.isFormatSession)
      .firstOrNull;

  group('la sesión que arregla el formato', () {
    test('devuelve su id para que el que apretó navegue', () {
      final sessionId = _projects.startRoadmapFormatSession(projectId);

      expect(sessionId, isNotNull);
      expect(formatSessionOf(projectId)?.id, sessionId);
      expect(formatSessionOf(projectId)?.title, 'Definir el formato');
    });

    test('pedirla dos veces no abre dos: devuelve la que ya está', () {
      final primera = _projects.startRoadmapFormatSession(projectId);
      final segunda = _projects.startRoadmapFormatSession(projectId);

      expect(segunda, primera);
      final project = _projects.data.projects.single;
      expect(
        project.sessions.where((s) => s.isFormatSession).length,
        1,
        reason: 'dos sesiones sobre la misma carpeta se pisan los archivos',
      );
    });

    test('la que falló el chequeo sigue contando como abierta', () {
      // `failed` es el veredicto de «arreglá eso y volvé a cerrar»: la sesión
      // sigue siendo donde continuar, no una para descartar.
      expect(
        ProjectsViewModel.openFormatSessionOf(
          _conFormato(SessionStatus.failed),
        ),
        isNotNull,
      );
      expect(
        ProjectsViewModel.openFormatSessionOf(
          _conFormato(SessionStatus.running),
        ),
        isNotNull,
      );
    });

    test('cerrada de verdad ya no traba nada', () {
      expect(
        ProjectsViewModel.openFormatSessionOf(
          _conFormato(SessionStatus.finished),
        ),
        isNull,
      );
    });

    test('una sesión común no cuenta, aunque esté corriendo', () {
      final project = _conFormato(SessionStatus.running, formato: false);
      expect(ProjectsViewModel.openFormatSessionOf(project), isNull);
    });
  });

  group('el botón de la pantalla de Estado', () {
    Widget app() => MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(
        body: ProjectStateView(project: _projects.data.projects.single),
      ),
    );

    testWidgets('apretarlo abre la sesión Y navega a ella', (tester) async {
      await tester.pumpWidget(app());
      await tester.pump();

      expect(find.text('Definir el formato'), findsOneWidget);
      expect(_workspace.data.lens, WorkspaceLens.projectState);

      await tester.tap(find.text('Definir el formato'));
      await tester.pump();

      // Antes creaba la sesión y te dejaba mirando la misma pantalla de
      // error, sin ninguna señal de que algo había pasado.
      expect(_workspace.data.lens, WorkspaceLens.session);
      final project = _projects.data.projects.single;
      expect(project.activeSessionId, formatSessionOf(projectId)?.id);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('con una abierta ofrece ir, no abrir otra', (tester) async {
      _projects.startRoadmapFormatSession(projectId);

      await tester.pumpWidget(app());
      await tester.pump();

      expect(find.text('Definir el formato'), findsNothing);
      expect(find.text('Ir a la sesión abierta'), findsOneWidget);

      await tester.tap(find.text('Ir a la sesión abierta'));
      await tester.pump();

      expect(_workspace.data.lens, WorkspaceLens.session);
      expect(
        _projects.data.projects.single.sessions
            .where((s) => s.isFormatSession)
            .length,
        1,
      );

      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
