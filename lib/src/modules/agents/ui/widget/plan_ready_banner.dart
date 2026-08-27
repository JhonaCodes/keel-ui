import 'package:flutter/material.dart';

import 'package:keel_ui/src/shared/shared.dart';

/// «Terminé de planificar. ¿Lo implemento?»
///
/// El CLI de Claude tiene modo plan pero, corriendo en `-p`, NO expone la
/// tool `ExitPlanMode` con la que normalmente se aprueba un plan: el agente
/// la busca, no la encuentra, y cierra el turno ofreciéndolo de palabra. Esta
/// tarjeta es ese apretón de manos, puesto de este lado.
///
/// Por eso aparece al terminar el turno y no cuando el agente avisa: no hay
/// nada que el agente pueda llamar para avisar. El costo de esa decisión es
/// que también aparece cuando el agente solo hizo una pregunta — y ahí
/// «Seguir planificando» la baja sin hacer nada.
///
/// Los botones no se apagan por `isStreaming` porque cuando esta tarjeta está
/// en pantalla el turno ya terminó; lo único que los apaga es haber
/// contestado, para que un doble click no mande dos turnos.
class PlanReadyBanner extends StatefulWidget {
  const PlanReadyBanner({
    super.key,
    required this.onImplement,
    required this.onKeepPlanning,
  });

  final VoidCallback onImplement;
  final VoidCallback onKeepPlanning;

  @override
  State<PlanReadyBanner> createState() => _PlanReadyBannerState();
}

class _PlanReadyBannerState extends State<PlanReadyBanner> {
  bool _answered = false;

  void _respond(VoidCallback action) {
    if (_answered) return;
    setState(() => _answered = true);
    action();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.all(14),
          decoration: ShapeDecoration(
            color: scheme.surfaceContainerHigh,
            shape: 16.smoothBorder(
              side: BorderSide(color: scheme.primary.withValues(alpha: 0.3)),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.architecture, size: 18, color: scheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'El plan está listo. Al implementarlo sale del modo '
                      'plan y arranca a escribir, sobre esta misma '
                      'conversación.',
                      style: TextStyle(color: scheme.onSurface, fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _answered
                        ? null
                        : () => _respond(widget.onKeepPlanning),
                    child: const Text('Seguir planificando'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _answered
                        ? null
                        : () => _respond(widget.onImplement),
                    child: const Text('Implementar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
