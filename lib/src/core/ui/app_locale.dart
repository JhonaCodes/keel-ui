import 'package:flutter/widgets.dart';

/// Traduce el `language` guardado en [AppSettings] (`'en'`, `'es_CO'`, o
/// `''` para el idioma del sistema) al [Locale] que espera `MaterialApp`.
Locale? localeForLanguageCode(String code) {
  if (code.isEmpty) return null;
  final parts = code.split('_');
  return parts.length > 1 ? Locale(parts[0], parts[1]) : Locale(parts[0]);
}
