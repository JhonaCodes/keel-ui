import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/core/services/local_database.dart';
import 'package:keel_ui/src/modules/sidebar_layout/model/sidebar_layout.dart';
import 'package:keel_ui/src/modules/sidebar_layout/viewmodel/sidebar_layout_viewmodel.dart';

const _kind = SidebarSectionKind.project;

void main() {
  LocalDatabase.markUnavailable();

  late SidebarLayoutViewModel layout;

  setUp(() async {
    // Uno nuevo por prueba: el singleton acumularía la disposición de la
    // anterior y cada test estaría leyendo la basura del que corrió antes.
    layout = SidebarLayoutViewModel();
    await layout.ready;
  });

  List<String> visible(List<String> presentes) => [
    for (final slot in layout.slotsFor(_kind, presentes))
      switch (slot) {
        SidebarItemSlot(:final itemId) => itemId,
        SidebarGroupSlot(:final name, :final memberIds) =>
          '$name(${memberIds.join(',')})',
      },
  ];

  group('la disposición es una pista, el catálogo es la verdad', () {
    test('sin nada guardado se ve el catálogo tal cual', () {
      expect(visible(['a', 'b', 'c']), ['a', 'b', 'c']);
    });

    test('un ítem nuevo aparece al final', () async {
      await layout.drop(
        _kind,
        draggedId: 'c',
        targetId: 'a',
        spot: SidebarDropSpot.before,
        presentIds: ['a', 'b', 'c'],
      );

      expect(visible(['a', 'b', 'c', 'd']), ['c', 'a', 'b', 'd']);
    });

    test('un ítem borrado no rompe ni esconde al resto', () async {
      await layout.drop(
        _kind,
        draggedId: 'b',
        targetId: 'a',
        spot: SidebarDropSpot.into,
        presentIds: ['a', 'b', 'c'],
      );

      expect(visible(['a', 'c']), ['Grupo(a)', 'c']);
    });

    test('un grupo que se quedó sin miembros presentes no se dibuja', () async {
      await layout.drop(
        _kind,
        draggedId: 'b',
        targetId: 'a',
        spot: SidebarDropSpot.into,
        presentIds: ['a', 'b', 'c'],
      );

      expect(visible(['c']), ['c']);
    });
  });

  group('agrupar', () {
    test('soltar en el medio de otro crea el grupo con los dos', () async {
      await layout.drop(
        _kind,
        draggedId: 'b',
        targetId: 'a',
        spot: SidebarDropSpot.into,
        presentIds: ['a', 'b', 'c'],
      );

      expect(visible(['a', 'b', 'c']), ['Grupo(a,b)', 'c']);
      expect(layout.groupOf(_kind, 'b')?.memberIds, ['a', 'b']);
    });

    test('soltar sobre un grupo lo suma al final', () async {
      final presentes = ['a', 'b', 'c'];
      await layout.drop(
        _kind,
        draggedId: 'b',
        targetId: 'a',
        spot: SidebarDropSpot.into,
        presentIds: presentes,
      );
      final grupo = layout.groupOf(_kind, 'a')!;

      await layout.drop(
        _kind,
        draggedId: 'c',
        targetId: grupo.id,
        spot: SidebarDropSpot.into,
        presentIds: presentes,
      );

      expect(visible(presentes), ['Grupo(a,b,c)']);
    });

    test('un grupo no entra en otro grupo', () async {
      final presentes = ['a', 'b', 'c', 'd'];
      await layout.drop(
        _kind,
        draggedId: 'b',
        targetId: 'a',
        spot: SidebarDropSpot.into,
        presentIds: presentes,
      );
      await layout.drop(
        _kind,
        draggedId: 'd',
        targetId: 'c',
        spot: SidebarDropSpot.into,
        presentIds: presentes,
      );
      final primero = layout.groupOf(_kind, 'a')!;
      final segundo = layout.groupOf(_kind, 'c')!;

      await layout.drop(
        _kind,
        draggedId: segundo.id,
        targetId: primero.id,
        spot: SidebarDropSpot.into,
        presentIds: presentes,
      );

      // Quedó ordenado detrás, no adentro.
      expect(visible(presentes), ['Grupo(a,b)', 'Grupo(c,d)']);
    });

    test('soltar algo sobre sí mismo no hace nada', () async {
      await layout.drop(
        _kind,
        draggedId: 'a',
        targetId: 'a',
        spot: SidebarDropSpot.into,
        presentIds: ['a', 'b'],
      );

      expect(visible(['a', 'b']), ['a', 'b']);
    });
  });

  group('sacar de un grupo', () {
    test('el encabezado lo devuelve a la raíz', () async {
      final presentes = ['a', 'b', 'c'];
      await layout.drop(
        _kind,
        draggedId: 'b',
        targetId: 'a',
        spot: SidebarDropSpot.into,
        presentIds: presentes,
      );

      await layout.moveToRoot(_kind, 'b', presentIds: presentes);

      // El grupo era de dos: sacando uno ya no agrupa nada y se disuelve.
      expect(visible(presentes), ['a', 'c', 'b']);
      expect(layout.groupOf(_kind, 'b'), isNull);
    });

    test('un grupo que baja a un solo miembro se disuelve', () async {
      final presentes = ['a', 'b'];
      await layout.drop(
        _kind,
        draggedId: 'b',
        targetId: 'a',
        spot: SidebarDropSpot.into,
        presentIds: presentes,
      );

      await layout.moveToRoot(_kind, 'b', presentIds: presentes);

      expect(visible(presentes), ['a', 'b']);
      expect(layout.groupOf(_kind, 'a'), isNull);
    });

    test('deshacer el grupo deja a los miembros en su lugar', () async {
      final presentes = ['a', 'b', 'c'];
      await layout.drop(
        _kind,
        draggedId: 'b',
        targetId: 'a',
        spot: SidebarDropSpot.into,
        presentIds: presentes,
      );
      final grupo = layout.groupOf(_kind, 'a')!;

      await layout.ungroup(_kind, grupo.id, presentIds: presentes);

      expect(visible(presentes), ['a', 'b', 'c']);
    });
  });

  group('ordenar', () {
    test('soltar arriba inserta antes', () async {
      await layout.drop(
        _kind,
        draggedId: 'c',
        targetId: 'a',
        spot: SidebarDropSpot.before,
        presentIds: ['a', 'b', 'c'],
      );

      expect(visible(['a', 'b', 'c']), ['c', 'a', 'b']);
    });

    test('soltar abajo inserta después', () async {
      await layout.drop(
        _kind,
        draggedId: 'a',
        targetId: 'b',
        spot: SidebarDropSpot.after,
        presentIds: ['a', 'b', 'c'],
      );

      expect(visible(['a', 'b', 'c']), ['b', 'a', 'c']);
    });

    test('ordenar contra un miembro ordena adentro del grupo', () async {
      final presentes = ['a', 'b', 'c'];
      await layout.drop(
        _kind,
        draggedId: 'b',
        targetId: 'a',
        spot: SidebarDropSpot.into,
        presentIds: presentes,
      );

      await layout.drop(
        _kind,
        draggedId: 'c',
        targetId: 'a',
        spot: SidebarDropSpot.before,
        presentIds: presentes,
      );

      expect(visible(presentes), ['Grupo(c,a,b)']);
    });
  });

  group('el nombre y el pliegue', () {
    Future<SidebarGroupSlot> unGrupo(List<String> presentes) async {
      await layout.drop(
        _kind,
        draggedId: presentes[1],
        targetId: presentes[0],
        spot: SidebarDropSpot.into,
        presentIds: presentes,
      );
      return layout.groupOf(_kind, presentes[0])!;
    }

    test('renombrar lo deja escrito', () async {
      final presentes = ['a', 'b'];
      final grupo = await unGrupo(presentes);

      expect(
        layout.renameGroup(_kind, grupo.id, 'Clientes', presentIds: presentes),
        isNull,
      );
      expect(visible(presentes), ['Clientes(a,b)']);
    });

    test('un nombre vacío se rechaza y no cambia nada', () async {
      final presentes = ['a', 'b'];
      final grupo = await unGrupo(presentes);

      expect(
        layout.renameGroup(_kind, grupo.id, '   ', presentIds: presentes),
        isNotNull,
      );
      expect(visible(presentes), ['Grupo(a,b)']);
    });

    test('el pliegue se guarda', () async {
      final presentes = ['a', 'b'];
      final grupo = await unGrupo(presentes);

      await layout.toggleGroup(_kind, grupo.id, presentIds: presentes);

      expect(layout.groupOf(_kind, 'a')!.collapsed, isTrue);
    });
  });

  group('lo que se guarda', () {
    test('cada sección lleva su id, que es lo que la base exige', () {
      const guardado = SidebarLayout(
        kind: SidebarSectionKind.agent,
        slots: [SidebarItemSlot('a')],
      );

      expect(guardado.toJson()['id'], 'agent');
      expect(SidebarLayout.fromJson(guardado.toJson()), guardado);
    });

    test('un grupo sobrevive el viaje entero', () {
      const grupo = SidebarGroupSlot(
        id: 'g1',
        name: 'Clientes',
        memberIds: ['a', 'b'],
        collapsed: true,
      );

      expect(SidebarSlot.fromJson(grupo.toJson()), grupo);
    });

    test('las secciones no se mezclan entre sí', () async {
      await layout.drop(
        _kind,
        draggedId: 'b',
        targetId: 'a',
        spot: SidebarDropSpot.into,
        presentIds: ['a', 'b'],
      );

      expect(layout.slotsFor(SidebarSectionKind.agent, ['a', 'b']), [
        const SidebarItemSlot('a'),
        const SidebarItemSlot('b'),
      ]);
    });
  });
}
