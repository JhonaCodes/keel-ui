import 'dart:async';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:multiselect_field/multiselect_field.dart';

import 'package:keel_ui/src/modules/agents/model/agent.dart';
import 'package:keel_ui/src/modules/agents/model/agent_model_option.dart';
import 'package:keel_ui/src/modules/agents/service/chat_actions.dart';
import 'package:keel_ui/src/modules/agents/service/chat_attachment_store.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/chat_attachment_strip.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/chat_composer_field.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/chat_message_bubble.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/queued_messages_strip.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/agent_activity_indicator.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/agent_status_icon.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/context_usage_ring.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/effort_level_selector.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/fade_in_entrance.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/permission_request_banner.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/provider_badge.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/reasoning_panel.dart';
import 'package:keel_ui/src/shared/shared.dart';

class ChatView extends StatefulWidget {
  const ChatView({
    super.key,
    required this.agent,
    this.controller,
    this.emptyState,
    this.actions = const LocalChatActions(),
    this.fontScaleOverride,
  });

  final Agent agent;

  /// Where the user's intents actually execute. The default talks to this
  /// engine's [AgentsService] singleton; the dedicated assistant window
  /// swaps in an RPC bridge because its engine's singletons are empty.
  final ChatActions actions;

  /// Lets a caller that also wants to fill the composer from outside (e.g.
  /// the Assistant panel's example prompts) own the controller instead of
  /// this widget creating its own. Defaults to an internally-owned one, so
  /// every other caller is unaffected.
  final TextEditingController? controller;

  /// Font scale to use instead of this engine's settings singleton. The
  /// assistant window has no database, so its settings hold defaults only —
  /// main sends the real value with the snapshot.
  final double? fontScaleOverride;

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

  /// Images already copied into app storage, waiting to travel with the
  /// next message. Stored paths, not the originals — see
  /// [ChatAttachmentStore].
  final List<String> _attachments = [];

  /// A drag is hovering the chat, so the drop hint is showing.
  bool _isDragging = false;

  @override
  void dispose() {
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  /// Sends, or QUEUES when the agent is mid-turn — the ViewModel decides.
  /// The composer never refuses input: a correction you thought of while
  /// the model works is exactly the one worth writing down.
  void _send() {
    final text = _controller.text;
    if (text.trim().isEmpty && _attachments.isEmpty) return;
    widget.actions.sendMessage(
      widget.agent.id,
      text,
      imagePaths: [..._attachments],
    );
    _controller.clear();
    setState(_attachments.clear);
  }

  Future<void> _pickImages() async {
    final files = await openFiles(
      acceptedTypeGroups: [
        XTypeGroup(
          label: 'Imágenes',
          extensions: ChatAttachmentStore.supportedExtensions.toList(),
        ),
      ],
    );
    await _attach([for (final file in files) file.path]);
  }

  Future<void> _onDropDone(DropDoneDetails details) async {
    setState(() => _isDragging = false);
    await _attach([for (final file in details.files) file.path]);
  }

  /// Everything dropped or picked goes through here: non-images are
  /// discarded silently (a drag can carry a folder or a PDF) and the rest
  /// is copied into app storage before it is ever shown as a thumbnail.
  Future<void> _attach(List<String> paths) async {
    if (paths.isEmpty) return;
    final stored = await ChatAttachmentStore.adoptImages(paths);
    if (!mounted || stored.isEmpty) return;
    setState(() => _attachments.addAll(stored));
  }

  void _removeAttachment(String path) {
    setState(() => _attachments.remove(path));
    // Never sent, so the stored copy has no reason to survive.
    unawaited(ChatAttachmentStore.discard(path));
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
      widget.actions.deleteAgent(agent.id);
    }
  }

  void _onModelChanged(List<Choice<String>> selected) {
    if (selected.isEmpty) return;
    final model = selected.first.key;
    if (model == null) return;
    widget.actions.setAgentModel(widget.agent.id, model);
  }

  Future<void> _toggleFullFileSystemAccess() async {
    final agent = widget.agent;

    if (agent.fullFileSystemAccess) {
      widget.actions.setAgentFullFileSystemAccess(agent.id, false);
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
      widget.actions.setAgentFullFileSystemAccess(agent.id, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final agent = widget.agent;

    // The drop area is the WHOLE chat, not just the composer: you drag a
    // screenshot at the conversation you are reading, not at a 40px input.
    return DropTarget(
      onDragEntered: (_) => setState(() => _isDragging = true),
      onDragExited: (_) => setState(() => _isDragging = false),
      onDragDone: _onDropDone,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Column(
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
                    Text(
                      agent.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(width: 6),
                    ProviderBadge(provider: agent.provider),
                    const SizedBox(width: 8),
                    // Each provider runs its own CLI with its own model
                    // names: a codex agent must never be offered `sonnet`.
                    MultiSelectField<String>.chip(
                      key: ValueKey(agent.provider),
                      label: 'Modelo',
                      singleSelection: true,
                      chipSize: ChipSize.small,
                      data: () => [
                        for (final option in modelOptionsFor(agent.provider))
                          Choice(option.alias, option.label),
                      ],
                      defaultData: [
                        Choice(
                          initialModelFor(agent.provider, agent.model),
                          modelLabelFor(
                            agent.provider,
                            initialModelFor(agent.provider, agent.model),
                          ),
                        ),
                      ],
                      onChanged: _onModelChanged,
                    ),
                    const SizedBox(width: 4),
                    EffortLevelSelector(
                      effort: agent.effort,
                      onChanged: (effort) =>
                          widget.actions.setAgentEffort(agent.id, effort),
                    ),
                    const SizedBox(width: 4),
                    ContextUsageRing(
                      ratio: agent.contextUsageRatio,
                      onCompact: () => widget.actions.requestCompact(agent.id),
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
                      onRespond: (grant) => widget.actions
                          .respondToPermissionRequest(agent.id, grant: grant),
                    ),
                  ),
                ),
              Expanded(
                child: agent.messages.isEmpty
                    ? widget.emptyState ??
                          const Center(
                            child: Text('Escríbele algo a tu agente'),
                          )
                    : SelectionArea(
                        child: ListView.builder(
                          reverse: true,
                          padding: const EdgeInsets.all(16),
                          itemCount: agent.messages.length,
                          itemBuilder: (context, index) {
                            final msgIndex = agent.messages.length - 1 - index;
                            final message = agent.messages[msgIndex];
                            return FadeInEntrance(
                              key: ValueKey(
                                message.timestamp.microsecondsSinceEpoch,
                              ),
                              child: ChatMessageBubble(
                                message: message,
                                agentId: agent.id,
                                agentColor: agent.iconColor,
                                actions: widget.actions,
                                fontScaleOverride: widget.fontScaleOverride,
                              ),
                            );
                          },
                        ),
                      ),
              ),
              if (agent.liveReasoning != null &&
                  agent.liveReasoning!.isNotEmpty)
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    QueuedMessagesStrip(
                      messages: agent.queuedMessages,
                      isStreaming: agent.isStreaming,
                      onRemove: (index) =>
                          widget.actions.removeQueuedMessage(agent.id, index),
                      onSendNow: () =>
                          widget.actions.sendQueuedMessages(agent.id),
                    ),
                    ChatAttachmentStrip(
                      paths: _attachments,
                      onRemove: _removeAttachment,
                    ),
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Adjuntar imagen',
                          icon: const Icon(Icons.image_outlined),
                          onPressed: _pickImages,
                        ),
                        Expanded(
                          child: Container(
                            decoration: ShapeDecoration(
                              shape: 16.smoothBorder(
                                side: BorderSide(
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                              ),
                            ),
                            child: ChatComposerField(
                              controller: _controller,
                              onSend: _send,
                              hintText: agent.isStreaming
                                  ? 'Escribí y se envía cuando termine…'
                                  : 'Escribe un mensaje…',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Mid-turn both intents exist at once — stop what is
                        // running, or add to what comes next — so both get
                        // their own button instead of one that changes
                        // meaning under the cursor.
                        if (agent.isStreaming)
                          IconButton(
                            tooltip: 'Detener',
                            onPressed: () => widget.actions.stopAgent(agent.id),
                            icon: const Icon(Icons.stop_circle),
                          ),
                        IconButton.filled(
                          tooltip: agent.isStreaming
                              ? 'Encolar para cuando termine'
                              : null,
                          onPressed: _send,
                          icon: Icon(
                            agent.isStreaming
                                ? Icons.schedule_send
                                : Icons.send,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_isDragging) const ChatDropHint(),
        ],
      ),
    );
  }
}
