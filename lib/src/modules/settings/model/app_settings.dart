/// The tools that *change things* — the only ones that need your consent.
/// Reading files, searching them and consulting the web is always allowed
/// (see `kAlwaysAllowedTools`), because an agent that cannot open the code it
/// is asked about has nothing to say about it.
const List<String> kAvailableExtraTools = [
  'Bash',
  'Edit',
  'MultiEdit',
  'Write',
  'NotebookEdit',
];

class AppSettings {
  final double chatFontScale;
  final List<String> extraAllowedTools;

  /// Git repo the catalog syncs with (export/refresh). Empty = not
  /// configured. Always set from the UI, never hardcoded.
  final String catalogRepoUrl;

  /// Git repo the Knowledge section pulls docs from. Empty = not
  /// configured.
  final String knowledgeRepoUrl;

  const AppSettings({
    this.chatFontScale = 0.9,
    this.extraAllowedTools = const [],
    this.catalogRepoUrl = '',
    this.knowledgeRepoUrl = '',
  });

  AppSettings copyWith({
    double? chatFontScale,
    List<String>? extraAllowedTools,
    String? catalogRepoUrl,
    String? knowledgeRepoUrl,
  }) {
    return AppSettings(
      chatFontScale: chatFontScale ?? this.chatFontScale,
      extraAllowedTools: extraAllowedTools ?? this.extraAllowedTools,
      catalogRepoUrl: catalogRepoUrl ?? this.catalogRepoUrl,
      knowledgeRepoUrl: knowledgeRepoUrl ?? this.knowledgeRepoUrl,
    );
  }

  Map<String, dynamic> toJson() => {
    'chatFontScale': chatFontScale,
    'extraAllowedTools': extraAllowedTools,
    'catalogRepoUrl': catalogRepoUrl,
    'knowledgeRepoUrl': knowledgeRepoUrl,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      chatFontScale: (json['chatFontScale'] as num?)?.toDouble() ?? 0.9,
      extraAllowedTools:
          (json['extraAllowedTools'] as List?)?.cast<String>() ?? const [],
      catalogRepoUrl: json['catalogRepoUrl'] as String? ?? '',
      knowledgeRepoUrl: json['knowledgeRepoUrl'] as String? ?? '',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettings &&
          runtimeType == other.runtimeType &&
          chatFontScale == other.chatFontScale &&
          catalogRepoUrl == other.catalogRepoUrl &&
          knowledgeRepoUrl == other.knowledgeRepoUrl &&
          extraAllowedTools.length == other.extraAllowedTools.length &&
          extraAllowedTools.every(other.extraAllowedTools.contains);

  @override
  int get hashCode => Object.hash(
    chatFontScale,
    Object.hashAll(extraAllowedTools),
    catalogRepoUrl,
    knowledgeRepoUrl,
  );

  @override
  String toString() =>
      'AppSettings(chatFontScale: $chatFontScale, '
      'extraAllowedTools: $extraAllowedTools, '
      'catalogRepoUrl: $catalogRepoUrl, '
      'knowledgeRepoUrl: $knowledgeRepoUrl)';
}
