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

  /// La carpeta que hace de vault: ahí adentro vive `keel-backup.zip` y,
  /// normalmente, las bases de saber locales. Es de ESTA máquina, así que
  /// nunca viaja en un respaldo. Vacío = no configurada; se elige desde la
  /// UI, nunca hardcodeada.
  final String vaultPath;

  /// El repo remoto al que se sube el vault. Vacío = solo local.
  final String vaultRepoUrl;

  /// Si el usuario ya contestó la pantalla de bienvenida. Sin esto, elegir
  /// "empezar de cero" y cerrar la app volvería a preguntar en el arranque
  /// siguiente, porque el sistema sigue igual de vacío.
  final bool vaultOnboardingDone;

  /// Git repo the Knowledge section pulls docs from. Empty = not
  /// configured.
  final String knowledgeRepoUrl;

  /// Último tamaño de la ventana principal, para volver a abrirla como el
  /// usuario la dejó en vez de imponerle un tamaño cada arranque.
  final double windowWidth;
  final double windowHeight;

  /// Idioma elegido en Ajustes: `'en'` o `'es_CO'`.
  final String language;

  const AppSettings({
    this.chatFontScale = kDefaultChatFontScale,
    this.extraAllowedTools = const [],
    this.vaultPath = '',
    this.vaultRepoUrl = '',
    this.vaultOnboardingDone = false,
    this.knowledgeRepoUrl = '',
    this.windowWidth = kDefaultWindowWidth,
    this.windowHeight = kDefaultWindowHeight,
    this.language = 'en',
  });

  AppSettings copyWith({
    double? chatFontScale,
    List<String>? extraAllowedTools,
    String? vaultPath,
    String? vaultRepoUrl,
    bool? vaultOnboardingDone,
    String? knowledgeRepoUrl,
    double? windowWidth,
    double? windowHeight,
    String? language,
  }) {
    return AppSettings(
      chatFontScale: chatFontScale ?? this.chatFontScale,
      extraAllowedTools: extraAllowedTools ?? this.extraAllowedTools,
      vaultPath: vaultPath ?? this.vaultPath,
      vaultRepoUrl: vaultRepoUrl ?? this.vaultRepoUrl,
      vaultOnboardingDone: vaultOnboardingDone ?? this.vaultOnboardingDone,
      knowledgeRepoUrl: knowledgeRepoUrl ?? this.knowledgeRepoUrl,
      windowWidth: windowWidth ?? this.windowWidth,
      windowHeight: windowHeight ?? this.windowHeight,
      language: language ?? this.language,
    );
  }

  Map<String, dynamic> toJson() => {
    'chatFontScale': chatFontScale,
    'extraAllowedTools': extraAllowedTools,
    'vaultPath': vaultPath,
    'vaultRepoUrl': vaultRepoUrl,
    'vaultOnboardingDone': vaultOnboardingDone,
    'knowledgeRepoUrl': knowledgeRepoUrl,
    'windowWidth': windowWidth,
    'windowHeight': windowHeight,
    'language': language,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final language = json['language'] as String?;
    return AppSettings(
      chatFontScale:
          (json['chatFontScale'] as num?)?.toDouble() ?? kDefaultChatFontScale,
      extraAllowedTools:
          (json['extraAllowedTools'] as List?)?.cast<String>() ?? const [],
      vaultPath: json['vaultPath'] as String? ?? '',
      vaultRepoUrl: json['vaultRepoUrl'] as String? ?? '',
      vaultOnboardingDone: json['vaultOnboardingDone'] as bool? ?? false,
      knowledgeRepoUrl: json['knowledgeRepoUrl'] as String? ?? '',
      windowWidth:
          (json['windowWidth'] as num?)?.toDouble() ?? kDefaultWindowWidth,
      windowHeight:
          (json['windowHeight'] as num?)?.toDouble() ?? kDefaultWindowHeight,
      language: switch (language) {
        'es' || 'es_CO' => 'es_CO',
        'en' => 'en',
        _ => 'en',
      },
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettings &&
          runtimeType == other.runtimeType &&
          chatFontScale == other.chatFontScale &&
          vaultPath == other.vaultPath &&
          vaultRepoUrl == other.vaultRepoUrl &&
          vaultOnboardingDone == other.vaultOnboardingDone &&
          knowledgeRepoUrl == other.knowledgeRepoUrl &&
          language == other.language &&
          extraAllowedTools.length == other.extraAllowedTools.length &&
          extraAllowedTools.every(other.extraAllowedTools.contains);

  @override
  int get hashCode => Object.hash(
    chatFontScale,
    Object.hashAll(extraAllowedTools),
    vaultPath,
    vaultRepoUrl,
    vaultOnboardingDone,
    knowledgeRepoUrl,
    language,
  );

  @override
  String toString() =>
      'AppSettings(chatFontScale: $chatFontScale, '
      'extraAllowedTools: $extraAllowedTools, '
      'vaultPath: $vaultPath, '
      'vaultRepoUrl: $vaultRepoUrl, '
      'knowledgeRepoUrl: $knowledgeRepoUrl, '
      'language: $language)';
}
