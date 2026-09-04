import 'package:flutter/foundation.dart';

import 'package:keel_ui/src/shared/shared.dart';

/// Qué tiene que pasar con un mensaje escrito mientras el agente trabaja.
enum QueuedDelivery {
  /// Queda bajo control del usuario hasta que elija mandarlo.
  standby,

  /// Sale solo cuando el turno que corre entregue el control. Nunca se
  /// inyecta adentro de un proceso CLI ya arrancado.
  afterCurrentTurn,

  /// El usuario pidió interrumpir el turno actual. Persiste hasta que ese
  /// turno se haya cerrado de verdad, y entonces sale como turno siguiente.
  interrupting,
}

QueuedDelivery _deliveryFromName(String? name) => switch (name) {
  'afterCurrentTurn' => QueuedDelivery.afterCurrentTurn,
  'interrupting' => QueuedDelivery.interrupting,
  _ => QueuedDelivery.standby,
};

/// Algo que el usuario escribió MIENTRAS el agente seguía en el turno
/// anterior.
///
/// Los CLI locales son de un turno por proceso (`claude -p`, `codex exec`):
/// no hay stdin donde meter un mensaje a mitad de camino. Así que un mensaje
/// escrito durante un turno espera acá y sale como el turno siguiente, en vez
/// de que el compositor te deje afuera hasta que el modelo termine.
///
/// **Este modelo es uno solo para toda la app.** Vivía duplicado: el chat de
/// una sesión de proyecto tenía identidad, fecha y modo de entrega, y el chat
/// 1:1 tenía una versión pobre con texto y adjuntos nada más — que es la
/// razón por la que en el 1:1 no se podía editar ni mandar uno suelto. Eran
/// la misma idea escrita dos veces, y solo una estaba terminada.
class QueuedMessage {
  QueuedMessage({
    String? id,
    required this.text,
    DateTime? createdAt,
    this.imagePaths = const [],
    this.delivery = QueuedDelivery.standby,
    this.viaKeelAi = false,
  }) : id = id ?? generateUuidV4(),
       createdAt = createdAt ?? DateTime.now();

  /// Identidad estable, para que editar o borrar una fila nunca dependa de
  /// un índice que puede moverse mientras termina otro turno.
  final String id;

  final String text;

  /// Adjuntos ya guardados por `ChatAttachmentStore` — esperan con el
  /// mensaje al que pertenecen.
  final List<String> imagePaths;

  final DateTime createdAt;
  final QueuedDelivery delivery;

  /// Lo escribió Keel AI en nombre del usuario. Espera acá igual que
  /// cualquier otro mensaje, y la atribución tiene que viajar con él: la
  /// sesión que lo recibe casi siempre está corriendo, así que si esto se
  /// perdiera en la cola el hilo lo mostraría como tipeado por el usuario.
  final bool viaKeelAi;

  QueuedMessage copyWith({
    String? text,
    List<String>? imagePaths,
    QueuedDelivery? delivery,
  }) {
    return QueuedMessage(
      id: id,
      text: text ?? this.text,
      imagePaths: imagePaths ?? this.imagePaths,
      createdAt: createdAt,
      delivery: delivery ?? this.delivery,
      viaKeelAi: viaKeelAi,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'imagePaths': imagePaths,
    'createdAt': createdAt.toIso8601String(),
    'delivery': delivery.name,
    'viaKeelAi': viaKeelAi,
  };

  factory QueuedMessage.fromJson(Map<String, dynamic> json) {
    return QueuedMessage(
      id: json['id'] as String?,
      text: json['text'] as String? ?? '',
      imagePaths: (json['imagePaths'] as List?)?.cast<String>() ?? const [],
      // Tolerante: una cola guardada antes de que esto tuviera fecha no la
      // trae, y perder un mensaje del usuario por eso sería peor.
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      delivery: _deliveryFromName(json['delivery'] as String?),
      viaKeelAi: json['viaKeelAi'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QueuedMessage &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          text == other.text &&
          listEquals(imagePaths, other.imagePaths) &&
          createdAt == other.createdAt &&
          delivery == other.delivery &&
          viaKeelAi == other.viaKeelAi;

  @override
  int get hashCode => Object.hash(
    id,
    text,
    Object.hashAll(imagePaths),
    createdAt,
    delivery,
    viaKeelAi,
  );

  @override
  String toString() =>
      'QueuedMessage(id: $id, text: $text, images: ${imagePaths.length}, '
      'delivery: ${delivery.name}, viaKeelAi: $viaKeelAi)';
}
