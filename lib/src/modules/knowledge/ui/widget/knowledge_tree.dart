import 'package:flutter/material.dart';

import 'package:keel_ui/src/modules/knowledge/model/knowledge_base.dart';
import 'package:keel_ui/src/modules/knowledge/model/knowledge_document.dart';
import 'package:keel_ui/src/modules/knowledge/ui/screen/knowledge_base_form_screen.dart';
import 'package:keel_ui/src/modules/knowledge/viewmodel/knowledge_viewmodel.dart';

/// El árbol del Saber: las bases en la raíz, sus carpetas desplegables y sus
/// documentos como hojas. Qué está desplegado es estado de vista y vive acá;
/// el contenido sale del índice que arma el ViewModel.
class KnowledgeTree extends StatefulWidget {
  const KnowledgeTree({
    super.key,
    required this.state,
    required this.viewmodel,
  });

  final KnowledgeState state;
  final KnowledgeViewModel viewmodel;

  @override
  State<KnowledgeTree> createState() => _KnowledgeTreeState();
}

class _KnowledgeTreeState extends State<KnowledgeTree> {
  /// Claves desplegadas: el id de la base para su raíz, y
  /// `<baseId>::<rutaRelativa>` para cada carpeta de adentro.
  final _expanded = <String>{};

  void _toggle(String key) => setState(() {
    _expanded.contains(key) ? _expanded.remove(key) : _expanded.add(key);
  });

  @override
  Widget build(BuildContext context) {
    if (widget.state.bases.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Todavía no hay bases de saber. Creá una con el botón + : una '
          'carpeta que ya tengas en el disco, o un repo git.',
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        for (final base in widget.state.bases) ..._baseRows(context, base),
      ],
    );
  }

  List<Widget> _baseRows(BuildContext context, KnowledgeBase base) {
    final index = widget.state.indexes[base.id];
    final isOpen = _expanded.contains(base.id);

    return [
      _BaseRow(
        base: base,
        documentCount: index?.documentCount ?? 0,
        problem: index?.problem ?? '',
        expanded: isOpen,
        syncing: widget.state.syncing.contains(base.id),
        onToggle: () => _toggle(base.id),
        onSync: () => widget.viewmodel.syncBase(base.id),
        onEdit: () => openKnowledgeBaseFormScreen(context, initial: base),
      ),
      if (isOpen && index != null)
        for (final node in index.nodes) ..._nodeRows(base, node, 1),
    ];
  }

  List<Widget> _nodeRows(KnowledgeBase base, KnowledgeNode node, int depth) {
    final key = '${base.id}::${node.relativePath}';
    final isOpen = _expanded.contains(key);
    final selected =
        widget.state.selectedDocument?.baseId == base.id &&
        widget.state.selectedDocument?.relativePath == node.relativePath;

    return [
      _NodeRow(
        node: node,
        depth: depth,
        expanded: isOpen,
        selected: selected,
        onTap: () => node.isDirectory
            ? _toggle(key)
            : widget.viewmodel.selectDocument(base.id, node.relativePath),
      ),
      if (node.isDirectory && isOpen)
        for (final child in node.children) ..._nodeRows(base, child, depth + 1),
    ];
  }
}

/// La fila de una base: nombre, cuántos documentos tiene y sus acciones.
class _BaseRow extends StatelessWidget {
  const _BaseRow({
    required this.base,
    required this.documentCount,
    required this.problem,
    required this.expanded,
    required this.syncing,
    required this.onToggle,
    required this.onSync,
    required this.onEdit,
  });

  final KnowledgeBase base;
  final int documentCount;
  final String problem;
  final bool expanded;
  final bool syncing;
  final VoidCallback onToggle;
  final VoidCallback onSync;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
        child: Row(
          children: [
            Icon(
              expanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
              size: 18,
            ),
            const SizedBox(width: 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    base.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    problem.isNotEmpty
                        ? problem
                        : '$documentCount documentos · ${base.source.label}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: problem.isEmpty
                          ? theme.colorScheme.onSurfaceVariant
                          : theme.colorScheme.error,
                    ),
                  ),
                ],
              ),
            ),
            if (syncing)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              IconButton(
                tooltip: base.source == KnowledgeSource.git
                    ? 'Actualizar (git pull)'
                    : 'Releer la carpeta',
                icon: const Icon(Icons.refresh, size: 18),
                onPressed: onSync,
              ),
            IconButton(
              tooltip: 'Editar base',
              icon: const Icon(Icons.tune, size: 18),
              onPressed: onEdit,
            ),
          ],
        ),
      ),
    );
  }
}

/// La fila de una carpeta o un documento, sangrada según su profundidad.
class _NodeRow extends StatelessWidget {
  const _NodeRow({
    required this.node,
    required this.depth,
    required this.expanded,
    required this.selected,
    required this.onTap,
  });

  final KnowledgeNode node;
  final int depth;
  final bool expanded;
  final bool selected;
  final VoidCallback onTap;

  IconData get _icon {
    if (node.isDirectory) {
      return expanded ? Icons.folder_open_outlined : Icons.folder_outlined;
    }
    return switch (KnowledgeDocument.kindOf(node.relativePath)) {
      KnowledgeDocumentKind.markdown => Icons.article_outlined,
      KnowledgeDocumentKind.mermaid => Icons.account_tree_outlined,
      KnowledgeDocumentKind.svg => Icons.polyline_outlined,
      KnowledgeDocumentKind.image => Icons.image_outlined,
      KnowledgeDocumentKind.code => Icons.code,
      KnowledgeDocumentKind.unsupported => Icons.insert_drive_file_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      child: Container(
        color: selected ? theme.colorScheme.primary.withValues(alpha: 0.14) : null,
        padding: EdgeInsets.fromLTRB(6.0 + depth * 14, 4, 6, 4),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              child: node.isDirectory
                  ? Icon(
                      expanded
                          ? Icons.keyboard_arrow_down
                          : Icons.keyboard_arrow_right,
                      size: 16,
                    )
                  : null,
            ),
            Icon(_icon, size: 15, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                node.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
            if (node.isDirectory)
              Text(
                '${node.documentCount}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
