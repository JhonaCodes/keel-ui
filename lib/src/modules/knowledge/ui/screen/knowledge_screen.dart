import 'package:flutter/material.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/src/modules/knowledge/ui/screen/knowledge_base_form_screen.dart';
import 'package:keel_ui/src/modules/knowledge/ui/widget/knowledge_document_view.dart';
import 'package:keel_ui/src/modules/knowledge/ui/widget/knowledge_tree.dart';
import 'package:keel_ui/src/modules/knowledge/viewmodel/knowledge_viewmodel.dart';

/// El área de Saber: bases con frontera de contexto a la izquierda, el
/// documento abierto a la derecha. Ver `docs/features/16-knowledge-bases.md`.
class KnowledgeScreen extends StatelessWidget {
  const KnowledgeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saber'),
        actions: [
          ReactiveViewModelBuilder<KnowledgeViewModel, KnowledgeState>(
            viewmodel: KnowledgeService.instance.notifier,
            build: (state, viewmodel, keep) => IconButton(
              tooltip: 'Actualizar todas las bases',
              icon: state.syncing.isEmpty
                  ? const Icon(Icons.refresh)
                  : const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
              onPressed: state.syncing.isEmpty ? viewmodel.syncAll : null,
            ),
          ),
          IconButton(
            tooltip: 'Nueva base de saber',
            icon: const Icon(Icons.add),
            onPressed: () => openKnowledgeBaseFormScreen(context),
          ),
        ],
      ),
      body: ReactiveViewModelBuilder<KnowledgeViewModel, KnowledgeState>(
        viewmodel: KnowledgeService.instance.notifier,
        build: (state, viewmodel, keep) {
          final document = state.selectedDocument;

          return Column(
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 300,
                      child: KnowledgeTree(state: state, viewmodel: viewmodel),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: document == null
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: Text(
                                  'Elegí un documento del árbol.',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            )
                          : KnowledgeDocumentView(document: document),
                    ),
                  ],
                ),
              ),
              if (state.status.isNotEmpty) _StatusBar(status: state.status),
            ],
          );
        },
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(status, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}
