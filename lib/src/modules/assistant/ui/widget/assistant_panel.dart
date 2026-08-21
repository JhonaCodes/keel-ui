import 'package:flutter/material.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/src/core/ui/form_panel.dart';
import 'package:keel_ui/src/modules/agents/model/agent.dart';
import 'package:keel_ui/src/modules/agents/model/chat_message.dart';
import 'package:keel_ui/src/modules/agents/ui/view/chat_view.dart';
import 'package:keel_ui/src/modules/agents/viewmodel/agents_viewmodel.dart';
import 'package:keel_ui/src/modules/assistant/ui/widget/assistant_welcome_card.dart';

Future<void> openAssistantPanel(BuildContext context) {
  // Resolved here, in the button's tap handler — outside any widget build
  // phase — never inside the panel itself. `resolveKeelAiSession` can
  // mutate `AgentsViewModel` (starting a session), and `initState` still
  // runs as part of `StatefulElement._firstBuild`, i.e. inside the build
  // phase: mutating there trips "setState() or markNeedsBuild() called
  // during build" on every other mounted listener of that same notifier.
  final agentId = AgentsService.instance.notifier.resolveKeelAiSession();
  return showFormPanel<void>(
    context,
    child: AssistantPanel(initialAgentId: agentId),
  );
}

/// The Keel AI panel — a chat with the reserved system-assistant profile,
/// kept separate from the main window's own focused conversation. Reuses
/// [ChatView] for the chat mechanics; owns only which session is on screen
/// and the empty-state welcome card. Session resolution/creation itself is
/// [AgentsViewModel] business logic, not this widget's — see
/// [openAssistantPanel].
class AssistantPanel extends StatefulWidget {
  const AssistantPanel({super.key, required this.initialAgentId});

  final String? initialAgentId;

  @override
  State<AssistantPanel> createState() => _AssistantPanelState();
}

class _AssistantPanelState extends State<AssistantPanel> {
  final _controller = TextEditingController();
  late String? _selectedAgentId = widget.initialAgentId;

  void _newConversation() {
    // Safe here: a button's onPressed runs outside the build phase, unlike
    // initState — see the note on openAssistantPanel.
    final id = AgentsService.instance.notifier.startNewKeelAiSession();
    if (id == null) return;
    setState(() => _selectedAgentId = id);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ReactiveViewModelBuilder<AgentsViewModel, AgentsState>(
      viewmodel: AgentsService.instance.notifier,
      build: (state, viewmodel, keep) {
        final agent = state.agents
            .where((entry) => entry.id == _selectedAgentId)
            .firstOrNull;
        final sessions = agent == null
            ? const <Agent>[]
            : (state.agents
                  .where((entry) => entry.profileId == agent.profileId)
                  .toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt)));

        return Scaffold(
          appBar: AppBar(
            title: const Text('Asistente'),
            actions: [
              if (sessions.length > 1)
                _SessionsMenu(
                  sessions: sessions,
                  selectedId: _selectedAgentId,
                  onSelect: (id) => setState(() => _selectedAgentId = id),
                ),
              IconButton(
                tooltip: 'Nueva conversación',
                icon: const Icon(Icons.add_comment_outlined),
                onPressed: _newConversation,
              ),
            ],
          ),
          body: agent == null
              ? const Center(child: CircularProgressIndicator())
              : ChatView(
                  key: ValueKey(agent.id),
                  agent: agent,
                  controller: _controller,
                  emptyState: AssistantWelcomeCard(
                    onExampleTap: (prompt) =>
                        setState(() => _controller.text = prompt),
                  ),
                ),
        );
      },
    );
  }
}

class _SessionsMenu extends StatelessWidget {
  const _SessionsMenu({
    required this.sessions,
    required this.selectedId,
    required this.onSelect,
  });

  final List<Agent> sessions;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  String _label(Agent session) {
    final time =
        '${session.createdAt.hour.toString().padLeft(2, '0')}:'
        '${session.createdAt.minute.toString().padLeft(2, '0')}';
    final firstUserMessage = session.messages
        .where((message) => message.role == ChatRole.user)
        .firstOrNull;
    if (firstUserMessage == null) return 'Nueva ($time)';
    final firstLine = firstUserMessage.text.trim().split('\n').first;
    final preview = firstLine.length > 28
        ? '${firstLine.substring(0, 28)}…'
        : firstLine;
    return '$preview ($time)';
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Conversaciones',
      icon: const Icon(Icons.history),
      onSelected: onSelect,
      itemBuilder: (context) => [
        for (final session in sessions)
          CheckedPopupMenuItem(
            value: session.id,
            checked: session.id == selectedId,
            child: Text(_label(session)),
          ),
      ],
    );
  }
}
