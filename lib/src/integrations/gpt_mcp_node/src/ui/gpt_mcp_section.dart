part of '../../gpt_mcp_node.dart';

/// Settings section: GPT MCP of this PC or of the server, picked at the
/// top. Both show the same thing: the ChatGPT connection, the chat's access
/// requests, the granted folders, a folder picker and a new folder for GPT.
class GptMcpSection extends StatefulWidget {
  const GptMcpSection({super.key});

  @override
  State<GptMcpSection> createState() => _GptMcpSectionState();
}

class _GptMcpSectionState extends State<GptMcpSection> {
  GptMcpTarget _target = GptMcpTarget.pc;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t.settingGptMcp, style: theme.textTheme.labelLarge),
        const SizedBox(height: 4),
        Text(t.descriptionGptMcp, style: theme.textTheme.bodySmall),
        const SizedBox(height: 8),
        SegmentedButton<GptMcpTarget>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(
              value: GptMcpTarget.pc,
              label: Text(t.labelGptMcpThisPc),
              icon: const Icon(Icons.laptop_mac, size: 16),
            ),
            ButtonSegment(
              value: GptMcpTarget.server,
              label: Text(t.labelGptMcpServer),
              icon: const Icon(Icons.dns_outlined, size: 16),
            ),
          ],
          selected: {_target},
          onSelectionChanged: (selection) =>
              setState(() => _target = selection.first),
        ),
        const SizedBox(height: 8),
        switch (_target) {
          GptMcpTarget.pc => const _GptMcpPcPanel(),
          GptMcpTarget.server => const _GptMcpServerPanel(),
        },
      ],
    );
  }
}

class _GptMcpPcPanel extends StatelessWidget {
  const _GptMcpPcPanel();

  @override
  Widget build(BuildContext context) =>
      ReactiveViewModelBuilder<GptMcpNodeViewModel, GptMcpNodeState>(
        viewmodel: GptMcpNodeService.instance.notifier,
        build: (state, viewmodel, keep) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((state.status?.panelUrl ?? '').isNotEmpty)
              _GptMcpOpenPanelButton(onOpen: viewmodel.openPanel),
            _GptMcpNodePanel(
              state: state,
              actions: viewmodel,
              canPickLocally: true,
            ),
          ],
        ),
      );
}

/// The web panel: this PC and the server, with the whole folder tree.
class _GptMcpOpenPanelButton extends StatelessWidget {
  const _GptMcpOpenPanelButton({required this.onOpen});

  final Future<void> Function() onOpen;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: OutlinedButton.icon(
        icon: const Icon(Icons.open_in_browser, size: 18),
        label: Text(t.buttonGptMcpOpenPanel),
        onPressed: onOpen,
      ),
    );
  }
}

class _GptMcpServerPanel extends StatelessWidget {
  const _GptMcpServerPanel();

  @override
  Widget build(BuildContext context) =>
      ReactiveViewModelBuilder<GptMcpServerViewModel, GptMcpNodeState>(
        viewmodel: GptMcpServerService.instance.notifier,
        build: (state, viewmodel, keep) => _GptMcpNodePanel(
          state: state,
          actions: viewmodel,
          canPickLocally: false,
        ),
      );
}

/// One node's GPT MCP, whichever machine it runs on.
class _GptMcpNodePanel extends StatelessWidget {
  const _GptMcpNodePanel({
    required this.state,
    required this.actions,
    required this.canPickLocally,
  });

  final GptMcpNodeState state;
  final GptMcpNodeActions actions;

  /// This PC's folders can also be picked with the system dialog.
  final bool canPickLocally;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 1.5,
          child: state.busy ? const LinearProgressIndicator() : null,
        ),
        _GptMcpConnectionRow(state: state, onToggle: actions.setEnabled),
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
            _GptMcpRequestTile(request: request, onDecide: actions.decide),
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
          _GptMcpGrantTile(grant: grant, onChange: actions.setGrant),
        if (canPickLocally) ...[
          const SizedBox(height: 4),
          _GptMcpAddFolderButton(
            onPicked: (path) => actions.setGrant(path, GptAccessMode.read),
          ),
        ],
        const SizedBox(height: 12),
        _GptMcpFolderBrowser(state: state, actions: actions),
        const SizedBox(height: 8),
        _GptMcpNewFolder(onCreate: actions.createFolder),
      ],
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
          onChanged:
              state.connection == GptMcpConnection.notStarted || state.busy
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

/// none / read / read-write, for a granted folder or a picker row.
class _GptMcpModeButton extends StatelessWidget {
  const _GptMcpModeButton({required this.mode, required this.onChange});

  final GptAccessMode? mode;
  final ValueChanged<GptAccessMode?> onChange;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return SegmentedButton<GptAccessMode?>(
      showSelectedIcon: false,
      style: const ButtonStyle(visualDensity: VisualDensity.compact),
      segments: [
        ButtonSegment(value: null, label: Text(t.labelGptMcpNone)),
        ButtonSegment(
          value: GptAccessMode.read,
          label: Text(t.labelGptMcpRead),
        ),
        ButtonSegment(
          value: GptAccessMode.write,
          label: Text(t.labelGptMcpWrite),
        ),
      ],
      selected: {mode},
      onSelectionChanged: (selection) => onChange(selection.first),
    );
  }
}

class _GptMcpGrantTile extends StatelessWidget {
  const _GptMcpGrantTile({required this.grant, required this.onChange});

  final GptGrant grant;
  final Future<void> Function(String folder, GptAccessMode? mode) onChange;

  @override
  Widget build(BuildContext context) {
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
          _GptMcpModeButton(
            mode: grant.mode,
            onChange: (mode) => onChange(grant.path, mode),
          ),
        ],
      ),
    );
  }
}

/// The node's folders under its base: open one to go in, set its access.
class _GptMcpFolderBrowser extends StatelessWidget {
  const _GptMcpFolderBrowser({required this.state, required this.actions});

  final GptMcpNodeState state;
  final GptMcpNodeActions actions;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final parent = state.browseParent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                t.labelGptMcpBrowseIn(
                  state.browsePath.isEmpty ? state.base : state.browsePath,
                ),
                style: theme.textTheme.labelMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (parent != null)
              TextButton.icon(
                icon: const Icon(Icons.arrow_upward, size: 16),
                label: Text(t.buttonGptMcpUp),
                onPressed: state.busy ? null : () => actions.browse(parent),
              ),
          ],
        ),
        if (state.folders.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              t.messageGptMcpNoSubfolders,
              style: theme.textTheme.bodySmall,
            ),
          ),
        for (final folder in state.folders)
          _GptMcpFolderRow(
            folder: folder,
            enabled: !state.busy,
            onOpen: () => actions.browse(folder.path),
            onChange: (mode) => actions.setGrant(folder.path, mode),
          ),
      ],
    );
  }
}

class _GptMcpFolderRow extends StatelessWidget {
  const _GptMcpFolderRow({
    required this.folder,
    required this.enabled,
    required this.onOpen,
    required this.onChange,
  });

  final GptFolderNode folder;
  final bool enabled;
  final VoidCallback onOpen;
  final ValueChanged<GptAccessMode?> onChange;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final inherited = folder.explicit == null ? folder.effective : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: enabled ? onOpen : null,
              child: Row(
                children: [
                  const Icon(Icons.folder_outlined, size: 16),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      folder.name,
                      style: theme.textTheme.bodyMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (inherited != null) ...[
                    const SizedBox(width: 6),
                    Text(
                      inherited == GptAccessMode.write
                          ? t.labelGptMcpWrite
                          : t.labelGptMcpRead,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          _GptMcpModeButton(
            mode: folder.explicit,
            onChange: enabled ? onChange : (_) {},
          ),
        ],
      ),
    );
  }
}

/// A new folder for GPT inside the folder shown, granted read-write.
class _GptMcpNewFolder extends StatefulWidget {
  const _GptMcpNewFolder({required this.onCreate});

  final Future<void> Function(String folder, GptAccessMode mode) onCreate;

  @override
  State<_GptMcpNewFolder> createState() => _GptMcpNewFolderState();
}

class _GptMcpNewFolderState extends State<_GptMcpNewFolder> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    await widget.onCreate(name, GptAccessMode.write);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            decoration: InputDecoration(
              isDense: true,
              hintText: t.hintGptMcpNewFolder,
              prefixIcon: const Icon(
                Icons.create_new_folder_outlined,
                size: 18,
              ),
            ),
            onSubmitted: (_) => _create(),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: _create,
          child: Text(t.buttonGptMcpCreateFolder),
        ),
      ],
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
