import 'package:flutter/material.dart';

import 'package:keel_ui/src/core/ui/form_panel.dart';
import 'package:keel_ui/src/modules/agent_profiles/model/agent_profile.dart';
import 'package:keel_ui/src/modules/agents/model/agent_tool_activity.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/agent_activity_indicator.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/markdown_text.dart';
import 'package:keel_ui/src/modules/projects/model/member_color.dart';
import 'package:keel_ui/src/modules/projects/model/project.dart';
import 'package:keel_ui/src/modules/projects/model/session_map.dart';
import 'package:keel_ui/src/modules/projects/model/session_subagent.dart';
import 'package:keel_ui/src/modules/projects/ui/widget/map_edges_painter.dart';
import 'package:keel_ui/src/modules/projects/ui/widget/map_node_card.dart';
import 'package:keel_ui/src/modules/projects/viewmodel/projects_viewmodel.dart';

/// Entrar a un nodo del mapa: qué se le pidió, cómo lo razona, qué hizo, sus
/// números, y —cuando corresponde— escribirle.
///
/// Panel y no ventana suelta: en esta app todo lo que tiene un campo de texto
/// entra por el costado derecho, y el mapa sigue vivo detrás.
Future<void> openMapNodeInspector(
  BuildContext context, {
  required Project project,
  required MapNode node,
  required List<AgentProfile> members,
}) {
  return showFormPanel(
    context,
    width: 520,
    child: MapNodeInspectorScreen(
      project: project,
      node: node,
      members: members,
    ),
  );
}

class MapNodeInspectorScreen extends StatefulWidget {
  const MapNodeInspectorScreen({
    super.key,
    required this.project,
    required this.node,
    required this.members,
  });

  final Project project;
  final MapNode node;
  final List<AgentProfile> members;

  @override
  State<MapNodeInspectorScreen> createState() => _MapNodeInspectorScreenState();
}

class _MapNodeInspectorScreenState extends State<MapNodeInspectorScreen> {
  final _composer = TextEditingController();

  @override
  void dispose() {
    _composer.dispose();
    super.dispose();
  }

  MapNode get _node => widget.node;
  SessionSubagent? get _subagent => _node.subagent;

  AgentProfile? get _owner => widget.members
      .where((member) => member.id == _node.profileId)
      .firstOrNull;

  /// A quién le llega lo que escribas. Un subagente en curso NO tiene canal
  /// —el CLI no lo abre—, así que lo que se puede es hablarle al miembro que
  /// lo abrió, con el pedido a la vista.
  AgentProfile? get _writeTo => _owner;

  void _send() {
    final target = _writeTo;
    final text = _composer.text.trim();
    if (target == null || text.isEmpty) return;
    ProjectsService.instance.notifier.sendToChannel(
      widget.project.id,
      '@${target.name} $text',
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final subagent = _subagent;

    return Scaffold(
      appBar: AppBar(
        title: Text(_node.label),
        actions: [
          IconButton(
            tooltip: 'Cerrar',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      body: Column(
        children: [
          _Header(node: _node, owner: _owner),
          const Divider(height: 1),
          // Una sola por toda la ficha, como en el chat: seleccionar cruzando
          // dos secciones tiene que funcionar, y con un `SelectableText` por
          // bloque cada uno es una isla.
          Expanded(
            child: SelectionArea(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  if (subagent != null) ...[
                    _Section(
                      icon: Icons.account_tree_outlined,
                      label: 'le pidió',
                      child: _Body(text: subagent.prompt),
                    ),
                    _Section(
                      icon: Icons.psychology_outlined,
                      label: 'cómo razona',
                      trailing: subagent.isRunning ? 'en vivo' : null,
                      child: _Body(
                        text: subagent.reasoning,
                        empty:
                            'No dejó pensamiento visible. Con modelos que no lo '
                            'emiten, acá no hay nada que mostrar.',
                        mono: true,
                      ),
                    ),
                    _Section(
                      icon: Icons.terminal,
                      label: 'qué hizo',
                      trailing: '${subagent.tools.length}',
                      child: _Tools(tools: subagent.tools),
                    ),
                    if (subagent.result.isNotEmpty)
                      _Section(
                        icon: Icons.check,
                        label: 'qué devolvió',
                        child: _Body(text: subagent.result),
                      ),
                  ] else ...[
                    _Section(
                      icon: Icons.assignment_outlined,
                      label: 'el encargo',
                      child: _Body(
                        text: _node.nodeInstruction,
                        empty:
                            'Este nodo no pertenece a un caso de resolución: habla '
                            'cuando lo consultan.',
                      ),
                    ),
                    _Section(
                      icon: Icons.psychology_outlined,
                      label: 'cómo razona',
                      trailing: _node.isLive ? 'en vivo' : null,
                      child: _Body(
                        text: _node.reasoning,
                        empty: 'Todavía no razonó nada en este paso.',
                        mono: true,
                      ),
                    ),
                    if (_node.said.isNotEmpty)
                      _Section(
                        icon: Icons.check,
                        label: 'qué resolvió',
                        // Lo que dijo ENTERO. El cuadro del lienzo muestra su
                        // primera frase porque mide dos centímetros; acá
                        // adentro no hay nada que obligue a recortar.
                        child: _Body(text: _node.said),
                      ),
                  ],
                  if (_node.consults.isNotEmpty)
                    _Section(
                      icon: Icons.reply,
                      label: 'le consultaron',
                      trailing: '${_node.consults.length}',
                      child: _Consults(consults: _node.consults),
                    ),
                  _Section(
                    icon: Icons.pin_outlined,
                    label: 'números',
                    child: _Numbers(node: _node),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          if (subagent != null && subagent.isRunning)
            _Locked(parent: _owner?.name ?? 'el miembro que lo abrió'),
          if (_writeTo != null)
            _Composer(
              controller: _composer,
              hint: 'Escribile a @${_writeTo!.name}…',
              onSend: _send,
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              color: scheme.surfaceContainerLow,
              child: Text(
                'Este nodo ya no es miembro del proyecto, así que no hay a '
                'quién escribirle.',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.node, required this.owner});

  final MapNode node;
  final AgentProfile? owner;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = node.colorIndex >= 0
        ? memberColorFor(node.colorIndex)
        : scheme.primary;
    final stateColor = mapStateColor(node.state, scheme);

    final subtitle = switch (node.kind) {
      MapNodeKind.subagent =>
        'subagente · abierto por ${owner?.name ?? 'un miembro'}',
      _ =>
        node.workNodeId == null
            ? (owner?.role ?? 'miembro del proyecto')
            : 'nodo ${node.nodeTitle}',
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 13),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              node.kind == MapNodeKind.subagent
                  ? Icons.account_tree_outlined
                  : Icons.smart_toy,
              size: 17,
              color: accent,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  node.label,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: scheme.outline),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: stateColor),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(mapStateIcon(node.state), size: 12, color: stateColor),
                const SizedBox(width: 5),
                Text(
                  _stateLabel(node.state),
                  style: TextStyle(fontSize: 10.5, color: stateColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _stateLabel(MapNodeState state) => switch (state) {
    MapNodeState.idle => 'en reposo',
    MapNodeState.thinking => 'pensando',
    MapNodeState.working => 'trabajando',
    MapNodeState.writing => 'escribiendo',
    MapNodeState.replying => 'contestando',
    MapNodeState.waiting => 'esperándote',
    MapNodeState.done => 'cerrado',
    MapNodeState.failed => 'cortó',
  };
}

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.label,
    required this.child,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final Widget child;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 14),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: scheme.outline),
              const SizedBox(width: 7),
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 9,
                  letterSpacing: 1.3,
                  color: scheme.outline,
                ),
              ),
              const Spacer(),
              if (trailing != null)
                Text(
                  trailing!,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 9.5,
                    color: scheme.outline,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.text, this.empty, this.mono = false});

  final String text;
  final String? empty;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (text.trim().isEmpty) {
      return Text(
        empty ?? '—',
        style: TextStyle(fontSize: 12, color: scheme.outline),
      );
    }

    // El razonamiento no: es el flujo crudo del modelo, y leerlo en
    // monoespaciada es parte de saber que estás mirando lo que pensó y no lo
    // que escribió. Todo lo demás sale de un agente en markdown, y mostrarlo
    // crudo es mostrar el andamiaje en vez del contenido.
    if (mono) {
      return Text(
        text.trim(),
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 11.5,
          height: 1.55,
          color: scheme.onSurfaceVariant,
        ),
      );
    }

    return MarkdownText(
      text.trim(),
      color: scheme.onSurfaceVariant,
      fontSize: 12.5,
    );
  }
}

/// Las idas y vueltas hacia atrás, en orden y enteras.
///
/// El lienzo dibuja UNA por par —la última— para no volverse una pared de
/// globos. Las anteriores viven acá, que es a donde lleva el contador del
/// pie del nodo: un número que no se puede abrir es un número que no dice
/// nada.
class _Consults extends StatelessWidget {
  const _Consults({required this.consults});

  final List<MapConsult> consults;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, consult) in consults.indexed) ...[
          if (index > 0) const SizedBox(height: 14),
          Row(
            children: [
              Icon(Icons.reply, size: 11, color: kMapConsultColor),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  '@${consult.askedBy}'.toUpperCase(),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 9,
                    letterSpacing: 1,
                    color: kMapConsultColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          _Quote(
            text: consult.ask,
            empty: 'No quedó registrado con qué frase lo llamó.',
            color: kMapConsultColor,
          ),
          const SizedBox(height: 7),
          _Quote(
            text: consult.answer,
            empty: 'Sin respuesta.',
            color: scheme.tertiary,
          ),
        ],
      ],
    );
  }
}

/// Una línea de la conversación, con la barrita del color de quien habla.
class _Quote extends StatelessWidget {
  const _Quote({required this.text, required this.empty, required this.color});

  final String text;
  final String empty;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final body = text.trim();

    // La barrita es un BORDE, no una columna al lado. Con `Row` +
    // `CrossAxisAlignment.stretch` había que saber el alto de antemano, y acá
    // adentro nadie lo sabe: la sección crece con el texto. Eso tiraba
    // «BoxConstraints forces an infinite height» al abrir una ficha con
    // consultas, que es justo cuando esto se mira.
    return Container(
      padding: const EdgeInsets.only(left: 9),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: color.withValues(alpha: 0.7), width: 2),
        ),
      ),
      child: body.isEmpty
          ? Text(
              empty,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.45,
                fontStyle: FontStyle.italic,
                color: scheme.outline,
              ),
            )
          : MarkdownText(body, color: scheme.onSurfaceVariant, fontSize: 12.5),
    );
  }
}

class _Tools extends StatelessWidget {
  const _Tools({required this.tools});

  final List<AgentToolActivity> tools;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (tools.isEmpty) {
      return Text(
        'Todavía no abrió ninguna herramienta.',
        style: TextStyle(fontSize: 12, color: scheme.outline),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final tool in tools)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: AgentActivityIndicator(activity: tool),
          ),
      ],
    );
  }
}

/// Tiempo, herramientas y costo. Un guion donde el dato no existe, nunca un
/// cero: un cero al lado de un número real se lee «salió gratis».
class _Numbers extends StatelessWidget {
  const _Numbers({required this.node});

  final MapNode node;

  @override
  Widget build(BuildContext context) {
    final isSubagent = node.kind == MapNodeKind.subagent;

    return Row(
      children: [
        _Number(label: 'tiempo', value: _clock(node.elapsed)),
        const SizedBox(width: 26),
        if (isSubagent)
          const _Number(label: 'tokens', value: 'al padre', muted: true)
        else
          _Number(
            label: 'costo',
            value: node.costUsd > 0
                ? '\$${node.costUsd.toStringAsFixed(2)}'
                : '—',
            muted: node.costUsd == 0,
          ),
        const SizedBox(width: 26),
        if (node.subagentCount > 0)
          _Number(label: 'subagentes', value: '${node.subagentCount}'),
        if (node.backCalls > 0) ...[
          const SizedBox(width: 26),
          _Number(label: 'consultas', value: '${node.backCalls}'),
        ],
      ],
    );
  }

  static String _clock(Duration elapsed) {
    if (elapsed <= Duration.zero) return '—';
    final minutes = elapsed.inMinutes;
    final seconds = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _Number extends StatelessWidget {
  const _Number({required this.label, required this.value, this.muted = false});

  final String label;
  final String value;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 9,
            letterSpacing: 1,
            color: scheme.outline,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 14,
            color: muted ? scheme.outline : scheme.onSurface,
          ),
        ),
      ],
    );
  }
}

/// Por qué no se le puede escribir a un subagente en curso. Dicho donde se
/// intenta, no escondido en la documentación.
class _Locked extends StatelessWidget {
  const _Locked({required this.parent});

  final String parent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 11, 16, 11),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline, size: 14, color: scheme.primary),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'Mientras corre, a un subagente no se le puede escribir: el CLI '
              'no abre ese canal. Lo que va acá abajo le llega a $parent, que '
              'es quien lo abrió.',
              style: TextStyle(
                fontSize: 11.5,
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

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.hint,
    required this.onSend,
  });

  final TextEditingController controller;
  final String hint;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 5,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: hint,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: onSend,
            icon: const Icon(Icons.send, size: 16),
          ),
        ],
      ),
    );
  }
}
