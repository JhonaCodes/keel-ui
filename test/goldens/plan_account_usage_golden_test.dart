import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:keel_core/integrations/plan_usage/plan_usage.dart';
import 'package:keel_ui/src/core/ui/app_theme.dart';
import 'package:keel_ui/src/modules/machine/ui/widget/plan_account_form.dart';
import 'package:keel_ui/src/modules/machine/ui/widget/plan_account_usage.dart';
import 'package:keel_ui/src/modules/machine/ui/widget/plan_usage_rail.dart';

/// Cómo se ven las cuentas en Máquina y en el riel: Claude con dos cuentas
/// (una en uso, otra cerca del límite), Codex con una sesión cerrada y
/// OpenRouter con sus créditos.
final _productFont = File('/System/Library/Fonts/Supplemental/Arial.ttf');
final _pubCache =
    Platform.environment['PUB_CACHE'] ??
    '${Platform.environment['HOME']}/.pub-cache';
final _materialIconsFont = File(
  '$_pubCache/hosted/pub.dev/provider-6.1.2/'
  'extension/devtools/build/assets/fonts/MaterialIcons-Regular.otf',
);

final _today = DateTime.now();

DateTime _todayAt(int hour, int minute) =>
    DateTime(_today.year, _today.month, _today.day, hour, minute);

const _claudeDefault = PlanAccount(
  provider: PlanProvider.claude,
  name: PlanAccount.defaultName,
);
const _codexDefault = PlanAccount(
  provider: PlanProvider.codex,
  name: PlanAccount.defaultName,
);

final _claude = [
  PlanUsage(
    account: _claudeDefault,
    email: 'dev@example.com',
    plan: 'team',
    meters: [
      PlanMeter(
        kind: PlanMeterKind.session,
        percent: 4,
        resetsAt: _todayAt(23, 0),
      ),
      PlanMeter(
        kind: PlanMeterKind.weekly,
        percent: 0,
        resetsAt: DateTime(2026, 10, 20, 10),
      ),
    ],
  ),
  PlanUsage(
    account: const PlanAccount(
      provider: PlanProvider.claude,
      name: 'trabajo',
      configDir: '/home/dev/.claude-trabajo',
    ),
    email: 'trabajo@example.com',
    plan: 'max',
    meters: [
      PlanMeter(
        kind: PlanMeterKind.session,
        percent: 82,
        resetsAt: _todayAt(23, 30),
      ),
      PlanMeter(
        kind: PlanMeterKind.weekly,
        percent: 93,
        resetsAt: DateTime(2026, 10, 18, 21),
      ),
    ],
  ),
];

final _codex = [
  PlanUsage(
    account: _codexDefault,
    email: 'dev@example.com',
    plan: 'plus',
    meters: [
      PlanMeter(
        kind: PlanMeterKind.weekly,
        percent: 12,
        resetsAt: DateTime(2026, 10, 19, 8),
      ),
    ],
  ),
  const PlanUsage(
    account: PlanAccount(
      provider: PlanProvider.codex,
      name: 'personal',
      configDir: '/home/dev/.codex-personal',
    ),
    error: 'not signed in',
    problem: PlanUsageProblem.notSignedIn,
  ),
];

const _openRouter = PlanUsage(
  account: PlanAccount(
    provider: PlanProvider.openRouter,
    name: PlanAccount.defaultName,
  ),
  meters: [
    PlanMeter(kind: PlanMeterKind.credits, percent: 41, used: 4.1, limit: 10),
  ],
  spend: {'day': 0.32, 'week': 1.85, 'month': 4.1},
);

void main() {
  setUpAll(() async {
    if (!await _productFont.exists()) return;
    final bytes = ByteData.sublistView(await _productFont.readAsBytes());
    for (final family in ['GoldenArial', 'monospace']) {
      final loader = FontLoader(family)..addFont(Future.value(bytes));
      await loader.load();
    }
    if (await _materialIconsFont.exists()) {
      final icons = ByteData.sublistView(
        await _materialIconsFont.readAsBytes(),
      );
      await (FontLoader('MaterialIcons')..addFont(Future.value(icons))).load();
    }
  });

  testWidgets('plan accounts golden', (tester) async {
    Widget card(PlanUsage usage, {bool active = false}) => PlanAccountUsage(
      usage: usage,
      active: active,
      onUse: usage.account.provider.hasAccounts ? () {} : null,
      onSignIn: usage.account.provider.hasAccounts ? () {} : null,
      onSignOut: usage.account.provider.hasAccounts ? () {} : null,
      onRemove: usage.account.isDefault ? null : () {},
    );
    await _surface(
      tester,
      const Size(760, 900),
      ListView(
        padding: const EdgeInsets.fromLTRB(22, 16, 22, 16),
        children: [
          card(_claude[0], active: true),
          card(_claude[1]),
          PlanAccountForm(
            provider: PlanProvider.claude,
            onAdd: (_) async => null,
          ),
          const SizedBox(height: 14),
          card(_codex[0], active: true),
          card(_codex[1]),
          const SizedBox(height: 14),
          card(_openRouter),
        ],
      ),
    );
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/plan_account_usage.png'),
    );
  }, skip: !_productFont.existsSync());

  testWidgets('plan usage rail golden', (tester) async {
    bool active(PlanAccount account) => account.isDefault;
    await _surface(
      tester,
      const Size(70, 330),
      Padding(
        padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
        child: Column(
          children: [
            PlanUsageRailProvider(
              provider: PlanProvider.claude,
              expanded: true,
              foldable: true,
              accounts: _claude,
              isActive: active,
              onToggle: () {},
              onPressed: () {},
            ),
            PlanUsageRailProvider(
              provider: PlanProvider.codex,
              expanded: false,
              foldable: true,
              accounts: [_codex[0]],
              isActive: active,
              onToggle: () {},
              onPressed: () {},
            ),
            PlanUsageRailProvider(
              provider: PlanProvider.openRouter,
              expanded: true,
              foldable: false,
              accounts: const [_openRouter],
              isActive: (_) => false,
              onToggle: () {},
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/plan_usage_rail.png'),
    );
  }, skip: !_productFont.existsSync());
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
