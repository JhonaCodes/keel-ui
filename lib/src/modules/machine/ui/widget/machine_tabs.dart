import 'package:flutter/material.dart';

import 'package:keel_ui/src/modules/machine/model/machine_tab.dart';

/// El cuerpo de Máquina: una pestaña por [MachineTab], cada una con lo suyo.
/// Antes era una sola lista con la versión, los CLIs, las cuentas, el
/// consumo y el fierro uno debajo del otro, y no se entendía qué era qué.
class MachineTabs extends StatelessWidget {
  const MachineTabs({
    super.key,
    required this.title,
    required this.actions,
    required this.pages,
  });

  final String title;
  final List<Widget> actions;

  /// Una página por pestaña. Cada una es una columna; el scroll lo pone esto.
  final Map<MachineTab, Widget> pages;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: MachineTab.values.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          actions: actions,
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [for (final tab in MachineTab.values) Tab(text: tab.label)],
          ),
        ),
        body: TabBarView(
          children: [
            for (final tab in MachineTab.values)
              ListView(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 32),
                children: [?pages[tab]],
              ),
          ],
        ),
      ),
    );
  }
}
