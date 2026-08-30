import 'package:flutter/material.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/l10n/generated/app_localizations.dart';
import 'package:keel_ui/src/integrations/app_update/app_update.dart';
import 'package:keel_ui/src/integrations/machine/machine.dart';
import 'package:keel_ui/src/integrations/usage_ledger/usage_ledger.dart';
import 'package:keel_ui/src/modules/machine/model/machine_snapshot.dart';
import 'package:keel_ui/src/modules/machine/ui/widget/usage_bars.dart';
import 'package:keel_ui/src/modules/machine/viewmodel/machine_viewmodel.dart';

/// Qué tenés instalado, cuánto gastó Keel y cómo está el fierro.
class MachineScreen extends StatefulWidget {
  const MachineScreen({super.key});

  @override
  State<MachineScreen> createState() => _MachineScreenState();
}

class _MachineScreenState extends State<MachineScreen> {
  @override
  void initState() {
    super.initState();
    MachineService.instance.notifier.startWatching();
  }

  @override
  void dispose() {
    MachineService.instance.notifier.stopWatching();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.pageTitleMachineTitle),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: TextButton.icon(
              onPressed: () =>
                  MachineService.instance.notifier.refreshServices(force: true),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Revisar de nuevo'),
            ),
          ),
        ],
      ),
      body: ReactiveViewModelBuilder<MachineViewModel, MachineSnapshot>(
        viewmodel: MachineService.instance.notifier,
        build: (snapshot, viewmodel, keep) => ListView(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 32),
          children: [
            // Primero Keel: la pregunta "¿qué estoy corriendo?" es de esta
            // pantalla igual que las otras tres, y es la única que además
            // tiene algo para hacer al respecto.
            const KeelVersionSection(),
            _Head(
              'Servicios',
              trailing: snapshot.services.isEmpty
                  ? null
                  : '${snapshot.supportedCount} con adaptador',
            ),
            if (snapshot.probing && snapshot.services.isEmpty)
              const _Loading()
            else
              for (final service in snapshot.services)
                _ServiceRow(service: service),
            const SizedBox(height: 10),
            _Note(AppLocalizations.of(context)!.messageDetectionNotIntegration),

            const _Usage(),

            _Head('Fierro', trailing: 'ahora mismo'),
            _Hardware(machine: snapshot.machine),
          ],
        ),
      ),
    );
  }
}

/// El consumo: el gráfico por día y el corte por motor.
class _Usage extends StatelessWidget {
  const _Usage();

  @override
  Widget build(BuildContext context) {
    return ReactiveViewModelBuilder<UsageLedgerViewModel, UsageLedgerState>(
      viewmodel: UsageLedgerService.instance.notifier,
      build: (state, viewmodel, keep) {
        final days = rollupByDay(state.entries, today: DateTime.now());
        final models = modelsIn(days);
        final engines = rollupByEngine(state.entries);
        final total = days.fold(0, (sum, day) => sum + day.total);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Head(
              AppLocalizations.of(context)!.labelConsumption,
              trailing: total == 0 ? null : '${_tokens(total)} tokens',
            ),
            UsageBars(days: days, models: models),
            if (models.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 6,
                children: [
                  for (final model in models) _LegendDot(model: model),
                ],
              ),
            ],
            const SizedBox(height: 18),
            if (engines.isEmpty)
              _Note(AppLocalizations.of(context)!.messageNoConsumptionYet)
            else ...[
              _EngineTable(engines: engines),
              const SizedBox(height: 10),
              _Note(
                'Es el consumo de Keel, no el de tu cuenta: solo puede sumar '
                'lo que salió por acá. Y el historial empieza el día que se '
                'instaló esta pantalla.',
              ),
            ],
          ],
        );
      },
    );
  }
}

class _EngineTable extends StatelessWidget {
  const _EngineTable({required this.engines});

  final List<EngineUsage> engines;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final head = TextStyle(
      fontFamily: 'monospace',
      fontSize: 9.5,
      letterSpacing: 0.9,
      color: scheme.outline,
    );
    const cell = TextStyle(fontFamily: 'monospace', fontSize: 11.5);

    return Table(
      columnWidths: const {
        0: FlexColumnWidth(1.4),
        1: FlexColumnWidth(1),
        2: FlexColumnWidth(1.2),
        3: FlexColumnWidth(1.2),
        4: FlexColumnWidth(1.4),
      },
      children: [
        TableRow(
          children: [
            Text('MOTOR', style: head),
            Text('TURNOS', style: head),
            Text('ENTRADA', style: head),
            Text('SALIDA', style: head),
            Text(AppLocalizations.of(context)!.labelCacheReadShort, style: head),
          ],
        ),
        for (final engine in engines)
          TableRow(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: scheme.outlineVariant)),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Text(engine.provider, style: cell),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                // Los turnos parados o caídos gastaron y no informaron nada.
                // Sumados en silencio bajarían el promedio por turno sin
                // explicar por qué, así que se dicen al lado del total.
                child: Text(
                  engine.unmeasured || engine.unmeasuredTurns == 0
                      ? '${engine.turns}'
                      : '${engine.turns}  (${engine.unmeasuredTurns} s/m)',
                  style: cell,
                ),
              ),
              if (engine.unmeasured)
                // Una sola celda con la verdad, en vez de tres ceros. Un cero
                // al lado de otro motor se lee "salió gratis"; lo que pasa es
                // que su CLI no informa nada.
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Text(
                    AppLocalizations.of(context)!.messageNoTokenCount,
                    style: cell.copyWith(color: scheme.outline),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Text(_tokens(engine.inputTokens), style: cell),
                ),
              if (engine.unmeasured)
                const SizedBox.shrink()
              else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Text(_tokens(engine.outputTokens), style: cell),
                ),
              if (engine.unmeasured)
                const SizedBox.shrink()
              else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Text(_tokens(engine.cacheReadTokens), style: cell),
                ),
            ],
          ),
      ],
    );
  }
}

class _Hardware extends StatelessWidget {
  const _Hardware({required this.machine});

  final MachineState machine;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (machine.cpu.isEmpty) return const _Loading();

    final running = machine.processes.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _Metric(
                label: 'Procesador',
                value: machine.cpu.replaceFirst('Apple ', ''),
                detail: '${machine.cores} núcleos',
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: _Metric(
                label: 'Carga',
                value: machine.load.toStringAsFixed(2).replaceAll('.', ','),
                detail: 'de ${AppLocalizations.of(context)!.labelCoresShort(machine.cores)}',
                ratio: machine.loadRatio,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: _Metric(
                label: 'Memoria',
                value: _gigabytes(machine.memoryUsedBytes),
                detail: 'de ${_gigabytes(machine.memoryTotalBytes)} GB',
                ratio: machine.memoryRatio,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: _Metric(
                label: 'Keel',
                value: '$running',
                detail: running == 1 ? 'turno corriendo' : 'turnos corriendo',
              ),
            ),
          ],
        ),
        if (machine.processes.isNotEmpty) ...[
          const SizedBox(height: 16),
          for (final process in machine.processes)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 64,
                    child: Text(
                      '${process.pid}',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: scheme.outline,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 90,
                    child: Text(
                      process.command.split('/').last,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 70,
                    child: Text(
                      '${process.cpuPercent.toStringAsFixed(1)} %',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 78,
                    child: Text(
                      '${(process.residentBytes / 1048576).round()} MB',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      RunningProcesses.labelOf(process.pid),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }

  String _gigabytes(int bytes) =>
      (bytes / 1073741824).toStringAsFixed(1).replaceAll('.', ',');
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.detail,
    this.ratio,
  });

  final String label;
  final String value;
  final String detail;
  final double? ratio;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 9.5,
              letterSpacing: 0.9,
              color: scheme.outline,
            ),
          ),
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: value),
                TextSpan(
                  text: '  $detail',
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 17,
              letterSpacing: -0.3,
            ),
          ),
          if (ratio case final value?) ...[
            const SizedBox(height: 9),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 3,
                backgroundColor: scheme.outlineVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ServiceRow extends StatelessWidget {
  const _ServiceRow({required this.service});

  final CliService service;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (chipLabel, chipColor) = switch (service) {
      CliService(installed: true, supported: true) => (
        'soportado',
        scheme.tertiary,
      ),
      CliService(installed: true) => (
        'detectado, sin adaptador',
        scheme.outline,
      ),
      _ => ('no instalado', scheme.outline),
    };

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 116,
            child: Text(
              service.binary,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: service.installed ? scheme.onSurface : scheme.outline,
              ),
            ),
          ),
          SizedBox(
            width: 150,
            child: Text(
              service.version.isEmpty ? '—' : service.version,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              service.installed ? service.path : AppLocalizations.of(context)!.messageNotInPath,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 10.5,
                color: scheme.outline,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(chipLabel, style: TextStyle(fontSize: 11, color: chipColor)),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.model});

  final String model;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, color: colorForModel(model)),
        const SizedBox(width: 6),
        Text(
          model,
          style: TextStyle(
            fontSize: 11.5,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 18),
    child: Center(
      child: SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 1.8),
      ),
    ),
  );
}

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.outline,
      ),
    );
  }
}

class _Head extends StatelessWidget {
  const _Head(this.label, {this.trailing});

  final String label;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = TextStyle(
      fontFamily: 'monospace',
      fontSize: 10,
      letterSpacing: 1.2,
      color: scheme.outline,
    );
    return Padding(
      padding: const EdgeInsets.only(top: 26, bottom: 10),
      child: Row(
        children: [
          Text(label.toUpperCase(), style: style),
          const SizedBox(width: 8),
          Expanded(child: Divider(height: 1, color: scheme.outlineVariant)),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            Text(trailing!, style: style),
          ],
        ],
      ),
    );
  }
}

String _tokens(int value) {
  if (value >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(1).replaceAll('.', ',')} M';
  }
  if (value >= 1000) return '${(value / 1000).round()} k';
  return '$value';
}
