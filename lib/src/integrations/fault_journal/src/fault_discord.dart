part of '../fault_journal.dart';

/// El webhook al que se reportan las fallas, o vacío para no reportar nada.
///
/// Entra por `--dart-define` y NO vive en el repositorio: un webhook de
/// Discord es una credencial —cualquiera que la tenga escribe en el canal—
/// y en el código quedaría en el historial de git para siempre.
///
/// ```sh
/// flutter build macos --release --dart-define-from-file=keel_secrets.json
/// ```
///
/// Sin la define, [reportToDiscord] no hace nada: una compilación de alguien
/// que no configuró el canal no tiene por qué fallar ni avisar.
const _kDiscordWebhook = String.fromEnvironment('KEEL_DISCORD_WEBHOOK');

/// Con qué nombre forzar el entorno, o vacío para deducirlo.
///
/// Sirve para el caso que el modo de compilación no distingue: una release
/// que se reparte para probar es `prod` para el compilador y `beta` para
/// quien la mira en el canal.
///
/// ```sh
/// flutter build macos --release --dart-define=KEEL_ENV=beta
/// ```
const _kEnvironmentOverride = String.fromEnvironment('KEEL_ENV');

/// En qué entorno pasó: `dev` mientras se desarrolla, `prod` en lo instalado.
///
/// Se deduce del modo de compilación y no de una variable que haya que
/// acordarse de poner: `flutter run` es debug y el DMG que se instala es
/// release. Sin esto, las fallas de la máquina de desarrollo y las de la app
/// que usa alguien caen mezcladas en el mismo canal, que es justo lo que
/// vuelve inútil un canal de errores.
String get _environment => _kEnvironmentOverride.isNotEmpty
    ? _kEnvironmentOverride
    : (kReleaseMode ? 'prod' : 'dev');

/// Cuánto se espera entre dos posts. Discord corta al que le escribe muy
/// seguido, y una falla de layout llega de a ráfagas.
const _kDiscordGap = Duration(seconds: 2);

/// Cuántas fallas pueden estar esperando turno. Más que esto y lo que está
/// pasando no es "hubo un error": es que algo entró en bucle, y vaciarle el
/// bucle al canal no lo cuenta mejor que las primeras veinte.
const _kDiscordQueueCap = 20;

/// Cuánto se le da al post antes de dejarlo ir.
const _kDiscordBudget = Duration(seconds: 10);

/// Topes de Discord. El embed entero no puede pasar de 6000 caracteres, y
/// cada parte tiene el suyo; se recorta acá para que el rechazo no llegue
/// como un 400 que nadie ve.
const _kDiscordTitleCap = 240;
const _kDiscordDetailCap = 1400;
const _kDiscordFieldCap = 1000;

int _discordPending = 0;
Future<void> _discordQueue = Future<void>.value();

/// Manda la falla al canal de Discord.
///
/// Va al lado de [noticeOf] y por la misma puerta: solo las fallas NUEVAS,
/// que es donde `record` ya descartó las repetidas. Una falla que se repite
/// sube su contador en el diario y no vuelve a escribir en el canal.
///
/// **Nada de acá puede usar `Log`.** El diario se alimenta de `Logger.root`,
/// así que un `Log.e` porque el post falló sería una falla nueva, que
/// intentaría postearse, que fallaría igual. Todo lo que se queja acá lo
/// hace por `debugPrint`, que no vuelve a entrar.
Future<void> reportToDiscord(Fault fault) async {
  if (_kDiscordWebhook.isEmpty) return;
  // En tests no. `flutter test` no es una corrida de verdad y el canal no
  // tiene por qué enterarse de un caso que prueba justamente que algo falla.
  if (Platform.environment['FLUTTER_TEST'] == 'true') return;

  if (_discordPending >= _kDiscordQueueCap) return;
  _discordPending++;

  // En fila y de a uno: los posts en paralelo son exactamente lo que Discord
  // cuenta para cortarte.
  _discordQueue = _discordQueue.then((_) async {
    try {
      await _postToDiscord(fault);
      await Future<void>.delayed(_kDiscordGap);
    } finally {
      _discordPending--;
    }
  });

  return _discordQueue;
}

Future<void> _postToDiscord(Fault fault) async {
  try {
    final response = await http
        .post(
          Uri.parse(_kDiscordWebhook),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode(discordPayloadOf(fault)),
        )
        .timeout(_kDiscordBudget);

    // 204 es lo normal; 200 también aparece. Cualquier otra cosa se dice una
    // vez y se sigue: el diario local ya guardó la falla igual.
    if (response.statusCode != 204 && response.statusCode != 200) {
      debugPrint(
        'Discord rechazó el reporte (${response.statusCode}): ${response.body}',
      );
    }
  } catch (error) {
    // Sin red, sin DNS, o el webhook borrado. El reporte es un extra: que no
    // salga no puede costarle nada a la app.
    debugPrint('No se pudo reportar la falla a Discord: $error');
  }
}

/// El embed, armado para leerse de un vistazo en el canal.
///
/// La barra lateral la pinta Discord con `color`, y ese color ES la
/// severidad: rojo oscuro lo crítico, rojo un error, ámbar algo que reventó
/// dibujando. Se distingue sin abrir el mensaje ni leer una palabra.
///
/// El cuerpo va en `description` y no en campos porque `description` acepta
/// markdown de verdad —encabezados, listas, bloques de código— y los campos
/// no. Los campos quedan para los tres datos cortos que sí conviene ver en
/// fila.
/// Público a propósito: es la única parte de esto que se puede probar sin
/// red, y lo que se rompe en un embed —un campo vacío, un color que no
/// corresponde, un tope pasado— se rompe acá.
Map<String, dynamic> discordPayloadOf(Fault fault) => {
  'username': 'Keel-bot',
  'embeds': [
    {
      // Arriba de todo y en ese orden: lo primero que hay que saber de una
      // falla que llega al canal es si le pasó a alguien de verdad.
      'author': {
        'name': '${_environment.toUpperCase()} · ${fault.severity.label}',
      },
      'title': _discordCut(fault.message, _kDiscordTitleCap),
      'color': fault.severity.color,
      'description': _discordBody(fault),
      'timestamp': fault.at.toUtc().toIso8601String(),
      'fields': [
        // Los vacíos se omiten: Discord rechaza el embed entero si un campo
        // viene sin valor.
        if (fault.where.isNotEmpty)
          {
            'name': 'Origen',
            'value': '`${_discordCut(fault.where, _kDiscordFieldCap)}`',
            'inline': true,
          },
        {
          'name': 'Veces',
          'value': fault.count > 1 ? '×${fault.count}' : 'primera',
          'inline': true,
        },
        {'name': 'Máquina', 'value': _discordHost(), 'inline': true},
      ],
      'footer': {'text': 'Keel · diario de fallas · $_environment'},
    },
  ],
};

/// El cuerpo en markdown.
///
/// El stack va en un bloque ```dart porque Discord le pone resaltado y, sobre
/// todo, ancho fijo: un stack con sangría reflowed no se lee.
String _discordBody(Fault fault) {
  final sections = <String>[
    if (fault.context.isNotEmpty) '### Contexto\n${fault.context}',
    if (fault.detail.isNotEmpty)
      '### Detalle\n```dart\n'
          '${_discordCut(fault.detail, _kDiscordDetailCap)}\n```',
  ];
  // Sin detalle ni contexto el título ya lo dijo todo, y un embed con
  // `description` vacío lo rechaza Discord.
  return sections.isEmpty ? '_Sin más detalle._' : sections.join('\n\n');
}

/// De qué máquina salió. Sirve para no mezclar la laptop con el servidor
/// cuando los dos reportan al mismo canal.
String _discordHost() {
  try {
    return '${Platform.localHostname} · ${Platform.operatingSystem}';
  } catch (_) {
    return Platform.operatingSystem;
  }
}

String _discordCut(String text, int cap) {
  final flat = text.trim();
  if (flat.length <= cap) return flat;
  return '${flat.substring(0, cap - 1)}…';
}
