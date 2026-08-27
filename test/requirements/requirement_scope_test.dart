import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/core/services/local_database.dart';
import 'package:keel_ui/src/integrations/chat_references/chat_references.dart';
import 'package:keel_ui/src/modules/agent_profiles/model/agent_profile.dart';
import 'package:keel_ui/src/modules/agent_profiles/viewmodel/agent_profiles_viewmodel.dart';
import 'package:keel_ui/src/modules/projects/model/project.dart';
import 'package:keel_ui/src/modules/projects/viewmodel/projects_viewmodel.dart';

final _epoch = DateTime.utc(2026, 8, 27);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  LocalDatabase.markUnavailable();

  late Project portal;
  late Project api;

  Future<AgentProfile> perfil(String handle, String role) async {
    final profiles = AgentProfilesService.instance.notifier;
    await profiles.ready;
    final existing = profiles.data.profiles
        .where((profile) => profile.name == handle)
        .firstOrNull;
    if (existing != null) return existing;
    final profile = AgentProfile(
      id: 'perfil-$handle',
      name: handle,
      role: role,
      systemPrompt: '',
      model: 'sonnet',
      effort: 'high',
      createdAt: _epoch,
    );
    await profiles.seedReservedProfile(profile);
    return profile;
  }

  Project proyecto(String name, List<String> profileIds) {
    final projects = ProjectsService.instance.notifier;
    projects.createProject(
      name: name,
      purpose: '',
      workingDirectory: '/tmp/keel-$name',
      profileIds: profileIds,
      workflowIds: const [],
      ruleNames: const [],
      knowledgeBaseNames: const [],
    );
    return projects.data.projects.firstWhere((p) => p.name == name);
  }

  setUp(() async {
    final projects = ProjectsService.instance.notifier;
    await projects.ready;
    for (final project in [...projects.data.projects]) {
      projects.deleteProject(project.id);
    }
    final flutter = await perfil('flutter-expert', 'front');
    final apiDev = await perfil('api-dev', 'backend');
    final compartido = await perfil('arquitecto', 'arquitectura');

    portal = proyecto('aulamas-portal', [flutter.id, compartido.id]);
    api = proyecto('aulamas-api', [apiDev.id, compartido.id]);
  });

  test('el @ ofrece a los miembros de los dos lados', () {
    final scope = RequirementReferenceScope(from: portal, to: api);

    expect(
      scope.agents.map((agent) => agent.name),
      containsAll(['flutter-expert', 'api-dev', 'arquitecto']),
    );
  });

  test('y a nadie más: un agente de otro proyecto no está', () {
    final otro = proyecto('kiwio', const []);
    expect(otro.name, 'kiwio');

    final scope = RequirementReferenceScope(from: portal, to: api);

    expect(
      scope.agents.map((agent) => agent.name),
      isNot(contains('keelai')),
      reason: 'el hilo es de dos proyectos, no del catálogo entero',
    );
  });

  test('el que está en los dos aparece una sola vez', () {
    final scope = RequirementReferenceScope(from: portal, to: api);
    final veces = scope.agents
        .where((agent) => agent.name == 'arquitecto')
        .length;

    expect(veces, 1);
  });

  test('no ofrece carpetas: no sobreviven el respaldo', () {
    final scope = RequirementReferenceScope(from: portal, to: api);

    expect(scope.directoryRoots, isEmpty);
  });

  group('de qué lado contesta', () {
    test('cada uno desde su propio proyecto', () {
      final scope = RequirementReferenceScope(from: portal, to: api);

      expect(scope.sideOf('api-dev')!.isTarget, isTrue);
      expect(scope.sideOf('api-dev')!.project.name, 'aulamas-api');
      expect(scope.sideOf('flutter-expert')!.isTarget, isFalse);
      expect(scope.sideOf('flutter-expert')!.project.name, 'aulamas-portal');
    });

    test('el que está en los dos contesta como destino', () {
      final scope = RequirementReferenceScope(from: portal, to: api);

      // Es a quien se le está preguntando si puede hacer el trabajo.
      expect(scope.sideOf('arquitecto')!.isTarget, isTrue);
      expect(scope.sideOf('arquitecto')!.project.name, 'aulamas-api');
    });

    test('un handle que no es de nadie no resuelve', () {
      final scope = RequirementReferenceScope(from: portal, to: api);

      expect(scope.sideOf('fantasma'), isNull);
    });
  });

  test('un proyecto borrado deja un lado menos, no un error', () {
    final scope = RequirementReferenceScope(from: null, to: api);

    expect(scope.agents.map((agent) => agent.name), contains('api-dev'));
    expect(
      scope.agents.map((agent) => agent.name),
      isNot(contains('flutter-expert')),
    );
    expect(scope.sideOf('flutter-expert'), isNull);
    expect(scope.sideOf('api-dev')!.isTarget, isTrue);
  });
}
