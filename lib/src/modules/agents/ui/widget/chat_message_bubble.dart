import 'package:flutter/material.dart';
import 'package:info_label/info_label.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/src/core/ui/app_theme.dart';
import 'package:keel_ui/src/modules/agents/model/chat_message.dart';
import 'package:keel_ui/src/modules/agents/model/file_edit.dart';
import 'package:keel_ui/src/modules/agents/service/chat_actions.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/bubble_width.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/chat_message_body.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/chat_notice_label.dart';
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
    required this.agentColor,
    this.actions = const LocalChatActions(),
    this.fontScaleOverride,
  });

  final ChatMessage message;
  final String agentId;

  /// The agent's own colour, so a system trace line ("Creé la skill …") is
  /// visibly ITS trace and not an anonymous app notice.
  final Color agentColor;

  final ChatActions actions;

  /// Font scale handed down instead of read from the local settings
  /// singleton. The assistant window's engine has no database, so its
  /// settings only ever hold defaults — main sends the real value in the
  /// snapshot (see `AssistantWindowState.chatFontScale`).
  final double? fontScaleOverride;

  @override
  Widget build(BuildContext context) {
    final override = fontScaleOverride;
    if (override != null) {
      return _ChatMessageBubbleContent(
        message: message,
        agentId: agentId,
        agentColor: agentColor,
        actions: actions,
        fontScale: override,
      );
    }

    return ReactiveViewModelBuilder<SettingsViewModel, AppSettings>(
      viewmodel: SettingsService.instance.notifier,
      build: (settings, viewmodel, keep) => _ChatMessageBubbleContent(
        message: message,
        agentId: agentId,
        agentColor: agentColor,
        actions: actions,
        fontScale: settings.chatFontScale,
      ),
    );
  }
}

class _ChatMessageBubbleContent extends StatelessWidget {
  const _ChatMessageBubbleContent({
    required this.message,
    required this.agentId,
    required this.agentColor,
    required this.actions,
    required this.fontScale,
  });

  final ChatMessage message;
  final String agentId;
  final Color agentColor;
  final ChatActions actions;
  final double fontScale;

  @override
  Widget build(BuildContext context) {
    if (message.role == ChatRole.error || message.role == ChatRole.blocked) {
      return ChatNoticeLabel(
        role: message.role,
        text: message.text,
        fontSize: 13 * fontScale,
      );
    }

    // Left, with the thread — centred it read as a divider between
    // messages rather than as one more thing the agent did.
    if (message.role == ChatRole.system) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: InfoLabel(
            text: message.text,
            typeInfoLabel: TypeInfoLabel.neutral,
            // Estas notas van de una línea (una mención que no llegó) a doce
            // (el plan de la sesión). Con el icono centrado, un bloque largo lo
            // deja flotando en el medio, lejos del renglón que encabeza.
            crossAxisAlignment: CrossAxisAlignment.start,
            leftIcon: Icon(
              Icons.smart_toy_outlined,
              size: 14,
              color: agentColor,
            ),
            fontSize: 12 * fontScale,
          ),
        ),
      );
    }

    final scheme = Theme.of(context).colorScheme;

    final alignment = switch (message.role) {
      ChatRole.user => Alignment.centerRight,
      ChatRole.assistant => Alignment.centerLeft,
      ChatRole.error || ChatRole.blocked => Alignment.centerLeft,
      ChatRole.system => Alignment.center,
    };

    // Your own messages sit on the cool blue the palette reserves for them,
    // not on the brass container: brass on brass-deep measures 3.6:1, under
    // the 4.5:1 floor for body text, and the letters sink into their own
    // bubble. Ink on this blue is 10.3:1. Same two tokens the project thread
    // already uses, so "you" reads identically in a 1:1 chat and a channel.
    final background = switch (message.role) {
      ChatRole.user => AppColors.userBubble,
      ChatRole.assistant => scheme.surfaceContainerHighest,
      ChatRole.error || ChatRole.blocked => scheme.errorContainer,
      // Unreachable — ChatRole.system returns early above.
      ChatRole.system => scheme.surfaceContainerHighest,
    };

    final foreground = switch (message.role) {
      ChatRole.user => scheme.onSurface,
      ChatRole.assistant => scheme.onSurface,
      ChatRole.error || ChatRole.blocked => scheme.onErrorContainer,
      ChatRole.system => scheme.onSurface,
    };

    final borderSide = switch (message.role) {
      ChatRole.user => const BorderSide(color: AppColors.userBubbleBorder),
      ChatRole.assistant => BorderSide.none,
      ChatRole.error || ChatRole.blocked => BorderSide.none,
      ChatRole.system => BorderSide.none,
    };

    final tier = bubbleWidthTierFor(message.text);

    final bubble = Align(
      alignment: alignment,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return _HoverDeleteOverlay(
            onDelete: () => actions.deleteMessage(agentId, message.timestamp),
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
                    workingDirectory: AgentsService
                        .instance
                        .notifier
                        .looseAgentWorkingDirectory,
                    windowAgentId: agentId,
                    onAskAboutLine:
                        ({
                          required filePath,
                          required lineNumber,
                          required lineContent,
                          required question,
                        }) => actions.askAboutLine(
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
                        }) async => actions.recordManualEdit(
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
