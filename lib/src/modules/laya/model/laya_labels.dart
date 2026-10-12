import 'package:keel_core/modules/laya_forms/model/laya_form.dart';

/// Cómo se dicen en la app las respuestas de Laya, que llegan en inglés.
abstract final class LayaLabels {
  /// El nombre de una acción recomendada para una tarea.
  static String action(String key) => switch (key) {
    'continue' => 'seguir',
    'unblock' => 'desbloquear',
    'split' => 'dividir',
    'close' => 'cerrar',
    'reprioritize' => 'repriorizar',
    _ => key,
  };

  static String percent(double value) => '${(value * 100).round()} %';

  /// Cómo de segura está Laya, en palabras.
  static String confidence(double? value) => switch (value ?? 0) {
    >= 0.75 => 'segura',
    >= 0.5 => 'bastante segura',
    _ => 'duda: tómalo como sin respuesta',
  };

  static String idle(int days) => switch (days) {
    0 => 'cambió hoy',
    1 => '1 día sin cambios',
    _ => '$days días sin cambios',
  };

  /// `yes`/`no` en el idioma de la app; el resto, tal cual.
  static String answerName(String name) => switch (name) {
    'yes' => 'sí',
    'no' => 'no',
    _ => name,
  };

  /// «Sí — 94 %», «Bug — 81 %»: la respuesta con su probabilidad.
  static String answerHeadline(LayaFormAnswer answer) {
    final chosen = answer.answer;
    if (chosen == null) return '—';
    final name = answerName(chosen);
    final label = '${name[0].toUpperCase()}${name.substring(1)}';
    final probability = answer.probabilities[chosen];
    return probability == null ? label : '$label — ${percent(probability)}';
  }

  /// Quién armó el formulario.
  static String creator(String createdBy) => switch (createdBy) {
    'user' => 'tuyo',
    'keel-ai' => 'de Keel AI',
    'phone' => 'del celular',
    _ => 'de $createdBy',
  };

  /// Cuándo, corto: «hoy 10:42» o «13/10 10:42».
  static String when(DateTime at) {
    String two(int n) => n.toString().padLeft(2, '0');
    final now = DateTime.now();
    final time = '${two(at.hour)}:${two(at.minute)}';
    final today =
        at.year == now.year && at.month == now.month && at.day == now.day;
    return today ? 'hoy $time' : '${two(at.day)}/${two(at.month)} $time';
  }
}
