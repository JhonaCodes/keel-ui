class ClaudeModelOption {
  final String alias;
  final String label;

  const ClaudeModelOption({required this.alias, required this.label});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClaudeModelOption &&
          runtimeType == other.runtimeType &&
          alias == other.alias &&
          label == other.label;

  @override
  int get hashCode => Object.hash(alias, label);

  @override
  String toString() => 'ClaudeModelOption(alias: $alias, label: $label)';
}

const kDefaultClaudeModelAlias = 'sonnet';

const kClaudeModelOptions = <ClaudeModelOption>[
  ClaudeModelOption(alias: 'sonnet', label: 'Sonnet 5'),
  ClaudeModelOption(alias: 'opus', label: 'Opus 5'),
  ClaudeModelOption(alias: 'fable', label: 'Fable 5'),
  ClaudeModelOption(alias: 'claude-haiku-4-5-20251001', label: 'Haiku 4.5'),
];

String claudeModelLabel(String alias) {
  for (final option in kClaudeModelOptions) {
    if (option.alias == alias) return option.label;
  }
  return alias;
}
