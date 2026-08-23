part of '../../catalog_bundle.dart';

/// La revisión de seguridad, para leer.
///
/// Agrupada por gravedad y con el fragmento exacto a la vista. Un aviso sin
/// el texto que lo disparó obliga a creerle a la app, y creer sin poder
/// mirar es justo lo que este feature viene a evitar.
class BundleFindingsView extends StatelessWidget {
  const BundleFindingsView({super.key, required this.audit});

  final BundleAudit audit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (audit.isClean) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.verified_outlined, size: 18, color: scheme.tertiary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Revisé ${audit.scannedTexts} textos y no encontré nada '
                'conocido. No es una garantía: busca lo que sabe buscar.',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final risk in BundleRisk.values)
          if (audit.at(risk) case final findings when findings.isNotEmpty) ...[
            _RiskHead(risk: risk, count: findings.length),
            for (final finding in findings) _FindingCard(finding: finding),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

/// El color de cada gravedad. Semántico y aparte del acento de la app: rojo
/// no es «la marca», es «pará».
Color riskColor(BundleRisk risk, ColorScheme scheme) => switch (risk) {
  BundleRisk.alta => scheme.error,
  BundleRisk.media => scheme.primary,
  BundleRisk.baja => scheme.outline,
};

IconData riskIcon(BundleRisk risk) => switch (risk) {
  BundleRisk.alta => Icons.gpp_maybe_outlined,
  BundleRisk.media => Icons.info_outline,
  BundleRisk.baja => Icons.remove_circle_outline,
};

class _RiskHead extends StatelessWidget {
  const _RiskHead({required this.risk, required this.count});

  final BundleRisk risk;
  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = riskColor(risk, scheme);
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 8),
      child: Row(
        children: [
          Icon(riskIcon(risk), size: 15, color: color),
          const SizedBox(width: 7),
          Text(
            'GRAVEDAD ${risk.label.toUpperCase()}',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 10,
              letterSpacing: 1.2,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Divider(height: 1, color: scheme.outlineVariant)),
          const SizedBox(width: 8),
          Text(
            '$count',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 10,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _FindingCard extends StatelessWidget {
  const _FindingCard({required this.finding});

  final BundleFinding finding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = riskColor(finding.risk, scheme);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 3, height: 13, color: color),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  finding.kind,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  finding.where,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10.5,
                    color: scheme.outline,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            finding.what,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          if (finding.excerpt.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(6),
              ),
              child: SelectableText(
                finding.excerpt,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
