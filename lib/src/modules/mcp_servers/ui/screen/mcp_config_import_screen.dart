import 'package:flutter/material.dart';

import 'package:keel_ui/src/core/ui/form_panel.dart';
import 'package:keel_ui/src/integrations/mcp_catalog/mcp_catalog.dart';
import 'package:keel_ui/src/modules/mcp_servers/viewmodel/mcp_servers_viewmodel.dart';

Future<void> openMcpConfigImportScreen(BuildContext context) {
  return showFormPanel<void>(context, child: const McpConfigImportScreen());
}

/// Pegar el bloque `mcpServers` que publica cualquier servidor en su
/// documentación, en vez de traducirlo al formulario campo por campo.
///
/// Mismo idioma que el importador de hooks: se lee mientras escribís, se
/// muestra qué va a pasar, y no se escribe nada hasta que apretás.
class McpConfigImportScreen extends StatefulWidget {
  const McpConfigImportScreen({super.key});

  @override
  State<McpConfigImportScreen> createState() => _McpConfigImportScreenState();
}

class _McpConfigImportScreenState extends State<McpConfigImportScreen> {
  final _controller = TextEditingController();
  PastedMcpConfig _parsed = const PastedMcpConfig();
  String? _formError;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() {
      _parsed = parseMcpServersJson(value);
      _formError = null;
    });
  }

  void _submit() {
    final viewmodel = McpServersService.instance.notifier;
    final failures = <String>[];

    for (final server in _parsed.servers) {
      final existing = viewmodel.serverNamed(server.name);
      final error = existing == null
          ? viewmodel.createServer(
              name: server.name,
              transport: server.transport,
              command: server.command,
              args: server.args,
              env: server.env,
              secretEnv: const {},
              url: server.url,
              headers: server.headers,
            )
          : viewmodel.updateServer(
              existing.id,
              name: server.name,
              transport: server.transport,
              command: server.command,
              args: server.args,
              env: server.env,
              // Una config pegada no sabe de secrets: si el que ya estaba
              // tenía referencias puestas a mano, se conservan.
              secretEnv: existing.secretEnv,
              url: server.url,
              headers: server.headers,
            );
      if (error != null) failures.add('${server.name}: $error');
    }

    if (failures.isNotEmpty) {
      setState(() => _formError = failures.join('\n'));
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final viewmodel = McpServersService.instance.notifier;
    final servers = _parsed.servers;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pegar una configuración MCP'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: FilledButton(
              onPressed: servers.isEmpty ? null : _submit,
              child: Text(
                servers.isEmpty
                    ? 'Registrar'
                    : 'Registrar ${servers.length == 1 ? "1" : servers.length}',
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            minLines: 8,
            maxLines: 18,
            onChanged: _onChanged,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            decoration: const InputDecoration(
              labelText: 'Pegá el bloque tal como está en la documentación',
              alignLabelWithHint: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
            ),
          ),
          if (_parsed.error.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(_parsed.error, style: TextStyle(color: scheme.error)),
          ],
          if (servers.isNotEmpty) ...[
            const SizedBox(height: 22),
            Text(
              'SE VAN A REGISTRAR',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                letterSpacing: 1.2,
                color: scheme.outline,
              ),
            ),
            const SizedBox(height: 8),
            for (final server in servers)
              _PreviewRow(
                server: server,
                replaces: viewmodel.serverNamed(server.name) != null,
              ),
          ],
          if (_parsed.problems.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(
              'NO SE PUDIERON LEER',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                letterSpacing: 1.2,
                color: scheme.error,
              ),
            ),
            const SizedBox(height: 6),
            for (final problem in _parsed.problems)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  problem,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
          if (servers.any((server) => server.sensitiveEnvKeys.isNotEmpty)) ...[
            const SizedBox(height: 18),
            _SecretWarning(
              keys: [for (final server in servers) ...server.sensitiveEnvKeys],
            ),
          ],
          if (_formError != null) ...[
            const SizedBox(height: 14),
            Text(_formError!, style: TextStyle(color: scheme.error)),
          ],
        ],
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({required this.server, required this.replaces});

  final PastedMcpServer server;
  final bool replaces;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            replaces ? '~' : '+',
            style: TextStyle(
              fontFamily: 'monospace',
              color: replaces ? scheme.primary : scheme.tertiary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: server.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      TextSpan(
                        text: replaces
                            ? ' — reemplaza al que ya estaba registrado con '
                                  'ese nombre'
                            : ' — ${server.transport.label.toLowerCase()}',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                  style: theme.textTheme.bodyMedium,
                ),
                Text(
                  server.detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: scheme.outline,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// El aviso que hace que este importador no sea un agujero: un token pegado
/// en `env` queda como texto en la base.
class _SecretWarning extends StatelessWidget {
  const _SecretWarning({required this.keys});

  final List<String> keys;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.key_outlined, size: 16, color: scheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '${keys.join(', ')} ${keys.length == 1 ? "trae" : "traen"} un '
            'valor adentro, y va a quedar como texto en la base. Si es una '
            'credencial de verdad, registrala en Secrets y dejá acá la '
            'referencia: es para lo que existe esa sección.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
