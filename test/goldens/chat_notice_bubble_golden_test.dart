import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/l10n/generated/app_localizations.dart';
import 'package:keel_ui/src/core/services/local_database.dart';
import 'package:keel_ui/src/core/ui/app_theme.dart';
import 'package:keel_ui/src/modules/agents/model/chat_message.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/chat_notice_bubble.dart';

/// Cómo se ve un informe largo dentro de una nota del hilo.
///
/// El golden existe por una razón concreta: el diseño anterior sólo se veía
/// mal cuando el texto era LARGO —un muro ámbar sobre ámbar, sin viñetas y
/// sin título— y ninguna aserción de widget captura eso. Acá se mira.
final _productFont = File('/System/Library/Fonts/Supplemental/Arial.ttf');
final _pubCache =
    Platform.environment['PUB_CACHE'] ??
    '${Platform.environment['HOME']}/.pub-cache';
final _materialIconsFont = File(
  '$_pubCache/hosted/pub.dev/provider-6.1.2/'
  'extension/devtools/build/assets/fonts/MaterialIcons-Regular.otf',
);

const _report = '''
**Caso bloqueado** en «Implementar la feature»: el nodo cerró con evidencia
pero el checklist quedó incompleto.

### Ítem 1 (authorize) — PARCIAL

- `authorize.rs`: 3 Actions nuevas (`UpdateMenuAvailability`, `ViewTerminals`,
  `ManageTerminals`), y helper `authorize_or_response()` para que los handlers
  no repitan la traducción a envelope.
- `orders`: 4 handlers con `authorize()`. En el service saqué la mitad
  merchant-scope y conservé la de roles.
- `terminals`: 5 guards. `get_current_terminal` queda SIN guard a propósito.

### Restricción que no perdí en silencio

`orders_service.rs` admitía sólo `{owner, admin, pos_terminal}` y EXCLUYE
`staff` y `manager`, que en `rbac.md:32-40` sí tienen `pos:orders`.

### Pendiente

- `menu`: 25 handlers + ~24 call sites.
- `payments`: 14 handlers; los guards del service se preservan por contrato.
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  LocalDatabase.markUnavailable();

  setUpAll(() async {
    if (!await _productFont.exists() || !await _materialIconsFont.exists()) {
      return;
    }
    final bytes = ByteData.sublistView(await _productFont.readAsBytes());
    for (final family in ['GoldenArial', 'monospace']) {
      await (FontLoader(family)..addFont(Future.value(bytes))).load();
    }
    final iconBytes = ByteData.sublistView(
      await _materialIconsFont.readAsBytes(),
    );
    await (FontLoader('MaterialIcons')
          ..addFont(Future.value(iconBytes)))
        .load();
  });

  testWidgets('notice bubble golden', (tester) async {
    if (!_productFont.existsSync() || !_materialIconsFont.existsSync()) {
      return;
    }
    tester.view.physicalSize = const Size(900, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final theme = buildAppTheme();
    await tester.pumpWidget(
      MaterialApp(
        theme: theme.copyWith(
          textTheme: theme.textTheme.apply(fontFamily: 'GoldenArial'),
        ),
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: ListView(
              children: const [
                ChatNoticeBubble(
                  role: ChatRole.blocked,
                  text: _report,
                  fontSize: 13,
                ),
                SizedBox(height: 4),
                ChatNoticeBubble(
                  role: ChatRole.error,
                  text:
                      'El turno murió: `cargo test` salió con código 101 y el '
                      'proceso no dejó salida en `stderr`.',
                  fontSize: 13,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 350));

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/chat_notice_bubble.png'),
    );
  });
}
