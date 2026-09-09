import 'package:keel_ui/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/src/core/ui/app_theme.dart';
import 'package:keel_ui/src/modules/agent_profiles/model/agent_profile.dart';
import 'package:keel_ui/src/modules/agents/model/chat_message.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/bubble_width.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/chat_message_body.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/chat_notice_label.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/reasoning_panel.dart';
import 'package:keel_ui/src/modules/settings/model/app_settings.dart';
import 'package:keel_ui/src/modules/settings/viewmodel/settings_viewmodel.dart';
import 'package:keel_ui/src/modules/projects/model/member_color.dart';
import 'package:keel_ui/src/modules/projects/model/session_message_reference.dart';
import 'package:keel_ui/src/modules/projects/ui/widget/member_avatar.dart';
import 'package:keel_ui/src/modules/projects/viewmodel/projects_viewmodel.dart';
import 'package:keel_ui/src/shared/shared.dart';

/// A message in a workstation channel. Unlike the 1:1 bubble, several authors
/// share this thread, so every agent message carries an avatar outside the
/// bubble (who wrote it) and which workflow step it belongs to.
class SessionMessageBubble extends StatelessWidget {
  const SessionMessageBubble({
    super.key,
    required this.message,
    required this.projectId,
    required this.sessionId,
    required this.author,
    required this.nodeTitle,
    required this.askedBy,
    required this.memberIndex,
    required this.askedByIndex,
  });

  final ChatMessage message;
  final String projectId;

  /// La sesión a la que pertenece este mensaje. Hace falta para armar la
  /// referencia que copia el botón: un id de mensaje derivado de un hilo
  /// histórico solo es único adentro de su sesión.
  final String sessionId;
  final AgentProfile? author;
  final String? nodeTitle;
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

  final SessionMessageBubble bubble;
  final double fontScale;

  @override
  Widget build(BuildContext context) {
    final message = bubble.message;

    if (message.role == ChatRole.error || message.role == ChatRole.blocked) {
      return ChatNoticeLabel(
        role: message.role,
        text: message.text,
        fontSize: 13 * fontScale,
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
              if (!isUser)
                _AuthorLine(bubble: bubble, accent: accent)
              else if (message.viaKeelAi)
                _OnBehalfLine(at: message.timestamp),
              ChatMessageBody(
                message: message,
                foreground: foreground,
                fontScale: fontScale,
                workingDirectory: ProjectsService.instance.notifier
                    .workingDirectoryOf(bubble.projectId),
                onAskAboutLine:
                    ({
                      required filePath,
                      required lineNumber,
                      required lineContent,
                      required question,
                    }) => ProjectsService.instance.notifier.askAboutLine(
                      bubble.projectId,
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
                    }) => ProjectsService.instance.notifier.recordManualEdit(
                      bubble.projectId,
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
              MemberAvatar(color: accent, size: isConsult ? 22 : 28),
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

  final SessionMessageBubble bubble;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final author = bubble.author;
    // Sin autor no es el mensaje de un miembro: es una nota que escribió la
    // app. Esas burbujas nunca tuvieron encabezado, y tampoco les toca el
    // botón de copiar referencia.
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
          if (bubble.nodeTitle != null && !isConsultReply)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: ShapeDecoration(
                color: scheme.secondaryContainer,
                shape: 4.smoothBorder(),
              ),
              child: Text(
                bubble.nodeTitle!,
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
                AppLocalizations.of(context).threadConsultOf(bubble.askedBy!.name),
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
          CopyMessageReferenceButton(
            reference: SessionMessageReference(
              projectId: bubble.projectId,
              sessionId: bubble.sessionId,
              messageId: bubble.message.id,
            ),
          ),
        ],
      ),
    );
  }
}

/// Se lo puso Keel AI: el usuario decidió la respuesta en el chat del
/// sistema y no la tipeó acá. Sin esta línea, al releer el hilo dentro de
/// una semana ese mensaje se lee como si lo hubiera escrito él a mano.
class _OnBehalfLine extends StatelessWidget {
  const _OnBehalfLine({required this.at});

  final DateTime at;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.smart_toy_outlined, size: 12, color: scheme.outline),
          const SizedBox(width: 5),
          Text(
            'Keel AI · en tu nombre',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: scheme.outline,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _clockOf(at),
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

/// Copia el token que apunta a ESTE mensaje, para pegarlo en el chat de Keel
/// AI y preguntarle a qué se refiere. Confirma con un tilde durante dos
/// segundos, igual que el visor de código.
class CopyMessageReferenceButton extends StatefulWidget {
  const CopyMessageReferenceButton({super.key, required this.reference});

  final SessionMessageReference reference;

  @override
  State<CopyMessageReferenceButton> createState() =>
      _CopyMessageReferenceButtonState();
}

class _CopyMessageReferenceButtonState
    extends State<CopyMessageReferenceButton> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.reference.token));
    if (!mounted) return;
    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: _copied ? 'Referencia copiada' : 'Copiar referencia',
      child: InkWell(
        onTap: _copy,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Icon(
            _copied ? Icons.check : Icons.link,
            size: 13,
            color: _copied ? scheme.primary : scheme.outline,
          ),
        ),
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
