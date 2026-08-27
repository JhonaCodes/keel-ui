part of '../usage_ledger.dart';

/// Un día del gráfico: cuánto se gastó, partido por modelo.
class DayUsage {
  final DateTime day;

  /// Tokens por modelo, para poder apilar las barras. Un día sin actividad
  /// existe igual, con el mapa vacío: un hueco en el eje dice algo, y
  /// saltearlo mentiría sobre el ritmo.
  final Map<String, int> byModel;

  const DayUsage({required this.day, required this.byModel});

  int get total => byModel.values.fold(0, (sum, value) => sum + value);
}

/// Los últimos [days] días terminando hoy, en orden. Los días sin actividad
/// vienen vacíos, no ausentes.
List<DayUsage> rollupByDay(
  List<UsageEntry> entries, {
  required DateTime today,
  int days = 14,
}) {
  final base = DateTime(today.year, today.month, today.day);
  final buckets = <DateTime, Map<String, int>>{
    for (var back = days - 1; back >= 0; back--)
      base.subtract(Duration(days: back)): <String, int>{},
  };

  for (final entry in entries) {
    final bucket = buckets[entry.day];
    if (bucket == null) continue;
    if (entry.totalTokens == 0) continue;
    final model = entry.model.isEmpty ? entry.provider : entry.model;
    bucket[model] = (bucket[model] ?? 0) + entry.totalTokens;
  }

  return [
    for (final bucket in buckets.entries)
      DayUsage(day: bucket.key, byModel: bucket.value),
  ];
}

/// El total de un motor, para la tabla.
class EngineUsage {
  final String provider;
  final int turns;
  final int inputTokens;
  final int outputTokens;
  final int cacheReadTokens;
  final double costUsd;

  /// Cuántos de esos turnos no informaron un solo contador.
  ///
  /// Contarlos aparte es lo que evita el peor de los dos errores posibles:
  /// omitirlos dice que el turno no existió, y sumarlos en silencio baja el
  /// promedio por turno sin que se sepa por qué.
  final int unmeasuredTurns;

  const EngineUsage({
    required this.provider,
    required this.turns,
    required this.inputTokens,
    required this.outputTokens,
    required this.cacheReadTokens,
    required this.costUsd,
    this.unmeasuredTurns = 0,
  });

  /// Un motor que corrió turnos y no informó un solo token. Es distinto de
  /// haber gastado cero, y la UI tiene que decirlo así: un cero al lado de
  /// otro motor se lee "salió gratis", y lo que pasa es que no se sabe.
  bool get unmeasured =>
      turns > 0 &&
      inputTokens == 0 &&
      outputTokens == 0 &&
      cacheReadTokens == 0;
}

/// Los motores que aparecen en [entries], de mayor a menor consumo.
List<EngineUsage> rollupByEngine(List<UsageEntry> entries) {
  final providers = {for (final entry in entries) entry.provider};

  final rows = [
    for (final provider in providers)
      () {
        final mine = entries.where((entry) => entry.provider == provider);
        return EngineUsage(
          provider: provider,
          turns: mine.length,
          inputTokens: mine.fold(0, (sum, e) => sum + e.inputTokens),
          outputTokens: mine.fold(0, (sum, e) => sum + e.outputTokens),
          cacheReadTokens: mine.fold(0, (sum, e) => sum + e.cacheReadTokens),
          costUsd: mine.fold(0.0, (sum, e) => sum + e.costUsd),
          unmeasuredTurns: mine.where((e) => !e.tokensReported).length,
        );
      }(),
  ];
  rows.sort((a, b) {
    final byTokens = (b.inputTokens + b.outputTokens).compareTo(
      a.inputTokens + a.outputTokens,
    );
    return byTokens != 0 ? byTokens : a.provider.compareTo(b.provider);
  });
  return rows;
}

/// Tokens por proyecto, de mayor a menor. Las entradas sin proyecto (los
/// chats 1:1) van bajo la clave vacía y las agrupa quien las dibuja.
Map<String, int> rollupByProject(List<UsageEntry> entries) {
  final totals = <String, int>{};
  for (final entry in entries) {
    totals[entry.projectId] =
        (totals[entry.projectId] ?? 0) + entry.totalTokens;
  }
  final sorted = totals.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return {for (final entry in sorted) entry.key: entry.value};
}

/// Los modelos que aparecen en un tramo, en el orden en que hay que
/// apilarlos: el que más gastó primero, para que la leyenda y las barras
/// coincidan.
List<String> modelsIn(List<DayUsage> days) {
  final totals = <String, int>{};
  for (final day in days) {
    for (final entry in day.byModel.entries) {
      totals[entry.key] = (totals[entry.key] ?? 0) + entry.value;
    }
  }
  final sorted = totals.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return [for (final entry in sorted) entry.key];
}
