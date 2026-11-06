import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:keel_core/integrations/plan_usage/plan_usage.dart';
import 'package:keel_ui/src/core/ui/app_theme.dart';
import 'package:keel_ui/src/modules/machine/ui/widget/plan_usage_rail.dart';

/// El riel de consumo solo, con los números que no entraban: tres cifras
/// (una clave de OpenRouter que gastó casi nueve veces su tope), un límite
/// justo en 100 y uno de cuatro cifras.
///
/// `monospace` se carga con Menlo, que es lo que resuelve macOS en la app:
/// con Arial tres cifras entran en la caja vieja y el defecto no se ve.
final _productFont = File('/System/Library/Fonts/Supplemental/Arial.ttf');
final _monospaceFont = File('/System/Library/Fonts/Menlo.ttc');
final _pubCache =
    Platform.environment['PUB_CACHE'] ??
    '${Platform.environment['HOME']}/.pub-cache';
final _materialIconsFont = File(
  '$_pubCache/hosted/pub.dev/provider-6.1.2/'
  'extension/devtools/build/assets/fonts/MaterialIcons-Regular.otf',
);

PlanUsage _usage(PlanAccount account, List<(PlanMeterKind, double)> meters) =>
    PlanUsage(
      account: account,
      meters: [
        for (final (kind, percent) in meters)
          PlanMeter(kind: kind, percent: percent),
      ],
    );

const _claudeDefault = PlanAccount(
  provider: PlanProvider.claude,
  name: PlanAccount.defaultName,
);

final _claude = [
  _usage(_claudeDefault, [
    (PlanMeterKind.session, 37),
    (PlanMeterKind.weekly, 42),
  ]),
  _usage(
    const PlanAccount(
      provider: PlanProvider.claude,
      name: 'trabajo',
      configDir: '/home/dev/.claude-trabajo',
    ),
    [(PlanMeterKind.session, 100), (PlanMeterKind.weekly, 1240)],
  ),
];

final _codex = _usage(
  const PlanAccount(
    provider: PlanProvider.codex,
    name: PlanAccount.defaultName,
  ),
  [(PlanMeterKind.weekly, 20)],
);

final _openRouter = _usage(
  const PlanAccount(
    provider: PlanProvider.openRouter,
    name: PlanAccount.defaultName,
  ),
  [(PlanMeterKind.credits, 98), (PlanMeterKind.keyLimit, 897)],
);

Widget _rail() {
  bool active(PlanAccount account) => account.isDefault;
  return Padding(
    padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
    child: Column(
      children: [
        PlanUsageRailProvider(
          provider: PlanProvider.claude,
          expanded: true,
          accounts: _claude,
          isActive: active,
          onToggle: () {},
          onPressed: () {},
        ),
        PlanUsageRailProvider(
          provider: PlanProvider.codex,
          expanded: true,
          accounts: [_codex],
          isActive: active,
          onToggle: () {},
          onPressed: () {},
        ),
        PlanUsageRailProvider(
          provider: PlanProvider.openRouter,
          expanded: true,
          accounts: [_openRouter],
          isActive: (_) => false,
          onToggle: () {},
          onPressed: () {},
        ),
      ],
    ),
  );
}

void main() {
  setUpAll(() async {
    Future<void> load(String family, File font) async {
      if (!await font.exists()) return;
      final bytes = ByteData.sublistView(await font.readAsBytes());
      await (FontLoader(family)..addFont(Future.value(bytes))).load();
    }

    await load('GoldenArial', _productFont);
    await load('monospace', _monospaceFont);
    await load('MaterialIcons', _materialIconsFont);
  });

  // El riel mide 72 puntos: un consumo de tres cifras se lee en una línea,
  // igual que uno de dos, en vez de partirse en "89" sobre "7".
  testWidgets('a three-digit rail number stays on one line', (tester) async {
    await _surface(tester, const Size(72, 520), _rail());
    final twoDigits = tester.getSize(find.text('98')).height;
    expect(tester.getSize(find.text('897')).height, twoDigits);
    expect(tester.getSize(find.text('100')).height, twoDigits);
    expect(tester.getSize(find.text('1k')).height, twoDigits);
  }, skip: !_monospaceFont.existsSync());

  // Todas las cuentas miden lo mismo, con nombre o sin él (OpenRouter).
  testWidgets('every rail account tile has the same height', (tester) async {
    await _surface(tester, const Size(72, 520), _rail());
    final heights = {
      for (final tile in tester.widgetList(find.byType(PlanUsageRailAccount)))
        tester.getSize(find.byWidget(tile)).height,
    };
    expect(heights, hasLength(1));
  });

  // La cuenta en uso se reconoce por el color del tile: «default» no se
  // escribe. Las otras sí llevan su nombre, que es lo que las distingue.
  testWidgets('the default account is not labelled', (tester) async {
    await _surface(tester, const Size(72, 520), _rail());
    expect(find.text('default'), findsNothing);
    expect(find.text('trabajo'), findsOneWidget);
  });

  testWidgets('plan usage rail large numbers golden', (tester) async {
    await _surface(tester, const Size(72, 520), _rail());
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/plan_usage_rail_large_numbers.png'),
    );
  }, skip: !_productFont.existsSync() || !_monospaceFont.existsSync());
}

Future<void> _surface(WidgetTester tester, Size size, Widget child) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final theme = buildAppTheme();
  await tester.pumpWidget(
    MaterialApp(
      theme: theme.copyWith(
        textTheme: theme.textTheme.apply(fontFamily: 'GoldenArial'),
      ),
      home: Scaffold(body: child),
    ),
  );
}
