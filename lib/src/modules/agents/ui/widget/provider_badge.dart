import 'package:flutter/material.dart';

import 'package:keel_ui/src/modules/agents/model/agent_provider.dart';

/// Tiny mark next to an agent's name saying which CLI drives it. Neutral
/// glyphs (two letters), no third-party trademarks.
class ProviderBadge extends StatelessWidget {
  const ProviderBadge({super.key, required this.provider});

  final AgentProvider provider;

  @override
  Widget build(BuildContext context) {
    final background = switch (provider) {
      AgentProvider.claude => const Color(0xFFCC785C),
      AgentProvider.codex => const Color(0xFF10A37F),
    };

    return Tooltip(
      message: 'Proveedor: ${provider.label}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: background.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: background.withValues(alpha: 0.6)),
        ),
        child: Text(
          provider.shortTag,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: background,
          ),
        ),
      ),
    );
  }
}
