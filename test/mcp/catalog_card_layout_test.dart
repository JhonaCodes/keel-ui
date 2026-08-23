import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/core/ui/app_theme.dart';
import 'package:keel_ui/src/integrations/mcp_catalog/mcp_catalog.dart';
import 'package:keel_ui/src/modules/mcp_servers/model/mcp_probe_result.dart';
import 'package:keel_ui/src/modules/mcp_servers/model/mcp_server_config.dart';
import 'package:keel_ui/src/modules/mcp_servers/ui/widget/installed_integration_card.dart';
import 'package:keel_ui/src/modules/mcp_servers/ui/widget/catalog_entry_card.dart';

/// Una tarjeta del catálogo, en la caja EXACTA que le da la grilla.
///
/// El alto lo fija `mainAxisExtent` en la pantalla; si cambia allá y no acá,
/// este test deja de probar lo que dice probar.
const _tileWidth = 280.0;
const _tileHeight = 102.0;

void main() {
  _instaladas();

  group('las tarjetas del catálogo entran en su caja', () {
    // El bug que motivó esto: con el tagline en dos líneas la tarjeta
    // desbordaba por un pixel. No se ve hasta que alguien abre la pantalla,
    // así que se prueba fichas por ficha.
    for (final entry in kMcpCatalog) {
      testWidgets('${entry.id} no desborda', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(),
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: _tileWidth,
                  height: _tileHeight,
                  child: CatalogEntryCard(entry: entry, onTap: () {}),
                ),
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(find.text(entry.name), findsOneWidget);
      });
    }

    testWidgets('tampoco con un tagline mucho más largo', (tester) async {
      const largo = McpCatalogEntry(
        id: 'largo',
        name: 'Un servicio con nombre bastante largo también',
        tagline:
            'Una descripción deliberadamente larga que no entra en dos '
            'líneas ni en tres, para ver qué hace la tarjeta cuando el '
            'texto se le va de las manos.',
        category: McpCatalogCategory.trabajo,
        auth: McpCatalogAuth.oauth,
        transport: McpTransport.stdio,
        serverName: 'largo',
        command: 'npx',
        args: ['-y', '@un/paquete-con-un-nombre-interminable@latest'],
        docsUrl: 'https://ejemplo',
        glyph: 'LA',
        colorIndex: 0,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: _tileWidth,
                height: _tileHeight,
                child: CatalogEntryCard(entry: largo, onTap: () {}),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('ni en la columna más angosta que puede darle la grilla', (
      tester,
    ) async {
      // maxCrossAxisExtent es 280, así que con un panel apenas más ancho que
      // dos columnas cada tarjeta queda cerca de 140.
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 140,
                height: _tileHeight,
                child: CatalogEntryCard(entry: kMcpCatalog.first, onTap: () {}),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });
}

/// La tarjeta de una integración instalada, en el panel más angosto que
/// puede quedar: el panel mide 1000, pero se achica solo cuando la ventana
/// no le da (`showFormPanel` lo acota a `ancho - 120`).
void _instaladas() {
  const anchos = [1000.0, 780.0, 620.0];

  group('la tarjeta de una instalada aguanta el panel angosto', () {
    for (final ancho in anchos) {
      testWidgets('a $ancho de ancho', (tester) async {
        final server = McpServerConfig(
          id: 'x',
          name: 'atlassian-search-con-nombre-largo',
          transport: McpTransport.stdio,
          command: 'uvx',
          args: const ['mcp-atlassian', '--transport', 'stdio'],
          createdAt: DateTime(2026),
          catalogId: 'atlassian',
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(),
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: ancho,
                  child: InstalledIntegrationCard(
                    server: server,
                    probe: McpProbeResult(
                      ok: true,
                      at: DateTime.now(),
                      serverName: 'mcp-atlassian',
                      tools: List.generate(98, (i) => 'tool_$i'),
                    ),
                    probing: false,
                  ),
                ),
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
      });
    }
  });
}
