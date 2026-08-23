import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:keel_ui/src/integrations/fault_journal/fault_journal.dart';

/// Lo que se prueba es el embed, no la red.
///
/// Un embed mal armado no falla acá: Discord lo rechaza con un 400 que sale
/// por `debugPrint` y que nadie mira. Las reglas que lo rechazan son pocas y
/// fijas —ningún campo sin valor, `description` no vacía, los topes— así que
/// se fijan acá y no en el canal.
void main() {
  Fault faultWith({
    FaultSeverity severity = FaultSeverity.error,
    String message = 'Algo se rompió',
    String where = 'projects_viewmodel.dart:984',
    String detail = 'StateError: Bad state: no element',
    String context = 'proyecto «keel-ui»',
    int count = 1,
  }) {
    final at = DateTime.utc(2026, 8, 23, 21, 55);
    return Fault(
      id: 'f-1',
      at: at,
      lastAt: at,
      count: count,
      message: message,
      where: where,
      detail: detail,
      context: context,
      severity: severity,
    );
  }

  Map<String, dynamic> embedOf(Fault fault) =>
      (discordPayloadOf(fault)['embeds'] as List).first
          as Map<String, dynamic>;

  group('discordPayloadOf', () {
    test('la barra lateral es el color de la severidad', () {
      // Es LO que se lee de un vistazo en el canal: si el color no sigue a la
      // severidad, el mensaje miente antes de abrirse.
      for (final severity in FaultSeverity.values) {
        expect(
          embedOf(faultWith(severity: severity))['color'],
          severity.color,
          reason: 'la severidad ${severity.name} debe pintar su propio color',
        );
      }
      // Y no son todos el mismo color.
      expect(
        FaultSeverity.values.map((severity) => severity.color).toSet(),
        hasLength(FaultSeverity.values.length),
      );
    });

    test('ningún campo va sin valor: Discord rechaza el embed entero', () {
      final embed = embedOf(faultWith(where: '', context: '', detail: ''));
      final fields = (embed['fields'] as List).cast<Map<String, dynamic>>();
      expect(fields, isNotEmpty);
      for (final field in fields) {
        expect(field['name'], isNotEmpty);
        expect(field['value'], isNotEmpty);
      }
    });

    test('sin detalle ni contexto la descripción no queda vacía', () {
      final embed = embedOf(faultWith(context: '', detail: ''));
      expect(embed['description'], isNotEmpty);
    });

    test('el origen no entra como campo cuando no se supo', () {
      final fields = (embedOf(faultWith(where: ''))['fields'] as List)
          .cast<Map<String, dynamic>>();
      expect(fields.map((field) => field['name']), isNot(contains('Origen')));
    });

    test('un stack enorme se recorta y el embed sigue bajo el tope', () {
      // El tope duro de Discord es 6000 caracteres contando todo el embed.
      final embed = embedOf(faultWith(detail: 'x' * 40000));
      expect(jsonEncode(embed).length, lessThan(6000));
      expect(embed['description'], contains('…'));
    });

    test('las repeticiones se cuentan en el mensaje', () {
      final fields = (embedOf(faultWith(count: 7))['fields'] as List)
          .cast<Map<String, dynamic>>();
      final veces = fields.firstWhere((field) => field['name'] == 'Veces');
      expect(veces['value'], '×7');
    });

    test('dice en qué entorno pasó, arriba de todo', () {
      // Bajo `flutter test` no hay release, así que acá siempre es dev. Lo
      // que se fija es que el dato ESTÉ y esté donde se lee primero: una
      // falla de la máquina de desarrollo mezclada con una de producción, sin
      // forma de distinguirlas, es lo que vuelve inútil el canal.
      final embed = embedOf(faultWith(severity: FaultSeverity.critica));
      final author = (embed['author'] as Map)['name'] as String;
      expect(author, startsWith('DEV'));
      expect(author, contains('Crítica'));
      expect((embed['footer'] as Map)['text'], contains('dev'));
    });

    test('el timestamp va en ISO-8601 UTC, que es lo que Discord entiende', () {
      final embed = embedOf(faultWith());
      expect(DateTime.parse(embed['timestamp'] as String).isUtc, isTrue);
    });
  });

  // Escribe los tres ejemplos a disco para poder mandarlos al canal de verdad
  // y mirar cómo se ven. No es una aserción: es la muestra que se revisa a
  // ojo, generada por el MISMO código que corre en producción.
  test('deja los ejemplos listos para inspección visual', () async {
    final salida = Platform.environment['KEEL_DISCORD_SAMPLE_DIR'];
    if (salida == null) return;
    for (final severity in FaultSeverity.values) {
      final fault = faultWith(
        severity: severity,
        message: switch (severity) {
          FaultSeverity.critica =>
            'No se pudo abrir la base local: LMDB devolvió MDB_PANIC',
          FaultSeverity.error =>
            'Bad state: No element · ProjectsViewModel._pick',
          FaultSeverity.interfaz =>
            'RenderFlex overflowed by 42 pixels on the right',
        },
        detail: switch (severity) {
          FaultSeverity.critica =>
            'LocalDatabaseException: MDB_PANIC: Update of meta page failed\n'
                '#0  LocalDatabase._load (local_database.dart:96:7)\n'
                '#1  LocalDatabase._ensureIndex (local_database.dart:84:12)',
          FaultSeverity.error =>
            'StateError: Bad state: No element\n'
                '#0  Iterable.first (dart:core/iterable.dart:588:5)\n'
                '#1  ProjectsViewModel._pick (projects_viewmodel.dart:984:12)\n'
                '#2  ProjectsViewModel.openSession '
                '(projects_viewmodel.dart:1021:9)',
          FaultSeverity.interfaz =>
            'A RenderFlex overflowed by 42 pixels on the right.\n'
                'The relevant error-causing widget was:\n'
                '  Row SessionHeader.build (session_header.dart:64:14)',
        },
      );
      File('$salida/${severity.name}.json')
          .writeAsStringSync(jsonEncode(discordPayloadOf(fault)));
    }
  });
}
