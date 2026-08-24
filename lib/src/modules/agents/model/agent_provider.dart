/// Which provider adapter drives an agent's turns. The set is closed: a
/// provider earns its entry only when its CLI or API runner exists.
enum AgentProvider {
  claude(alias: 'claude', label: 'Claude', shortTag: 'CL'),
  codex(alias: 'codex', label: 'Codex', shortTag: 'CX'),
  openRouter(alias: 'openrouter', label: 'OpenRouter', shortTag: 'OR'),
  deepSeek(alias: 'deepseek', label: 'DeepSeek', shortTag: 'DS');

  final String alias;
  final String label;

  /// Two-letter mark for the small provider badge next to an agent's name.
  final String shortTag;

  const AgentProvider({
    required this.alias,
    required this.label,
    required this.shortTag,
  });

  /// Environment variable required by providers that run through a remote
  /// API. CLI-backed providers authenticate outside Keel and return null.
  String? get secretName => switch (this) {
    AgentProvider.openRouter => 'OPENROUTER_API_KEY',
    AgentProvider.deepSeek => 'DEEPSEEK_API_KEY',
    AgentProvider.claude || AgentProvider.codex => null,
  };

  bool get requiresApiKey => secretName != null;

  String turnFailureMessage({String? memberName}) {
    final member = memberName?.trim();
    return member == null || member.isEmpty
        ? '$label reportó un error en este turno.'
        : '$label reportó un error en el turno de $member.';
  }

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
