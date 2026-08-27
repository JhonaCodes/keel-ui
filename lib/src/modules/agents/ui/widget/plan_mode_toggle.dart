import 'package:flutter/material.dart';

import 'package:keel_ui/src/modules/agents/model/agent_provider.dart';

/// El botón que decide si el próximo turno planifica o trabaja.
///
/// Vive en el compositor y no en el encabezado a propósito: es una decisión
/// sobre el mensaje que estás por mandar, y se toma mirando lo que escribiste.
///
/// El tooltip cambia con el proveedor porque lo que hay detrás cambia. En
/// Claude es el modo plan del propio CLI —su system prompt, su freno—; en
/// Codex y en los proveedores por API es una aproximación nuestra: se le
/// sacan las tools de escritura y se le explica por qué. Decir «modo plan» a
/// secas en los dos casos sería prometer lo mismo sobre dos cosas distintas.
class PlanModeToggle extends StatelessWidget {
  const PlanModeToggle({
    super.key,
    required this.enabled,
    required this.provider,
    required this.onChanged,
  });

  final bool enabled;
  final AgentProvider provider;
  final ValueChanged<bool> onChanged;

  static String tooltipFor(AgentProvider provider, {required bool enabled}) {
    if (enabled) return 'Modo plan activo: propone y no toca nada';
    return switch (provider) {
      AgentProvider.claude =>
        'Modo plan: que proponga cómo lo haría antes de tocar nada',
      _ =>
        'Modo plan: se le sacan las herramientas de escritura. '
            'Es una aproximación — el modo plan propio es el de Claude',
    };
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltipFor(provider, enabled: enabled),
      icon: Icon(
        enabled ? Icons.architecture : Icons.architecture_outlined,
        color: enabled ? Theme.of(context).colorScheme.primary : null,
      ),
      onPressed: () => onChanged(!enabled),
    );
  }
}
