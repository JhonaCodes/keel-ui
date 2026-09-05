import 'dart:async';
import 'package:flutter/material.dart';

import 'package:keel_ui/l10n/generated/app_localizations.dart';
import 'package:keel_ui/src/integrations/requirements_mcp/requirements_mcp.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/markdown_text.dart';
import 'package:keel_ui/src/modules/projects/model/project.dart';
import 'package:keel_ui/src/modules/projects/viewmodel/projects_viewmodel.dart';
import 'package:keel_ui/src/modules/requirements/model/internal_requirement.dart';
import 'package:keel_ui/src/modules/requirements/service/requirement_target_activity.dart';
import 'package:keel_ui/src/modules/requirements/viewmodel/requirements_viewmodel.dart';
import 'package:keel_ui/src/modules/workflows/ui/screen/workflow_picker_panel.dart';
import 'package:keel_ui/src/modules/workspace/viewmodel/workspace_viewmodel.dart';
import 'package:keel_ui/src/integrations/chat_references/chat_references.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/chat_reference_composer_field.dart';

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

  /// Vale para el próximo llamado y no se guarda: el hilo no tiene sesión
  /// que reanudar ni nada que implementar, así que persistirlo sería guardar
  /// un modo que no cambia nada entre una visita y la siguiente.
  bool _planMode = false;

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

  RequirementReferenceScope get _scope => RequirementReferenceScope(
    from: _project(requirement.fromProjectId),
    to: _project(requirement.toProjectId),
  );

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    // Se guarda el texto LEGIBLE, no los enlaces `keel://`. Un requerimiento
    // es un documento que cruza de proyecto y viaja en el respaldo, donde
    // las rutas de esta máquina se sacan a propósito: nombrar la carpeta
    // sirve, guardar su ruta absoluta no.
    final visible = ChatReferenceService.visibleText(text);
    RequirementsService.instance.notifier.reply(
      requirement.id,
      side: RequirementSide.usuario,
      kind: RequirementEntryKind.correccion,
      text: visible,
    );
    _controller.clear();

    // Nombrar a alguien es llamarlo. Sin mención esto queda como estaba: una
    // nota en el hilo, sin gastar un turno en algo que escribiste para vos.
    final scope = _scope;
    final member = ChatReferenceService.explicitlyMentionedMember(
      visible,
      scope.agents,
    );
    if (member == null) return;
    final side = scope.sideOf(member.name);
    if (side == null) return;

    unawaited(
      ProjectsService.instance.notifier.answerInRequirementThread(
        requirement: requirement,
        member: member,
        memberProject: side.project,
        asTarget: side.isTarget,
        question: visible,
        planMode: _planMode,
      ),
    );
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
          // Una sola para todo el hilo, como en el chat: seleccionar cruzando
          // dos franjas tiene que funcionar.
          child: SelectionArea(
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
                  if (requirement.taskPath case final path?)
                    _TaskNote(taskPath: path),
                  for (final entry in requirement.thread)
                    if (entry.kind != RequirementEntryKind.evaluacion)
                      _Band(
                        side: entry.side,
                        handle: entry.authorHandle,
                        at: entry.createdAt,
                        // Lo escribe un agente, o sea que viene en markdown.
                        child: MarkdownText(
                          entry.text,
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 12.6,
                        ),
                      ),
                ],
              ),
            ),
          ),
        ),
        _Composer(
          controller: _controller,
          onSend: _send,
          scope: _scope,
          thinking: RequirementsService.instance.notifier.isThinking(
            requirement.id,
          ),
          planMode: _planMode,
          onPlanModeChanged: (enabled) => setState(() => _planMode = enabled),
        ),
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
    final t = AppLocalizations.of(context);
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
                        text: '#${from?.name ?? t.labelDeletedProject}',
                        style: const TextStyle(color: _kOrigen),
                      ),
                      const TextSpan(text: ' → '),
                      TextSpan(
                        text: '#${to?.name ?? t.labelDeletedProject}',
                        style: const TextStyle(color: _kDestino),
                      ),
                      TextSpan(text: ' · ${t.labelOpenSince(_edad(t, edad))}'),
                      if (requirement.blocking)
                        TextSpan(text: ' · ${t.labelBlockingRequester}'),
                    ],
                  ),
                  style: text.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
                // Qué está haciendo el destino de verdad: el que pide veía
                // «tomado» y nada más, sin saber si había alguien del otro
                // lado.
                if (_targetActivity case final activity?)
                  Text(
                    'destino: $activity',
                    style: text.bodySmall?.copyWith(color: _kDestino),
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

  String? get _targetActivity {
    final sessionId = requirement.takenInSessionId;
    if (sessionId == null) return null;
    final session = to?.sessions
        .where((entry) => entry.id == sessionId)
        .firstOrNull;
    return requirementTargetActivity(session);
  }

  static String _edad(AppLocalizations t, Duration age) {
    if (age.inMinutes < 60) return t.durationMinutesShort(age.inMinutes);
    if (age.inHours < 24) return t.durationHoursShort(age.inHours);
    return t.durationDaysShort(age.inDays);
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
    final t = AppLocalizations.of(context);
    final color = switch (side) {
      RequirementSide.origen => _kOrigen,
      RequirementSide.destino => _kDestino,
      RequirementSide.usuario => scheme.primary,
    };

    // La barra es un BORDE y no una columna al lado.
    //
    // Con `Row` + `CrossAxisAlignment.stretch` la barrita pide el alto de la
    // franja, y acá adentro nadie lo sabe: la franja vive en un
    // `SingleChildScrollView`, o sea con alto sin límite. Eso tira "RenderBox
    // was not laid out" en CADA franja y en CADA frame, con el volcado del
    // árbol de render entero cada vez — que es lo que dejaba la ventana sin
    // responder hasta matarla a mano. El mismo error ya había aparecido en la
    // ficha de un nodo del mapa; acá quedaba el otro.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        padding: const EdgeInsets.only(left: 10),
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: color, width: 3)),
        ),
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
                  _cuando(t, at),
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
    );
  }

  static String _cuando(AppLocalizations t, DateTime at) {
    final dias = t.labelWeekdayShort.split(', ');
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
    // La etiqueta va DENTRO del markdown y no como un `TextSpan` al lado:
    // así se sigue leyendo como una frase —«Necesito que…»— y lo que escribió
    // el agente se renderiza en vez de mostrar sus asteriscos.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MarkdownText(
          '**Necesito** ${requirement.need}',
          color: scheme.onSurface,
          fontSize: 12.6,
        ),
        if (requirement.context.isNotEmpty) ...[
          const SizedBox(height: 4),
          MarkdownText(
            '**Contexto:** ${requirement.context}',
            color: scheme.onSurfaceVariant,
            fontSize: 12.6,
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
    final t = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(13, 6, 0, 6),
      child: Text(
        // Sin handle lo tomaste vos con el botón, no un agente. «Lo tomó @»
        // con la arroba colgando es lo que salía antes.
        (requirement.takenByHandle ?? '').isEmpty
            ? t.messageTakenByYou
            : t.messageRequirementTaken(requirement.takenByHandle!),
        style: TextStyle(fontSize: 11.5, color: scheme.outline),
      ),
    );
  }
}

/// En qué tarea terminó. El final que al requerimiento le faltaba: aceptar
/// dejaba un veredicto de texto y nada más.
class _TaskNote extends StatelessWidget {
  const _TaskNote({required this.taskPath});

  final String taskPath;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(13, 6, 0, 6),
      child: Row(
        children: [
          Icon(Icons.task_alt, size: 14, color: scheme.tertiary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              t.messageRequirementTask(taskPath),
              style: TextStyle(fontSize: 11.5, color: scheme.tertiary),
            ),
          ),
        ],
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
    final t = AppLocalizations.of(context);
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
                t.labelVerdict,
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
          MarkdownText(verdict.reason, color: scheme.onSurface, fontSize: 12.6),
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
  const _Composer({
    required this.controller,
    required this.onSend,
    required this.scope,
    required this.thinking,
    required this.planMode,
    required this.onPlanModeChanged,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final RequirementReferenceScope scope;

  /// Si hay un agente redactando su respuesta ahora mismo.
  final bool thinking;

  /// El agente que llames propone en vez de afirmar. Acá NO hay tarjeta de
  /// «Implementar»: este turno ya es de solo lectura y el hilo nunca
  /// implementa nada — eso lo hace «Tomar y evaluar», que abre una sesión de
  /// proyecto. Por eso tampoco se persiste: vale para el próximo llamado.
  final bool planMode;
  final ValueChanged<bool> onPlanModeChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Row(
        children: [
          IconButton(
            tooltip: planMode
                ? t.tooltipPlanModeActive
                : t.messagePlanMode,
            icon: Icon(
              planMode ? Icons.architecture : Icons.architecture_outlined,
              size: 18,
              color: planMode ? scheme.primary : null,
            ),
            constraints: const BoxConstraints.tightFor(width: 34, height: 34),
            padding: EdgeInsets.zero,
            onPressed: () => onPlanModeChanged(!planMode),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: planMode ? scheme.primary : scheme.outline,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              // El `@` lista a los miembros de los dos proyectos: nombrar a
              // uno lo trae a contestar acá mismo. Sin mención, esto sigue
              // siendo lo que era — una nota que ven los dos lados.
              child: ChatReferenceComposerField(
                controller: controller,
                scope: scope,
                onSend: onSend,
                enabled: !thinking,
                hintText: thinking
                    ? t.messageRequirementAnswering
                    : planMode
                    ? t.messagePlanRequest
                    : t.messageWriteHere,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: thinking ? null : onSend,
            icon: thinking
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send, size: 16),
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
    final t = AppLocalizations.of(context);
    final requirements = RequirementsService.instance.notifier;
    final pidieronCierre = requirement.status == RequirementStatus.respondido;
    final destino = ProjectsService.instance.notifier.data.projects
        .where((project) => project.id == requirement.toProjectId)
        .firstOrNull;
    final sinTomar =
        requirement.status == RequirementStatus.abierto &&
        (destino?.maintained ?? false);

    // Ya tomado: el botón de tomar se fue, y sin esto no queda ninguna
    // puerta al trabajo que el requerimiento arrancó. La sesión se busca en
    // el destino porque puede haberse borrado: un id guardado no garantiza
    // que lo que apunta siga existiendo.
    final trabajando = destino?.sessions
        .where((session) => session.id == requirement.takenInSessionId)
        .firstOrNull;

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
                    TextSpan(
                      text: '${t.messageRequirementClosed} ',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  TextSpan(text: t.messageOnlyOriginCanClose),
                ],
              ),
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ),
          if (sinTomar)
            FilledButton.tonal(
              onPressed: () => _tomarYEvaluar(context),
              child: Text(t.buttonAssignAndEvaluate),
            )
          else if (trabajando != null)
            TextButton.icon(
              icon: const Icon(Icons.arrow_forward, size: 15),
              onPressed: () => WorkspaceService.instance.notifier.openSession(
                destino!.id,
                trabajando.id,
              ),
              label: Text(t.buttonGoToSession),
            ),
          if (pidieronCierre)
            TextButton(
              onPressed: () => _rechazar(context, requirements),
              child: Text(t.buttonRejectAndExplain),
            ),
          const SizedBox(width: 6),
          FilledButton(
            onPressed: () => requirements.close(requirement.id),
            child: Text(t.buttonClose),
          ),
        ],
      ),
    );
  }

  /// Arranca el trabajo del otro lado.
  ///
  /// Abre una sesión NUEVA en el proyecto destino con el requerimiento
  /// renderizado como pedido. No es una elección de estilo: una sesión nueva
  /// es la única forma de que el trabajo del destino no arrastre nada del
  /// contexto de quien pidió.
  Future<void> _tomarYEvaluar(BuildContext context) async {
    final projects = ProjectsService.instance.notifier;
    final from = projects.data.projects
        .where((project) => project.id == requirement.fromProjectId)
        .firstOrNull;
    final to = projects.data.projects
        .where((project) => project.id == requirement.toProjectId)
        .firstOrNull;
    if (to == null) return;

    // Evaluar un requerimiento no es resolver un ticket, y el destino puede
    // tener un workflow para cada cosa. Con uno solo no se pregunta: una
    // pregunta con una sola respuesta es un click de más.
    final options = projects.choosableWorkflowsOf(to);
    var workflowId = to.activeWorkflowId ?? '';
    if (options.length > 1) {
      if (!context.mounted) return;
      final t = AppLocalizations.of(context);
      final picked = await openWorkflowPicker(
        context,
        options: options,
        currentId: workflowId,
        title: t.labelWithWorkflow,
        note: t.messageNewRequirementSessionNote(to.name),
      );
      if (picked == null) return;
      workflowId = picked;
    }
    if (!context.mounted) return;
    final t = AppLocalizations.of(context);

    final sessionId = projects.startRequirementSession(
      projectId: to.id,
      sessionTitle: '${requirement.code} · ${requirement.title}',
      request: renderRequirementForTurn(
        requirement,
        fromProject: from?.name ?? t.labelProjectNoLongerExists,
        toProject: to.name,
      ),
      workflowId: workflowId,
    );
    if (sessionId == null) return;
    // Tomarlo es de este botón y no del agente. Antes esto abría la sesión y
    // dejaba el requerimiento en `abierto` hasta que el agente se acordara de
    // llamar `take_requirement`: en el medio, el botón seguía ofreciendo
    // tomarlo —invitando a abrir una segunda sesión sobre lo mismo— y «Ir a
    // la sesión» no aparecía, porque depende de `takenInSessionId`.
    RequirementsService.instance.notifier.take(
      requirement.id,
      handle: '',
      sessionId: sessionId,
    );
    // Un botón que apretaste SÍ navega. La regla de que crear no es ir vale
    // para lo que arranca solo —una tool, la API— no para esto: apretar
    // «tomar» y quedarte mirando el requerimiento es quedarte mirando el
    // lado que ya leíste, mientras el trabajo empieza en otra pantalla.
    WorkspaceService.instance.notifier.openSession(to.id, sessionId);
  }

  Future<void> _rechazar(
    BuildContext context,
    RequirementsViewModel requirements,
  ) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) {
        final t = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(t.pageTitleRejectClosure),
          content: SizedBox(
            width: 420,
            child: TextField(
              controller: controller,
              autofocus: true,
              minLines: 3,
              maxLines: 6,
              decoration: InputDecoration(
                labelText: t.formLabelWhatMissing,
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
              child: Text(t.buttonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: Text(t.buttonReject),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (reason == null) return;
    requirements.rejectClosure(requirement.id, reason: reason);
  }
}
