import 'package:flutter/material.dart';
import 'package:info_label/info_label.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/src/core/ui/app_theme.dart';
import 'package:keel_ui/src/modules/agents/model/chat_message.dart';
import 'package:keel_ui/src/modules/agents/model/file_edit.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/bubble_width.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/chat_message_body.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/inline_file_editor.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/reasoning_panel.dart';
import 'package:keel_ui/src/modules/agents/viewmodel/agents_viewmodel.dart';
import 'package:keel_ui/src/modules/settings/model/app_settings.dart';
import 'package:keel_ui/src/modules/settings/viewmodel/settings_viewmodel.dart';
import 'package:keel_ui/src/shared/shared.dart';

class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.agentId,
  });

  final ChatMessage message;
  final String agentId;

  @override
  Widget build(BuildContext context) {
    return ReactiveViewModelBuilder<SettingsViewModel, AppSettings>(
      viewmodel: SettingsService.instance.notifier,
      build: (settings, viewmodel, keep) => _ChatMessageBubbleContent(
        message: message,
        agentId: agentId,
        fontScale: settings.chatFontScale,
      ),
    );
  }
}

class _ChatMessageBubbleContent extends StatelessWidget {
  const _ChatMessageBubbleContent({
    required this.message,
    required this.agentId,
    required this.fontScale,
  });

  final ChatMessage message;
  final String agentId;
  final double fontScale;

  @override
  Widget build(BuildContext context) {
    if (message.role == ChatRole.error) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: InfoLabel(
            text: message.text,
            typeInfoLabel: TypeInfoLabel.error,
            leftIcon: const Icon(Icons.error_outline, size: 14),
            fontSize: 13 * fontScale,
          ),
        ),
      );
    }

    if (message.role == ChatRole.system) {
      return Align(
        alignment: Alignment.center,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: InfoLabel(
            text: message.text,
            typeInfoLabel: TypeInfoLabel.neutral,
            leftIcon: const Icon(Icons.smart_toy_outlined, size: 14),
            fontSize: 12 * fontScale,
          ),
        ),
      );
    }

    final scheme = Theme.of(context).colorScheme;

    final alignment = switch (message.role) {
      ChatRole.user => Alignment.centerRight,
      ChatRole.assistant => Alignment.centerLeft,
      ChatRole.error => Alignment.centerLeft,
      ChatRole.system => Alignment.center,
    };

    // Your own messages sit on the cool blue the palette reserves for them,
    // not on the brass container: brass on brass-deep measures 3.6:1, under
    // the 4.5:1 floor for body text, and the letters sink into their own
    // bubble. Ink on this blue is 10.3:1. Same two tokens the station thread
    // already uses, so "you" reads identically in a 1:1 chat and a channel.
    final background = switch (message.role) {
      ChatRole.user => AppColors.userBubble,
      ChatRole.assistant => scheme.surfaceContainerHighest,
      ChatRole.error => scheme.errorContainer,
      // Unreachable — ChatRole.system returns early above.
      ChatRole.system => scheme.surfaceContainerHighest,
    };

    final foreground = switch (message.role) {
      ChatRole.user => scheme.onSurface,
      ChatRole.assistant => scheme.onSurface,
      ChatRole.error => scheme.onErrorContainer,
      ChatRole.system => scheme.onSurface,
    };

    final borderSide = switch (message.role) {
      ChatRole.user => const BorderSide(color: AppColors.userBubbleBorder),
      ChatRole.assistant => BorderSide.none,
      ChatRole.error => BorderSide.none,
      ChatRole.system => BorderSide.none,
    };

    final tier = bubbleWidthTierFor(message.text);

    final bubble = Align(
      alignment: alignment,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return _HoverDeleteOverlay(
            onDelete: () => AgentsService.instance.notifier.deleteMessage(
              agentId,
              message.timestamp,
            ),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 6),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              constraints: BoxConstraints(
                maxWidth: bubbleMaxWidthFor(tier, constraints.maxWidth),
              ),
              decoration: ShapeDecoration(
                color: background,
                shape: 16.smoothBorder(side: borderSide),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ChatMessageBody(
                    message: message,
                    foreground: foreground,
                    fontScale: fontScale,
                  ),
                  for (final fileEdit in message.fileEdits)
                    InlineFileEditor(
                      fileEdit: fileEdit,
                      windowAgentId: agentId,
                      onAskAboutLine:
                          ({
                            required filePath,
                            required lineNumber,
                            required lineContent,
                            required question,
                          }) => AgentsService.instance.notifier.askAboutLine(
                            agentId,
                            filePath: filePath,
                            lineNumber: lineNumber,
                            lineContent: lineContent,
                            question: question,
                          ),
                      onManualEditSaved:
                          ({
                            required filePath,
                            required beforeContent,
                            required afterContent,
                          }) async =>
                              AgentsService.instance.notifier.recordManualEdit(
                                agentId,
                                FileEdit(
                                  path: filePath,
                                  beforeContent: beforeContent,
                                  afterContent: afterContent,
                                ),
                              ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );

    final reasoning = message.reasoning;
    if (reasoning == null || reasoning.isEmpty) return bubble;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 2),
          child: ReasoningPanel(text: reasoning),
        ),
        bubble,
      ],
    );
  }
}

class _HoverDeleteOverlay extends StatefulWidget {
  const _HoverDeleteOverlay({required this.onDelete, required this.child});

  final VoidCallback onDelete;
  final Widget child;

  @override
  State<_HoverDeleteOverlay> createState() => _HoverDeleteOverlayState();
}

class _HoverDeleteOverlayState extends State<_HoverDeleteOverlay> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          widget.child,
          if (_hovering)
            Positioned(
              top: -6,
              right: -6,
              child: Material(
                color: scheme.errorContainer,
                shape: const CircleBorder(),
                elevation: 2,
                child: IconButton(
                  tooltip: 'Eliminar mensaje',
                  icon: Icon(
                    Icons.close,
                    size: 14,
                    color: scheme.onErrorContainer,
                  ),
                  constraints: const BoxConstraints.tightFor(
                    width: 26,
                    height: 26,
                  ),
                  padding: EdgeInsets.zero,
                  onPressed: widget.onDelete,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
