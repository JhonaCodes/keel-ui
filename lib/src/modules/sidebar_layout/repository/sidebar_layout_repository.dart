import 'package:keel_ui/src/core/services/local_database.dart';
import 'package:keel_ui/src/modules/sidebar_layout/model/sidebar_layout.dart';

class SidebarLayoutRepository {
  static const _prefix = 'sidebar_layout_';

  Future<List<SidebarLayout>> load() async {
    final records = await LocalDatabase.getAllWithPrefix(_prefix);
    return records.map(SidebarLayout.fromJson).toList();
  }

  Future<void> save(List<SidebarLayout> layouts) {
    return LocalDatabase.replaceAllWithPrefix(
      _prefix,
      layouts.map((layout) => layout.toJson()).toList(),
    );
  }

  /// Las secciones del sidebar que el usuario dejó ABIERTAS, por clave.
  ///
  /// Se guardan las abiertas y no las plegadas porque el default es plegado:
  /// una sección que nadie tocó nunca no tiene por qué abrirse sola. Con la
  /// lista al revés habría que distinguir «plegada» de «todavía no existe»,
  /// que son la misma cosa.
  ///
  /// Va en un registro aparte y no adentro de [SidebarLayout] porque no es
  /// por sección del catálogo sino por PROYECTO —las claves son cosas como
  /// `boards:<projectId>`—, y meterlo ahí obligaría a inventarle un
  /// `SidebarSectionKind` que no existe.
  static const _openKey = 'sidebar_open_sections';

  Future<Set<String>> loadOpenSections() async {
    final record = await LocalDatabase.get(_openKey);
    final keys = record?['open'] as List?;
    return {...?keys?.cast<String>()};
  }

  Future<void> saveOpenSections(Set<String> open) {
    return LocalDatabase.put(_openKey, {'id': _openKey, 'open': open.toList()});
  }
}
