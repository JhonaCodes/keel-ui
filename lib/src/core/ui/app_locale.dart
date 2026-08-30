import 'package:flutter/widgets.dart';

/// Traduce el `language` guardado en [AppSettings] al [Locale] que espera
/// `MaterialApp`. El valor histórico `es` se mantiene legible, pero siempre
/// se resuelve como español de Colombia.
Locale? localeForLanguageCode(String code) {
  return switch (code) {
    'es' || 'es_CO' => const Locale('es', 'CO'),
    'en' => const Locale('en'),
    _ => const Locale('en'),
  };
}
