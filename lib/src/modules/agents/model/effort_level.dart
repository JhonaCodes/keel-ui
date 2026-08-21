class EffortLevel {
  final String alias;
  final String label;

  const EffortLevel({required this.alias, required this.label});
}

const kDefaultEffortAlias = 'medium';

const kEffortLevels = <EffortLevel>[
  EffortLevel(alias: 'low', label: 'Rápido'),
  EffortLevel(alias: 'medium', label: 'Normal'),
  EffortLevel(alias: 'high', label: 'Alto'),
  EffortLevel(alias: 'xhigh', label: 'Muy alto'),
  EffortLevel(alias: 'max', label: 'Máximo'),
];

String effortLabel(String alias) {
  for (final level in kEffortLevels) {
    if (level.alias == alias) return level.label;
  }
  return alias;
}
