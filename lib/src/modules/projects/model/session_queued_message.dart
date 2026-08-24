import 'package:flutter/foundation.dart';

/// Qué debe ocurrir con un mensaje escrito mientras una sesión trabaja.
enum SessionQueuedDelivery {
  /// Queda bajo control del usuario hasta que elija enviarlo.
  standby,

  /// Sale automáticamente cuando el turno que está corriendo entregue el
  /// control. Nunca se inyecta dentro de un proceso CLI ya iniciado.
  afterCurrentTurn,

  /// El usuario pidió interrumpir el turno actual. Persiste hasta que ese
  /// turno se haya cerrado de verdad y entonces sale como el turno siguiente.
  interrupting,
}

SessionQueuedDelivery _deliveryFromName(String? name) {
  return switch (name) {
    'afterCurrentTurn' => SessionQueuedDelivery.afterCurrentTurn,
    'interrupting' => SessionQueuedDelivery.interrupting,
    _ => SessionQueuedDelivery.standby,
  };
}

/// Un mensaje pendiente de una sesión de proyecto.
///
/// Tiene identidad estable para que editar o eliminar una fila nunca dependa
/// de un índice que puede cambiar mientras termina otro turno.
class SessionQueuedMessage {
  const SessionQueuedMessage({
    required this.id,
    required this.text,
    required this.createdAt,
    this.imagePaths = const [],
    this.delivery = SessionQueuedDelivery.standby,
  });

  final String id;
  final String text;
  final List<String> imagePaths;
  final DateTime createdAt;
  final SessionQueuedDelivery delivery;

  SessionQueuedMessage copyWith({
    String? text,
    List<String>? imagePaths,
    SessionQueuedDelivery? delivery,
  }) {
    return SessionQueuedMessage(
      id: id,
      text: text ?? this.text,
      imagePaths: imagePaths ?? this.imagePaths,
      createdAt: createdAt,
      delivery: delivery ?? this.delivery,
    );
  }

  Map<String, Object> toJson() => {
    'id': id,
    'text': text,
    'imagePaths': imagePaths,
    'createdAt': createdAt.toIso8601String(),
    'delivery': delivery.name,
  };

  factory SessionQueuedMessage.fromJson(Map<String, dynamic> json) {
    return SessionQueuedMessage(
      id: json['id'] as String,
      text: json['text'] as String? ?? '',
      imagePaths: (json['imagePaths'] as List?)?.cast<String>() ?? const [],
      createdAt: DateTime.parse(json['createdAt'] as String),
      delivery: _deliveryFromName(json['delivery'] as String?),
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is SessionQueuedMessage &&
            id == other.id &&
            text == other.text &&
            listEquals(imagePaths, other.imagePaths) &&
            createdAt == other.createdAt &&
            delivery == other.delivery;
  }

  @override
  int get hashCode =>
      Object.hash(id, text, Object.hashAll(imagePaths), createdAt, delivery);
}
