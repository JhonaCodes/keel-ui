import 'package:keel_ui/src/core/services/cli_turn_workspace.dart';

class PermissionRequest {
  final String toolName;
  final String message;
  final String? kind;
  final String? itemName;
  final String? changeIntent;
  final String? changeReason;
  final String? requestedBy;

  const PermissionRequest({
    required this.toolName,
    required this.message,
    this.kind,
    this.itemName,
    this.changeIntent,
    this.changeReason,
    this.requestedBy,
  });

  bool get isCatalogChange => kind != null;

  bool get isSandboxRestriction => message.contains('allowed working director');

  /// Si esto lo frenó un hook y no la falta de un permiso.
  ///
  /// Importa porque la respuesta es OTRA: conceder un permiso no destraba
  /// nada acá — no fue el permiso lo que bloqueó. Lo que corresponde es
  /// mirar el hook, y si está de más, apagarlo.
  bool get isHookDenial => message.contains('[$kHookDenialMarker ');

  /// El nombre del hook que bloqueó, si se puede leer del mensaje.
  String? get blockingHookName {
    final match = RegExp(
      r'\[' + kHookDenialMarker + r' ([^\]]+)\]',
    ).firstMatch(message);
    return match?.group(1);
  }

  Map<String, dynamic> toJson() => {
    'toolName': toolName,
    'message': message,
    'kind': kind,
    'itemName': itemName,
    'changeIntent': changeIntent,
    'changeReason': changeReason,
    'requestedBy': requestedBy,
  };

  factory PermissionRequest.fromJson(Map<String, dynamic> json) {
    return PermissionRequest(
      toolName: json['toolName'] as String,
      message: json['message'] as String,
      kind: json['kind'] as String?,
      itemName: json['itemName'] as String?,
      changeIntent: json['changeIntent'] as String?,
      changeReason: json['changeReason'] as String?,
      requestedBy: json['requestedBy'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PermissionRequest &&
          runtimeType == other.runtimeType &&
          toolName == other.toolName &&
          message == other.message &&
          kind == other.kind &&
          itemName == other.itemName &&
          changeIntent == other.changeIntent &&
          changeReason == other.changeReason &&
          requestedBy == other.requestedBy;

  @override
  int get hashCode => Object.hash(
    toolName,
    message,
    kind,
    itemName,
    changeIntent,
    changeReason,
    requestedBy,
  );

  @override
  String toString() =>
      'PermissionRequest(toolName: $toolName, message: $message)';
}
