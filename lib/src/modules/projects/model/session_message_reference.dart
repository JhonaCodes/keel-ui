/// Una referencia a UN mensaje de UNA sesión de proyecto.
///
/// Es lo que el botón de la burbuja deja en el portapapeles y lo que el
/// usuario pega en el chat de Keel AI para preguntar a qué se refiere. Su
/// forma de cable es el token `keel://` —el mismo esquema que ya usan las
/// referencias del compositor (`keel://skill/…`, `keel://knowledge/…`)—, así
/// que no lleva `toJson`/`fromJson`: [token] y [tryParse] SON su
/// serialización, y nunca se persiste como objeto.
///
/// Lleva el proyecto y la sesión además del mensaje a propósito. El id de un
/// mensaje derivado de un hilo histórico solo es único dentro de su sesión
/// (ver `legacyChatMessageId`), y resolver por los tres campos convierte una
/// búsqueda en toda la app en un acceso directo.
class SessionMessageReference {
  const SessionMessageReference({
    required this.projectId,
    required this.sessionId,
    required this.messageId,
  });

  final String projectId;
  final String sessionId;
  final String messageId;

  /// Lo que se copia y se pega. Legible, de una sola línea y sin espacios,
  /// para que sobreviva a un chat y a un argumento de tool.
  String get token =>
      'keel://message/$messageId'
      '?project=${Uri.encodeQueryComponent(projectId)}'
      '&session=${Uri.encodeQueryComponent(sessionId)}';

  /// Saca la referencia de lo que sea que haya escrito el usuario o el
  /// modelo: el token pelado, el token adentro de una oración, o un enlace
  /// Markdown que lo envuelve. Devuelve null si no hay ninguna.
  static SessionMessageReference? tryParse(String raw) {
    final match = _pattern.firstMatch(raw);
    if (match == null) return null;
    final uri = Uri.tryParse(match.group(0)!);
    if (uri == null || uri.scheme != 'keel' || uri.host != 'message') {
      return null;
    }
    final messageId = uri.pathSegments.firstOrNull?.trim() ?? '';
    final projectId = uri.queryParameters['project']?.trim() ?? '';
    final sessionId = uri.queryParameters['session']?.trim() ?? '';
    if (messageId.isEmpty || projectId.isEmpty || sessionId.isEmpty) {
      return null;
    }
    return SessionMessageReference(
      projectId: projectId,
      sessionId: sessionId,
      messageId: messageId,
    );
  }

  static final RegExp _pattern = RegExp(r'keel://message/[^\s)\]"]+');

  SessionMessageReference copyWith({
    String? projectId,
    String? sessionId,
    String? messageId,
  }) => SessionMessageReference(
    projectId: projectId ?? this.projectId,
    sessionId: sessionId ?? this.sessionId,
    messageId: messageId ?? this.messageId,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionMessageReference &&
          runtimeType == other.runtimeType &&
          projectId == other.projectId &&
          sessionId == other.sessionId &&
          messageId == other.messageId;

  @override
  int get hashCode => Object.hash(projectId, sessionId, messageId);

  @override
  String toString() => 'SessionMessageReference($token)';
}
