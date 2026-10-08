part of '../system_vault.dart';

/// Categoría → entidades, tal cual [catalogAsJson].
typedef VaultCatalog = Map<String, List<Map<String, dynamic>>>;

/// Qué hacer con lo que subió otra máquina: lo que se aplica acá, lo que
/// cambió en los dos lados (gana lo de acá) y lo que allá se borró (acá se
/// conserva: el respaldo no propaga borrados).
typedef VaultMergePlan = ({
  VaultCatalog toApply,
  List<String> conflicts,
  List<String> deletedThere,
});

/// El merge de tres vías, por nombre dentro de cada categoría, entre el
/// respaldo que esta máquina vio por última vez ([base]), el que subió otra
/// ([theirs]) y el catálogo vivo de acá ([local]).
///
/// keel-server sube su catálogo ENTERO, no solo lo que cambió: aplicar todo
/// pisaría con copias viejas lo que se editó acá y todavía no se respaldó.
/// Por eso solo viaja lo que allá cambió respecto de [base].
final class VaultThreeWayMerge {
  const VaultThreeWayMerge({
    required this.base,
    required this.theirs,
    required this.local,
  });

  final VaultCatalog base;
  final VaultCatalog theirs;
  final VaultCatalog local;

  VaultMergePlan plan() {
    final toApply = <String, List<Map<String, dynamic>>>{};
    final conflicts = <String>[];
    final deletedThere = <String>[];

    for (final MapEntry(key: category, value: entries) in theirs.entries) {
      final before = _byName(base[category]);
      final here = _byName(local[category]);
      for (final entry in entries) {
        final name = entry['name'];
        if (name is! String) continue;
        final previous = before[name];
        if (_same(entry, previous)) continue;
        final mine = here[name];
        if (_same(mine, entry)) continue;
        if (_same(mine, previous)) {
          (toApply[category] ??= []).add(entry);
        } else {
          conflicts.add('$category/$name');
        }
      }
    }

    for (final MapEntry(key: category, value: entries) in base.entries) {
      final there = _byName(theirs[category]);
      final here = _byName(local[category]);
      for (final name in _byName(entries).keys) {
        if (!there.containsKey(name) && here.containsKey(name)) {
          deletedThere.add('$category/$name');
        }
      }
    }

    return (toApply: toApply, conflicts: conflicts, deletedThere: deletedThere);
  }

  /// Catálogo y secrets de un zip del vault, para leerlo en otro isolate:
  /// el zip lleva también las bases de saber y pesa decenas de MB.
  static ({VaultCatalog catalog, List<Map<String, dynamic>> secrets}) catalogOf(
    Uint8List bytes,
  ) {
    final contents = decodeVault(bytes);
    return (catalog: contents.catalog, secrets: contents.secrets);
  }

  static Map<String, Map<String, dynamic>> _byName(
    List<Map<String, dynamic>>? entries,
  ) => {
    for (final entry in entries ?? const <Map<String, dynamic>>[])
      if (entry['name'] case final String name) name: entry,
  };

  /// Igualdad por contenido: el orden de las claves depende de qué versión
  /// de keel_core escribió el zip, así que se compara la forma canónica.
  static bool _same(Map<String, dynamic>? a, Map<String, dynamic>? b) =>
      jsonEncode(_canonical(a)) == jsonEncode(_canonical(b));

  static Object? _canonical(Object? value) => switch (value) {
    final Map<dynamic, dynamic> map => {
      for (final key in map.keys.map((key) => '$key').toList()..sort())
        key: _canonical(map[key]),
    },
    final List<dynamic> list => [...list.map(_canonical)],
    _ => value,
  };
}
