/// Which local CLI drives an agent's turns. The set is closed: a provider
/// earns its entry when its adapter exists in `core/services`.
enum AgentProvider {
  claude(alias: 'claude', label: 'Claude', shortTag: 'CL'),
  codex(alias: 'codex', label: 'Codex', shortTag: 'CX');

  final String alias;
  final String label;

  /// Two-letter mark for the small provider badge next to an agent's name.
  final String shortTag;

  const AgentProvider({
    required this.alias,
    required this.label,
    required this.shortTag,
  });

  static AgentProvider? tryFromAlias(String alias) {
    for (final provider in values) {
      if (provider.alias == alias) return provider;
    }
    return null;
  }

  factory AgentProvider.fromAlias(String alias) {
    final provider = tryFromAlias(alias);
    if (provider == null) {
      throw ArgumentError.value(alias, 'alias', 'Proveedor desconocido');
    }
    return provider;
  }
}
