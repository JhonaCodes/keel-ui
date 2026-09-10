import 'package:flutter/material.dart';

import 'package:keel_ui/l10n/generated/app_localizations.dart';
import 'package:keel_ui/src/core/ui/app_theme.dart';
import 'package:keel_ui/src/modules/agents/model/chat_message.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/bubble_width.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/markdown_text.dart';

/// El tono de una nota del hilo: qué color la enmarca, qué ícono la firma y
/// cómo se titula.
///
/// Es un tipo y no tres variables sueltas porque los tres valores tienen que
/// moverse juntos: un borde ámbar con el ícono de excepción, o un título de
/// falla sobre el color de advertencia, es exactamente la confusión que este
/// widget existe para evitar.
@immutable
class _NoticeTone {
  const _NoticeTone({
    required this.accent,
    required this.icon,
    required this.title,
  });

  final Color accent;
  final IconData icon;
  final String title;
}

/// Una nota del hilo que no escribió nadie: una falla de ejecución, o un
/// cierre bloqueado del workflow.
///
/// Se lee como una burbuja más del chat —mismo radio, mismo ancho, mismo
/// cuerpo markdown— y no como un cartel aparte. Antes era una caja plana con
/// el texto crudo pintado del color del tono: un informe largo salía como un
/// muro ámbar sobre ámbar, sin viñetas, sin código en línea y sin un título
/// que dijera qué se estaba mirando. El contenido no cambió; cambió que
/// ahora se puede leer.
///
/// El color solo enmarca —borde, ícono y título—; el cuerpo va sobre la tinta
/// normal del tema. Un párrafo entero teñido de amarillo es más difícil de
/// leer que uno neutro, y el tono ya está dicho por el marco.
///
/// La distinción entre [ChatRole.error] y [ChatRole.blocked] es el motivo por
/// el que este widget existe y no se toca: un caso bloqueado es un resultado
/// ESPERADO del workflow, y cuando el hilo lo pintaba del rojo de la
/// excepción se leía como un crash de la app.
class ChatNoticeBubble extends StatelessWidget {
  const ChatNoticeBubble({
    super.key,
    required this.role,
    required this.text,
    required this.fontSize,
  });

  final ChatRole role;
  final String text;
  final double fontSize;

  _NoticeTone _toneFor(AppLocalizations l10n, ColorScheme scheme) {
    // Sin `default`: un rol nuevo rompe la compilación acá, en vez de
    // heredar en silencio el tono de la falla.
    return switch (role) {
      ChatRole.error => _NoticeTone(
        accent: scheme.error,
        icon: Icons.error_outline,
        title: l10n.chatNoticeFailureTitle,
      ),
      ChatRole.blocked => _NoticeTone(
        accent: AppColors.brass,
        icon: Icons.block,
        title: l10n.chatNoticeWarningTitle,
      ),
      // Un mensaje de una persona, de un agente o una nota de la app no
      // llega acá: las burbujas lo atajan antes. Si alguna vez llegara, se
      // ve como información neutra — nunca como una falla.
      ChatRole.user || ChatRole.assistant || ChatRole.system => _NoticeTone(
        accent: scheme.outline,
        icon: Icons.info_outline,
        title: l10n.chatNoticeInfoTitle,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tone = _toneFor(AppLocalizations.of(context), scheme);
    final tier = bubbleWidthTierFor(text);

    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: LayoutBuilder(
          builder: (context, constraints) => Container(
            constraints: BoxConstraints(
              maxWidth: bubbleMaxWidthFor(tier, constraints.maxWidth),
            ),
            decoration: BoxDecoration(
              // El tinte es del acento pero apenas: lo suficiente para que la
              // burbuja no sea una más, no tanto como para competir con el
              // texto que lleva adentro.
              color: Color.alphaBlend(
                tone.accent.withValues(alpha: 0.06),
                scheme.surfaceContainerHighest,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: tone.accent, width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _NoticeHeader(tone: tone),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: tone.accent.withValues(alpha: 0.3),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                  child: MarkdownText(
                    text,
                    color: scheme.onSurface,
                    fontSize: fontSize,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// La franja de identidad: de quién es la nota, de qué tipo es y cómo se
/// llama.
class _NoticeHeader extends StatelessWidget {
  const _NoticeHeader({required this.tone});

  final _NoticeTone tone;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 9, 14, 9),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // El logo firma la nota: la escribió Keel, no el agente ni vos.
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Image.asset(
              'assets/icon.png',
              width: 16,
              height: 16,
              filterQuality: FilterQuality.medium,
            ),
          ),
          const SizedBox(width: 8),
          Icon(tone.icon, size: 15, color: tone.accent),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              tone.title.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                height: 1.2,
                letterSpacing: 1.1,
                fontWeight: FontWeight.w600,
                color: tone.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
