import 'package:flutter/material.dart';

import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/src/core/services/external_link_service.dart';
import 'package:keel_ui/src/core/ui/form_panel.dart';
import 'package:keel_ui/src/integrations/mcp_catalog/mcp_catalog.dart';
import 'package:keel_ui/src/modules/agent_profiles/viewmodel/agent_profiles_viewmodel.dart';
import 'package:keel_ui/src/modules/mcp_servers/model/mcp_server_config.dart';
import 'package:keel_ui/src/modules/mcp_servers/viewmodel/mcp_servers_viewmodel.dart';
import 'package:keel_ui/src/modules/mcp_servers/ui/widget/integration_credentials.dart';
import 'package:keel_ui/src/modules/mcp_servers/ui/widget/integration_glyph.dart';
import 'package:keel_ui/src/modules/mcp_servers/ui/widget/probe_status.dart';
import 'package:keel_ui/src/modules/secrets/ui/widget/secret_multi_select.dart';

Future<void> openMcpServerFormScreen(
  BuildContext context, {
  McpServerConfig? initial,
  McpCatalogEntry? fromCatalog,
}) {
  return showFormPanel<void>(
    context,
    child: McpServerFormScreen(initial: initial, fromCatalog: fromCatalog),
  );
}

class McpServerFormScreen extends StatefulWidget {
  const McpServerFormScreen({super.key, this.initial, this.fromCatalog});

  final McpServerConfig? initial;

  /// La ficha del catálogo con la que se abre el formulario ya lleno. Sigue
  /// siendo un formulario común: todo lo que trae la ficha se puede cambiar
  /// antes de registrar, y después también.
  final McpCatalogEntry? fromCatalog;

  @override
  State<McpServerFormScreen> createState() => _McpServerFormScreenState();
}

class _McpServerFormScreenState extends State<McpServerFormScreen> {
  /// La ficha con la que hay que dibujar: la que se pasó al instalar, o la
  /// que quedó guardada cuando el servidor se instaló desde el catálogo.
  McpCatalogEntry? get _entry =>
      widget.fromCatalog ?? mcpCatalogEntryFor(widget.initial?.catalogId ?? '');

  late final _nameController = TextEditingController(
    text: widget.initial?.name ?? widget.fromCatalog?.serverName,
  );
  late final _commandController = TextEditingController(
    text: widget.initial?.command ?? widget.fromCatalog?.command,
  );
  late final _argsController = TextEditingController(
    text: (widget.initial?.args ?? widget.fromCatalog?.args ?? const []).join(
      ' ',
    ),
  );
  late final _urlController = TextEditingController(
    text: widget.initial?.url ?? widget.fromCatalog?.url,
  );
  late final _headersController = TextEditingController(
    text: formatKeyValueLines(
      widget.initial?.headers ?? widget.fromCatalog?.headers ?? const {},
    ),
  );
  late McpTransport _transport =
      widget.initial?.transport ??
      widget.fromCatalog?.transport ??
      McpTransport.stdio;

  /// The secret picker grants env KEY == secret NAME — the common case for
  /// API keys. A different env key can be mapped by editing the config via
  /// Keel AI (`register_mcp_server`), not from this form.
  late List<String> _secretNames = [
    ...?(widget.initial?.secretEnv ?? widget.fromCatalog?.secretEnv)?.values,
  ];

  /// Registering an MCP is not enough for anyone to use it: an agent only
  /// sees it if its profile carries it. The assistant's profile is hidden
  /// from the profiles screen, so this switch is the only way to hand it
  /// one — without it, a registered MCP is invisible to Keel AI forever.
  late bool _availableToKeelAi =
      widget.initial != null &&
      AgentProfilesService.instance.notifier.keelAiUsesMcpServer(
        widget.initial!.name,
      );

  String? _nameError;
  String? _formError;

  @override
  void dispose() {
    _nameController.dispose();
    _commandController.dispose();
    _argsController.dispose();
    _urlController.dispose();
    _headersController.dispose();
    super.dispose();
  }

  void _onNameChanged(String value) {
    setState(() {
      _nameError = validateMcpServerName(value.trim());
      _formError = null;
    });
  }

  void _submit() {
    final name = _nameController.text.trim();
    final nameError = validateMcpServerName(name);
    if (nameError != null) {
      setState(() => _nameError = nameError);
      return;
    }

    final args = _argsController.text
        .split(' ')
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toList();
    final secretEnv = {for (final name in _secretNames) name: name};

    final viewmodel = McpServersService.instance.notifier;
    final initial = widget.initial;
    final error = initial == null
        ? viewmodel.createServer(
            name: name,
            transport: _transport,
            command: _commandController.text,
            args: args,
            env: const {},
            secretEnv: secretEnv,
            url: _urlController.text,
            headers: parseKeyValueLines(_headersController.text),
            catalogId: widget.fromCatalog?.id ?? '',
          )
        : viewmodel.updateServer(
            initial.id,
            name: name,
            transport: _transport,
            command: _commandController.text,
            args: args,
            // Literal env vars have no field in this form on purpose —
            // credentials go through Secrets and nothing else needed one.
            // Whatever `register_mcp_server` stored is carried through
            // untouched instead of being silently wiped on save.
            env: initial.env,
            secretEnv: secretEnv,
            url: _urlController.text,
            headers: parseKeyValueLines(_headersController.text),
          );

    if (error != null) {
      setState(() => _formError = error);
      return;
    }

    // After the name is final: the grant is stored by NAME.
    AgentProfilesService.instance.notifier.setKeelAiMcpServer(
      name,
      enabled: _availableToKeelAi,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initial != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar MCP' : 'Registrar MCP'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: FilledButton(
              onPressed: _submit,
              child: Text(isEditing ? 'Guardar' : 'Registrar'),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_entry case final entry?) ...[
                  _CatalogHeader(entry: entry),
                  const SizedBox(height: 20),
                  IntegrationCredentials(entry: entry),
                  const SizedBox(height: 4),
                ],
                TextField(
                  controller: _nameController,
                  autofocus: _entry == null,
                  onChanged: _onNameChanged,
                  decoration: InputDecoration(
                    labelText:
                        'Nombre (minúsculas; las tools llegan como '
                        'mcp__<nombre>__*)',
                    errorText: _nameError,
                    border: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<McpTransport>(
                  initialValue: _transport,
                  decoration: const InputDecoration(
                    labelText: 'Transporte',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                    ),
                  ),
                  items: [
                    for (final transport in McpTransport.values)
                      DropdownMenuItem(
                        value: transport,
                        child: Text(transport.label),
                      ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _transport = value);
                  },
                ),
                const SizedBox(height: 16),
                if (_transport == McpTransport.stdio) ...[
                  TextField(
                    controller: _commandController,
                    decoration: const InputDecoration(
                      labelText: 'Comando (ej: npx)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(16)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _argsController,
                    decoration: const InputDecoration(
                      labelText:
                          'Argumentos separados por espacio '
                          '(ej: -y @modelcontextprotocol/server-gdrive)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(16)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SecretMultiSelect(
                    selectedNames: _secretNames,
                    onChanged: (names) => setState(() => _secretNames = names),
                  ),
                ] else ...[
                  TextField(
                    controller: _urlController,
                    decoration: const InputDecoration(
                      labelText: 'URL',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(16)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _headersController,
                    minLines: 2,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: 'Headers (KEY=valor, una por línea)',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(16)),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                SwitchListTile(
                  value: _availableToKeelAi,
                  onChanged: (value) =>
                      setState(() => _availableToKeelAi = value),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Dárselo a Keel AI (el asistente)'),
                  subtitle: const Text(
                    'Registrar el MCP no basta: un agente solo lo ve si lo '
                    'tiene asignado. Al resto de los agentes se les asigna '
                    'desde su perfil.',
                  ),
                ),
                if (widget.initial case final server?) ...[
                  const SizedBox(height: 20),
                  _ProbeRow(server: server),
                ],
                if (_formError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _formError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Lo que la ficha del catálogo sabe y el formulario no: de qué servicio se
/// trata, cómo se autentica y dónde está su documentación.
class _CatalogHeader extends StatelessWidget {
  const _CatalogHeader({required this.entry});

  final McpCatalogEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IntegrationGlyph.forEntry(entry, size: 36),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.name, style: theme.textTheme.titleMedium),
                  Text(
                    entry.tagline,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: () => openExternalUrl(entry.docsUrl),
              icon: const Icon(Icons.open_in_new, size: 15),
              label: const Text('Documentación'),
            ),
          ],
        ),
        if (entry.note.isNotEmpty) ...[
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.warning_amber_outlined,
                size: 16,
                color: scheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  entry.note,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Probar la conexión desde el propio formulario, que es donde uno está
/// cuando acaba de cargar el token y quiere saber si sirvió.
///
/// Aparece solo al editar: un servidor sin registrar todavía no tiene id, y
/// probar una configuración que no está guardada dejaría un resultado
/// colgado de nada.
class _ProbeRow extends StatelessWidget {
  const _ProbeRow({required this.server});

  final McpServerConfig server;

  @override
  Widget build(BuildContext context) {
    return ReactiveViewModelBuilder<McpServersViewModel, McpServersState>(
      viewmodel: McpServersService.instance.notifier,
      build: (state, viewmodel, keep) {
        final probing = state.probing.contains(server.id);
        final probe = state.probes[server.id];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Divider(height: 1),
            const SizedBox(height: 14),
            Row(
              children: [
                OutlinedButton(
                  onPressed: probing
                      ? null
                      : () => viewmodel.probeServer(server.id),
                  child: const Text('Probar la conexión'),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: ProbeStatus(result: probe, probing: probing),
                ),
              ],
            ),
            if (probe != null && probe.ok && probe.tools.isNotEmpty) ...[
              const SizedBox(height: 12),
              _ToolChips(tools: probe.tools),
            ],
          ],
        );
      },
    );
  }
}

/// Las tools que devolvió, que es la única prueba de que el agente las va a
/// ver. Se cortan a veinte: la lista completa de algunos servidores es más
/// larga que el formulario entero.
class _ToolChips extends StatelessWidget {
  const _ToolChips({required this.tools});

  static const _shown = 20;

  final List<String> tools;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final extra = tools.length - _shown;

    return Wrap(
      spacing: 5,
      runSpacing: 5,
      children: [
        for (final tool in tools.take(_shown)) _chip(scheme, tool),
        if (extra > 0) _chip(scheme, '+$extra más'),
      ],
    );
  }

  Widget _chip(ColorScheme scheme, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: scheme.surfaceContainerHigh,
      border: Border.all(color: scheme.outlineVariant),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontFamily: 'monospace',
        fontSize: 10.5,
        color: scheme.onSurfaceVariant,
      ),
    ),
  );
}
