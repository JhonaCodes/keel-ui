import 'package:flutter/material.dart';

import 'package:keel_ui/src/modules/projects/model/session_decision.dart';

/// La tarjeta de «te está esperando»: una pregunta, un permiso o una
/// aprobación que un agente le pidió al usuario y sin la cual el nodo no
/// sigue.
///
/// Vive sobre el composer, en el mismo lugar que la tarjeta de permiso y el
/// banner del plan, porque es la misma clase de cosa: un turno suspendido
/// esperándote. Muestra una decisión a la vez, la más vieja; la cola entera
/// llega con la fase de permisos bloqueantes.
class SessionDecisionCard extends StatefulWidget {
  const SessionDecisionCard({
    super.key,
    required this.decision,
    required this.memberHandle,
    required this.onAnswer,
    required this.onApprove,
    required this.onReject,
    required this.onPermission,
  });

  final SessionDecision decision;
  final String memberHandle;
  final ValueChanged<String> onAnswer;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  /// Un permiso concedido ([grant] true) o rechazado, con hasta dónde vale:
  /// once | session | profile | app.
  final void Function(bool grant, String scope) onPermission;

  @override
  State<SessionDecisionCard> createState() => _SessionDecisionCardState();
}

class _SessionDecisionCardState extends State<SessionDecisionCard> {
  final _controller = TextEditingController();
  bool _answered = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _answered) return;
    setState(() => _answered = true);
    widget.onAnswer(trimmed);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final decision = widget.decision;
    final isApproval = decision.kind == SessionDecisionKind.approval;
    final isPermission =
        decision.kind == SessionDecisionKind.permission && decision.blocking;

    void permit(bool grant, String scope) {
      if (_answered) return;
      setState(() => _answered = true);
      widget.onPermission(grant, scope);
    }

    return Material(
      color: scheme.tertiaryContainer.withValues(alpha: 0.35),
      child: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: scheme.outlineVariant)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  switch (decision.kind) {
                    SessionDecisionKind.question => Icons.help_outline_rounded,
                    SessionDecisionKind.permission => Icons.lock_open_rounded,
                    SessionDecisionKind.approval =>
                      Icons.fact_check_outlined,
                  },
                  size: 16,
                  color: scheme.tertiary,
                ),
                const SizedBox(width: 8),
                Text(
                  'ESPERÁNDOTE',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                    letterSpacing: 1.1,
                    color: scheme.outline,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '@${widget.memberHandle} · ${decision.title}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (decision.detail.isNotEmpty) ...[
              const SizedBox(height: 6),
              SelectableText(
                decision.detail,
                style: const TextStyle(fontSize: 13),
              ),
            ],
            const SizedBox(height: 8),
            if (isPermission)
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  OutlinedButton(
                    onPressed: _answered ? null : () => permit(false, 'once'),
                    child: const Text('Rechazar'),
                  ),
                  FilledButton.tonal(
                    onPressed: _answered ? null : () => permit(true, 'once'),
                    child: const Text('Solo esta vez'),
                  ),
                  FilledButton.tonal(
                    onPressed: _answered
                        ? null
                        : () => permit(true, 'session'),
                    child: const Text('Esta sesión'),
                  ),
                  FilledButton.tonal(
                    onPressed: _answered
                        ? null
                        : () => permit(true, 'profile'),
                    child: const Text('Este agente acá'),
                  ),
                  FilledButton(
                    onPressed: _answered ? null : () => permit(true, 'app'),
                    child: const Text('Siempre'),
                  ),
                ],
              )
            else if (isApproval)
              Row(
                children: [
                  FilledButton.tonal(
                    onPressed: _answered
                        ? null
                        : () {
                            setState(() => _answered = true);
                            widget.onReject();
                          },
                    child: const Text('Rechazar'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _answered
                        ? null
                        : () {
                            setState(() => _answered = true);
                            widget.onApprove();
                          },
                    child: const Text('Aprobar y continuar'),
                  ),
                ],
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (decision.options.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final option in decision.options)
                          ActionChip(
                            label: Text(option),
                            onPressed: _answered
                                ? null
                                : () => _submit(option),
                          ),
                      ],
                    ),
                  if (decision.options.isNotEmpty) const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          enabled: !_answered,
                          minLines: 1,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            isDense: true,
                            hintText: 'Tu respuesta',
                            border: OutlineInputBorder(),
                          ),
                          onSubmitted: _submit,
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _answered
                            ? null
                            : () => _submit(_controller.text),
                        child: const Text('Responder'),
                      ),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
