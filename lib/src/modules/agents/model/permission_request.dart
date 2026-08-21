class PermissionRequest {
  final String toolName;
  final String message;

  const PermissionRequest({required this.toolName, required this.message});

  bool get isSandboxRestriction => message.contains('allowed working director');

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
