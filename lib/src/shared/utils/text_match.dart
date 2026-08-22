part of '../shared.dart';

/// Normaliza [text] para compararlo con tolerancia: minúsculas, sin acentos,
/// espacios colapsados y sin puntuación final.
///
/// Es la comparación del plan de una sesión. Exigir el texto EXACTO convertía
/// un retoque de redacción en un desmarque: replanificar reformulando un
/// punto ya hecho lo devolvía a pendiente y el ciclo volvía a trabajar lo
/// mismo. Con esto, dos textos que dicen lo mismo con otra mayúscula, otro
/// acento u otro punto final son el mismo punto.
String normalizeForMatch(String text) {
  return text
      .toLowerCase()
      .replaceAll(RegExp(r'[áàä]'), 'a')
      .replaceAll(RegExp(r'[éèë]'), 'e')
      .replaceAll(RegExp(r'[íìï]'), 'i')
      .replaceAll(RegExp(r'[óòö]'), 'o')
      .replaceAll(RegExp(r'[úùü]'), 'u')
      .replaceAll('ñ', 'n')
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'[.,;:!?]+$'), '')
      .trim();
}
