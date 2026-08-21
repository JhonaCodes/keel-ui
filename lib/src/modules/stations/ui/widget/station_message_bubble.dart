import 'package:flutter/material.dart';
import 'package:info_label/info_label.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/src/core/ui/app_theme.dart';
import 'package:keel_ui/src/modules/agent_profiles/model/agent_profile.dart';
import 'package:keel_ui/src/modules/agents/model/chat_message.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/bubble_width.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/chat_message_body.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/inline_file_editor.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/reasoning_panel.dart';
import 'package:keel_ui/src/modules/settings/model/app_settings.dart';
import 'package:keel_ui/src/modules/settings/viewmodel/settings_viewmodel.dart';
import 'package:keel_ui/src/modules/stations/model/member_color.dart';
import 'package:keel_ui/src/modules/stations/ui/widget/member_avatar.dart';
import 'package:keel_ui/src/modules/stations/viewmodel/stations_viewmodel.dart';
import 'package:keel_ui/src/shared/shared.dart';

/// A message in a workstation channel. Unlike the 1:1 bubble, several authors
/// share this thread, so every agent message carries an avatar outside the
/// bubble (who wrote it) and which workflow step it belongs to.
class StationMessageBubble extends StatelessWidget {
  const StationMessageBubble({
    super.key,
    required this.message,
    required this.stationId,
    required this.author,
    required this.stepTitle,
    required this.askedBy,
    required this.memberIndex,
    required this.askedByIndex,
  });

  final ChatMessage message;
  final String stationId;
  final AgentProfile? author;
  final String? stepTitle;
  final AgentProfile? askedBy;
  final int memberIndex;
  final int askedByIndex;

  @override
  Widget build(BuildContext context) {
    return ReactiveViewModelBuilder<SettingsViewModel, AppSettings>(
      viewmodel: SettingsService.instance.notifier,
      build: (settings, viewmodel, keep) =>
          _Content(bubble: this, fontScale: settings.chatFontScale),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.bubble, required this.fontScale});

  final StationMessageBubble bubble;
  final double fontScale;

  @override
  Widget build(BuildContext context) {
    final message = bubble.message;

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

    final scheme = Theme.of(context).colorScheme;
    final isUser = message.role == ChatRole.user;
    final isConsult = bubble.askedBy != null;
    final accent = memberColorFor(bubble.memberIndex);

    // Your own messages sit on a cool blue, not on the amber accent: in the
    // mockup the accent belongs to the workflow chrome, and a brass bubble
    // would compete with it. A consult reply sits on the panel colour with a
    // dashed rule — same neutral border as any bubble, not accent-tinted.
    final background = switch ((isUser, isConsult)) {
      (true, _) => AppColors.userBubble,
      (false, true) => scheme.surfaceContainerLow,
      (false, false) => scheme.surfaceContainerHighest,
    };
    final askedByColor = memberColorFor(bubble.askedByIndex);
    final borderColor = switch ((isUser, isConsult)) {
      (true, _) => AppColors.userBubbleBorder,
      (false, true) => askedByColor,
      (false, false) => scheme.outlineVariant,
    };
    final foreground = scheme.onSurface;
    final tier = bubbleWidthTierFor(message.text);

    final bubbleContent = LayoutBuilder(
      builder: (context, constraints) {
        final decoration = BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
          border: isConsult ? null : Border.all(color: borderColor),
        );

        final content = Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          constraints: BoxConstraints(
            maxWidth: bubbleMaxWidthFor(tier, constraints.maxWidth),
          ),
          decoration: decoration,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser) _AuthorLine(bubble: bubble, accent: accent),
              ChatMessageBody(
                message: message,
                foreground: foreground,
                fontScale: fontScale,
              ),
              for (final fileEdit in message.fileEdits)
                InlineFileEditor(
                  fileEdit: fileEdit,
                  onAskAboutLine:
                      ({
                        required filePath,
                        required lineNumber,
                        required lineContent,
                        required question,
                      }) => StationsService.instance.notifier.askAboutLine(
                        bubble.stationId,
                        profileId: bubble.author?.id ?? '',
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
                      }) => StationsService.instance.notifier.recordManualEdit(
                        bubble.stationId,
                        profileId: bubble.author?.id ?? '',
                        filePath: filePath,
                      ),
                ),
            ],
          ),
        );

        return isConsult
            ? _DashedRoundedBorder(
                color: borderColor,
                radius: 12,
                child: content,
              )
            : content;
      },
    );

    final row = isUser
        ? bubbleContent
        : Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MemberAvatar(color: accent, small: isConsult),
              const SizedBox(width: 10),
              if (isConsult) ...[
                Container(width: 3, height: 34, color: askedByColor),
                const SizedBox(width: 8),
              ],
              Flexible(child: bubbleContent),
            ],
          );

    final bubbleBody = Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(top: 6, bottom: 6, left: isConsult ? 34 : 0),
        child: row,
      ),
    );

    final reasoning = message.reasoning;
    if (reasoning == null || reasoning.isEmpty) return bubbleBody;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: isConsult ? 34 : 4, bottom: 2),
          child: ReasoningPanel(text: reasoning),
        ),
        bubbleBody,
      ],
    );
  }
}

String _clockOf(DateTime at) {
  return '${at.hour.toString().padLeft(2, '0')}:'
      '${at.minute.toString().padLeft(2, '0')}';
}

/// The member's presence outside the bubble — a rounded-square glyph in
/// their colour, smaller for a nested consult reply.
class _AuthorLine extends StatelessWidget {
  const _AuthorLine({required this.bubble, required this.accent});

  final StationMessageBubble bubble;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final author = bubble.author;
    if (author == null) return const SizedBox.shrink();

    final isConsultReply = bubble.askedBy != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            author.name,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: accent,
            ),
          ),
          if (bubble.stepTitle != null && !isConsultReply)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: ShapeDecoration(
                color: scheme.secondaryContainer,
                shape: 4.smoothBorder(),
              ),
              child: Text(
                bubble.stepTitle!,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10,
                  color: scheme.onSecondaryContainer,
                ),
              ),
            ),
          if (isConsultReply)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: memberColorFor(
                  bubble.askedByIndex,
                ).withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: memberColorFor(bubble.askedByIndex),
                  width: 1,
                ),
              ),
              child: Text(
                'consulta de ${bubble.askedBy!.name}',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: memberColorFor(bubble.askedByIndex),
                ),
              ),
            ),
          Text(
            _clockOf(bubble.message.timestamp),
            style: TextStyle(
              fontSize: 11,
              color: scheme.outline,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// A dashed rounded-rectangle rule around [child] — the mockup marks a
/// consult (the bubble and its `asktag`) with a dashed border where every
/// other border in the app is solid, and `smoothBorder` has no dashed mode.
class _DashedRoundedBorder extends StatelessWidget {
  const _DashedRoundedBorder({
    required this.color,
    required this.radius,
    required this.child,
  });

  final Color color;
  final double radius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: _DashedRRectPainter(color: color, radius: radius),
      child: child,
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  _DashedRRectPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  static const _dashWidth = 4.0;
  static const _dashGap = 3.0;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0.5, 0.5, size.width - 1, size.height - 1),
      Radius.circular(radius),
    );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final metric = (Path()..addRRect(rrect)).computeMetrics().first;
    var distance = 0.0;
    while (distance < metric.length) {
      final next = (distance + _dashWidth).clamp(0.0, metric.length);
      canvas.drawPath(metric.extractPath(distance, next), paint);
      distance = next + _dashGap;
    }
  }

  @override
  bool shouldRepaint(_DashedRRectPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}
