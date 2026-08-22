import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/integrations/mcp_catalog/mcp_catalog.dart';
import 'package:keel_ui/src/modules/mcp_servers/model/mcp_server_config.dart';
import 'package:keel_ui/src/modules/secrets/model/secret.dart';

void main() {
  group('el catálogo', () {
    test('no repite ids ni nombres de servidor', () {
      final ids = kMcpCatalog.map((entry) => entry.id).toList();
      final names = kMcpCatalog.map((entry) => entry.serverName).toList();

      expect(ids.toSet().length, ids.length, reason: 'hay un id repetido');
      expect(
        names.toSet().length,
        names.length,
        reason: 'dos fichas se registrarían con el mismo prefijo de tools',
      );
    });

    test('cada nombre de servidor es válido como prefijo de tools', () {
      for (final entry in kMcpCatalog) {
        expect(
          validateMcpServerName(entry.serverName),
          isNull,
          reason: '${entry.id} no se podría registrar',
        );
      }
    });

    test('cada secret que declara se llama como un secret', () {
      for (final entry in kMcpCatalog) {
        for (final credential in entry.credentials) {
          expect(
            validateSecretName(credential.name),
            isNull,
            reason: '${entry.id} pide ${credential.name}',
          );
          expect(credential.hint, isNotEmpty);
        }
      }
    });

    test('los secrets que declara son exactamente los que usa', () {
      for (final entry in kMcpCatalog) {
        final usados = {
          ...entry.secretEnv.values,
          for (final value in entry.headers.values)
            ...secretPlaceholdersIn(value),
        };

        expect(
          entry.secretNames.toSet(),
          usados,
          reason:
              '${entry.id} declara ${entry.secretNames} y usa $usados — una '
              'credencial que se pide y no se usa deja al usuario cargando '
              'un secret que no va a ninguna parte',
        );
      }
    });

    test('cada ficha sabe cómo levantar', () {
      for (final entry in kMcpCatalog) {
        expect(entry.docsUrl, startsWith('https://'), reason: entry.id);
        expect(entry.glyph.length, 2, reason: entry.id);
        expect(entry.tagline, isNotEmpty, reason: entry.id);

        switch (entry.transport) {
          case McpTransport.stdio:
            expect(entry.command, isNotEmpty, reason: entry.id);
            expect(entry.url, isEmpty, reason: entry.id);
          case McpTransport.http || McpTransport.sse:
            expect(entry.url, startsWith('https://'), reason: entry.id);
            expect(entry.command, isEmpty, reason: entry.id);
        }
      }
    });

    test('un servidor que pide OAuth lo dice en la nota', () {
      for (final entry in kMcpCatalog) {
        if (entry.auth != McpCatalogAuth.oauth) continue;
        expect(
          entry.note,
          isNotEmpty,
          reason:
              '${entry.id} pide OAuth y no lo avisa; con --strict-mcp-config '
              'un servidor autenticado por fuera no se ve desde acá',
        );
      }
    });

    test('mcpCatalogEntryFor no inventa fichas', () {
      expect(mcpCatalogEntryFor('github')?.name, 'GitHub');
      expect(mcpCatalogEntryFor('no-existe'), isNull);
      expect(mcpCatalogEntryFor(''), isNull);
    });

    test('agrupar por categoría respeta el orden y saca lo instalado', () {
      final agrupado = mcpCatalogByCategory(excludingIds: {'github'});
      final planos = agrupado.values.expand((entries) => entries).toList();

      expect(planos.map((entry) => entry.id), isNot(contains('github')));
      expect(planos.length, kMcpCatalog.length - 1);
      expect(agrupado.keys.first, McpCatalogCategory.trabajo);
    });
  });
}
