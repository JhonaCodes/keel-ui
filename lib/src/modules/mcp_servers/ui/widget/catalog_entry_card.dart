import 'package:flutter/material.dart';

import 'package:keel_ui/src/integrations/mcp_catalog/mcp_catalog.dart';
import 'package:keel_ui/src/modules/mcp_servers/model/mcp_server_config.dart';
import 'package:keel_ui/src/modules/mcp_servers/ui/widget/integration_glyph.dart';

/// Una ficha del catálogo, todavía sin instalar.
///
/// Muestra el transporte y si pide credencial porque son las dos cosas que
/// deciden si vale la pena abrirla ahora: un servidor que pide un token que
/// no tenés a mano es para otro momento.
class CatalogEntryCard extends StatelessWidget {
  const CatalogEntryCard({super.key, required this.entry, required this.onTap});

  final McpCatalogEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final transport = switch (entry.transport) {
      McpTransport.stdio => 'stdio · ${entry.command}',
      McpTransport.http => 'HTTP',
      McpTransport.sse => 'SSE',
    };
    final auth = switch (entry.auth) {
      McpCatalogAuth.ninguna => 'sin credencial',
      McpCatalogAuth.token => 'token',
      McpCatalogAuth.oauth => 'OAuth',
      McpCatalogAuth.archivo => 'autorizar',
    };

    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            border: Border.all(color: scheme.outlineVariant),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IntegrationGlyph.forEntry(entry),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 1),
                    // El tagline se lleva lo que sobra en vez de medir fijo.
                    // Con alto fijo, un tagline de dos líneas desbordaba por
                    // un pixel — y subir el número solo mueve el problema al
                    // primer texto un poco más largo.
                    Expanded(
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: Text(
                          entry.tagline,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$transport · $auth'.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 9.5,
                        letterSpacing: 0.5,
                        color: scheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
