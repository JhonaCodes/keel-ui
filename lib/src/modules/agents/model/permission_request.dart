/// La marca que los wrappers de keel-ui dejan en stderr cuando un hook
/// bloquea. Se repite acá en vez de importar la integración de hooks por una
/// constante — mismo criterio que `kKeelAiSkillNameForExport`.
const _hookDenialMarker = 'keel:hook';

class PermissionRequest {
  final String toolName;
  final String message;

  const PermissionRequest({required this.toolName, required this.message});

  bool get isSandboxRestriction => message.contains('allowed working director');

  /// Si esto lo frenó un hook y no la falta de un permiso.
  ///
  /// Importa porque la respuesta es OTRA: conceder un permiso no destraba
  /// nada acá — no fue el permiso lo que bloqueó. Lo que corresponde es
  /// mirar el hook, y si está de más, apagarlo.
  bool get isHookDenial => message.contains('[$_hookDenialMarker ');

  /// El nombre del hook que bloqueó, si se puede leer del mensaje.
  String? get blockingHookName {
    final match = RegExp(
      r'\[' + _hookDenialMarker + r' ([^\]]+)\]',
    ).firstMatch(message);
    return match?.group(1);
  }

  Map<String, dynamic> toJson() => {'toolName': toolName, 'message': message};

  factory PermissionRequest.fromJson(Map<String, dynamic> json) {
    return PermissionRequest(
      toolName: json['toolName'] as String,
      message: json['message'] as String,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PermissionRequest &&
          runtimeType == other.runtimeType &&
          toolName == other.toolName &&
          message == other.message;

  @override
  int get hashCode => Object.hash(toolName, message);

  @override
  String toString() =>
      'PermissionRequest(toolName: $toolName, message: $message)';
}
