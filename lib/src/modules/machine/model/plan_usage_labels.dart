import 'package:flutter/material.dart';

import 'package:keel_core/integrations/plan_usage/plan_usage.dart';

/// Cómo se dice el consumo de una cuenta, igual en la tarjeta de Máquina y
/// en el medidor del riel.
abstract final class PlanUsageLabels {
  static String percent(double? value) =>
      value == null ? '—' : '${value.round()} %';

  /// El porcentaje sin el signo, para el riel donde no entra.
  static String shortPercent(double? value) =>
      value == null ? '—' : '${value.round()}';

  static double? ratio(double? value) =>
      value == null ? null : (value / 100).clamp(0, 1).toDouble();

  static String money(double value) => '\$${value.toStringAsFixed(2)}';

  static String meter(PlanMeterKind kind) => switch (kind) {
    PlanMeterKind.session => 'Sesión',
    PlanMeterKind.weekly => 'Semana',
    PlanMeterKind.credits => 'Créditos',
    PlanMeterKind.keyLimit => 'Tope de la clave',
  };

  /// La letra del riel: S sesión, W semana, \$ créditos, K tope de la clave.
  static String meterShort(PlanMeterKind kind) => switch (kind) {
    PlanMeterKind.session => 'S',
    PlanMeterKind.weekly => 'W',
    PlanMeterKind.credits => '\$',
    PlanMeterKind.keyLimit => 'K',
  };

  /// El nombre del proveedor en el riel, donde caben unos ocho caracteres.
  static String providerShort(PlanProvider provider) => switch (provider) {
    PlanProvider.claude => 'Claude',
    PlanProvider.codex => 'Codex',
    PlanProvider.openRouter => 'Router',
  };

  /// Lo que va al lado del porcentaje: cuándo reinicia, o cuánto se gastó
  /// de cuánto.
  static String detail(PlanMeter meter) => switch (meter) {
    PlanMeter(:final double used, :final double limit) =>
      '${money(used)} de ${money(limit)}',
    PlanMeter(:final resetsAt) => resets(resetsAt),
  };

  /// La hora sola si reinicia hoy; si no, el día y la hora.
  static String resets(DateTime? at) {
    if (at == null) return '';
    String two(int n) => n.toString().padLeft(2, '0');
    final now = DateTime.now();
    final time = '${two(at.hour)}:${two(at.minute)}';
    final sameDay =
        at.year == now.year && at.month == now.month && at.day == now.day;
    return sameDay
        ? 'reinicia $time'
        : 'reinicia ${two(at.day)}/${two(at.month)} $time';
  }

  /// El gasto de OpenRouter por período, o vacío si no lo informó.
  static String spend(Map<String, double> spend) => [
    for (final (key, label) in const [
      ('day', 'hoy'),
      ('week', 'semana'),
      ('month', 'mes'),
    ])
      if (spend[key] case final value?) '$label ${money(value)}',
  ].join(' · ');

  /// Verde con holgura, latón desde el 70 % y rojo desde el 90 %.
  static Color levelColor(PlanUsageLevel level, ColorScheme scheme) =>
      switch (level) {
        PlanUsageLevel.normal => scheme.tertiary,
        PlanUsageLevel.high => scheme.primary,
        PlanUsageLevel.critical => scheme.error,
      };

  /// Por qué no hay números. El detalle crudo solo cuando la lectura falló
  /// de una forma no prevista.
  static String problem(PlanUsage usage) => switch (usage.problem) {
    PlanUsageProblem.notInstalled =>
      '${usage.account.provider.label} no está instalado',
    PlanUsageProblem.notSignedIn => 'Sin sesión iniciada',
    PlanUsageProblem.noPlanLimits =>
      'Sin límites de plan: entra con una API key, no con una suscripción',
    PlanUsageProblem.failed || null => 'No se pudo leer: ${usage.error}',
  };

  /// El texto completo de una cuenta, para el tooltip del riel.
  static String summary(PlanUsage usage) {
    final head = [
      usage.account.provider.label,
      if (usage.account.provider.hasAccounts) usage.account.name,
      usage.identity,
    ].where((part) => part.isNotEmpty).join(' · ');
    if (!usage.ok) return '$head\n${problem(usage)} — abre Máquina';
    return [
      head,
      for (final meter in usage.meters)
        '${PlanUsageLabels.meter(meter.kind)} ${percent(meter.percent)} · '
            '${detail(meter)}',
      if (spend(usage.spend) case final line when line.isNotEmpty) line,
    ].join('\n');
  }
}
