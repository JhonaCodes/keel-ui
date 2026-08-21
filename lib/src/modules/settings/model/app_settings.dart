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

  const AppSettings({
    this.chatFontScale = 0.9,
    this.extraAllowedTools = const [],
  });

  AppSettings copyWith({
    double? chatFontScale,
    List<String>? extraAllowedTools,
  }) {
    return AppSettings(
      chatFontScale: chatFontScale ?? this.chatFontScale,
      extraAllowedTools: extraAllowedTools ?? this.extraAllowedTools,
    );
  }

  Map<String, dynamic> toJson() => {
    'chatFontScale': chatFontScale,
    'extraAllowedTools': extraAllowedTools,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      chatFontScale: (json['chatFontScale'] as num?)?.toDouble() ?? 0.9,
      extraAllowedTools:
          (json['extraAllowedTools'] as List?)?.cast<String>() ?? const [],
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettings &&
          runtimeType == other.runtimeType &&
          chatFontScale == other.chatFontScale &&
          extraAllowedTools.length == other.extraAllowedTools.length &&
          extraAllowedTools.every(other.extraAllowedTools.contains);

  @override
  int get hashCode =>
      Object.hash(chatFontScale, Object.hashAll(extraAllowedTools));

  @override
  String toString() =>
      'AppSettings(chatFontScale: $chatFontScale, extraAllowedTools: $extraAllowedTools)';
}
