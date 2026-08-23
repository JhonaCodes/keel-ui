part of '../catalog_bundle.dart';

/// El paquete de una cosa, cerrado sobre lo que necesita.
///
/// Función PURA sobre el catálogo portable: entra el catálogo entero y qué
/// se quiere empaquetar, sale el subconjunto. Sin ViewModels, sin disco y
/// sin red, porque es lo único de este feature que decide **qué viaja**, y
/// eso hay que poder probarlo sin la app.
///
/// La regla es «que funcione igual del otro lado»: si el agente lo usa, va.
/// Un paquete al que le falta una skill no es un agente incompleto, es un
/// agente distinto.
class BundleClosure {
  const BundleClosure({required this.catalog, required this.missing});

  /// Categoría → entidades, subconjunto del catálogo de entrada.
  final Map<String, List<Map<String, dynamic>>> catalog;

  /// Lo que el agente nombra y de este lado no existe. No es un error: un
  /// perfil puede referirse a una skill que borraste. Se dice, porque del
  /// otro lado va a faltar igual y en silencio sería peor.
  final List<String> missing;

  List<Map<String, dynamic>> of(String category) =>
      catalog[category] ?? const [];

  int get entityCount =>
      catalog.values.fold(0, (sum, entities) => sum + entities.length);

  Map<String, int> get counts => {
    for (final entry in catalog.entries)
      if (entry.value.isNotEmpty) entry.key: entry.value.length,
  };
}

/// Arma el cierre de [name] dentro de [kind] sobre [catalog].
BundleClosure buildBundleClosure({
  required BundleKind kind,
  required String name,
  required Map<String, List<Map<String, dynamic>>> catalog,
}) {
  final picked = <String, Map<String, Map<String, dynamic>>>{};
  final missing = <String>[];

  Map<String, dynamic>? entityNamed(String category, String entityName) =>
      (catalog[category] ?? const <Map<String, dynamic>>[])
          .where((json) => json['name'] == entityName)
          .firstOrNull;

  /// Suma una entidad al paquete. Devuelve true si estaba y todavía no se
  /// había sumado — así el recorrido no vuelve sobre sus pasos.
  bool take(String category, String entityName, {String? nameFor}) {
    if (entityName.isEmpty) return false;
    final already = picked[category]?.containsKey(entityName) ?? false;
    if (already) return false;

    final json = entityNamed(category, entityName);
    if (json == null) {
      missing.add('${nameFor ?? category}: $entityName');
      return false;
    }
    picked.putIfAbsent(category, () => {})[entityName] = json;
    return true;
  }

  List<String> namesIn(Map<String, dynamic> json, String key) => [
    for (final value in json[key] as List? ?? const [])
      if (value is String) value,
  ];

  void takeProfile(String handle) {
    if (!take('profiles', handle, nameFor: 'agente')) return;
    final profile = picked['profiles']![handle]!;

    for (final skill in namesIn(profile, 'skills')) {
      take('skills', skill, nameFor: 'skill');
    }
    for (final rule in namesIn(profile, 'rules')) {
      take('rules', rule, nameFor: 'regla');
    }
    for (final tool in namesIn(profile, 'tools')) {
      take('tools', tool, nameFor: 'tool');
    }
    for (final server in namesIn(profile, 'mcpServers')) {
      take('mcp_servers', server, nameFor: 'servidor MCP');
    }
    for (final base in namesIn(profile, 'knowledgeBaseNames')) {
      take('knowledge_bases', base, nameFor: 'base de saber');
    }
    for (final hookName in namesIn(profile, 'hooks')) {
      if (!take('hooks', hookName, nameFor: 'hook')) continue;
      final hook = picked['hooks']![hookName]!;
      // Un hook puede correr una TOOL registrada en vez de un comando. Sin
      // ella el hook no hace nada del otro lado, y falla en silencio: no hay
      // nadie mirando cuando un guardarraíl no salta.
      final body = hook['body'];
      if (body is Map && body['kind'] == 'tool') {
        take('tools', body['toolName'] as String? ?? '', nameFor: 'tool');
      }
      // Las reglas que el hook dice hacer cumplir viajan con él: son el
      // texto que explica por qué te frenó.
      for (final rule in namesIn(hook, 'enforces')) {
        take('rules', rule, nameFor: 'regla');
      }
    }
  }

  switch (kind) {
    case BundleKind.skill:
      take('skills', name, nameFor: 'skill');

    case BundleKind.agent:
      takeProfile(name);

    case BundleKind.workflow:
      if (take('workflows', name, nameFor: 'workflow')) {
        final workflow = picked['workflows']![name]!;
        // Las skills que el workflow declara viajan con él: sin eso, del
        // otro lado llega un flujo que le pide a sus turnos un saber que ahí
        // no existe.
        for (final skill
            in (workflow['skillNames'] as List?)?.cast<String>() ??
                const <String>[]) {
          take('skills', skill, nameFor: 'skill');
        }
        final roles = {
          for (final step in workflow['steps'] as List? ?? const [])
            if (step is Map && step['role'] is String) step['role'] as String,
        };
        // `*` no es un puesto: es «cualquiera del proyecto», y buscarle
        // candidatos daría siempre «puesto sin ningún agente».
        roles.remove(kAnyRole);
        // Un workflow no nombra agentes: nombra PUESTOS, y el proyecto pone
        // quién los ocupa. Se empaqueta a todos los que hoy podrían ocupar
        // cada puesto — es lo único que hace que el workflow arranque del
        // otro lado en vez de quedar pidiendo roles que ahí no existen.
        for (final role in roles) {
          final candidates = [
            for (final profile
                in catalog['profiles'] ?? const <Map<String, dynamic>>[])
              if (profile['role'] == role) profile['name'] as String? ?? '',
          ];
          if (candidates.isEmpty) {
            missing.add('puesto sin ningún agente: $role');
            continue;
          }
          candidates.forEach(takeProfile);
        }
      }
  }

  return BundleClosure(
    catalog: {
      for (final category in kCatalogCategories)
        if (picked[category]?.isNotEmpty ?? false)
          category: picked[category]!.values.toList(),
    },
    missing: missing,
  );
}

/// Los secrets que [closure] necesita del otro lado, por nombre.
///
/// Salen de las tools (que los reciben como variables de entorno) y de los
/// servidores MCP (por `secretEnv` y por los `{{PLACEHOLDER}}` de sus
/// headers). Es lo único que un paquete puede decir de un secret: el valor
/// no viaja, ni siquiera cuando el que exporta querría mandarlo.
List<String> requiredSecretsOf(BundleClosure closure) {
  final names = <String>{};

  for (final tool in closure.of('tools')) {
    for (final name in tool['secretNames'] as List? ?? const []) {
      if (name is String && name.isNotEmpty) names.add(name);
    }
  }

  for (final server in closure.of('mcp_servers')) {
    for (final name in (server['secretEnv'] as Map? ?? const {}).values) {
      if (name is String && name.isNotEmpty) names.add(name);
    }
    for (final value in (server['headers'] as Map? ?? const {}).values) {
      if (value is String) names.addAll(secretPlaceholdersIn(value));
    }
  }

  return names.toList()..sort();
}

/// La línea de resumen que va en la tapa, según qué se empaquetó.
String bundleSummaryOf(BundleKind kind, Map<String, dynamic> root) {
  final text = switch (kind) {
    BundleKind.agent => root['role'] as String? ?? '',
    BundleKind.workflow => root['whenToApply'] as String? ?? '',
    BundleKind.skill => firstLineOf(root['content'] as String? ?? ''),
  };
  return text.trim();
}

/// La primera línea con texto de [content], sin el `#` de un título.
String firstLineOf(String content) {
  for (final line in content.split('\n')) {
    final clean = line.replaceAll(RegExp(r'^#+\s*'), '').trim();
    if (clean.isNotEmpty) return clean;
  }
  return '';
}
