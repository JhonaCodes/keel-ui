part of '../../catalog_bridge.dart';

/// La sección de Ajustes con el bloque que hay que pegar en un cliente MCP
/// de escritorio —ChatGPT desktop— para que vea el catálogo de Keel.
///
/// Muestra tres cosas distintas según el estado, y ninguna de las tres es
/// un error silencioso: o el catálogo no está sirviendo, o el worker no se
/// compiló todavía, o está todo listo y hay un bloque para copiar.
class ChatGptCatalogSection extends StatelessWidget {
  const ChatGptCatalogSection({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return ReactiveViewModelBuilder<CatalogBridgeViewModel, CatalogBridgeState>(
      viewmodel: CatalogBridgeService.instance.notifier,
      build: (bridge, viewmodel, keep) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.settingChatGptCatalog,
            style: theme.textTheme.labelLarge,
          ),
          const SizedBox(height: 4),
          Text(
            t.descriptionChatGptCatalog,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          switch ((bridge.isServing, bridge.command.isResolved)) {
            (false, _) => Text(t.messageCatalogBridgeNotRunning),
            (true, false) => _WorkerMissing(onRetry: viewmodel.refreshCommand),
            (true, true) => _CatalogConfigBlock(
              json: bridge.command.toPrettyJson(),
            ),
          },
        ],
      ),
    );
  }
}

/// El catálogo está sirviendo pero el binario del worker no existe en esta
/// máquina: el día uno, y después de cada `flutter clean`.
class _WorkerMissing extends StatelessWidget {
  const _WorkerMissing({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t.messageCatalogWorkerMissing),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh, size: 18),
          label: Text(t.buttonCheckAgain),
        ),
      ],
    );
  }
}

/// El bloque JSON listo para copiar.
///
/// Es `Stateful` por el acuse: sin él, apretar copiar no cambia nada en
/// pantalla y no hay forma de saber si el clic entró. Mismo molde que
/// `SyntaxHighlightedCodeView` y `CopyMessageReferenceButton` — marca y
/// vuelve sola a los dos segundos.
class _CatalogConfigBlock extends StatefulWidget {
  const _CatalogConfigBlock({required this.json});

  final String json;

  @override
  State<_CatalogConfigBlock> createState() => _CatalogConfigBlockState();
}

class _CatalogConfigBlockState extends State<_CatalogConfigBlock> {
  bool _copied = false;
  Timer? _reset;

  @override
  void dispose() {
    _reset?.cancel();
    super.dispose();
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.json));
    if (!mounted) return;
    setState(() => _copied = true);
    _reset?.cancel();
    _reset = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: SelectableText(
            widget.json,
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
            ),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _copy,
          icon: Icon(_copied ? Icons.check : Icons.copy, size: 18),
          label: Text(
            _copied ? t.messageCopiedToClipboard : t.tooltipCopyToClipboard,
          ),
        ),
      ],
    );
  }
}
