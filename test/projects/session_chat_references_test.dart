import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/l10n/generated/app_localizations.dart';

import 'package:keel_ui/src/core/services/local_database.dart';
import 'package:keel_ui/src/integrations/chat_references/chat_references.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/chat_reference_composer_field.dart';
import 'package:keel_ui/src/core/ui/app_theme.dart';
import 'package:keel_ui/src/modules/agent_profiles/model/agent_profile.dart';
import 'package:keel_ui/src/modules/agent_profiles/viewmodel/agent_profiles_viewmodel.dart';
import 'package:keel_ui/src/modules/agents/model/chat_message.dart';
import 'package:keel_ui/src/modules/knowledge/model/knowledge_base.dart';
import 'package:keel_ui/src/modules/knowledge/viewmodel/knowledge_viewmodel.dart';
import 'package:keel_ui/src/modules/projects/model/project.dart';
import 'package:keel_ui/src/modules/projects/model/session.dart';
import 'package:keel_ui/src/modules/projects/ui/view/session_chat_view.dart';
import 'package:keel_ui/src/modules/projects/viewmodel/projects_viewmodel.dart';
import 'package:keel_ui/src/modules/rules/model/rule.dart';
import 'package:keel_ui/src/modules/rules/viewmodel/rules_viewmodel.dart';
import 'package:keel_ui/src/modules/skills/model/skill.dart';
import 'package:keel_ui/src/modules/skills/viewmodel/skills_viewmodel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  LocalDatabase.markUnavailable();

  final now = DateTime(2026, 8, 25);
  final profile = AgentProfile(
    id: 'flutter-profile',
    name: 'flutter-expert',
    role: 'implementador',
    systemPrompt: '',
    model: 'sonnet',
    effort: 'high',
    createdAt: now,
  );

  late Project project;
  late Directory projectRoot;
  late Directory knowledgeRoot;

  setUp(() async {
    projectRoot = await Directory.systemTemp.createTemp('keel-chat-project-');
    knowledgeRoot = await Directory.systemTemp.createTemp(
      'keel-chat-knowledge-',
    );
    await Directory('${projectRoot.path}/lib/src').create(recursive: true);
    await Directory('${knowledgeRoot.path}/guide').create(recursive: true);
    await File(
      '${knowledgeRoot.path}/guide/architecture.md',
    ).writeAsString('# Arquitectura\nUsa un grafo adaptativo.');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => projectRoot.path,
        );
    addTearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            null,
          );
      await projectRoot.delete(recursive: true);
      await knowledgeRoot.delete(recursive: true);
    });

    await AgentProfilesService.instance.notifier.ready;
    await SkillsService.instance.notifier.ready;
    await RulesService.instance.notifier.ready;
    await KnowledgeService.instance.notifier.ready;
    AgentProfilesService.instance.notifier.updateState(
      AgentProfilesState(profiles: [profile]),
    );
    SkillsService.instance.notifier.updateState(
      SkillsState(
        skills: [
          Skill(
            id: 'skill-tdd',
            name: 'tdd-workflow',
            content: 'Primero escribe una prueba roja.',
            createdAt: now,
          ),
        ],
      ),
    );
    RulesService.instance.notifier.updateState(
      RulesState(
        rules: [
          Rule(
            id: 'rule-tdd',
            name: 'tdd-required',
            content: 'No implementes antes de reproducir.',
            createdAt: now,
          ),
        ],
      ),
    );
    KnowledgeService.instance.notifier.updateState(
      KnowledgeState(
        bases: [
          KnowledgeBase(
            id: 'knowledge-engineering',
            name: 'engineering',
            description: 'Arquitectura del producto.',
            source: KnowledgeSource.local,
            localPath: knowledgeRoot.path,
            createdAt: now,
          ),
        ],
        indexes: {
          'knowledge-engineering': KnowledgeIndex(
            rootPath: knowledgeRoot.path,
            nodes: const [
              KnowledgeNode(
                name: 'guide',
                relativePath: 'guide',
                isDirectory: true,
                children: [
                  KnowledgeNode(
                    name: 'architecture.md',
                    relativePath: 'guide/architecture.md',
                    isDirectory: false,
                  ),
                ],
              ),
            ],
          ),
        },
      ),
    );
    project = Project(
      id: 'project',
      name: 'keel-ui',
      purpose: '',
      workingDirectory: projectRoot.path,
      profileIds: [profile.id],
      activeSessionId: 'session',
      sessions: [
        Session(
          id: 'session',
          title: 'Sesión',
          createdAt: now,
          messages: [
            ChatMessage(
              role: ChatRole.assistant,
              text: 'Listo.',
              timestamp: now,
              authorProfileId: profile.id,
            ),
          ],
        ),
      ],
      createdAt: now,
    );
    ProjectsService.instance.notifier.updateState(
      ProjectsState(projects: [project], selectedProjectId: project.id),
    );
  });

  Future<void> pumpChat(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        // The widgets under test read AppLocalizations; without the
        // delegates `AppLocalizations.of` returns null and build throws.
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildAppTheme(),
        home: Scaffold(body: SessionChatView(project: project)),
      ),
    );
    await tester.pump();
  }

  testWidgets('al escribir @ filtra agentes y permite insertarlos', (
    tester,
  ) async {
    await pumpChat(tester);

    final field = find.byType(TextField).last;
    await tester.enterText(field, '@flutter');
    await tester.pump();

    expect(find.text('Agente · implementador'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(
      tester.widget<TextField>(field).controller!.text,
      '@flutter-expert ',
    );
  });

  testWidgets('/, \$ y # muestran catálogos y crean enlaces tipados', (
    tester,
  ) async {
    await pumpChat(tester);
    final field = find.byType(TextField).last;

    final directorySuggestions = await tester.runAsync(
      () => ChatReferenceService.suggestions(
        scope: ProjectReferenceScope(project: project, members: [profile]),
        query: const ChatReferenceQuery(
          kind: ChatReferenceKind.directory,
          text: 'lib',
          start: 0,
          end: 4,
        ),
      ),
    );
    expect(directorySuggestions, isNotEmpty);

    await tester.enterText(field, '/lib');
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    expect(find.text('Directorio del proyecto'), findsWidgets);
    await tester.tap(find.text('/lib').first);
    await tester.pump();
    expect(tester.widget<TextField>(field).controller!.text, '/lib ');

    await tester.enterText(field, '\$tdd');
    await tester.pump();
    expect(find.text('Skill'), findsOneWidget);
    expect(find.text('Regla'), findsOneWidget);
    await tester.tap(find.text('\$tdd-workflow'));
    await tester.pump();
    expect(tester.widget<TextField>(field).controller!.text, '\$tdd-workflow ');

    await tester.enterText(field, '#arch');
    await tester.pump();
    expect(find.text('Documento de Saber'), findsOneWidget);
    await tester.tap(find.text('#engineering/guide/architecture.md'));
    await tester.pump();
    expect(
      tester.widget<TextField>(field).controller!.text,
      '#engineering/guide/architecture.md ',
    );
  });

  testWidgets('mantiene el token legible y materializa su ID al enviar', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    String? sent;
    await tester.pumpWidget(
      MaterialApp(
        // The widgets under test read AppLocalizations; without the
        // delegates `AppLocalizations.of` returns null and build throws.
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildAppTheme(),
        home: Scaffold(
          body: ChatReferenceComposerField(
            controller: controller,
            scope: ProjectReferenceScope(project: project, members: [profile]),
            onSend: () {
              sent = controller.text;
              controller.clear();
            },
            hintText: 'Mensaje',
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '\$tdd');
    await tester.pump();
    await tester.tap(find.text('\$tdd-workflow'));
    await tester.pump();
    expect(controller.text, '\$tdd-workflow ');

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(sent, contains('keel://skill/skill-tdd'));
    expect(controller.text, isEmpty);
  });

  test(
    'resuelve contenido enlazado y rechaza rutas fuera del proyecto',
    () async {
      final text = [
        '[/lib](keel://directory?path=lib)',
        '[\$tdd-workflow](keel://skill/skill-tdd)',
        '[\$tdd-required](keel://rule/rule-tdd)',
        '[#engineering/guide/architecture.md]'
            '(keel://knowledge/knowledge-engineering?path=guide%2Farchitecture.md)',
        '[/escape](keel://directory?path=..%2Fescape)',
      ].join(' ');

      final context = await ChatReferenceService.promptContext(
        ProjectReferenceScope(project: project, members: [profile]),
        text,
      );

      expect(context, contains('${projectRoot.path}/lib'));
      expect(context, contains('Primero escribe una prueba roja.'));
      expect(context, contains('No implementes antes de reproducir.'));
      expect(context, contains('Usa un grafo adaptativo.'));
      expect(context, isNot(contains('/escape')));
    },
  );

  test('la cola muestra texto limpio y conserva IDs al editar', () {
    const original =
        'Revisá [\$tdd-workflow](keel://skill/skill-tdd) antes de cerrar.';

    expect(
      ChatReferenceService.visibleText(original),
      'Revisá \$tdd-workflow antes de cerrar.',
    );
    expect(
      ChatReferenceService.restoreReferencesAfterEdit(
        original,
        'Revisá \$tdd-workflow con más cuidado.',
      ),
      contains('[\$tdd-workflow](keel://skill/skill-tdd)'),
    );
    expect(
      ChatReferenceService.restoreReferencesAfterEdit(
        original,
        'Ya no uses esa instrucción.',
      ),
      isNot(contains('keel://')),
    );
  });

  test('una @mención explícita elige solo miembros y omite código', () {
    expect(
      ChatReferenceService.explicitlyMentionedMember(
        'Consultá a @flutter-expert.',
        [profile],
      ),
      profile,
    );
    expect(
      ChatReferenceService.explicitlyMentionedMember(
        'Ejemplo: `@flutter-expert`',
        [profile],
      ),
      isNull,
    );
    expect(
      ChatReferenceService.explicitlyMentionedMember(
        'Consultá a @otro-proyecto.',
        [profile],
      ),
      isNull,
    );
  });

  test('cada miembro aparece una sola vez en el catálogo de agentes', () async {
    final reviewer = AgentProfile(
      id: 'reviewer-profile',
      name: 'reviewer',
      role: 'auditor',
      systemPrompt: '',
      model: 'sonnet',
      effort: 'high',
      createdAt: now,
    );
    final suggestions = await ChatReferenceService.suggestions(
      scope: ProjectReferenceScope(
        project: project,
        members: [profile, reviewer],
      ),
      query: const ChatReferenceQuery(
        kind: ChatReferenceKind.agent,
        text: '',
        start: 0,
        end: 1,
      ),
    );

    expect(
      suggestions.map((suggestion) => suggestion.title),
      containsAllInOrder(['@flutter-expert', '@reviewer']),
    );
    expect(suggestions, hasLength(2));
  });
}
