import 'package:flutter/material.dart';

import 'package:keel_ui/src/core/ui/form_panel.dart';
import 'package:keel_ui/src/modules/agent_profiles/model/agent_profile.dart';
import 'package:keel_ui/src/modules/agent_profiles/viewmodel/agent_profiles_viewmodel.dart';
import 'package:keel_ui/src/modules/agent_profiles/ui/widget/role_field.dart';
import 'package:keel_ui/src/modules/agents/model/agent_provider.dart';
import 'package:keel_ui/src/modules/agents/model/agent_model_option.dart';
import 'package:keel_ui/src/modules/mcp_servers/ui/widget/mcp_server_multi_select.dart';
import 'package:keel_ui/src/modules/agents/model/effort_level.dart';
import 'package:keel_ui/src/integrations/hook_delivery/hook_delivery.dart';
import 'package:keel_ui/src/modules/hooks/ui/widget/hook_multi_select.dart';
import 'package:keel_ui/src/modules/rules/ui/widget/rule_multi_select.dart';
import 'package:keel_ui/src/modules/skills/ui/widget/skill_multi_select.dart';
import 'package:keel_ui/src/modules/tools/ui/widget/tool_multi_select.dart';

Future<void> openAgentProfileFormScreen(
  BuildContext context, {
  AgentProfile? initial,
}) {
  return showFormPanel<void>(
    context,
    child: AgentProfileFormScreen(initial: initial),
  );
}

class AgentProfileFormScreen extends StatefulWidget {
  const AgentProfileFormScreen({super.key, this.initial});

  final AgentProfile? initial;

  @override
  State<AgentProfileFormScreen> createState() => _AgentProfileFormScreenState();
}

class _AgentProfileFormScreenState extends State<AgentProfileFormScreen> {
  late final _nameController = TextEditingController(
    text: widget.initial?.name,
  );
  late final _roleController = TextEditingController(
    text: widget.initial?.role,
  );
  late final _systemPromptController = TextEditingController(
    text: widget.initial?.systemPrompt,
  );
  late List<String> _skills = [...?widget.initial?.skills];
  late List<String> _rules = [...?widget.initial?.rules];
  late List<String> _hooks = [...?widget.initial?.hooks];
  late List<String> _tools = [...?widget.initial?.tools];
  late List<String> _mcpServers = [...?widget.initial?.mcpServers];
  late bool _canManageSystem = widget.initial?.canManageSystem ?? false;
  late AgentProvider _provider =
      widget.initial?.provider ?? AgentProvider.claude;
  /// Normalized against the provider: a codex agent created before the
  /// catalogs were split still carries a Claude alias, and offering it back
  /// would keep a value codex cannot run.
  late String _model = initialModelFor(
    widget.initial?.provider ?? AgentProvider.claude,
    widget.initial?.model ?? kDefaultClaudeModelAlias,
  );
  late String _effort = widget.initial?.effort ?? kDefaultEffortAlias;
  String? _nameError;
  String? _formError;

  @override
  void dispose() {
    _nameController.dispose();
    _roleController.dispose();
    _systemPromptController.dispose();
    super.dispose();
  }

  void _onNameChanged(String value) {
    setState(() {
      _nameError = validateAgentProfileName(value.trim());
      _formError = null;
    });
  }

  void _submit() {
    final name = _nameController.text.trim();
    final nameError = validateAgentProfileName(name);
    if (nameError != null) {
      setState(() => _nameError = nameError);
      return;
    }

    final viewmodel = AgentProfilesService.instance.notifier;
    final initial = widget.initial;
    final error = initial == null
        ? viewmodel.createProfile(
            name: name,
            role: _roleController.text,
            systemPrompt: _systemPromptController.text,
            skills: _skills,
            rules: _rules,
            hooks: _hooks,
            tools: _tools,
            mcpServers: _mcpServers,
            canManageSystem: _canManageSystem,
            provider: _provider,
            model: _model,
            effort: _effort,
          )
        : viewmodel.updateProfile(
            initial.id,
            name: name,
            role: _roleController.text,
            systemPrompt: _systemPromptController.text,
            skills: _skills,
            rules: _rules,
            hooks: _hooks,
            tools: _tools,
            mcpServers: _mcpServers,
            canManageSystem: _canManageSystem,
            provider: _provider,
            model: _model,
            effort: _effort,
          );

    if (error != null) {
      setState(() => _formError = error);
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initial != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing ? 'Editar agente registrado' : 'Registrar agente',
        ),
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
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _nameController,
                  autofocus: true,
                  onChanged: _onNameChanged,
                  decoration: InputDecoration(
                    labelText: 'Nombre (minúsculas, sin espacios, máx. 16)',
                    errorText: _nameError,
                    border: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                RoleField(controller: _roleController),
                const SizedBox(height: 16),
                TextField(
                  controller: _systemPromptController,
                  minLines: 10,
                  maxLines: 28,
                  decoration: const InputDecoration(
                    labelText: 'System prompt',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SkillMultiSelect(
                  selectedNames: _skills,
                  onChanged: (skills) => setState(() => _skills = skills),
                ),
                const SizedBox(height: 16),
                RuleMultiSelect(
                  selectedNames: _rules,
                  onChanged: (rules) => setState(() => _rules = rules),
                ),
                const SizedBox(height: 16),
                HookMultiSelect(
                  selectedNames: _hooks,
                  onChanged: (hooks) => setState(() => _hooks = hooks),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 4),
                  child: Text(
                    widget.initial?.name == kKeelAiHandleForHooks
                        ? 'Keel AI corre sin hooks a propósito: es a quien le '
                              'pedís apagar uno que te trabó. Lo que asignes '
                              'acá no se va a aplicar.'
                        : 'Corren fuera del modelo, así que no los puede '
                              'saltear. Las reglas de arriba se piden; estos '
                              'se cumplen.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const SizedBox(height: 16),
                ToolMultiSelect(
                  selectedNames: _tools,
                  onChanged: (tools) => setState(() => _tools = tools),
                ),
                const SizedBox(height: 16),
                McpServerMultiSelect(
                  selectedNames: _mcpServers,
                  onChanged: (servers) =>
                      setState(() => _mcpServers = servers),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Puede administrar el sistema'),
                  subtitle: const Text(
                    'Agente constructor: recibe las mismas tools de creación '
                    'que Keel AI (skills, reglas, tools, agentes, workflows, '
                    'estaciones) en sus chats 1:1.',
                  ),
                  contentPadding: EdgeInsets.zero,
                  value: _canManageSystem,
                  onChanged: (value) =>
                      setState(() => _canManageSystem = value),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<AgentProvider>(
                  initialValue: _provider,
                  decoration: const InputDecoration(
                    labelText:
                        'Proveedor (codex: sin tools/MCPs/esfuerzo, y sus '
                        'propios modelos)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                    ),
                  ),
                  items: [
                    for (final provider in AgentProvider.values)
                      DropdownMenuItem(
                        value: provider,
                        child: Text(provider.label),
                      ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    // The two CLIs share no model names, so the current pick
                    // means nothing to the new provider: fall back to its
                    // own default instead of carrying a foreign alias over.
                    setState(() {
                      _provider = value;
                      _model = defaultModelFor(value);
                    });
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  key: ValueKey(_provider),
                  initialValue: _model,
                  decoration: InputDecoration(
                    labelText: 'Modelo por defecto (${_provider.label})',
                    border: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                    ),
                  ),
                  items: [
                    for (final option in modelOptionsFor(_provider))
                      DropdownMenuItem(
                        value: option.alias,
                        child: Text(option.label),
                      ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _model = value);
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _effort,
                  decoration: const InputDecoration(
                    labelText: 'Esfuerzo por defecto',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                    ),
                  ),
                  items: [
                    for (final level in kEffortLevels)
                      DropdownMenuItem(
                        value: level.alias,
                        child: Text(level.label),
                      ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _effort = value);
                  },
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
