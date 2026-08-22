import 'package:flutter/material.dart';

import 'package:keel_ui/src/modules/mcp_servers/model/mcp_probe_result.dart';

/// El punto de estado del último probe, con lo que contestó al lado.
///
/// Tres estados y no dos: "sin probar" no es "falla". Un servidor recién
/// registrado no tiene por qué aparecer en rojo.
class ProbeStatus extends StatelessWidget {
  const ProbeStatus({super.key, required this.result, this.probing = false});

  final McpProbeResult? result;
  final bool probing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (probing) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 11,
            height: 11,
            child: CircularProgressIndicator(
              strokeWidth: 1.6,
              color: scheme.primary,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            'probando…',
            style: theme.textTheme.labelMedium?.copyWith(color: scheme.outline),
          ),
        ],
      );
    }

    final probe = result;
    final color = switch (probe) {
      null => scheme.outline,
      McpProbeResult(ok: true) => scheme.tertiary,
      _ => scheme.error,
    };
    final label = switch (probe) {
      null => 'sin probar',
      McpProbeResult(ok: true, :final tools) =>
        '${tools.length} tools · ${_ago(probe.at)}',
      _ => probe.error,
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

/// Hace cuánto, en las unidades en que uno lo piensa.
String _ago(DateTime at) {
  final elapsed = DateTime.now().difference(at);
  if (elapsed.inMinutes < 1) return 'recién';
  if (elapsed.inMinutes < 60) return 'hace ${elapsed.inMinutes} min';
  if (elapsed.inHours < 24) return 'hace ${elapsed.inHours} h';
  return 'hace ${elapsed.inDays} d';
}
