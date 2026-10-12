import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/core/ui/app_theme.dart';
import 'package:keel_ui/src/modules/sidebar_layout/model/sidebar_layout.dart';
import 'package:keel_ui/src/modules/sidebar_layout/ui/widget/sidebar_group_band.dart';

/// Cómo se ven las bandas de proyectos en la barra: una desplegada con sus
/// proyectos, una plegada y una vacía.
final _productFont = File('/System/Library/Fonts/Supplemental/Arial.ttf');
final _pubCache =
    Platform.environment['PUB_CACHE'] ??
    '${Platform.environment['HOME']}/.pub-cache';
final _materialIconsFont = File(
  '$_pubCache/hosted/pub.dev/provider-6.1.2/'
  'extension/devtools/build/assets/fonts/MaterialIcons-Regular.otf',
);

void main() {
  setUpAll(() async {
    if (!await _productFont.exists()) return;
    final bytes = ByteData.sublistView(await _productFont.readAsBytes());
    for (final family in ['GoldenArial', 'monospace']) {
      await (FontLoader(family)..addFont(Future.value(bytes))).load();
    }
    if (await _materialIconsFont.exists()) {
      final icons = ByteData.sublistView(
        await _materialIconsFont.readAsBytes(),
      );
      await (FontLoader('MaterialIcons')..addFont(Future.value(icons))).load();
    }
  });

  testWidgets('sidebar group bands golden', (tester) async {
    tester.view.physicalSize = const Size(210, 330);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final theme = buildAppTheme();
    Widget project(String name, {bool selected = false}) => Container(
      color: selected ? theme.colorScheme.surfaceContainerHighest : null,
      padding: const EdgeInsets.fromLTRB(14, 5, 14, 5),
      child: Text(
        '#  $name',
        style: TextStyle(
          fontSize: 13,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: theme.copyWith(
          textTheme: theme.textTheme.apply(fontFamily: 'GoldenArial'),
        ),
        home: Scaffold(
          body: ColoredBox(
            color: theme.colorScheme.surfaceContainerLow,
            child: ListView(
              children: [
                SidebarGroupBand(
                  group: const SidebarGroupSlot(
                    id: 'trabajo',
                    name: 'TRABAJO',
                    memberIds: ['a', 'b', 'c'],
                  ),
                  containsSelection: true,
                  runningCount: 1,
                  onToggle: () {},
                  onRename: (_) => null,
                  onRemove: () {},
                ),
                project('nui-app', selected: true),
                project('con-app'),
                project('kiwio'),
                SidebarGroupBand(
                  group: const SidebarGroupSlot(
                    id: 'personal-1',
                    name: 'PERSONAL',
                    memberIds: ['d', 'e'],
                    collapsed: true,
                  ),
                  onToggle: () {},
                  onRename: (_) => null,
                  onRemove: () {},
                ),
                SidebarGroupBand(
                  group: const SidebarGroupSlot(
                    id: 'ideas',
                    name: 'IDEAS',
                    memberIds: [],
                  ),
                  onToggle: () {},
                  onRename: (_) => null,
                  onRemove: () {},
                ),
                const SidebarGroupBandEmpty(),
                project('keel-ui'),
              ],
            ),
          ),
        ),
      ),
    );
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/sidebar_group_band.png'),
    );
  }, skip: !_productFont.existsSync());
}
