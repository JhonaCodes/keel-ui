part of '../../gpt_mcp_node.dart';

/// Settings section: the ChatGPT connection of this PC, its granted folders
/// and the chat's pending access requests.
class GptMcpSection extends StatelessWidget {
  const GptMcpSection({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return ReactiveViewModelBuilder<GptMcpNodeViewModel, GptMcpNodeState>(
      viewmodel: GptMcpNodeService.instance.notifier,
      build: (state, viewmodel, keep) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.settingGptMcp, style: theme.textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(t.descriptionGptMcp, style: theme.textTheme.bodySmall),
          const SizedBox(height: 8),
          _GptMcpConnectionRow(state: state, onToggle: viewmodel.setEnabled),
          if (state.chatUrlHint.isNotEmpty) ...[
            const SizedBox(height: 8),
            _GptMcpChatUrl(url: state.chatUrlHint),
          ],
          if (state.error != null) ...[
            const SizedBox(height: 8),
            Text(
              state.error!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          if (state.requests.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(t.labelGptMcpRequests, style: theme.textTheme.labelMedium),
            for (final request in state.requests)
              _GptMcpRequestTile(request: request, onDecide: viewmodel.decide),
          ],
          const SizedBox(height: 12),
          Text(t.labelGptMcpFolders, style: theme.textTheme.labelMedium),
          if (state.grants.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                t.messageGptMcpNoFolders,
                style: theme.textTheme.bodySmall,
              ),
            ),
          for (final grant in state.grants)
            _GptMcpGrantTile(grant: grant, onChange: viewmodel.setGrant),
          const SizedBox(height: 4),
          _GptMcpAddFolderButton(
            onPicked: (path) => viewmodel.setGrant(path, GptAccessMode.read),
          ),
        ],
      ),
    );
  }
}

class _GptMcpConnectionRow extends StatelessWidget {
  const _GptMcpConnectionRow({required this.state, required this.onToggle});

  final GptMcpNodeState state;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final (label, color) = switch (state.connection) {
      GptMcpConnection.notStarted => (
        t.labelGptMcpNotStarted,
        theme.colorScheme.outline,
      ),
      GptMcpConnection.tokenMissing => (
        t.messageGptMcpTokenMissing,
        theme.colorScheme.error,
      ),
      GptMcpConnection.off => (t.labelGptMcpOff, theme.colorScheme.outline),
      GptMcpConnection.connecting => (
        t.labelGptMcpConnecting,
        theme.colorScheme.tertiary,
      ),
      GptMcpConnection.connected => (
        t.labelGptMcpConnected,
        theme.colorScheme.primary,
      ),
    };
    return Row(
      children: [
        Icon(Icons.circle, size: 10, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
        Switch(
          value: state.enabled,
          onChanged: state.connection == GptMcpConnection.notStarted
              ? null
              : onToggle,
        ),
      ],
    );
  }
}

class _GptMcpChatUrl extends StatelessWidget {
  const _GptMcpChatUrl({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: SelectableText(
            '${t.labelGptMcpChatUrl}: $url',
            style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
          ),
        ),
        IconButton(
          tooltip: t.tooltipCopyToClipboard,
          icon: const Icon(Icons.copy, size: 16),
          onPressed: () => Clipboard.setData(ClipboardData(text: url)),
        ),
      ],
    );
  }
}

class _GptMcpGrantTile extends StatelessWidget {
  const _GptMcpGrantTile({required this.grant, required this.onChange});

  final GptGrant grant;
  final Future<void> Function(String folder, GptAccessMode? mode) onChange;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              grant.path,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SegmentedButton<GptAccessMode>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: GptAccessMode.read,
                label: Text(t.labelGptMcpRead),
              ),
              ButtonSegment(
                value: GptAccessMode.write,
                label: Text(t.labelGptMcpWrite),
              ),
            ],
            selected: {grant.mode},
            onSelectionChanged: (selection) =>
                onChange(grant.path, selection.first),
          ),
          IconButton(
            tooltip: t.buttonDelete,
            icon: const Icon(Icons.close, size: 16),
            onPressed: () => onChange(grant.path, null),
          ),
        ],
      ),
    );
  }
}

class _GptMcpRequestTile extends StatelessWidget {
  const _GptMcpRequestTile({required this.request, required this.onDecide});

  final GptAccessRequest request;
  final Future<void> Function(String requestId, GptAccessDecision decision)
  onDecide;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.path,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
                ),
                Text(
                  '${request.mode == GptAccessMode.write ? t.labelGptMcpWrite : t.labelGptMcpRead} · ${request.reason}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: () => onDecide(request.id, GptAccessDecision.approve),
            child: Text(t.buttonGptMcpApprove),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: () => onDecide(request.id, GptAccessDecision.deny),
            child: Text(t.buttonReject),
          ),
        ],
      ),
    );
  }
}

class _GptMcpAddFolderButton extends StatelessWidget {
  const _GptMcpAddFolderButton({required this.onPicked});

  final ValueChanged<String> onPicked;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return OutlinedButton.icon(
      icon: const Icon(Icons.create_new_folder_outlined, size: 18),
      label: Text(t.buttonGptMcpAddFolder),
      onPressed: () async {
        final path = await getDirectoryPath(
          confirmButtonText: t.buttonGptMcpAddFolder,
        );
        if (path != null) onPicked(path);
      },
    );
  }
}
