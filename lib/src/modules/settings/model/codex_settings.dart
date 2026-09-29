/// How Keel runs codex, from the Codex section of Settings.
///
/// Codex runs sandboxed and with `approval_policy=never`, so what Claude Code
/// decides with its permission prompts codex decides with its sandbox. These
/// three switches are that decision, made once for every codex turn.
class CodexSettings {
  const CodexSettings({
    this.fullDiskAccess = false,
    this.networkAccess = true,
    this.askPermission = true,
  });

  /// `danger-full-access` instead of `workspace-write`: codex may write
  /// outside the working directory. A chat's own toggle still turns it on
  /// for that chat alone.
  final bool fullDiskAccess;

  /// Network inside the `workspace-write` sandbox. On by default: without
  /// it `pub get`, `npm install` or `git push` fail inside codex, which
  /// Claude Code never blocks.
  final bool networkAccess;

  /// Keel's permission gate before every command and file edit — the card
  /// that asks once / always / deny. Off: codex writes and runs commands
  /// inside its sandbox without asking.
  final bool askPermission;

  CodexSettings copyWith({
    bool? fullDiskAccess,
    bool? networkAccess,
    bool? askPermission,
  }) => CodexSettings(
    fullDiskAccess: fullDiskAccess ?? this.fullDiskAccess,
    networkAccess: networkAccess ?? this.networkAccess,
    askPermission: askPermission ?? this.askPermission,
  );

  Map<String, dynamic> toJson() => {
    'fullDiskAccess': fullDiskAccess,
    'networkAccess': networkAccess,
    'askPermission': askPermission,
  };

  /// Settings saved before this section existed read the defaults.
  factory CodexSettings.fromJson(Map<String, dynamic>? json) {
    final data = json ?? const <String, dynamic>{};
    return CodexSettings(
      fullDiskAccess: data['fullDiskAccess'] as bool? ?? false,
      networkAccess: data['networkAccess'] as bool? ?? true,
      askPermission: data['askPermission'] as bool? ?? true,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CodexSettings &&
          fullDiskAccess == other.fullDiskAccess &&
          networkAccess == other.networkAccess &&
          askPermission == other.askPermission;

  @override
  int get hashCode => Object.hash(fullDiskAccess, networkAccess, askPermission);
}
