import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

import 'package:keel_ui/l10n/generated/app_localizations.dart';
import 'package:keel_ui/src/core/services/local_file_service.dart';
import 'package:keel_ui/src/modules/agents/model/code_language.dart';
import 'package:keel_ui/src/modules/agents/model/file_edit.dart';
import 'package:keel_ui/src/modules/agents/model/highlighted_line.dart';
import 'package:keel_ui/src/modules/agents/model/line_diff.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/code_editing_controller.dart';
import 'package:keel_ui/src/core/ui/confirm_card.dart';

typedef AskAboutLineCallback =
    Future<void> Function({
      required String filePath,
      required int lineNumber,
      required String lineContent,
      required String question,
    });

typedef ManualEditSavedCallback =
    Future<void> Function({
      required String filePath,
      required String beforeContent,
      required String afterContent,
    });

enum _EditorTab { diff, edit, preview }

class _NumberedDiffLine {
  final DiffLine line;
  final int? beforeLineNo;
  final int? afterLineNo;

  const _NumberedDiffLine(this.line, this.beforeLineNo, this.afterLineNo);
}

List<_NumberedDiffLine> _numberDiff(List<DiffLine> lines) {
  var before = 0;
  var after = 0;
  final result = <_NumberedDiffLine>[];
  for (final line in lines) {
    switch (line.type) {
      case LineDiffType.unchanged:
        before++;
        after++;
        result.add(_NumberedDiffLine(line, before, after));
      case LineDiffType.removed:
        before++;
        result.add(_NumberedDiffLine(line, before, null));
      case LineDiffType.added:
        after++;
        result.add(_NumberedDiffLine(line, null, after));
    }
  }
  return result;
}

/// The reusable content of the file editor — a plain widget, deliberately
/// not tied to a [Dialog] or window, so it can be hosted in either.
class FileEditorContent extends StatefulWidget {
  const FileEditorContent({
    super.key,
    required this.fileEdit,
    required this.onAskAboutLine,
    required this.onManualEditSaved,
  });

  final FileEdit fileEdit;
  final AskAboutLineCallback onAskAboutLine;
  final ManualEditSavedCallback onManualEditSaved;

  @override
  State<FileEditorContent> createState() => _FileEditorContentState();
}

class _FileEditorContentState extends State<FileEditorContent> {
  LocalFileService get _files => LocalFileService();

  late List<DiffLine>? _diff;
  late _EditorTab _tab;
  late final String _language;
  late final CodeEditingController _editController;
  final _questionController = TextEditingController();

  List<List<HlSpan>>? _beforeHlLines;
  List<List<HlSpan>>? _afterHlLines;

  int? _selectedLineIndex;
  bool _loading = true;
  bool _saving = false;
  bool _asking = false;
  String? _error;
  String? _loadedSnapshot;

  bool get _isMarkdown {
    final lower = widget.fileEdit.path.toLowerCase();
    return lower.endsWith('.md') || lower.endsWith('.markdown');
  }

  @override
  void initState() {
    super.initState();
    _language = codeLanguageForPath(widget.fileEdit.path);
    _editController = CodeEditingController(
      language: _language,
      theme: codeHighlightTheme(Brightness.dark),
    );
    _diff = computeLineDiff(
      widget.fileEdit.beforeContent ?? '',
      widget.fileEdit.afterContent,
    );
    if (_diff != null) {
      _beforeHlLines = highlightLines(
        widget.fileEdit.beforeContent ?? '',
        _language,
      );
      _afterHlLines = highlightLines(widget.fileEdit.afterContent, _language);
    }
    _tab = _diff != null ? _EditorTab.diff : _EditorTab.edit;
    _loadCurrentContent();
  }

  List<HlSpan> _hlSpansFor(_NumberedDiffLine numbered) {
    final removed = numbered.line.type == LineDiffType.removed;
    final lines = removed ? _beforeHlLines : _afterHlLines;
    final lineNo = removed ? numbered.beforeLineNo : numbered.afterLineNo;
    if (lines == null || lineNo == null || lineNo - 1 >= lines.length) {
      return [HlSpan(numbered.line.content, null)];
    }
    return lines[lineNo - 1];
  }

  Future<void> _loadCurrentContent() async {
    try {
      final content = await _files.readText(widget.fileEdit.path);
      if (!mounted) return;
      setState(() {
        _editController.text = content;
        _loadedSnapshot = content;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo abrir el archivo: $error';
        _loading = false;
      });
    }
  }

  Future<bool> _confirmOverwriteStale() {
    final t = AppLocalizations.of(context);
    return confirmWithCard(
      context,
      title: t.labelFileChanged,
      body: t.messageFileChangedBody,
      confirmLabel: t.buttonOverwriteAnyway,
      destructive: true,
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final newContent = _editController.text;

      final onDiskNow = await _files.readText(widget.fileEdit.path);
      if (onDiskNow != _loadedSnapshot) {
        final overwrite = await _confirmOverwriteStale();
        if (!overwrite) {
          if (!mounted) return;
          setState(() => _saving = false);
          return;
        }
      }

      await _files.writeText(widget.fileEdit.path, newContent);
      if (newContent != widget.fileEdit.afterContent) {
        await widget.onManualEditSaved(
          filePath: widget.fileEdit.path,
          beforeContent: widget.fileEdit.afterContent,
          afterContent: newContent,
        );
      }
      if (!mounted) return;
      setState(() {
        _saving = false;
        _loadedSnapshot = newContent;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'No se pudo guardar: $error';
      });
    }
  }

  Future<void> _reload() async {
    if (_editController.text != _loadedSnapshot) {
      final discard = await confirmWithCard(
        context,
        title: 'Descartar cambios sin guardar',
        body:
            'Tienes cambios sin guardar en este editor. Si recargas del '
            'disco ahora, los vas a perder.',
        confirmLabel: 'Descartar y recargar',
        destructive: true,
      );
      if (!discard) return;
    }

    setState(() => _loading = true);
    await _loadCurrentContent();
  }

  void _selectDiffLine(int index) {
    setState(
      () => _selectedLineIndex = _selectedLineIndex == index ? null : index,
    );
  }

  Future<void> _askAboutSelectedLine(_NumberedDiffLine numbered) async {
    final question = _questionController.text.trim();
    if (question.isEmpty) return;

    setState(() => _asking = true);
    await widget.onAskAboutLine(
      filePath: widget.fileEdit.path,
      lineNumber: numbered.afterLineNo ?? numbered.beforeLineNo ?? 0,
      lineContent: numbered.line.content,
      question: question,
    );
    if (!mounted) return;
    setState(() {
      _asking = false;
      _questionController.clear();
      _selectedLineIndex = null;
    });
  }

  @override
  void dispose() {
    _editController.dispose();
    _questionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _editController.theme = codeHighlightTheme(Theme.of(context).brightness);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TabBar(
          hasDiff: _diff != null,
          isMarkdown: _isMarkdown,
          selected: _tab,
          onSelected: (tab) => setState(() => _tab = tab),
        ),
        const SizedBox(height: 10),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        Expanded(
          child: switch ((_loading, _tab)) {
            (true, _) => const Center(child: CircularProgressIndicator()),
            (false, _EditorTab.diff) => _DiffTab(
              numbered: _diff == null ? null : _numberDiff(_diff!),
              selectedLineIndex: _selectedLineIndex,
              asking: _asking,
              questionController: _questionController,
              spansFor: _hlSpansFor,
              onSelectLine: _selectDiffLine,
              onAsk: _askAboutSelectedLine,
            ),
            (false, _EditorTab.edit) => _EditTab(
              controller: _editController,
              saving: _saving,
              onSave: _save,
              onReload: _reload,
            ),
            (false, _EditorTab.preview) => _PreviewTab(
              controller: _editController,
            ),
          },
        ),
      ],
    );
  }
}

class _DiffTab extends StatelessWidget {
  const _DiffTab({
    required this.numbered,
    required this.selectedLineIndex,
    required this.asking,
    required this.questionController,
    required this.spansFor,
    required this.onSelectLine,
    required this.onAsk,
  });

  final List<_NumberedDiffLine>? numbered;
  final int? selectedLineIndex;
  final bool asking;
  final TextEditingController questionController;
  final List<HlSpan> Function(_NumberedDiffLine line) spansFor;
  final ValueChanged<int> onSelectLine;
  final ValueChanged<_NumberedDiffLine> onAsk;

  @override
  Widget build(BuildContext context) {
    final lines = numbered;
    if (lines == null) {
      return const Center(
        child: Text('El archivo es muy grande para mostrar un diff.'),
      );
    }

    final theme = codeHighlightTheme(Theme.of(context).brightness);
    final selected = selectedLineIndex;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SelectionArea(
            child: ListView.builder(
              itemCount: lines.length,
              itemBuilder: (context, index) => _DiffLineRow(
                numbered: lines[index],
                hlSpans: spansFor(lines[index]),
                hlTheme: theme,
                selected: selected == index,
                onTap: () => onSelectLine(index),
              ),
            ),
          ),
        ),
        if (selected != null)
          _AskBar(
            asking: asking,
            controller: questionController,
            onSubmit: () => onAsk(lines[selected]),
          ),
      ],
    );
  }
}

class _EditTab extends StatelessWidget {
  const _EditTab({
    required this.controller,
    required this.saving,
    required this.onSave,
    required this.onReload,
  });

  final CodeEditingController controller;
  final bool saving;
  final VoidCallback onSave;
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: scheme.outlineVariant),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(10),
            child: TextField(
              controller: controller,
              maxLines: null,
              expands: true,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              decoration: const InputDecoration(border: InputBorder.none),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: saving ? null : onReload,
              child: const Text('Recargar del disco'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: saving ? null : onSave,
              child: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Guardar'),
            ),
          ],
        ),
      ],
    );
  }
}

class _PreviewTab extends StatelessWidget {
  const _PreviewTab({required this.controller});

  final CodeEditingController controller;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(child: GptMarkdown(controller.text));
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({
    required this.hasDiff,
    required this.isMarkdown,
    required this.selected,
    required this.onSelected,
  });

  final bool hasDiff;
  final bool isMarkdown;
  final _EditorTab selected;
  final ValueChanged<_EditorTab> onSelected;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<_EditorTab>(
      segments: [
        if (hasDiff)
          const ButtonSegment(value: _EditorTab.diff, label: Text('Diff')),
        const ButtonSegment(value: _EditorTab.edit, label: Text('Editar')),
        if (isMarkdown)
          const ButtonSegment(value: _EditorTab.preview, label: Text('Vista')),
      ],
      selected: {selected},
      onSelectionChanged: (values) => onSelected(values.first),
    );
  }
}

class _DiffLineRow extends StatelessWidget {
  const _DiffLineRow({
    required this.numbered,
    required this.hlSpans,
    required this.hlTheme,
    required this.selected,
    required this.onTap,
  });

  final _NumberedDiffLine numbered;
  final List<HlSpan> hlSpans;
  final Map<String, TextStyle> hlTheme;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final background = switch (numbered.line.type) {
      LineDiffType.added => Colors.green.withValues(alpha: 0.15),
      LineDiffType.removed => Colors.red.withValues(alpha: 0.15),
      LineDiffType.unchanged => Colors.transparent,
    };

    final textColor = switch (numbered.line.type) {
      LineDiffType.added => Colors.green.shade400,
      LineDiffType.removed => Colors.red.shade400,
      LineDiffType.unchanged => scheme.onSurface,
    };

    final marker = switch (numbered.line.type) {
      LineDiffType.added => '+',
      LineDiffType.removed => '-',
      LineDiffType.unchanged => ' ',
    };

    return InkWell(
      onTap: onTap,
      child: Container(
        color: selected ? scheme.primary.withValues(alpha: 0.15) : background,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 36,
              child: Text(
                (numbered.afterLineNo ?? numbered.beforeLineNo ?? '')
                    .toString(),
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: scheme.outline,
                ),
              ),
            ),
            SizedBox(
              width: 14,
              child: Text(
                marker,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ),
            Expanded(
              child: Text.rich(
                TextSpan(
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: scheme.onSurface,
                  ),
                  children: renderHighlightedLine(hlSpans, hlTheme),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AskBar extends StatelessWidget {
  const _AskBar({
    required this.asking,
    required this.controller,
    required this.onSubmit,
  });

  final bool asking;
  final TextEditingController controller;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: !asking,
              decoration: InputDecoration(
                hintText: t.hintAskAboutThisLine,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onSubmitted: (_) => onSubmit(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: asking ? null : onSubmit,
            icon: asking
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
          ),
        ],
      ),
    );
  }
}
