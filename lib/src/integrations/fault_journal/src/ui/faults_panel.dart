part of '../../fault_journal.dart';

/// Abre el diario. Abrirlo marca todo como visto: mirarlas ES verlas.
Future<void> openFaultsPanel(BuildContext context) async {
  unawaited(FaultJournalService.instance.notifier.markSeen());
  await showFormPanel<void>(context, width: 720, child: const FaultsPanel());
}

/// Todo lo que se rompió, lo más nuevo arriba.
class FaultsPanel extends StatelessWidget {
  const FaultsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return ReactiveViewModelBuilder<FaultJournalViewModel, FaultJournalState>(
      viewmodel: FaultJournalService.instance.notifier,
      build: (state, viewmodel, keep) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Fallas'),
            actions: [
              if (state.faults.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: TextButton(
                    onPressed: viewmodel.clear,
                    child: const Text('Vaciar'),
                  ),
                ),
            ],
          ),
          body: state.faults.isEmpty
              ? const _Empty()
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                  itemCount: state.faults.length + 1,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) => index == state.faults.length
                      ? const _Foot()
                      : _FaultRow(fault: state.faults[index]),
                ),
        );
      },
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.done_all, size: 28, color: scheme.tertiary),
            const SizedBox(height: 12),
            Text(
              'Nada roto por acá.',
              style: TextStyle(fontSize: 14, color: scheme.onSurface),
            ),
            const SizedBox(height: 8),
            Text(
              'Acá cae todo lo que revienta: un respaldo que no pudo '
              'escribir, un flujo que se cortó, un error de la interfaz. '
              'Antes eso vivía en la consola, que existe solo mientras la '
              'tengas abierta.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                height: 1.45,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Foot extends StatelessWidget {
  const _Foot();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 0),
      child: Text(
        'Se guardan las últimas ${FaultJournalViewModel.capacity}, hasta '
        '${FaultJournalViewModel.retention.inDays} días. Nada de esto sale '
        'de tu máquina.',
        style: TextStyle(fontSize: 11, height: 1.4, color: scheme.outline),
      ),
    );
  }
}

/// Una falla: se lee cerrada y se abre para ver el stack.
class _FaultRow extends StatefulWidget {
  const _FaultRow({required this.fault});

  final Fault fault;

  @override
  State<_FaultRow> createState() => _FaultRowState();
}

class _FaultRowState extends State<_FaultRow> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fault = widget.fault;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: fault.detail.isEmpty
                ? null
                : () => setState(() => _open = !_open),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Icon(
                      Icons.error_outline,
                      size: 15,
                      color: scheme.error,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fault.message,
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.35,
                            color: scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        _Meta(fault: fault),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    tooltip: 'Copiar la falla entera',
                    visualDensity: VisualDensity.compact,
                    iconSize: 15,
                    icon: const Icon(Icons.copy_all_outlined),
                    onPressed: () =>
                        Clipboard.setData(ClipboardData(text: fault.asText)),
                  ),
                  if (fault.detail.isNotEmpty)
                    Icon(
                      _open ? Icons.expand_less : Icons.expand_more,
                      size: 16,
                      color: scheme.outline,
                    ),
                ],
              ),
            ),
          ),
          if (_open)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(6),
              ),
              child: SelectableText(
                fault.detail,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10.5,
                  height: 1.45,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// La línea de abajo: cuándo, dónde y cuántas veces.
class _Meta extends StatelessWidget {
  const _Meta({required this.fault});

  final Fault fault;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final partes = [
      _ago(fault.lastAt),
      if (fault.where.isNotEmpty) fault.where,
      if (fault.context.isNotEmpty) fault.context,
    ];

    return Row(
      children: [
        Flexible(
          child: Text(
            partes.join('  ·  '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 10,
              color: scheme.outline,
            ),
          ),
        ),
        // El contador solo aparece cuando dice algo. "×1" es ruido.
        if (fault.count > 1) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: scheme.error.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '×${fault.count}',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 9.5,
                color: scheme.error,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

String _ago(DateTime at) {
  final elapsed = DateTime.now().difference(at);
  if (elapsed.inMinutes < 1) return 'recién';
  if (elapsed.inMinutes < 60) return 'hace ${elapsed.inMinutes} min';
  if (elapsed.inHours < 24) return 'hace ${elapsed.inHours} h';
  return 'hace ${elapsed.inDays} d';
}
