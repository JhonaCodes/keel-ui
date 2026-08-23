import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/integrations/catalog_bundle/catalog_bundle.dart';

/// Un catálogo de juguete con la forma exacta de `catalogAsJson()`.
Map<String, List<Map<String, dynamic>>> _catalog() => {
  'skills': [
    {'name': 'revisión', 'content': '# Revisión\nMirá el diff.'},
    {'name': 'suelta', 'content': 'Nadie la usa.'},
  ],
  'rules': [
    {'name': 'sin ternarios', 'content': 'Nada de `? :` anidados.'},
    {'name': 'tests primero', 'content': 'RED antes que GREEN.'},
  ],
  'tools': [
    {'name': 'desplegar', 'code': 'echo deploy', 'secretNames': ['DEPLOY_KEY']},
    {'name': 'medir', 'code': 'echo medir', 'secretNames': <String>[]},
  ],
  'hooks': [
    {
      'name': 'compuerta',
      'event': 'PreToolUse',
      'body': {'kind': 'tool', 'toolName': 'medir'},
      'enforces': ['tests primero'],
    },
  ],
  'mcp_servers': [
    {
      'name': 'linear',
      'transport': 'stdio',
      'command': 'npx',
      'args': ['-y', 'linear-mcp'],
      'secretEnv': {'LINEAR_API_KEY': 'LINEAR'},
      'headers': <String, String>{},
    },
    {
      'name': 'atlassian',
      'transport': 'http',
      'url': 'https://mcp.atlassian.com',
      'secretEnv': <String, String>{},
      'headers': {'Authorization': 'Bearer {{ATLASSIAN_TOKEN}}'},
    },
  ],
  'knowledge_bases': [
    {'name': 'manual', 'description': 'Cómo se hace', 'source': 'local'},
  ],
  'profiles': [
    {
      'name': 'flutter-expert',
      'role': 'implementador',
      'systemPrompt': 'Escribís Flutter.',
      'skills': ['revisión'],
      'rules': ['sin ternarios'],
      'hooks': ['compuerta'],
      'tools': ['desplegar'],
      'mcpServers': ['linear', 'atlassian'],
      'knowledgeBaseNames': ['manual'],
    },
    {
      'name': 'code-auditor',
      'role': 'auditor',
      'systemPrompt': 'Auditás.',
      'skills': <String>[],
      'rules': <String>[],
      'hooks': <String>[],
      'tools': <String>[],
      'mcpServers': <String>[],
      'knowledgeBaseNames': <String>[],
    },
    {
      'name': 'otro-auditor',
      'role': 'auditor',
      'systemPrompt': 'También auditás.',
      'skills': ['suelta'],
    },
  ],
  'workflows': [
    {
      'name': 'tdd',
      'whenToApply': 'Cuando hay que tocar código.',
      'steps': [
        {'title': 'RED', 'role': 'implementador', 'instruction': 'Un test que falle.'},
        {'title': 'Compuerta', 'role': 'auditor', 'instruction': 'Revisá.'},
      ],
    },
  ],
};

BundleClosure _closure(BundleKind kind, String name) =>
    buildBundleClosure(kind: kind, name: name, catalog: _catalog());

List<String> _names(BundleClosure closure, String category) =>
    [for (final json in closure.of(category)) json['name'] as String]..sort();

void main() {
  group('un agente viaja con todo lo que usa', () {
    test('sus skills, reglas, tools, hooks, MCPs y bases', () {
      final closure = _closure(BundleKind.agent, 'flutter-expert');

      expect(_names(closure, 'profiles'), ['flutter-expert']);
      expect(_names(closure, 'skills'), ['revisión']);
      expect(_names(closure, 'mcp_servers'), ['atlassian', 'linear']);
      expect(_names(closure, 'knowledge_bases'), ['manual']);
      expect(closure.missing, isEmpty);
    });

    test('la tool que corre un hook, que si no el hook no hace nada', () {
      final closure = _closure(BundleKind.agent, 'flutter-expert');
      // `medir` no está en las tools del perfil: llega porque es el cuerpo
      // del hook, y un guardarraíl que no salta falla en silencio.
      expect(_names(closure, 'tools'), ['desplegar', 'medir']);
    });

    test('la regla que el hook dice hacer cumplir', () {
      final closure = _closure(BundleKind.agent, 'flutter-expert');
      expect(_names(closure, 'rules'), ['sin ternarios', 'tests primero']);
    });

    test('y nada más: lo que no usa no viaja', () {
      final closure = _closure(BundleKind.agent, 'flutter-expert');
      expect(_names(closure, 'skills'), isNot(contains('suelta')));
      expect(closure.of('workflows'), isEmpty);
      expect(closure.of('projects'), isEmpty);
    });
  });

  group('un workflow viaja con quienes pueden ocuparlo', () {
    test('todos los agentes de cada puesto, cerrados a su vez', () {
      final closure = _closure(BundleKind.workflow, 'tdd');

      expect(_names(closure, 'workflows'), ['tdd']);
      // Un workflow nombra PUESTOS, no agentes: van los tres que hoy podrían
      // ocuparlos, o del otro lado el workflow queda pidiendo roles vacíos.
      expect(_names(closure, 'profiles'), [
        'code-auditor',
        'flutter-expert',
        'otro-auditor',
      ]);
      // Y con ellos lo suyo: la skill de `otro-auditor` entra por él.
      expect(_names(closure, 'skills'), ['revisión', 'suelta']);
    });

    test('un puesto sin nadie se nombra en vez de fallar', () {
      final catalog = _catalog();
      catalog['workflows'] = [
        {
          'name': 'huérfano',
          'steps': [
            {'title': 'X', 'role': 'traductor', 'instruction': 'Traducí.'},
          ],
        },
      ];
      final closure = buildBundleClosure(
        kind: BundleKind.workflow,
        name: 'huérfano',
        catalog: catalog,
      );

      expect(_names(closure, 'workflows'), ['huérfano']);
      expect(closure.of('profiles'), isEmpty);
      expect(closure.missing, ['puesto sin ningún agente: traductor']);
    });
  });

  group('una skill viaja sola', () {
    test('porque una skill es texto y no arrastra nada', () {
      final closure = _closure(BundleKind.skill, 'revisión');
      expect(closure.entityCount, 1);
      expect(_names(closure, 'skills'), ['revisión']);
    });
  });

  group('lo que falta se dice', () {
    test('una referencia rota se nombra y el resto igual viaja', () {
      final catalog = _catalog();
      catalog['profiles'] = [
        {
          'name': 'roto',
          'role': 'implementador',
          'skills': ['revisión', 'la-que-borré'],
          'tools': ['fantasma'],
        },
      ];
      final closure = buildBundleClosure(
        kind: BundleKind.agent,
        name: 'roto',
        catalog: catalog,
      );

      expect(_names(closure, 'skills'), ['revisión']);
      expect(closure.missing, ['skill: la-que-borré', 'tool: fantasma']);
    });

    test('exportar algo que no existe da un cierre vacío', () {
      final closure = _closure(BundleKind.agent, 'no-existe');
      expect(closure.entityCount, 0);
      expect(closure.missing, ['agente: no-existe']);
    });
  });

  group('los secrets viajan por nombre y nada más', () {
    test('de las tools, del secretEnv y de los headers', () {
      final closure = _closure(BundleKind.agent, 'flutter-expert');
      expect(requiredSecretsOf(closure), [
        'ATLASSIAN_TOKEN',
        'DEPLOY_KEY',
        'LINEAR',
      ]);
    });

    test('ningún valor aparece en el cierre', () {
      final closure = _closure(BundleKind.agent, 'flutter-expert');
      final serialized = closure.catalog.toString();
      expect(serialized, isNot(contains('secret_value')));
      // El header viaja con el placeholder, nunca resuelto.
      expect(serialized, contains('{{ATLASSIAN_TOKEN}}'));
    });
  });

  group('la tapa se llena sola', () {
    test('el resumen sale de lo que cada cosa ya dice', () {
      expect(
        bundleSummaryOf(BundleKind.agent, {'role': 'implementador'}),
        'implementador',
      );
      expect(
        bundleSummaryOf(BundleKind.workflow, {'whenToApply': 'Al tocar código.'}),
        'Al tocar código.',
      );
      expect(
        bundleSummaryOf(BundleKind.skill, {'content': '# Título\n\nQué hace.'}),
        'Título',
      );
    });

    test('los contadores son los del cierre', () {
      final closure = _closure(BundleKind.agent, 'flutter-expert');
      expect(closure.counts['profiles'], 1);
      expect(closure.counts['tools'], 2);
      expect(closure.counts.containsKey('projects'), isFalse);
    });
  });
}
