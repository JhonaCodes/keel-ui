import 'package:flutter/material.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_ui/src/core/ui/form_panel.dart';
import 'package:keel_ui/src/modules/catalog_locks/model/catalog_lock.dart';
import 'package:keel_ui/src/modules/catalog_locks/viewmodel/catalog_locks_viewmodel.dart';

Future<void> openCatalogLocksPanel(BuildContext context) {
  return showFormPanel<void>(context, child: const CatalogLocksScreen());
}

/// Todo lo que está bloqueado, junto y en un solo lugar.
///
/// Un candado se pone desde el ítem —el botón del tile— y hasta acá esa era
/// también la única forma de sacarlo: para acordarte de qué protegiste
/// tenías que recorrer skills, reglas, tools, agentes, workflows, proyectos,
/// hooks, MCPs, tableros, secrets y bases una por una. Con doce catálogos,
/// eso no es una lista: es una búsqueda.
///
/// Lo que muestra es exactamente lo que ve un agente cuando llama
/// `list_locked_items` — la misma data, sin una copia aparte.
class CatalogLocksScreen extends StatelessWidget {
  const CatalogLocksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Elementos bloqueados')),
      body: ReactiveViewModelBuilder<CatalogLocksViewModel, CatalogLocksState>(
        viewmodel: CatalogLocksService.instance.notifier,
        build: (state, viewmodel, keep) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(22, 8, 22, 32),
            children: [
              _Intro(count: viewmodel.userLocks.length),
              for (final group in viewmodel.locksByKind.entries) ...[
                _Head(
                  _kindLabel(group.key, group.value.length),
                  trailing: '${group.value.length}',
                ),
                for (final lock in group.value)
                  _LockRow(
                    lock: lock,
                    onUnlock: () => viewmodel.setLocked(
                      lock.kind,
                      lock.name,
                      locked: false,
                    ),
                  ),
              ],
              const _Head('Del sistema'),
              const _RegistryRow(),
            ],
          );
        },
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Text(
        count == 0
            ? 'No bloqueaste nada todavía. Un candado no te frena a vos: '
                  'frena a las tools — un agente que quiera cambiar o borrar '
                  'un ítem bloqueado tiene que pedirte permiso primero, '
                  'diciendo qué va a cambiar y por qué.'
            : count == 1
            ? 'Hay 1 elemento bloqueado. Un agente que quiera cambiarlo o '
                  'borrarlo tiene que pedirte permiso primero, diciendo qué '
                  'va a cambiar y por qué.'
            : 'Hay $count elementos bloqueados. Un agente que quiera '
                  'cambiarlos o borrarlos tiene que pedirte permiso primero, '
                  'diciendo qué va a cambiar y por qué.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _LockRow extends StatelessWidget {
  const _LockRow({required this.lock, required this.onUnlock});

  final CatalogLock lock;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            _kindIcon(lock.kind),
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(lock.name, style: theme.textTheme.bodyMedium)),
          IconButton(
            tooltip: 'Desbloquear',
            icon: const Icon(Icons.lock, size: 18),
            onPressed: onUnlock,
          ),
        ],
      ),
    );
  }
}

class _RegistryRow extends StatelessWidget {
  const _RegistryRow();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(
          Icons.shield_outlined,
          size: 16,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'El registro de candados. Fijo: es lo que hace que poner o sacar '
            'un candado con una tool también pida tu permiso.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// Mismo encabezado de sección que usa la pantalla de Máquina.
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

String _kindLabel(CatalogLockKind kind, int count) {
  final one = count == 1;
  return switch (kind) {
    CatalogLockKind.skill => one ? 'Skill' : 'Skills',
    CatalogLockKind.rule => one ? 'Regla' : 'Reglas',
    CatalogLockKind.tool => one ? 'Tool' : 'Tools',
    CatalogLockKind.agent => one ? 'Agente' : 'Agentes',
    CatalogLockKind.workflow => one ? 'Workflow' : 'Workflows',
    CatalogLockKind.project => one ? 'Proyecto' : 'Proyectos',
    CatalogLockKind.hook => one ? 'Hook' : 'Hooks',
    CatalogLockKind.mcpServer => one ? 'Integración MCP' : 'Integraciones MCP',
    CatalogLockKind.knowledgeBase => one ? 'Base de saber' : 'Bases de saber',
    CatalogLockKind.board => one ? 'Tablero' : 'Tableros',
    CatalogLockKind.secret => one ? 'Secret' : 'Secrets',
    CatalogLockKind.lockRegistry => 'Registro de candados',
  };
}

IconData _kindIcon(CatalogLockKind kind) {
  return switch (kind) {
    CatalogLockKind.skill => Icons.auto_awesome_outlined,
    CatalogLockKind.rule => Icons.gavel_outlined,
    CatalogLockKind.tool => Icons.build_outlined,
    CatalogLockKind.agent => Icons.person_outline,
    CatalogLockKind.workflow => Icons.account_tree_outlined,
    CatalogLockKind.project => Icons.folder_outlined,
    CatalogLockKind.hook => Icons.link,
    CatalogLockKind.mcpServer => Icons.extension_outlined,
    CatalogLockKind.knowledgeBase => Icons.menu_book_outlined,
    CatalogLockKind.board => Icons.dashboard_outlined,
    CatalogLockKind.secret => Icons.key_outlined,
    CatalogLockKind.lockRegistry => Icons.shield_outlined,
  };
}
