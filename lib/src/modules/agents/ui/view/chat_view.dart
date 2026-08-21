import 'package:flutter/material.dart';
import 'package:multiselect_field/multiselect_field.dart';

import 'package:keel_ui/src/modules/agents/model/agent.dart';
import 'package:keel_ui/src/modules/agents/model/claude_model_option.dart';
import 'package:keel_ui/src/modules/agents/viewmodel/agents_viewmodel.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/chat_message_bubble.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/agent_activity_indicator.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/agent_status_icon.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/context_usage_ring.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/effort_level_selector.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/fade_in_entrance.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/permission_request_banner.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/reasoning_panel.dart';
import 'package:keel_ui/src/shared/shared.dart';

class ChatView extends StatefulWidget {
  const ChatView({
    super.key,
    required this.agent,
    this.controller,
    this.emptyState,
  });

  final Agent agent;

  /// Lets a caller that also wants to fill the composer from outside (e.g.
  /// the Assistant panel's example prompts) own the controller instead of
  /// this widget creating its own. Defaults to an internally-owned one, so
  /// every other caller is unaffected.
  final TextEditingController? controller;

  /// Shown instead of the default "Escríbele algo a tu agente" text when
  /// [Agent.messages] is empty. Lets a caller (e.g. the Assistant panel)
  /// swap in something richer without this widget knowing what that is.
  final Widget? emptyState;

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  late final TextEditingController _controller =
      widget.controller ?? TextEditingController();

  bool get _ownsController => widget.controller == null;

  @override
  void dispose() {
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text;
    if (text.trim().isEmpty || widget.agent.isStreaming) return;
    AgentsService.instance.notifier.sendMessage(widget.agent.id, text);
    _controller.clear();
  }

  Future<void> _confirmAndDelete() async {
    final agent = widget.agent;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar agente'),
        content: Text('Se eliminará "${agent.name}" y su historial de chat.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      AgentsService.instance.notifier.deleteAgent(agent.id);
    }
  }

  void _onModelChanged(List<Choice<String>> selected) {
    if (selected.isEmpty) return;
    final model = selected.first.key;
    if (model == null) return;
    AgentsService.instance.notifier.setAgentModel(widget.agent.id, model);
  }

  Future<void> _toggleFullFileSystemAccess() async {
    final agent = widget.agent;

    if (agent.fullFileSystemAccess) {
      AgentsService.instance.notifier.setAgentFullFileSystemAccess(
        agent.id,
        false,
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dar acceso a todo el sistema de archivos'),
        content: Text(
          '"${agent.name}" podrá leer y escribir en cualquier carpeta del computador, no solo en tu carpeta de usuario.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Dar acceso'),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      AgentsService.instance.notifier.setAgentFullFileSystemAccess(
        agent.id,
        true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final agent = widget.agent;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.all(4),
                child: AgentStatusIcon(
                  color: agent.iconColor,
                  selected: true,
                  isWorking: agent.isStreaming,
                ),
              ),
              const SizedBox(width: 8),
              Text(agent.name, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(width: 8),
              MultiSelectField<String>.chip(
                label: 'Modelo',
                singleSelection: true,
                chipSize: ChipSize.small,
                data: () => [
                  for (final option in kClaudeModelOptions)
                    Choice(option.alias, option.label),
                ],
                defaultData: [
                  Choice(agent.model, claudeModelLabel(agent.model)),
                ],
                onChanged: _onModelChanged,
              ),
              const SizedBox(width: 4),
              EffortLevelSelector(
                effort: agent.effort,
                onChanged: (effort) => AgentsService.instance.notifier
                    .setAgentEffort(agent.id, effort),
              ),
              const SizedBox(width: 4),
              ContextUsageRing(
                ratio: agent.contextUsageRatio,
                onCompact: () =>
                    AgentsService.instance.notifier.requestCompact(agent.id),
              ),
              const Spacer(),
              IconButton(
                tooltip: agent.fullFileSystemAccess
                    ? 'Tiene acceso a todo el sistema de archivos (clic para quitarlo)'
                    : 'Dar acceso a todo el sistema de archivos',
                icon: Icon(
                  agent.fullFileSystemAccess
                      ? Icons.folder_open
                      : Icons.folder_off_outlined,
                  color: agent.fullFileSystemAccess
                      ? Theme.of(context).colorScheme.error
                      : null,
                ),
                onPressed: _toggleFullFileSystemAccess,
              ),
              IconButton(
                tooltip: 'Eliminar agente',
                icon: const Icon(Icons.delete_outline),
                onPressed: _confirmAndDelete,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        if (agent.pendingPermission != null)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 160),
            child: SingleChildScrollView(
              child: PermissionRequestBanner(
                request: agent.pendingPermission!,
                busy: agent.isStreaming,
                onRespond: (grant) => AgentsService.instance.notifier
                    .respondToPermissionRequest(agent.id, grant: grant),
              ),
            ),
          ),
        Expanded(
          child: agent.messages.isEmpty
              ? widget.emptyState ??
                    const Center(child: Text('Escríbele algo a tu agente'))
              : SelectionArea(
                  child: ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.all(16),
                    itemCount: agent.messages.length,
                    itemBuilder: (context, index) {
                      final msgIndex = agent.messages.length - 1 - index;
                      final message = agent.messages[msgIndex];
                      return FadeInEntrance(
                        key: ValueKey(message.timestamp.microsecondsSinceEpoch),
                        child: ChatMessageBubble(
                          message: message,
                          agentId: agent.id,
                        ),
                      );
                    },
                  ),
                ),
        ),
        if (agent.liveReasoning != null && agent.liveReasoning!.isNotEmpty)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 140),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: ReasoningPanel(
                    text: agent.liveReasoning!,
                    initiallyExpanded: true,
                  ),
                ),
              ),
            ),
          ),
        if (agent.currentActivity != null)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 60),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: AgentActivityIndicator(
                    activity: agent.currentActivity,
                  ),
                ),
              ),
            ),
          ),
        SizedBox(
          height: 2,
          child: agent.isStreaming
              ? const LinearProgressIndicator(minHeight: 2)
              : Divider(
                  height: 2,
                  thickness: 1,
                  color: Theme.of(context).dividerColor,
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: ShapeDecoration(
                    shape: 16.smoothBorder(
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ),
                  child: TextField(
                    controller: _controller,
                    enabled: !agent.isStreaming,
                    decoration: const InputDecoration(
                      hintText: 'Escribe un mensaje…',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: agent.isStreaming ? 'Detener' : null,
                onPressed: agent.isStreaming
                    ? () => AgentsService.instance.notifier.stopAgent(agent.id)
                    : _send,
                icon: Icon(agent.isStreaming ? Icons.stop_circle : Icons.send),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
