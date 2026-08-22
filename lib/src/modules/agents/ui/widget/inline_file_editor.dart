import 'package:flutter/material.dart';

import 'package:keel_ui/src/core/services/app_window_service.dart';
import 'package:keel_ui/src/core/services/file_edit_collector.dart';
import 'package:keel_ui/src/modules/agents/model/file_edit.dart';
import 'package:keel_ui/src/modules/agents/model/file_editor_window_arguments.dart';
import 'package:keel_ui/src/modules/agents/model/line_diff.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/file_editor_content.dart';
import 'package:keel_ui/src/shared/shared.dart';

/// The chat-bubble entry point for a [FileEdit]: a compact collapsed header
/// (name + change counts) that expands, in place, into the full
/// [FileEditorContent] — same diff/edit/preview experience as the separate
/// window, without leaving the conversation.
///
/// The widget owns no conversation of its own: whoever hosts it supplies the
/// callbacks, so the same editor serves a 1:1 agent chat and a workstation
/// channel. [windowAgentId] is only for popping out into a real OS window,
/// which needs an agent to bridge back to — null hides that button.
class InlineFileEditor extends StatefulWidget {
  const InlineFileEditor({
    super.key,
    required this.editAsReported,
    required this.workingDirectory,
    required this.onAskAboutLine,
    required this.onManualEditSaved,
    this.windowAgentId,
  });

  /// El cambio tal como lo registró el turno, con la ruta que reportó la CLI.
  final FileEdit editAsReported;

  /// El directorio del turno que escribió este mensaje.
  ///
  /// Los mensajes viejos guardaron la ruta como la reportó la CLI, que a
  /// veces es relativa (`./src/algo.rs`). Resolverla también acá hace que el
  /// hilo que ya está escrito se pueda abrir, no solo el que venga.
  final String? workingDirectory;

  /// El mismo cambio, con la ruta ya absoluta — que es la única con la que se
  /// puede abrir el archivo.
  FileEdit get fileEdit => editAsReported.path.startsWith('/')
      ? editAsReported
      : editAsReported.copyWith(
          path: FileEditCollector.resolvePath(
            editAsReported.path,
            workingDirectory,
          ),
        );
  final AskAboutLineCallback onAskAboutLine;
  final ManualEditSavedCallback onManualEditSaved;
  final String? windowAgentId;

  @override
  State<InlineFileEditor> createState() => _InlineFileEditorState();
}

class _InlineFileEditorState extends State<InlineFileEditor> {
  bool _expanded = false;

  String get _fileName => widget.fileEdit.path.split('/').last;

  ({int added, int removed})? get _counts {
    final diff = computeLineDiff(
      widget.fileEdit.beforeContent ?? '',
      widget.fileEdit.afterContent,
    );
    if (diff == null) return null;
    return (
      added: diff.where((line) => line.type == LineDiffType.added).length,
      removed: diff.where((line) => line.type == LineDiffType.removed).length,
    );
  }

  void _openInWindow() {
    final agentId = widget.windowAgentId;
    if (agentId == null) return;
    openAppWindow(
      FileEditorWindowArguments(fileEdit: widget.fileEdit, agentId: agentId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final counts = _counts;

    return Container(
      margin: const EdgeInsets.only(top: 6),
      decoration: ShapeDecoration(
        color: scheme.surfaceContainerHigh,
        shape: 12.smoothBorder(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.description_outlined,
                    size: 14,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _fileName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  if (counts != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      '+${counts.added} -${counts.removed}',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: scheme.outline,
                      ),
                    ),
                  ],
                  const SizedBox(width: 4),
                  if (widget.windowAgentId != null)
                    IconButton(
                      tooltip: 'Abrir en ventana nueva',
                      icon: const Icon(Icons.open_in_new, size: 14),
                      constraints: const BoxConstraints.tightFor(
                        width: 28,
                        height: 28,
                      ),
                      padding: EdgeInsets.zero,
                      onPressed: _openInWindow,
                    ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: scheme.outline,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            SizedBox(
              width: double.infinity,
              height: 480,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                child: FileEditorContent(
                  fileEdit: widget.fileEdit,
                  onAskAboutLine: widget.onAskAboutLine,
                  onManualEditSaved: widget.onManualEditSaved,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
