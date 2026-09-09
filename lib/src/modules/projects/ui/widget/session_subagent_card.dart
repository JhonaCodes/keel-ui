import 'package:keel_ui/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';

import 'package:keel_ui/src/modules/projects/model/session_subagent.dart';

/// Un subagente, en el hilo: qué se le pidió, en qué anda o qué devolvió.
///
/// Hasta acá los subagentes solo existían en el Mapa: en el chat quedaba una
/// línea transitoria de actividad y nada más. Que aparezcan donde se lee la
/// conversación es lo que permite ver que un padre abrió tres tareas que no
/// aportan nada, sin cambiar de pestaña.
class SessionSubagentCard extends StatefulWidget {
  const SessionSubagentCard({
    super.key,
    required this.subagent,
    required this.parentHandle,
  });

  final SessionSubagent subagent;
  final String parentHandle;

  @override
  State<SessionSubagentCard> createState() => _SessionSubagentCardState();
}

class _SessionSubagentCardState extends State<SessionSubagentCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final subagent = widget.subagent;
    final elapsed = subagent.elapsed;
    final elapsedLabel = elapsed.inMinutes >= 1
        ? '${elapsed.inMinutes} min'
        : '${elapsed.inSeconds} s';
    final phaseLabel = switch (subagent.phase) {
      SubagentPhase.thinking => t.subagentPhaseThinking,
      SubagentPhase.working => t.subagentPhaseWorking,
      SubagentPhase.writing => t.subagentPhaseWriting,
      SubagentPhase.done => t.subagentPhaseDone,
      SubagentPhase.failed => t.subagentPhaseFailed,
    };
    final result = subagent.result.trim();

    return Padding(
      padding: const EdgeInsets.only(left: 38, top: 4, bottom: 4),
      child: Material(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: result.isEmpty
              ? null
              : () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.account_tree_outlined,
                      size: 14,
                      color: scheme.outline,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'SUBAGENTE · ${subagent.agentType} · @${widget.parentHandle}',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                        letterSpacing: 1.0,
                        color: scheme.outline,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$phaseLabel · $elapsedLabel',
                      style: TextStyle(fontSize: 11, color: scheme.outline),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(subagent.ask, style: const TextStyle(fontSize: 12.5)),
                if (result.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    _expanded
                        ? result
                        : (result.length > 240
                              ? '${result.substring(0, 240)}…'
                              : result),
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
