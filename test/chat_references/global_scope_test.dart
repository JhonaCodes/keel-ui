import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/core/services/local_database.dart';
import 'package:keel_ui/src/integrations/chat_references/chat_references.dart';
import 'package:keel_ui/src/integrations/workspace_roots/workspace_roots.dart';
import 'package:keel_ui/src/modules/agent_profiles/model/agent_profile.dart';
import 'package:keel_ui/src/modules/agent_profiles/viewmodel/agent_profiles_viewmodel.dart';
import 'package:keel_ui/src/modules/projects/viewmodel/projects_viewmodel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  LocalDatabase.markUnavailable();

  late Directory root;

  setUp(() async {
    root = Directory.systemTemp.createTempSync('keel_scope');
    Directory('${root.path}/lib/src').createSync(recursive: true);

    final projects = ProjectsService.instance.notifier;
    await projects.ready;
    for (final project in [...projects.data.projects]) {
      projects.deleteProject(project.id);
    }
    projects.createProject(
      name: 'keel-ui',
      purpose: 'la app',
      workingDirectory: root.path,
      profileIds: const [],
      workflowIds: const [],
      ruleNames: const [],
      knowledgeBaseNames: const [],
    );

    final roots = WorkspaceRootsService.instance.notifier;
    await roots.ready;
    for (final path in [...roots.recentPaths]) {
      await roots.forget(path);
    }
  });

  tearDown(() => root.deleteSync(recursive: true));

  Future<List<ChatReferenceSuggestion>> pedir(
    ChatReferenceKind kind,
    String text,
  ) => ChatReferenceService.suggestions(
    scope: const GlobalReferenceScope(),
    query: ChatReferenceQuery(
      kind: kind,
      text: text,
      start: 0,
      end: text.length + 1,
    ),
  );

  test('sin proyecto, `/` ofrece los proyectos registrados', () async {
    final suggestions = await pedir(ChatReferenceKind.directory, 'keel');

    expect(
      suggestions.map((suggestion) => suggestion.title),
      contains('/keel-ui'),
    );
    final raiz = suggestions.firstWhere((s) => s.title == '/keel-ui');
    expect(raiz.insertion, contains('root='));
    expect(raiz.subtitle, root.path);
  });

  test('y también sus subcarpetas, con el proyecto adelante', () async {
    final suggestions = await pedir(ChatReferenceKind.directory, 'lib');

    expect(
      suggestions.map((suggestion) => suggestion.title),
      contains('/keel-ui/lib'),
    );
  });

  test('una carpeta enlazada aporta su ruta absoluta', () async {
    final text =
        '[/keel-ui/lib](keel://directory?path=lib'
        '&root=${Uri.encodeQueryComponent(root.path)})';

    final context = await ChatReferenceService.promptContext(
      const GlobalReferenceScope(),
      text,
    );

    expect(context, contains('DIRECTORIO ENLAZADO'));
    expect(context, contains('lib'));
  });

  test('una raíz que no es del scope no entra al prompt', () async {
    final intruso = Directory.systemTemp.createTempSync('keel_intruso');
    addTearDown(() => intruso.deleteSync(recursive: true));
    final text =
        '[/etc](keel://directory?path=.'
        '&root=${Uri.encodeQueryComponent(intruso.path)})';

    final context = await ChatReferenceService.promptContext(
      const GlobalReferenceScope(),
      text,
    );

    expect(context, isEmpty);
  });

  test('`@` ofrece todo el catálogo de agentes, no un canal', () async {
    final profiles = AgentProfilesService.instance.notifier;
    await profiles.ready;
    await profiles.seedReservedProfile(
      AgentProfile(
        id: 'perfil-suelto',
        name: 'analista',
        role: 'análisis',
        systemPrompt: '',
        model: 'sonnet',
        effort: 'high',
        createdAt: DateTime.utc(2026, 8, 27),
      ),
    );

    final suggestions = await pedir(ChatReferenceKind.agent, 'anal');

    expect(
      suggestions.map((suggestion) => suggestion.title),
      contains('@analista'),
    );
  });
}
