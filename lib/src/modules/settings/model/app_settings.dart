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

/// Tamaño de fuente por defecto del chat. Vive como constante para que la
/// ventana del asistente — que no lee la base — caiga exactamente en el
/// mismo valor que la ventana principal.
const kDefaultChatFontScale = 0.9;

/// Tamaño con el que abre la ventana principal la primera vez. Tres
/// columnas (rail, sidebar, conversación) necesitan ancho: por debajo del
/// mínimo el chat queda como una ranura.
const kDefaultWindowWidth = 1440.0;
const kDefaultWindowHeight = 900.0;
const kMinWindowWidth = 1100.0;
const kMinWindowHeight = 700.0;

class AppSettings {
  final double chatFontScale;
  final List<String> extraAllowedTools;

  /// Git repo the catalog syncs with (export/refresh). Empty = not
  /// configured. Always set from the UI, never hardcoded.
  final String catalogRepoUrl;

  /// Git repo the Knowledge section pulls docs from. Empty = not
  /// configured.
  final String knowledgeRepoUrl;

  /// Último tamaño de la ventana principal, para volver a abrirla como el
  /// usuario la dejó en vez de imponerle un tamaño cada arranque.
  final double windowWidth;
  final double windowHeight;

  const AppSettings({
    this.chatFontScale = kDefaultChatFontScale,
    this.extraAllowedTools = const [],
    this.catalogRepoUrl = '',
    this.knowledgeRepoUrl = '',
    this.windowWidth = kDefaultWindowWidth,
    this.windowHeight = kDefaultWindowHeight,
  });

  AppSettings copyWith({
    double? chatFontScale,
    List<String>? extraAllowedTools,
    String? catalogRepoUrl,
    String? knowledgeRepoUrl,
    double? windowWidth,
    double? windowHeight,
  }) {
    return AppSettings(
      chatFontScale: chatFontScale ?? this.chatFontScale,
      extraAllowedTools: extraAllowedTools ?? this.extraAllowedTools,
      catalogRepoUrl: catalogRepoUrl ?? this.catalogRepoUrl,
      knowledgeRepoUrl: knowledgeRepoUrl ?? this.knowledgeRepoUrl,
      windowWidth: windowWidth ?? this.windowWidth,
      windowHeight: windowHeight ?? this.windowHeight,
    );
  }

  Map<String, dynamic> toJson() => {
    'chatFontScale': chatFontScale,
    'extraAllowedTools': extraAllowedTools,
    'catalogRepoUrl': catalogRepoUrl,
    'knowledgeRepoUrl': knowledgeRepoUrl,
    'windowWidth': windowWidth,
    'windowHeight': windowHeight,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      chatFontScale:
          (json['chatFontScale'] as num?)?.toDouble() ?? kDefaultChatFontScale,
      extraAllowedTools:
          (json['extraAllowedTools'] as List?)?.cast<String>() ?? const [],
      catalogRepoUrl: json['catalogRepoUrl'] as String? ?? '',
      knowledgeRepoUrl: json['knowledgeRepoUrl'] as String? ?? '',
      windowWidth:
          (json['windowWidth'] as num?)?.toDouble() ?? kDefaultWindowWidth,
      windowHeight:
          (json['windowHeight'] as num?)?.toDouble() ?? kDefaultWindowHeight,
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
