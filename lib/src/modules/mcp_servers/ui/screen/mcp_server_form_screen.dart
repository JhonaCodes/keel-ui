import 'package:flutter/material.dart';

import 'package:keel_ui/src/core/ui/form_panel.dart';
import 'package:keel_ui/src/modules/agent_profiles/viewmodel/agent_profiles_viewmodel.dart';
import 'package:keel_ui/src/modules/mcp_servers/model/mcp_server_config.dart';
import 'package:keel_ui/src/modules/mcp_servers/viewmodel/mcp_servers_viewmodel.dart';
import 'package:keel_ui/src/modules/secrets/ui/widget/secret_multi_select.dart';

Future<void> openMcpServerFormScreen(
  BuildContext context, {
  McpServerConfig? initial,
}) {
  return showFormPanel<void>(
    context,
    child: McpServerFormScreen(initial: initial),
  );
}

class McpServerFormScreen extends StatefulWidget {
  const McpServerFormScreen({super.key, this.initial});

  final McpServerConfig? initial;

  @override
  State<McpServerFormScreen> createState() => _McpServerFormScreenState();
}

class _McpServerFormScreenState extends State<McpServerFormScreen> {
  late final _nameController = TextEditingController(
    text: widget.initial?.name,
  );
  late final _commandController = TextEditingController(
    text: widget.initial?.command,
  );
  late final _argsController = TextEditingController(
    text: widget.initial?.args.join(' '),
  );
  late final _urlController = TextEditingController(text: widget.initial?.url);
  late final _headersController = TextEditingController(
    text: formatKeyValueLines(widget.initial?.headers ?? const {}),
  );
  late McpTransport _transport =
      widget.initial?.transport ?? McpTransport.stdio;

  /// The secret picker grants env KEY == secret NAME — the common case for
  /// API keys. A different env key can be mapped by editing the config via
  /// Keel AI (`register_mcp_server`), not from this form.
  late List<String> _secretNames = [...?widget.initial?.secretEnv.values];

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
                TextField(
                  controller: _nameController,
                  autofocus: true,
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
