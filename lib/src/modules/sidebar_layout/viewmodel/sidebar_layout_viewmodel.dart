import 'dart:async';

import 'package:logger_rs/logger_rs.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/src/modules/sidebar_layout/model/sidebar_layout.dart';
import 'package:keel_ui/src/modules/sidebar_layout/repository/sidebar_layout_repository.dart';
import 'package:keel_ui/src/shared/shared.dart';

/// Dónde se soltó algo sobre una fila.
///
/// Un solo gesto —arrastrar— tiene que poder hacer dos cosas distintas, y la
/// zona de la fila es lo que las separa sin ambigüedad: por los bordes se
/// ordena, por el medio se agrupa. Es lo mismo que hace cualquier gestor de
/// archivos, y por eso no hay que explicarlo.
enum SidebarDropSpot { before, after, into }

/// El nombre con el que nace un grupo. Se renombra con doble click, igual
/// que un proyecto o una sesión.
const kDefaultSidebarGroupName = 'Grupo';

class SidebarLayoutViewModel extends ViewModel<SidebarLayoutState> {
  SidebarLayoutViewModel() : super(const SidebarLayoutState());

  final _repository = SidebarLayoutRepository();

  Future<void>? _ready;
  Future<void> get ready => _ready ??= _load();

  @override
  void init() {
    if (_ready == null) updateSilently(const SidebarLayoutState());
    unawaited(ready);
  }

  Future<void> _load() async {
    try {
      final layouts = await _repository.load();
      final open = await _repository.loadOpenSections();
      updateState(
        data.copyWith(
          layouts: {for (final layout in layouts) layout.kind: layout},
          openSections: open,
        ),
      );
    } catch (error) {
      Log.e('No pude leer cómo estaba acomodado el sidebar', error: error);
    }
  }

  /// Lo que hay que dibujar en [kind], en orden.
  ///
  /// [presentIds] es el catálogo — la verdad. Lo guardado es una pista: lo
  /// que existe y no figura aparece igual, al final; lo que figura y ya no
  /// existe se descarta. Esta función NO escribe: reconciliar mientras se
  /// dibuja tiene que ser barato y no puede disparar un guardado por frame.
  List<SidebarSlot> slotsFor(
    SidebarSectionKind kind,
    Iterable<String> presentIds,
  ) {
    final present = presentIds.toList();
    final remaining = present.toSet();
    final slots = <SidebarSlot>[];

    for (final slot in data.layoutOf(kind).slots) {
      switch (slot) {
        case SidebarItemSlot(:final itemId):
          if (remaining.remove(itemId)) slots.add(slot);
        case SidebarGroupSlot(:final memberIds):
          final members = [
            for (final id in memberIds)
              if (remaining.remove(id)) id,
          ];
          // Un grupo que se quedó sin nada que mostrar no se dibuja. No se
          // borra acá —esto no escribe—: lo limpia la próxima operación.
          if (members.isNotEmpty) {
            slots.add(slot.copyWith(memberIds: members));
          }
      }
    }

    // Lo nuevo va al final y en el orden del catálogo, que es el único que
    // esta capa conoce.
    for (final id in present) {
      if (remaining.contains(id)) slots.add(SidebarItemSlot(id));
    }
    return slots;
  }

  /// El grupo al que pertenece [itemId], si pertenece a alguno.
  SidebarGroupSlot? groupOf(SidebarSectionKind kind, String itemId) {
    for (final slot in data.layoutOf(kind).slots) {
      if (slot is SidebarGroupSlot && slot.memberIds.contains(itemId)) {
        return slot;
      }
    }
    return null;
  }

  /// Suelta [draggedId] sobre [targetId].
  ///
  /// [draggedId] y [targetId] pueden ser un ítem o un grupo — el sidebar deja
  /// mover las dos cosas. Soltar algo sobre sí mismo, o un grupo dentro de
  /// otro, no hace nada: son las dos formas de pedir lo imposible.
  Future<void> drop(
    SidebarSectionKind kind, {
    required String draggedId,
    required String targetId,
    required SidebarDropSpot spot,
    required Iterable<String> presentIds,
  }) async {
    if (draggedId == targetId) return;
    final slots = [...slotsFor(kind, presentIds)];
    final dragged = _takeOut(slots, draggedId);
    if (dragged == null) return;

    if (spot == SidebarDropSpot.into) {
      // Un grupo no entra en ningún lado: se ordena, no se anida.
      if (dragged is! SidebarItemSlot) {
        _insertRelative(slots, dragged, targetId, SidebarDropSpot.after);
      } else {
        _insertInto(slots, dragged.itemId, targetId);
      }
    } else {
      _insertRelative(slots, dragged, targetId, spot);
    }

    await _store(kind, slots);
  }

  /// Saca [itemId] de su grupo y lo deja suelto al final de la sección. Es lo
  /// que pasa al soltarlo sobre el encabezado.
  Future<void> moveToRoot(
    SidebarSectionKind kind,
    String itemId, {
    required Iterable<String> presentIds,
  }) async {
    if (groupOf(kind, itemId) == null) return;
    final slots = [...slotsFor(kind, presentIds)];
    final taken = _takeOut(slots, itemId);
    if (taken == null) return;
    slots.add(taken);
    await _store(kind, slots);
  }

  /// Deshace el grupo: sus miembros quedan sueltos, en el mismo lugar y en el
  /// mismo orden en que estaban adentro.
  Future<void> ungroup(
    SidebarSectionKind kind,
    String groupId, {
    required Iterable<String> presentIds,
  }) async {
    final slots = [...slotsFor(kind, presentIds)];
    final index = slots.indexWhere(
      (slot) => slot is SidebarGroupSlot && slot.id == groupId,
    );
    if (index < 0) return;
    final group = slots.removeAt(index) as SidebarGroupSlot;
    slots.insertAll(index, [
      for (final id in group.memberIds) SidebarItemSlot(id),
    ]);
    await _store(kind, slots);
  }

  /// Devuelve el error en castellano, o null. Misma convención que el resto
  /// de los CRUD de la app, así se enchufa directo en [InlineRenameField].
  String? renameGroup(
    SidebarSectionKind kind,
    String groupId,
    String name, {
    required Iterable<String> presentIds,
  }) {
    final clean = name.trim();
    if (clean.isEmpty) return 'El grupo necesita un nombre.';
    if (clean.length > 24) return 'Máximo 24 caracteres.';

    final slots = [
      for (final slot in slotsFor(kind, presentIds))
        if (slot is SidebarGroupSlot && slot.id == groupId)
          slot.copyWith(name: clean)
        else
          slot,
    ];
    unawaited(_store(kind, slots));
    return null;
  }

  Future<void> toggleGroup(
    SidebarSectionKind kind,
    String groupId, {
    required Iterable<String> presentIds,
  }) async {
    final slots = [
      for (final slot in slotsFor(kind, presentIds))
        if (slot is SidebarGroupSlot && slot.id == groupId)
          slot.copyWith(collapsed: !slot.collapsed)
        else
          slot,
    ];
    await _store(kind, slots);
  }

  // ── mecánica ────────────────────────────────────────────────────────

  /// Saca [id] de donde esté —raíz o adentro de un grupo— y lo devuelve.
  ///
  /// Un grupo que queda con menos de dos miembros desaparece acá mismo, y el
  /// que sobra vuelve a la raíz EN EL LUGAR del grupo. Un grupo nace de
  /// juntar dos cosas; con una sola adentro ya no agrupa nada, y quedaría
  /// como el resto de una mudanza en vez de como una decisión.
  static SidebarSlot? _takeOut(List<SidebarSlot> slots, String id) {
    for (var i = 0; i < slots.length; i++) {
      final slot = slots[i];
      if (slot is SidebarItemSlot && slot.itemId == id) {
        return slots.removeAt(i);
      }
      if (slot is SidebarGroupSlot) {
        if (slot.id == id) return slots.removeAt(i);
        if (slot.memberIds.contains(id)) {
          final members = [
            for (final member in slot.memberIds)
              if (member != id) member,
          ];
          if (members.isEmpty) {
            slots.removeAt(i);
          } else if (members.length == 1) {
            slots[i] = SidebarItemSlot(members.single);
          } else {
            slots[i] = slot.copyWith(memberIds: members);
          }
          return SidebarItemSlot(id);
        }
      }
    }
    return null;
  }

  /// Mete [itemId] adentro de [targetId]: si el destino es un grupo, al final
  /// de sus miembros; si es un ítem suelto, nace un grupo con los dos.
  static void _insertInto(
    List<SidebarSlot> slots,
    String itemId,
    String targetId,
  ) {
    for (var i = 0; i < slots.length; i++) {
      final slot = slots[i];
      if (slot is SidebarGroupSlot && slot.id == targetId) {
        slots[i] = slot.copyWith(memberIds: [...slot.memberIds, itemId]);
        return;
      }
      if (slot is SidebarItemSlot && slot.itemId == targetId) {
        slots[i] = SidebarGroupSlot(
          id: generateUuidV4(),
          name: kDefaultSidebarGroupName,
          memberIds: [targetId, itemId],
        );
        return;
      }
      // Soltar sobre un miembro de un grupo es soltar sobre el grupo: lo que
      // el usuario ve es que apuntó adentro.
      if (slot is SidebarGroupSlot && slot.memberIds.contains(targetId)) {
        final members = [...slot.memberIds];
        members.insert(members.indexOf(targetId) + 1, itemId);
        slots[i] = slot.copyWith(memberIds: members);
        return;
      }
    }
    slots.add(SidebarItemSlot(itemId));
  }

  static void _insertRelative(
    List<SidebarSlot> slots,
    SidebarSlot dragged,
    String targetId,
    SidebarDropSpot spot,
  ) {
    for (var i = 0; i < slots.length; i++) {
      final slot = slots[i];
      final isTarget =
          (slot is SidebarItemSlot && slot.itemId == targetId) ||
          (slot is SidebarGroupSlot && slot.id == targetId);
      if (isTarget) {
        slots.insert(spot == SidebarDropSpot.before ? i : i + 1, dragged);
        return;
      }
      // Ordenar contra un miembro de un grupo ordena ADENTRO del grupo, que
      // es lo que se está viendo.
      if (slot is SidebarGroupSlot &&
          slot.memberIds.contains(targetId) &&
          dragged is SidebarItemSlot) {
        final members = [...slot.memberIds];
        final at = members.indexOf(targetId);
        members.insert(
          spot == SidebarDropSpot.before ? at : at + 1,
          dragged.itemId,
        );
        slots[i] = slot.copyWith(memberIds: members);
        return;
      }
    }
    slots.add(dragged);
  }

  /// ¿Está abierta la sección [key]?
  ///
  /// Plegada es el default. Antes esto era un `bool` en el `State` del widget
  /// que arrancaba en `true` y no se guardaba: Tableros y Sesiones se abrían
  /// solos al entrar a un proyecto, y encima era uno solo para toda la barra,
  /// así que cambiar de proyecto te arrastraba el del anterior.
  bool isSectionOpen(String key) => data.openSections.contains(key);

  Future<void> toggleSection(String key) async {
    final open = {...data.openSections};
    if (!open.remove(key)) open.add(key);
    updateState(data.copyWith(openSections: open));
    try {
      await _repository.saveOpenSections(open);
    } catch (error) {
      Log.e('No pude guardar qué secciones quedaron abiertas', error: error);
    }
  }

  Future<void> _store(SidebarSectionKind kind, List<SidebarSlot> slots) async {
    final layout = SidebarLayout(kind: kind, slots: slots);
    updateState(data.copyWith(layouts: {...data.layouts, kind: layout}));
    try {
      await _repository.save(data.layouts.values.toList());
    } catch (error) {
      Log.e('No pude guardar cómo quedó el sidebar', error: error);
    }
  }
}

mixin SidebarLayoutService {
  static final ReactiveNotifier<SidebarLayoutViewModel> instance =
      ReactiveNotifier<SidebarLayoutViewModel>(() => SidebarLayoutViewModel());
}
