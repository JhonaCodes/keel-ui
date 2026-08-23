import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/modules/agent_profiles/model/agent_profile.dart';
import 'package:keel_ui/src/modules/agents/model/chat_message.dart';
import 'package:keel_ui/src/modules/projects/model/session.dart';
import 'package:keel_ui/src/modules/projects/model/session_map.dart';
import 'package:keel_ui/src/modules/projects/model/session_map_layout.dart';
import 'package:keel_ui/src/modules/projects/ui/widget/map_node_card.dart';
import 'package:keel_ui/src/modules/workflows/model/workflow.dart';

final _epoch = DateTime(2026, 8, 23);

AgentProfile _member(String name) => AgentProfile(
  id: name,
  name: name,
  role: name,
  systemPrompt: '',
  model: 'sonnet',
  effort: 'normal',
  createdAt: _epoch,
);

ChatMessage _said(String author, String text, {int? step, String? consultOf}) =>
    ChatMessage(
      role: ChatRole.assistant,
      text: text,
      timestamp: _epoch,
      authorProfileId: author,
      stepIndex: step,
      consultOfProfileId: consultOf,
    );

const _handles = [
  'i18n-contexto',
  'i18n-analista',
  'i18n-traductor',
  'i18n-auditor',
  'i18n-integrador',
];

/// El workflow del reporte: seis pasos, uno por rol.
SessionMap _mapOf(List<ChatMessage> messages) => SessionMap.from(
  session: Session(
    id: 's',
    title: 's',
    createdAt: _epoch,
    messages: messages,
    currentStepIndex: 5,
  ),
  members: [for (final handle in _handles) _member(handle)],
  workflow: Workflow(
    id: 'wf',
    name: 'i18n',
    whenToApply: '',
    createdAt: _epoch,
    steps: [
      for (final (title, role) in [
        ('Contexto', 'i18n-contexto'),
        ('Análisis', 'i18n-analista'),
        ('Traducción', 'i18n-traductor'),
        ('Auditoría', 'i18n-auditor'),
        ('Integración', 'i18n-integrador'),
        ('Cierre', 'i18n-traductor'),
      ])
        WorkflowStep(
          id: title,
          title: title,
          role: role,
          instruction: 'La instrucción de $title.',
        ),
    ],
  ),
);

MapLayout _layoutOf(List<ChatMessage> messages) =>
    MapLayout.of(_mapOf(messages));

/// Las dos consultas del reporte: los dos le contestan al MISMO nodo, así que
/// sus dos líneas se cruzarían si compartieran altura.
final _dosAlMismo = [
  _said('i18n-contexto', 'Listo.', step: 0),
  _said('i18n-analista', 'Listo.', step: 1),
  _said('i18n-traductor', 'Bloqueado. @i18n-auditor ¿cerraste?', step: 2),
  _said(
    'i18n-auditor',
    'No había nada que auditar.',
    consultOf: 'i18n-traductor',
  ),
  _said('i18n-traductor', 'Gracias. @i18n-integrador ¿la tabla?', step: 2),
  _said('i18n-integrador', 'Quedó como estaba.', consultOf: 'i18n-traductor'),
];

/// Puntos a lo largo de un camino, para mirar por dónde pasa.
List<Offset> _samples(Path path, {int count = 40}) {
  final metric = path.computeMetrics().first;
  return [
    for (var i = 0; i <= count; i++)
      metric.getTangentForOffset(metric.length * i / count)!.position,
  ];
}

void main() {
  group('cada réplica en su corredor', () {
    test('dos que se cruzarían caen en corredores distintos', () {
      final layout = _layoutOf(_dosAlMismo);
      final rects = layout.calloutRects.values.toList();

      expect(rects, hasLength(2));
      expect(rects.first.overlaps(rects.last), isFalse);
      expect(rects.first.top, isNot(rects.last.top));
    });

    test('sus líneas tampoco comparten altura', () {
      final map = _mapOf(_dosAlMismo);
      final layout = MapLayout.of(map);
      final idas = [
        for (final edge in map.edges)
          if (edge.kind == MapEdgeKind.back) layout.routeOf(edge)!,
      ];
      expect(idas, hasLength(2));

      // El tramo horizontal de cada una: la altura donde más tiempo pasa.
      double corridorOf(Path path) => _samples(
        path,
      ).map((point) => point.dy).reduce((a, b) => a < b ? a : b);

      expect(corridorOf(idas.first), isNot(corridorOf(idas.last)));
    });

    test('dos lejanas comparten corredor: no se gasta una fila de más', () {
      // El primer paso le pregunta al segundo, y el quinto al cuarto. Los
      // tramos no se tocan, así que entran en la misma fila.
      final layout = _layoutOf([
        _said('i18n-contexto', 'Arranco. @i18n-analista ¿el formato?', step: 0),
        _said('i18n-analista', 'JSON plano.', consultOf: 'i18n-contexto'),
        _said('i18n-analista', 'Listo.', step: 1),
        _said('i18n-traductor', 'Listo.', step: 2),
        _said('i18n-auditor', 'Listo.', step: 3),
        _said('i18n-integrador', 'Cierro. @i18n-auditor ¿la tabla?', step: 4),
        _said('i18n-auditor', 'Sin cambios.', consultOf: 'i18n-integrador'),
      ]);

      final tops = layout.calloutRects.values.map((rect) => rect.top).toSet();
      expect(layout.calloutRects, hasLength(2));
      expect(tops, hasLength(1));
    });
  });

  group('los puertos del borde', () {
    test('dos consultas al mismo nodo no salen del mismo punto', () {
      final map = _mapOf(_dosAlMismo);
      final layout = MapLayout.of(map);
      final traductor = map.nodes.firstWhere(
        (node) => node.label == 'i18n-traductor' && node.stepIndex == 2,
      );

      // Las dos idas nacen en el traductor: si salieran del centro las dos,
      // se superpondrían desde el arranque.
      final salidas = [
        for (final edge in map.edges)
          if (edge.kind == MapEdgeKind.back && edge.fromId == traductor.id)
            _samples(layout.routeOf(edge)!).first.dx,
      ];
      expect(salidas, hasLength(2));
      expect(salidas.first, isNot(salidas.last));

      // Y las dos siguen naciendo DENTRO del nodo.
      final rect = layout.rectOf(traductor.id)!;
      for (final x in salidas) {
        expect(x, greaterThan(rect.left));
        expect(x, lessThan(rect.right));
      }
    });
  });

  group('el camino es recto', () {
    test('vertical en las puntas y horizontal en el medio', () {
      final map = _mapOf(_dosAlMismo);
      final layout = MapLayout.of(map);
      final ida = layout.routeOf(
        map.edges.firstWhere((edge) => edge.kind == MapEdgeKind.back),
      )!;
      final points = _samples(ida, count: 60);

      // Arranca subiendo derecho…
      expect((points[1].dx - points.first.dx).abs(), lessThan(1));
      // …y termina bajando derecho.
      expect(
        (points.last.dx - points[points.length - 2].dx).abs(),
        lessThan(1),
      );
      // En el medio corre plano: el corredor.
      final medio = points.sublist(20, 40).map((point) => point.dy);
      expect(
        medio.reduce((a, b) => a > b ? a : b) -
            medio.reduce((a, b) => a < b ? a : b),
        lessThan(1),
      );
    });

    test('el corredor va debajo de su cuadro y arriba de los nodos', () {
      final map = _mapOf(_dosAlMismo);
      final layout = MapLayout.of(map);
      final callout = layout.calloutRects.values.first;
      final ida = layout.routeOf(
        map.edges.firstWhere((edge) => edge.kind == MapEdgeKind.back),
      )!;
      final corridor = _samples(
        ida,
      ).map((point) => point.dy).reduce((a, b) => a < b ? a : b);

      expect(corridor, greaterThan(callout.bottom));
      expect(corridor, lessThan(layout.rowY));
    });
  });

  group('la banda de arriba', () {
    test('crece con las filas y empuja los nodos', () {
      final sinReplicas = _layoutOf([
        _said('i18n-contexto', 'Listo.', step: 0),
      ]);
      final conReplicas = _layoutOf(_dosAlMismo);

      expect(conReplicas.rowY, greaterThan(sinReplicas.rowY));
      expect(conReplicas.guideTopY, lessThan(conReplicas.guideRowY));
      expect(conReplicas.guideRowY, lessThan(conReplicas.rowY));
    });

    test('sin consultas vuelve a su alto mínimo', () {
      final layout = _layoutOf([_said('i18n-contexto', 'Listo.', step: 0)]);
      expect(layout.calloutRects, isEmpty);
      expect(layout.guideRowY - layout.guideTopY, 74);
    });
  });

  group('encuadrar mira lo dibujado', () {
    test('la caja del contenido es más chica que el lienzo', () {
      final layout = _layoutOf([_said('i18n-contexto', 'Listo.', step: 0)]);

      // El lienzo tiene aire alrededor para poder arrastrar más allá del
      // último nodo; encuadrar ese aire dejaba el mapa chiquito en el medio
      // de la nada, que es lo que se veía.
      expect(layout.contentBounds.height, lessThan(layout.size.height));
      expect(layout.contentBounds.top, greaterThan(0));
    });
  });

  group('el aire entre columnas', () {
    test('alcanza para que dos cuadros de «resolvió» no se toquen', () {
      // Con la columna en 204 quedaban 8 puntos y seis pasos seguidos se
      // leían como una tira continua.
      final separacion =
          MapLayout.nodeWidth + MapLayout.columnGap - MapLayout.resolutionWidth;
      expect(separacion, greaterThanOrEqualTo(24));
    });
  });

  group('las dos letras de un handle', () {
    test('salen del último tramo, no del primero', () {
      // Una familia con prefijo común dejaba a todos en «i1».
      expect(initialsOf('i18n-analista'), 'an');
      expect(initialsOf('i18n-auditor'), 'au');
      expect(initialsOf('i18n-traductor'), 'tr');
      expect(initialsOf('i18n-integrador'), 'in');
    });

    test('un nombre de una sola palabra usa sus dos primeras', () {
      expect(initialsOf('arquitecto'), 'ar');
      expect(initialsOf('Rn'), 'rn');
    });

    test('nada raro rompe', () {
      expect(initialsOf(''), '··');
      expect(initialsOf('x'), 'x·');
      expect(initialsOf('---'), '··');
    });
  });
}
