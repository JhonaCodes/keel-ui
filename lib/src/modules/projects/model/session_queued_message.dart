import 'package:keel_ui/src/modules/agents/model/queued_message.dart';

/// La cola de una sesión de proyecto y la de un chat 1:1 son la misma cosa.
///
/// Estos alias existen para no renombrar 60 usos de un ViewModel de 4000
/// líneas en el mismo cambio que unificó el modelo. Los nombres viejos siguen
/// funcionando; el que manda es [QueuedMessage].
typedef SessionQueuedMessage = QueuedMessage;
typedef SessionQueuedDelivery = QueuedDelivery;
