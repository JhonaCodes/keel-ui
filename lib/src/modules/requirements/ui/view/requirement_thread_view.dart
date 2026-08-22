import 'package:flutter/material.dart';

import 'package:keel_ui/src/modules/projects/model/project.dart';
import 'package:keel_ui/src/modules/projects/viewmodel/projects_viewmodel.dart';
import 'package:keel_ui/src/modules/requirements/model/internal_requirement.dart';
import 'package:keel_ui/src/modules/requirements/viewmodel/requirements_viewmodel.dart';

/// Los dos lados, con su color. Origen y destino se distinguen a simple vista
/// o el hilo se vuelve una pared de texto de dos autores anónimos.
const _kOrigen = Color(0xFF4FA3D9);
const _kDestino = Color(0xFFD98E5A);

/// Un requerimiento abierto como hilo, no como formulario.
///
/// Es lo que es: una conversación entre dos proyectos que no comparten nada
/// más. Lo único que cruza la frontera está acá adentro; ni el hilo de la
/// sesión que lo abrió ni el trabajo del que lo resuelve aparecen de este
/// lado.
class RequirementThreadView extends StatefulWidget {
  const RequirementThreadView({super.key, required this.requirement});

  final InternalRequirement requirement;

  @override
  State<RequirementThreadView> createState() => _RequirementThreadViewState();
}

class _RequirementThreadViewState extends State<RequirementThreadView> {
  final _controller = TextEditingController();

  InternalRequirement get requirement => widget.requirement;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Project? _project(String id) => ProjectsService
      .instance
      .notifier
      .data
      .projects
      .where((project) => project.id == id)
      .firstOrNull;

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    RequirementsService.instance.notifier.reply(
      requirement.id,
      side: RequirementSide.usuario,
      kind: RequirementEntryKind.correccion,
      text: text,
    );
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(
          requirement: requirement,
          from: _project(requirement.fromProjectId),
          to: _project(requirement.toProjectId),
        ),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Band(
                  side: RequirementSide.origen,
                  handle: requirement.openedByHandle,
                  at: requirement.createdAt,
                  child: _Pedido(requirement: requirement),
                ),
                if (requirement.takenByHandle != null)
                  _TakenNote(requirement: requirement),
                if (requirement.verdict != null)
                  _VerdictBox(verdict: requirement.verdict!),
                for (final entry in requirement.thread)
                  if (entry.kind != RequirementEntryKind.evaluacion)
                    _Band(
                      side: entry.side,
                      handle: entry.authorHandle,
                      at: entry.createdAt,
                      child: Text(
                        entry.text,
                        style: const TextStyle(fontSize: 12.6),
                      ),
                    ),
              ],
            ),
          ),
        ),
        _Composer(controller: _controller, onSend: _send),
        _ClosureBar(requirement: requirement),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.requirement,
    required this.from,
    required this.to,
  });

  final InternalRequirement requirement;
  final Project? from;
  final Project? to;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final edad = DateTime.now().difference(requirement.createdAt);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      requirement.code,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        requirement.title,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '#${from?.name ?? 'proyecto eliminado'}',
                        style: const TextStyle(color: _kOrigen),
                      ),
                      const TextSpan(text: ' → '),
                      TextSpan(
                        text: '#${to?.name ?? 'proyecto eliminado'}',
                        style: const TextStyle(color: _kDestino),
                      ),
                      TextSpan(text: ' · abierto hace ${_edad(edad)}'),
                      if (requirement.blocking)
                        const TextSpan(text: ' · bloquea a quien lo pide'),
                    ],
                  ),
                  style: text.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          _StatusChip(status: requirement.status),
        ],
      ),
    );
  }

  static String _edad(Duration age) {
    if (age.inMinutes < 60) return '${age.inMinutes} min';
    if (age.inHours < 24) return '${age.inHours} h';
    return '${age.inDays} ${age.inDays == 1 ? 'día' : 'días'}';
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final RequirementStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg) = switch (status) {
      RequirementStatus.cerrado => (
        scheme.tertiary.withValues(alpha: 0.16),
        scheme.tertiary,
      ),
      RequirementStatus.cancelado ||
      RequirementStatus.externo => (scheme.surfaceContainerLow, scheme.outline),
      _ => (scheme.secondaryContainer, scheme.primary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status.label.toLowerCase(),
        style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: fg),
      ),
    );
  }
}

/// Una franja del hilo, con la barra de color de su lado.
class _Band extends StatelessWidget {
  const _Band({
    required this.side,
    required this.at,
    required this.child,
    this.handle,
  });

  final RequirementSide side;
  final String? handle;
  final DateTime at;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (side) {
      RequirementSide.origen => _kOrigen,
      RequirementSide.destino => _kDestino,
      RequirementSide.usuario => scheme.primary,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 3,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      side.label.toUpperCase(),
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                        letterSpacing: 0.8,
                        color: color,
                      ),
                    ),
                    if (handle != null)
                      Text(
                        '@$handle',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    Text(
                      _cuando(at),
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: scheme.outline,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                child,
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _cuando(DateTime at) {
    final dias = const ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
    final hh = at.hour.toString().padLeft(2, '0');
    final mm = at.minute.toString().padLeft(2, '0');
    return '${dias[at.weekday - 1]} $hh:$mm';
  }
}

class _Pedido extends StatelessWidget {
  const _Pedido({required this.requirement});

  final InternalRequirement requirement;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(
                text: 'Necesito ',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              TextSpan(text: requirement.need),
            ],
          ),
          style: const TextStyle(fontSize: 12.6),
        ),
        if (requirement.context.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(
                  text: 'Contexto: ',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(text: requirement.context),
              ],
            ),
            style: TextStyle(fontSize: 12.6, color: scheme.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}

class _TakenNote extends StatelessWidget {
  const _TakenNote({required this.requirement});

  final InternalRequirement requirement;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(13, 6, 0, 6),
      child: Text(
        'Lo tomó @${requirement.takenByHandle}',
        style: TextStyle(fontSize: 11.5, color: scheme.outline),
      ),
    );
  }
}

class _VerdictBox extends StatelessWidget {
  const _VerdictBox({required this.verdict});

  final RequirementVerdict verdict;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final good =
        verdict.kind == RequirementVerdictKind.viable ||
        verdict.kind == RequirementVerdictKind.yaResuelto;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'VEREDICTO',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10,
                  letterSpacing: 1,
                  color: scheme.outline,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: good
                      ? scheme.tertiary.withValues(alpha: 0.16)
                      : scheme.errorContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  verdict.kind.label.toLowerCase(),
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                    color: good ? scheme.tertiary : scheme.onErrorContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(verdict.reason, style: const TextStyle(fontSize: 12.6)),
          if (verdict.prerequisites.isNotEmpty) ...[
            const SizedBox(height: 6),
            for (final item in verdict.prerequisites)
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 2),
                child: Text(
                  '· $item',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.onSend});

  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: scheme.outline),
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                style: const TextStyle(fontSize: 12.6),
                onSubmitted: (_) => onSend(),
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: 'Escribí acá — lo ven los dos lados',
                  hintStyle: TextStyle(fontSize: 12.6),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: onSend,
            icon: const Icon(Icons.send, size: 16),
            constraints: const BoxConstraints.tightFor(width: 34, height: 34),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}

/// La regla del sistema, hecha botón.
///
/// Cerrar es del ORIGEN. El destino, del otro lado, ve «Pedir el cierre» y
/// tiene que justificar. Las dos cosas las decide el ViewModel; esto es solo
/// donde se ve.
class _ClosureBar extends StatelessWidget {
  const _ClosureBar({required this.requirement});

  final InternalRequirement requirement;

  @override
  Widget build(BuildContext context) {
    if (!requirement.status.isOpen) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final requirements = RequirementsService.instance.notifier;
    final pidieronCierre = requirement.status == RequirementStatus.respondido;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        children: [
          Icon(
            pidieronCierre ? Icons.priority_high : Icons.info_outline,
            size: 15,
            color: pidieronCierre ? scheme.primary : scheme.outline,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  if (pidieronCierre)
                    const TextSpan(
                      text: 'El destino pidió el cierre. ',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  const TextSpan(
                    text:
                        'Solo del lado que lo abrió se puede cerrar — es quien '
                        'sabe si lo que necesitaba está.',
                  ),
                ],
              ),
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ),
          if (pidieronCierre)
            TextButton(
              onPressed: () => _rechazar(context, requirements),
              child: const Text('Rechazar y explicar'),
            ),
          const SizedBox(width: 6),
          FilledButton(
            onPressed: () => requirements.close(requirement.id),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Future<void> _rechazar(
    BuildContext context,
    RequirementsViewModel requirements,
  ) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rechazar el cierre'),
        content: SizedBox(
          width: 420,
          child: TextField(
            controller: controller,
            autofocus: true,
            minLines: 3,
            maxLines: 6,
            decoration: InputDecoration(
              labelText: 'Qué falta',
              alignLabelWithHint: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null) return;
    requirements.rejectClosure(requirement.id, reason: reason);
  }
}
