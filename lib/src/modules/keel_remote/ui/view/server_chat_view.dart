import 'package:flutter/material.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_core/modules/agents/model/chat_message.dart';
import 'package:keel_ui/l10n/generated/app_localizations.dart';
import 'package:keel_ui/src/core/ui/app_theme.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/bubble_width.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/chat_composer_field.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/chat_notice_bubble.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/markdown_text.dart';
import 'package:keel_ui/src/modules/keel_remote/model/keel_nodes_state.dart';
import 'package:keel_ui/src/modules/keel_remote/model/server_chat.dart';
import 'package:keel_ui/src/modules/keel_remote/ui/keel_remote_presentation.dart';
import 'package:keel_ui/src/modules/keel_remote/ui/widget/keel_remote_parts.dart';
import 'package:keel_ui/src/modules/keel_remote/viewmodel/keel_nodes_viewmodel.dart';
import 'package:keel_ui/src/modules/keel_remote/viewmodel/server_chat_viewmodel.dart';
import 'package:keel_ui/src/shared/num_extension.dart';

/// The central area talking to Keel AI on a keel-server node.
class ServerChatView extends StatefulWidget {
  const ServerChatView({super.key});

  @override
  State<ServerChatView> createState() => _ServerChatViewState();
}

class _ServerChatViewState extends State<ServerChatView> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Which servers are online decides where the next message goes.
    KeelNodesService.instance.notifier.refresh();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final chat = ServerChatService.instance.notifier;
    if (chat.data.waiting || _controller.text.trim().isEmpty) return;
    final text = _controller.text;
    _controller.clear();
    chat.send(text);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return ReactiveViewModelBuilder<KeelNodesViewModel, KeelNodesState>(
      viewmodel: KeelNodesService.instance.notifier,
      build: (nodes, nodesViewmodel, keepNodes) =>
          ReactiveViewModelBuilder<ServerChatViewModel, ServerChatState>(
            viewmodel: ServerChatService.instance.notifier,
            build: (chat, viewmodel, keep) {
              final target = nodes.byId(viewmodel.targetNodeId);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ServerChatHeader(nodes: nodes, targetId: target?.id),
                  KeelLoadingBar(loading: chat.waiting),
                  const Divider(height: 1),
                  Expanded(
                    child: chat.messages.isEmpty
                        ? KeelEmptyText(
                            text: target == null
                                ? t.keelApiChatNoServer
                                : t.keelApiChatEmpty,
                          )
                        : SelectionArea(
                            child: _ServerChatThread(messages: chat.messages),
                          ),
                  ),
                  if (chat.waiting)
                    _ServerChatProgress(text: chat.progressLine(t)),
                  _ServerChatComposer(
                    controller: _controller,
                    waiting: chat.waiting,
                    onSend: _send,
                    onStop: viewmodel.cancel,
                  ),
                ],
              );
            },
          ),
    );
  }
}

class _ServerChatHeader extends StatelessWidget {
  const _ServerChatHeader({required this.nodes, required this.targetId});

  final KeelNodesState nodes;
  final String? targetId;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final servers = nodes.onlineServers;
    final chat = ServerChatService.instance.notifier;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 12, 10),
      child: Row(
        children: [
          const Icon(Icons.forum_outlined, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              t.keelApiChatTitle(nodes.byId(targetId)?.displayName ?? '—'),
              style: theme.textTheme.titleMedium,
            ),
          ),
          if (servers.length > 1)
            DropdownButton<String>(
              value: targetId,
              underline: const SizedBox.shrink(),
              hint: Text(t.keelApiChatServerLabel),
              onChanged: chat.selectNode,
              items: [
                for (final node in servers)
                  DropdownMenuItem<String>(
                    value: node.id,
                    child: Text(node.displayName),
                  ),
              ],
            ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: chat.newConversation,
            icon: const Icon(Icons.add_comment_outlined, size: 16),
            label: Text(t.keelApiChatNew),
          ),
        ],
      ),
    );
  }
}

class _ServerChatThread extends StatelessWidget {
  const _ServerChatThread({required this.messages});

  final List<ServerChatMessage> messages;

  @override
  Widget build(BuildContext context) {
    // Reversed so the newest message stays at the bottom, next to the
    // composer, as the thread grows.
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      itemCount: messages.length,
      itemBuilder: (context, index) =>
          _ServerChatBubble(message: messages[messages.length - 1 - index]),
    );
  }
}

class _ServerChatBubble extends StatelessWidget {
  const _ServerChatBubble({required this.message});

  final ServerChatMessage message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final failure = message.failure;
    if (message.role == ServerChatRole.notice && failure != null) {
      return ChatNoticeBubble(
        role: ChatRole.error,
        text: failure.message(AppLocalizations.of(context)),
        fontSize: 13,
      );
    }
    final fromPerson = message.role == ServerChatRole.person;
    final tier = bubbleWidthTierFor(message.text);
    return Align(
      alignment: fromPerson ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: LayoutBuilder(
          builder: (context, constraints) => Container(
            constraints: BoxConstraints(
              maxWidth: bubbleMaxWidthFor(tier, constraints.maxWidth),
            ),
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            decoration: BoxDecoration(
              color: fromPerson
                  ? AppColors.userBubble
                  : scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: MarkdownText(
              message.text,
              color: scheme.onSurface,
              fontSize: 13.5,
            ),
          ),
        ),
      ),
    );
  }
}

/// What Keel AI is doing on the node while it answers.
class _ServerChatProgress extends StatelessWidget {
  const _ServerChatProgress({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.outline,
        ),
      ),
    );
  }
}

class _ServerChatComposer extends StatelessWidget {
  const _ServerChatComposer({
    required this.controller,
    required this.waiting,
    required this.onSend,
    required this.onStop,
  });

  final TextEditingController controller;
  final bool waiting;
  final VoidCallback onSend;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: ShapeDecoration(
                shape: 16.smoothBorder(side: BorderSide(color: scheme.outline)),
              ),
              child: ChatComposerField(
                controller: controller,
                onSend: onSend,
                hintText: t.keelApiChatHint,
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (waiting)
            IconButton(
              tooltip: t.keelApiChatStop,
              onPressed: onStop,
              icon: const Icon(Icons.stop_circle),
            ),
          IconButton.filled(
            tooltip: t.keelApiChatSend,
            onPressed: waiting ? null : onSend,
            icon: const Icon(Icons.send),
          ),
        ],
      ),
    );
  }
}
