/// Qué está trabajando ahora mismo, contado en un solo lugar.
///
/// La lógica real vive en `keel_core` (pura, sin Flutter) para que el futuro
/// CLI headless cuente lo mismo sin arrastrar este host. Este archivo es un
/// re-export para no tocar cada import existente en keel-ui.
library;

export 'package:keel_core/modules/workspace/model/running_work.dart';
