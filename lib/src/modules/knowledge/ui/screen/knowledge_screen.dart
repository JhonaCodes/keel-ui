import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/src/modules/knowledge/viewmodel/knowledge_viewmodel.dart';

/// The Knowledge section: browse the markdown docs pulled from the
/// configured git repo, with the same renderer the chat uses.
class KnowledgeScreen extends StatefulWidget {
  const KnowledgeScreen({super.key});

  @override
  State<KnowledgeScreen> createState() => _KnowledgeScreenState();
}

class _KnowledgeScreenState extends State<KnowledgeScreen> {
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conocimiento'),
        actions: [
          ReactiveViewModelBuilder<KnowledgeViewModel, KnowledgeState>(
            viewmodel: KnowledgeService.instance.notifier,
            build: (state, viewmodel, keep) => IconButton(
              tooltip: 'Actualizar (git pull del repo configurado)',
              icon: state.busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              onPressed: state.busy ? null : viewmodel.update,
            ),
          ),
        ],
      ),
      body: ReactiveViewModelBuilder<KnowledgeViewModel, KnowledgeState>(
        viewmodel: KnowledgeService.instance.notifier,
        build: (state, viewmodel, keep) {
          if (state.documents.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  state.status.isEmpty
                      ? 'Sin documentación todavía.'
                      : state.status,
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final visible = _filter.isEmpty
              ? state.documents
              : state.documents
                    .where(
                      (path) =>
                          path.toLowerCase().contains(_filter.toLowerCase()),
                    )
                    .toList();

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 280,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                      child: TextField(
                        decoration: const InputDecoration(
                          isDense: true,
                          prefixIcon: Icon(Icons.search, size: 18),
                          hintText: 'Filtrar por nombre…',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(
                              Radius.circular(12),
                            ),
                          ),
                        ),
                        onChanged: (value) =>
                            setState(() => _filter = value.trim()),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: visible.length,
                        itemBuilder: (context, index) {
                          final path = visible[index];
                          return ListTile(
                            dense: true,
                            selected: path == state.selectedPath,
                            title: Text(
                              path.split('/').last,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: path.contains('/')
                                ? Text(
                                    path.substring(
                                      0,
                                      path.lastIndexOf('/'),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style:
                                        Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                  )
                                : null,
                            onTap: () => viewmodel.select(path),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: state.selectedPath == null
                    ? const Center(
                        child: Text('Elegí un documento de la izquierda.'),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: SelectionArea(
                          child: GptMarkdown(state.selectedContent),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
