import 'package:flutter/foundation.dart';

/// Las tres listas del sidebar que el usuario puede acomodar.
///
/// Las secciones de adentro de un proyecto —Estado, Tableros, Sesiones— no
/// están: no son una lista de cosas sueltas, son las partes del proyecto
/// abierto, y no hay nada que agrupar ahí.
enum SidebarSectionKind { project, requirement, agent }

/// Un lugar en la lista de una sección: o un ítem suelto, o un grupo.
///
/// Un grupo no puede contener otro grupo. Es una decisión, no una limitación
/// pendiente: con anidado, mover algo deja de tener un solo significado y la
/// lista se vuelve un árbol que hay que navegar en vez de una lista que se
/// lee.
sealed class SidebarSlot {
  const SidebarSlot();

  Map<String, dynamic> toJson();

  static SidebarSlot fromJson(Map<String, dynamic> json) {
    return json['type'] == 'group'
        ? SidebarGroupSlot.fromJson(json)
        : SidebarItemSlot.fromJson(json);
  }
}

/// Un proyecto, un requerimiento o un agente, en la raíz de su sección.
class SidebarItemSlot extends SidebarSlot {
  const SidebarItemSlot(this.itemId);

  final String itemId;

  @override
  Map<String, dynamic> toJson() => {'type': 'item', 'itemId': itemId};

  factory SidebarItemSlot.fromJson(Map<String, dynamic> json) =>
      SidebarItemSlot(json['itemId'] as String);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SidebarItemSlot && itemId == other.itemId;

  @override
  int get hashCode => itemId.hashCode;
}

/// Un grupo hecho por el usuario arrastrando una cosa sobre otra.
class SidebarGroupSlot extends SidebarSlot {
  const SidebarGroupSlot({
    required this.id,
    required this.name,
    required this.memberIds,
    this.collapsed = false,
  });

  final String id;
  final String name;

  /// En orden. El orden adentro de un grupo es tan del usuario como el de
  /// afuera.
  final List<String> memberIds;

  /// Si está plegado. Se persiste, al revés que el pliegue de Tableros o
  /// Sesiones: esos son del proyecto abierto y hay uno solo a la vez, y un
  /// grupo que se despliega solo en cada arranque no sirve para ordenar.
  final bool collapsed;

  SidebarGroupSlot copyWith({
    String? name,
    List<String>? memberIds,
    bool? collapsed,
  }) => SidebarGroupSlot(
    id: id,
    name: name ?? this.name,
    memberIds: memberIds ?? this.memberIds,
    collapsed: collapsed ?? this.collapsed,
  );

  @override
  Map<String, dynamic> toJson() => {
    'type': 'group',
    'id': id,
    'name': name,
    'memberIds': memberIds,
    'collapsed': collapsed,
  };

  factory SidebarGroupSlot.fromJson(Map<String, dynamic> json) {
    return SidebarGroupSlot(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      memberIds: (json['memberIds'] as List?)?.cast<String>() ?? const [],
      collapsed: json['collapsed'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SidebarGroupSlot &&
          id == other.id &&
          name == other.name &&
          collapsed == other.collapsed &&
          listEquals(memberIds, other.memberIds);

  @override
  int get hashCode =>
      Object.hash(id, name, collapsed, Object.hashAll(memberIds));
}

/// Cómo quedó acomodada UNA sección del sidebar.
///
/// Es una PISTA, no la verdad: el catálogo manda. Un ítem que existe y no
/// figura acá se muestra igual —al final de la sección—, y uno que figura
/// pero ya no existe se descarta. Sin esa regla, una disposición vieja
/// podría esconder un proyecto real, que es la única forma en que esta
/// función podría hacer daño.
class SidebarLayout {
  const SidebarLayout({required this.kind, this.slots = const []});

  final SidebarSectionKind kind;
  final List<SidebarSlot> slots;

  /// La clave del registro: una por sección, y el `id` que
  /// `replaceAllWithPrefix` exige en cada mapa que guarda.
  String get id => kind.name;

  SidebarLayout copyWith({List<SidebarSlot>? slots}) =>
      SidebarLayout(kind: kind, slots: slots ?? this.slots);

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'slots': [for (final slot in slots) slot.toJson()],
  };

  factory SidebarLayout.fromJson(Map<String, dynamic> json) {
    return SidebarLayout(
      kind: SidebarSectionKind.values.byName(json['kind'] as String),
      slots: [
        for (final slot in (json['slots'] as List?) ?? const [])
          SidebarSlot.fromJson((slot as Map).cast<String, dynamic>()),
      ],
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SidebarLayout &&
          kind == other.kind &&
          listEquals(slots, other.slots);

  @override
  int get hashCode => Object.hash(kind, Object.hashAll(slots));
}

class SidebarLayoutState {
  const SidebarLayoutState({
    this.layouts = const {},
    this.openSections = const {},
  });

  final Map<SidebarSectionKind, SidebarLayout> layouts;

  /// Las secciones que el usuario dejó abiertas (`boards:<projectId>`, …).
  /// Lo que no está acá está plegado, que es el default.
  final Set<String> openSections;

  SidebarLayout layoutOf(SidebarSectionKind kind) =>
      layouts[kind] ?? SidebarLayout(kind: kind);

  SidebarLayoutState copyWith({
    Map<SidebarSectionKind, SidebarLayout>? layouts,
    Set<String>? openSections,
  }) => SidebarLayoutState(
    layouts: layouts ?? this.layouts,
    openSections: openSections ?? this.openSections,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SidebarLayoutState &&
          mapEquals(layouts, other.layouts) &&
          setEquals(openSections, other.openSections);

  @override
  int get hashCode => Object.hash(
    Object.hashAll(layouts.entries.map((e) => e.value)),
    Object.hashAllUnordered(openSections),
  );
}
