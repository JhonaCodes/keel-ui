import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:reactive_notifier/reactive_notifier.dart';
import 'package:desktop_drop/desktop_drop.dart';

import 'package:keel_ui/src/core/services/external_link_service.dart';
import 'package:keel_ui/src/modules/agent_profiles/model/agent_profile.dart';
import 'package:keel_ui/src/modules/agent_profiles/viewmodel/agent_profiles_viewmodel.dart';
import 'package:keel_ui/src/modules/agents/model/chat_message.dart';
import 'package:keel_ui/src/modules/agents/service/chat_attachment_store.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/chat_attachment_strip.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/chat_composer_field.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/fade_in_entrance.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/permission_request_banner.dart';
import 'package:keel_ui/src/modules/projects/model/member_color.dart';
import 'package:keel_ui/src/modules/projects/model/project.dart';
import 'package:keel_ui/src/modules/projects/model/session.dart';
import 'package:keel_ui/src/modules/projects/model/session_queued_message.dart';
import 'package:keel_ui/src/modules/projects/model/thread_entry.dart';
import 'package:keel_ui/src/modules/projects/ui/view/session_map_view.dart';
import 'package:keel_ui/src/modules/projects/ui/widget/session_agent_picker.dart';
import 'package:keel_ui/src/modules/projects/ui/widget/session_live_turn_strip.dart';
import 'package:keel_ui/src/modules/projects/ui/widget/session_message_bubble.dart';
import 'package:keel_ui/src/modules/projects/ui/widget/session_queued_messages_panel.dart';
import 'package:keel_ui/src/modules/projects/ui/widget/workflow_progress_panel.dart';
import 'package:keel_ui/src/modules/projects/viewmodel/projects_viewmodel.dart';
import 'package:keel_ui/src/modules/workflows/model/workflow.dart';
import 'package:keel_ui/src/modules/workflows/ui/screen/workflow_picker_panel.dart';
import 'package:keel_ui/src/modules/workflows/viewmodel/workflows_viewmodel.dart';
import 'package:keel_ui/src/modules/workspace/viewmodel/workspace_viewmodel.dart';
import 'package:keel_ui/src/shared/shared.dart';

/// What the channel is showing: the conversation, or the same conversation
/// drawn as a network.
enum SessionTab { chat, map }

/// The channel: one shared thread where every member of the project writes,
/// with the running workflow beside it.
class SessionChatView extends StatefulWidget {
  const SessionChatView({super.key, required this.project});

  final Project project;

  @override
  State<SessionChatView> createState() => _SessionChatViewState();
}

class _SessionChatViewState extends State<SessionChatView> {
  SessionTab _tab = SessionTab.chat;

  /// Subscribes to the two catalogues the channel depends on. Reading them
  /// straight off their singletons instead — which is what this used to do —
  /// means the channel renders before they finish loading and never rebuilds:
  /// no author names, no colours, no step chips, and a panel claiming the
  /// project has no workflow.
  @override
  Widget build(BuildContext context) {
    return ReactiveViewModelBuilder<AgentProfilesViewModel, AgentProfilesState>(
      viewmodel: AgentProfilesService.instance.notifier,
      build: (profilesState, profilesViewModel, keepProfiles) {
        return ReactiveViewModelBuilder<WorkflowsViewModel, WorkflowsState>(
          viewmodel: WorkflowsService.instance.notifier,
          build: (workflowsState, workflowsViewModel, keepWorkflows) {
            final projects = ProjectsService.instance.notifier;
            return _ProjectChannel(
              project: widget.project,
              members: projects.membersOf(
                widget.project,
                session: widget.project.activeSession,
              ),
              allProfiles: profilesState.profiles,
              // El de la SESIÓN abierta, no el del proyecto: dos sesiones
              // del mismo proyecto pueden correr flujos distintos, y el
              // panel de la derecha tiene que mostrar el que está corriendo
              // acá.
              workflow: switch (widget.project.activeSession) {
                final Session open => projects.workflowOf(open),
                _ => projects.defaultWorkflowOf(widget.project),
              },
              tab: _tab,
              onTabChanged: (tab) => setState(() => _tab = tab),
            );
          },
        );
      },
    );
  }
}

class _ProjectChannel extends StatelessWidget {
  const _ProjectChannel({
    required this.project,
    required this.members,
    required this.allProfiles,
    required this.workflow,
    required this.tab,
    required this.onTabChanged,
  });

  final Project project;
  final List<AgentProfile> members;
  final List<AgentProfile> allProfiles;
  final Workflow? workflow;
  final SessionTab tab;
  final ValueChanged<SessionTab> onTabChanged;

  @override
  Widget build(BuildContext context) {
    final session = project.activeSession;
    final running = session?.isRunning ?? false;
    final pendingPermission = session?.pendingPermission;
    final liveTurn = session?.liveTurn;

    return Row(
      children: [
        Expanded(
          child: Column(
            children: [
              _ChannelHeader(
                project: project,
                session: session,
                members: members,
                workflow: workflow,
                tab: tab,
                onTabChanged: onTabChanged,
              ),
              const Divider(height: 1),
              if (project.workingDirectory.trim().isEmpty)
                _MissingFolderBanner(projectId: project.id),
              Expanded(
                child: switch (tab) {
                  SessionTab.chat => _ThreadList(
                    projectId: project.id,
                    session: session,
                    members: members,
                    allProfiles: allProfiles,
                    workflow: workflow,
                  ),
                  SessionTab.map => SessionMapView(
                    project: project,
                    session: session,
                    members: members,
                    workflow: workflow,
                  ),
                },
              ),
              if (tab == SessionTab.chat && liveTurn != null)
                SessionLiveTurnStrip(turn: liveTurn, members: members),
              if (tab == SessionTab.chat &&
                  session != null &&
                  pendingPermission != null)
                PermissionRequestBanner(
                  request: pendingPermission,
                  busy: running,
                  onRespond: (grant) => ProjectsService.instance.notifier
                      .respondToSessionPermission(
                        project.id,
                        session.id,
                        grant: grant,
                      ),
                ),
              // A finding remains visible at the point where the user can
              // provide a decision or missing context to the case owner.
              if (tab == SessionTab.chat && session != null && !running)
                _FindingBar(session: session),
              SizedBox(
                height: 2,
                child: running
                    ? const LinearProgressIndicator(minHeight: 2)
                    : Divider(
                        height: 2,
                        thickness: 1,
                        color: Theme.of(context).dividerColor,
                      ),
              ),
              if (tab == SessionTab.chat)
                _Composer(project: project, session: session),
            ],
          ),
        ),
        // En el mapa el panel se retira: dice lo mismo que el lienzo ya
        // muestra —los pasos, de quién es cada uno, cuál va— y son 272 px
        // que el mapa necesita más que él.
        if (tab == SessionTab.chat) ...[
          const VerticalDivider(width: 1),
          SizedBox(
            width: 272,
            child: WorkflowProgressPanel(
              project: project,
              session: session,
              workflow: workflow,
              members: members,
            ),
          ),
        ],
      ],
    );
  }
}

/// The thread itself: messages interleaved with the hand-off dividers that
/// explain why the speaker changed.
class _ThreadList extends StatelessWidget {
  const _ThreadList({
    required this.projectId,
    required this.session,
    required this.members,
    required this.allProfiles,
    required this.workflow,
  });

  final String projectId;
  final Session? session;
  final List<AgentProfile> members;
  final List<AgentProfile> allProfiles;
  final Workflow? workflow;

  @override
  Widget build(BuildContext context) {
    final open = session;
    if (open == null) return _EmptyChannel(projectId: projectId);

    final entries = buildThreadEntries(
      messages: open.messages,
      workflow: workflow,
    );

    return SelectionArea(
      child: ListView.builder(
        reverse: true,
        padding: const EdgeInsets.all(16),
        itemCount: entries.length,
        itemBuilder: (context, index) {
          final entry = entries[entries.length - 1 - index];
          return switch (entry) {
            ThreadHandoff(label: final label) => _HandoffDivider(label: label),
            ThreadMessage(message: final message) => _ThreadBubble(
              key: ValueKey(message.timestamp.microsecondsSinceEpoch),
              projectId: projectId,
              message: message,
              members: members,
              allProfiles: allProfiles,
              workflow: workflow,
            ),
          };
        },
      ),
    );
  }
}

class _ThreadBubble extends StatelessWidget {
  const _ThreadBubble({
    super.key,
    required this.projectId,
    required this.message,
    required this.members,
    required this.allProfiles,
    required this.workflow,
  });

  final String projectId;
  final ChatMessage message;
  final List<AgentProfile> members;

  /// Every registered profile, not just this project's members: a message
  /// keeps naming its author even after that agent is removed from the
  /// project. Resolving only against members is what made older messages lose
  /// their author line entirely.
  final List<AgentProfile> allProfiles;
  final Workflow? workflow;

  AgentProfile? _profileById(String? id) {
    if (id == null) return null;
    return allProfiles.where((p) => p.id == id).firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final author = _profileById(message.authorProfileId);
    final askedBy = _profileById(message.consultOfProfileId);
    final nodeId = message.workNodeId;
    final nodeTitle = nodeId == null ? null : 'nodo de resolución: $nodeId';
    final memberIds = [for (final member in members) member.id];

    return FadeInEntrance(
      child: SessionMessageBubble(
        message: message,
        projectId: projectId,
        author: author,
        nodeTitle: nodeTitle,
        askedBy: askedBy,
        memberIndex: author == null
            ? 0
            : authorPaletteIndex(author.id, memberIds),
        askedByIndex: askedBy == null
            ? 0
            : authorPaletteIndex(askedBy.id, memberIds),
      ),
    );
  }
}

/// The thin rule that marks where the work changed hands — a hair-line on
/// each side of a small monospace label, so it reads as punctuation in the
/// thread rather than as another message.
class _HandoffDivider extends StatelessWidget {
  const _HandoffDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(child: Divider(height: 1, color: scheme.outlineVariant)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                letterSpacing: 0.4,
                color: scheme.outline,
              ),
            ),
          ),
          Expanded(child: Divider(height: 1, color: scheme.outlineVariant)),
        ],
      ),
    );
  }
}

class _Composer extends StatefulWidget {
  const _Composer({required this.project, required this.session});

  final Project project;
  final Session? session;

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  final _controller = TextEditingController();
  final List<String> _attachments = [];
  bool _isDragging = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text;
    if (text.trim().isEmpty && _attachments.isEmpty) return;
    final session = widget.session;
    if (session == null) return;
    final images = [..._attachments];
    if (session.isRunning) {
      unawaited(
        ProjectsService.instance.notifier.queueSessionMessage(
          widget.project.id,
          session.id,
          text,
          imagePaths: images,
        ),
      );
    } else {
      unawaited(
        ProjectsService.instance.notifier.sendToChannel(
          widget.project.id,
          text,
          imagePaths: images,
        ),
      );
    }
    _controller.clear();
    setState(_attachments.clear);
  }

  Future<void> _editQueuedMessage(SessionQueuedMessage message) async {
    final edited = await showDialog<String>(
      context: context,
      builder: (_) => _QueuedMessageEditorDialog(message: message),
    );
    final session = widget.session;
    if (edited == null || session == null) return;
    await ProjectsService.instance.notifier.editQueuedSessionMessage(
      widget.project.id,
      session.id,
      message.id,
      edited,
    );
  }

  Future<void> _deleteQueuedMessage(SessionQueuedMessage message) async {
    final session = widget.session;
    if (session == null) return;
    await ProjectsService.instance.notifier.removeQueuedSessionMessage(
      widget.project.id,
      session.id,
      message.id,
    );
    for (final imagePath in message.imagePaths) {
      await ChatAttachmentStore.discard(imagePath);
    }
  }

  Future<void> _sendQueuedNow(SessionQueuedMessage message) async {
    final session = widget.session;
    if (session == null) return;
    await ProjectsService.instance.notifier.sendQueuedSessionMessageNow(
      widget.project.id,
      session.id,
      message.id,
    );
  }

  Future<void> _sendQueuedAfterTurn(SessionQueuedMessage message) async {
    final session = widget.session;
    if (session == null) return;
    await ProjectsService.instance.notifier.sendQueuedSessionMessageAfterTurn(
      widget.project.id,
      session.id,
      message.id,
    );
  }

  Future<void> _holdQueuedMessage(SessionQueuedMessage message) async {
    final session = widget.session;
    if (session == null) return;
    await ProjectsService.instance.notifier.holdQueuedSessionMessage(
      widget.project.id,
      session.id,
      message.id,
    );
  }

  Future<void> _pickImages() async {
    final files = await openFiles(
      acceptedTypeGroups: [
        XTypeGroup(
          label: 'Imágenes',
          extensions: ChatAttachmentStore.supportedExtensions.toList(),
        ),
      ],
    );
    await _attach([for (final file in files) file.path]);
  }

  Future<void> _attach(List<String> paths) async {
    final stored = await ChatAttachmentStore.adoptImages(paths);
    if (!mounted || stored.isEmpty) return;
    setState(() => _attachments.addAll(stored));
  }

  void _removeAttachment(String path) {
    setState(() => _attachments.remove(path));
    ChatAttachmentStore.discard(path);
  }

  @override
  Widget build(BuildContext context) {
    final project = widget.project;
    final session = widget.session;
    final running = session?.isRunning ?? false;
    final started =
        session?.messages.any((m) => m.role == ChatRole.assistant) ?? false;

    return DropTarget(
      onDragEntered: (_) => setState(() => _isDragging = true),
      onDragExited: (_) => setState(() => _isDragging = false),
      onDragDone: (details) async {
        setState(() => _isDragging = false);
        await _attach([for (final file in details.files) file.path]);
      },
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SessionQueuedMessagesPanel(
              messages: session?.queuedMessages ?? const [],
              isRunning: running,
              onEdit: (message) => unawaited(_editQueuedMessage(message)),
              onDelete: (message) => unawaited(_deleteQueuedMessage(message)),
              onSendNow: (message) => unawaited(_sendQueuedNow(message)),
              onSendAfterTurn: (message) =>
                  unawaited(_sendQueuedAfterTurn(message)),
              onHold: (message) => unawaited(_holdQueuedMessage(message)),
            ),
            ChatAttachmentStrip(
              paths: _attachments,
              onRemove: _removeAttachment,
            ),
            Row(
              children: [
                IconButton(
                  tooltip: 'Adjuntar imagen',
                  icon: Icon(
                    _isDragging
                        ? Icons.add_photo_alternate
                        : Icons.image_outlined,
                  ),
                  onPressed: _pickImages,
                ),
                Expanded(
                  child: Container(
                    decoration: ShapeDecoration(
                      shape: 16.smoothBorder(
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ),
                    child: ChatComposerField(
                      controller: _controller,
                      onSend: _send,
                      enabled: session != null,
                      hintText: switch (session) {
                        null => 'Creá una sesión para empezar',
                        _ when !started =>
                          'Qué necesitás en esta sesión de #${project.name}',
                        _ => 'Mensaje a #${project.name}',
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (running && session != null) ...[
                  IconButton.outlined(
                    tooltip: 'Detener',
                    onPressed: () => ProjectsService.instance.notifier
                        .stopSession(project.id, session.id),
                    icon: const Icon(Icons.stop_circle_outlined),
                  ),
                  const SizedBox(width: 8),
                ],
                IconButton.filled(
                  tooltip: running ? 'Guardar en espera' : 'Enviar',
                  onPressed: session == null ? null : _send,
                  icon: Icon(running ? Icons.schedule_send : Icons.send),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Text(switch (session) {
                null => 'Las sesiones se crean con el botón "Nueva sesión".',
                _ when !started =>
                  'Ejecuta el preflight del workflow en esta sesión.',
                _ when running =>
                  'Podés guardar mensajes en espera, programarlos para el '
                      'final del turno o interrumpir y enviarlos ahora.',
                _ =>
                  'El workflow coordina el grafo. Escribí cuando quieras '
                      'corregir el rumbo — se registra en el nodo activo.',
              }, style: Theme.of(context).textTheme.bodySmall),
            ),
          ],
        ),
      ),
    );
  }
}

class _QueuedMessageEditorDialog extends StatefulWidget {
  const _QueuedMessageEditorDialog({required this.message});

  final SessionQueuedMessage message;

  @override
  State<_QueuedMessageEditorDialog> createState() =>
      _QueuedMessageEditorDialogState();
}

class _QueuedMessageEditorDialogState
    extends State<_QueuedMessageEditorDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.message.text);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final text = _controller.text.trim();
    if (text.isEmpty && widget.message.imagePaths.isEmpty) return;
    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar mensaje en espera'),
      content: SizedBox(
        width: 480,
        child: TextField(
          controller: _controller,
          autofocus: true,
          minLines: 3,
          maxLines: 8,
          decoration: const InputDecoration(
            hintText: 'Mensaje que se enviará en el próximo turno',
          ),
          onSubmitted: (_) => _save(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _save, child: const Text('Guardar')),
      ],
    );
  }
}

class _ChannelHeader extends StatelessWidget {
  const _ChannelHeader({
    required this.project,
    required this.session,
    required this.members,
    required this.workflow,
    required this.tab,
    required this.onTabChanged,
  });

  final Project project;
  final Session? session;
  final List<AgentProfile> members;
  final Workflow? workflow;
  final SessionTab tab;
  final ValueChanged<SessionTab> onTabChanged;

  /// El pull request que abrió esta sesión, si alguno lo nombró en el hilo.
  ///
  /// Se lee de los mensajes y no de un campo propio: el PR lo abre un agente
  /// con `gh` en su turno, y el hilo es donde queda dicho. Guardarlo aparte
  /// sería un segundo lugar donde puede quedar viejo.
  ({int number, String url})? _pullRequest() {
    final open = session;
    if (open == null) return null;
    for (final message in open.messages.reversed) {
      final pr = lastPullRequestIn(message.text);
      if (pr != null) return pr;
    }
    return null;
  }

  /// Cuánto contexto lleva consumido la sesión abierta, en tokens.
  ///
  /// El porcentaje dice qué tan cerca está del techo; el número dice de qué
  /// techo estamos hablando, que no es el mismo en todos los modelos.
  String _contextDetail() {
    final open = session;
    final used = open?.contextUsedTokens;
    final total = open?.contextWindowTokens;
    if (used == null || total == null || total <= 0) return '';
    return 'Contexto: ${_thousands(used)} de ${_thousands(total)} tokens';
  }

  static String _thousands(int value) {
    final digits = value.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final open = session;
    String subtitle;
    if (open == null) {
      subtitle = project.purpose.isEmpty
          ? 'Sin sesión abierta'
          : project.purpose;
    } else {
      // El workflow salió de acá: pasó a ser una ficha que se puede tocar,
      // porque ya no es un dato del proyecto que solo se mira.
      subtitle = [
        'Sesión: ${open.title}',
        if (open.contextUsageRatio != null)
          'contexto ${(open.contextUsageRatio! * 100).round()}%',
      ].join(' · ');
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '#',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 16,
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        project.name,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
                Tooltip(
                  message: _contextDetail(),
                  child: Text(
                    subtitle,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Todo lo de la derecha, junto y encogible.
          //
          // Son seis cosas de ancho fijo —PR, workflow, agentes, pestañas,
          // caras, contador— y en un panel angosto no entran: la fila las
          // acomodaba a todas con su tamaño natural y desbordaba por la
          // derecha. Con `FittedBox` el grupo entero se achica en vez de
          // salirse, y el título de la izquierda sigue cortándose primero.
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_pullRequest() case final pr?) _PullRequestChip(pr: pr),
                  if (open != null)
                    _WorkflowChip(
                      project: project,
                      session: open,
                      workflow: workflow,
                    ),
                  if (open != null)
                    IconButton(
                      tooltip: 'Agentes de esta sesión',
                      icon: const Icon(Icons.person_add_alt_outlined, size: 20),
                      onPressed: () => openSessionAgentPicker(
                        context,
                        projectId: project.id,
                        sessionId: open.id,
                      ),
                    ),
                  SegmentedButton<SessionTab>(
                    segments: const [
                      ButtonSegment(
                        value: SessionTab.chat,
                        icon: Icon(Icons.forum_outlined, size: 16),
                        label: Text('Chat'),
                      ),
                      ButtonSegment(
                        value: SessionTab.map,
                        icon: Icon(Icons.hub_outlined, size: 16),
                        label: Text('Mapa'),
                      ),
                    ],
                    selected: {tab},
                    showSelectedIcon: false,
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                    ),
                    onSelectionChanged: (values) => onTabChanged(values.first),
                  ),
                  const SizedBox(width: 12),
                  _Facepile(members: members),
                  const SizedBox(width: 8),
                  Text(
                    '${members.length}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// El PR de la sesión, en el encabezado. Está también en el hilo, pero a los
/// cuarenta mensajes hay que ir a buscarlo: acá se llega de un click desde
/// cualquier punto de la conversación.
class _PullRequestChip extends StatelessWidget {
  const _PullRequestChip({required this.pr});

  final ({int number, String url}) pr;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Tooltip(
        message: 'Abrir ${pr.url}',
        child: TextButton.icon(
          onPressed: () => openExternalUrl(pr.url),
          icon: Icon(Icons.call_merge, size: 15, color: scheme.tertiary),
          label: Text(
            'PR #${pr.number}',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: scheme.tertiary,
            ),
          ),
        ),
      ),
    );
  }
}

/// The project's members as overlapping colour chips — who is in the room,
/// readable at a glance instead of as a bare count.
class _Facepile extends StatelessWidget {
  const _Facepile({required this.members});

  final List<AgentProfile> members;

  static const _maxShown = 5;

  static const _size = 24.0;
  static const _step = 17.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shown = members.take(_maxShown).toList();
    final overflow = members.length - shown.length;
    if (shown.isEmpty) return const SizedBox.shrink();

    // Overlapping avatars are laid out in a Stack, not with negative margins —
    // Container asserts on those.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: _size + (shown.length - 1) * _step,
          height: _size,
          child: Stack(
            children: [
              for (var index = 0; index < shown.length; index++)
                Positioned(
                  left: index * _step,
                  child: Tooltip(
                    message: shown[index].role.isEmpty
                        ? shown[index].name
                        : '${shown[index].name} · ${shown[index].role}',
                    child: Container(
                      width: _size,
                      height: _size,
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: scheme.surface, width: 1.5),
                      ),
                      child: Icon(
                        Icons.smart_toy,
                        size: 14,
                        color: memberColorFor(index),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (overflow > 0)
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Text(
              '+$overflow',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}

class _EmptyChannel extends StatelessWidget {
  const _EmptyChannel({required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.forum_outlined,
              size: 36,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              'Ninguna sesión abierta',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            Text(
              'Cada sesión es un entorno aparte: su propio hilo y su propio '
              'contexto, con toda la configuración de este proyecto.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () =>
                  WorkspaceService.instance.notifier.openNewSession(projectId),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Nueva sesión'),
            ),
          ],
        ),
      ),
    );
  }
}

/// An imported project lands without a working directory (paths never
/// travel in the catalog) — nothing can run until the user picks one here.
class _MissingFolderBanner extends StatelessWidget {
  const _MissingFolderBanner({required this.projectId});

  final String projectId;

  Future<void> _pickFolder() async {
    final path = await getDirectoryPath(confirmButtonText: 'Usar esta carpeta');
    if (path == null) return;
    ProjectsService.instance.notifier.setProjectWorkingDirectory(
      projectId,
      path,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: scheme.errorContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(
            Icons.folder_off_outlined,
            size: 18,
            color: scheme.onErrorContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Este proyecto no tiene carpeta de trabajo (vino de un '
              'import). Elegila para poder correr sesiones.',
              style: TextStyle(color: scheme.onErrorContainer, fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: _pickFolder,
            child: const Text('Elegir carpeta'),
          ),
        ],
      ),
    );
  }
}

class _FindingBar extends StatelessWidget {
  const _FindingBar({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    final findings = session.resolutionCase?.findings
        .where((finding) => finding.status.name != 'resolved')
        .toList();
    if (findings == null || findings.isEmpty) return const SizedBox.shrink();
    final finding = findings.first;

    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surfaceContainerLow,
      child: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: scheme.outlineVariant)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 8, 10, 8),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, size: 16, color: scheme.error),
            const SizedBox(width: 8),
            Text(
              finding.status.name == 'blocked' ? 'BLOQUEADO' : 'HALLAZGO',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                letterSpacing: 1.1,
                color: scheme.outline,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                finding.evidence.summary,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Con qué workflow corre esta sesión, y —mientras no arrancó— el botón para
/// cambiarlo.
///
/// Era una palabra en el subtítulo, al lado del nombre de la sesión y del
/// porcentaje de contexto: información, no decisión. Desde que cada sesión
/// elige su flujo es una decisión, y las decisiones se tocan.
class _WorkflowChip extends StatelessWidget {
  const _WorkflowChip({
    required this.project,
    required this.session,
    required this.workflow,
  });

  final Project project;
  final Session session;
  final Workflow? workflow;

  /// Cambiarlo con pasos ya corridos dejaría medio hilo hecho por una fila
  /// de agentes y la otra mitad por otra, y el `3/7` contando sobre una
  /// escala que esa sesión nunca usó.
  bool get _canChange => session.messages.isEmpty;

  Future<void> _pick(BuildContext context) async {
    final projects = ProjectsService.instance.notifier;
    final picked = await openWorkflowPicker(
      context,
      options: projects.choosableWorkflowsOf(project),
      currentId: session.workflowId,
      title: 'Con qué workflow corre',
      note:
          'Esta sesión y ninguna otra. Un proyecto hace trabajos de clases '
          'distintas —armar la carpeta de tareas, resolver un ticket, evaluar '
          'un requerimiento— y cada uno quiere otra fila de agentes.',
    );
    if (picked == null) return;
    projects.setSessionWorkflow(project.id, session.id, picked);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final name = workflow?.name ?? 'sin workflow';
    final label = Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: workflow == null ? scheme.error : scheme.outlineVariant,
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.account_tree_outlined,
            size: 13,
            color: workflow == null ? scheme.error : scheme.outline,
          ),
          const SizedBox(width: 6),
          Text(
            name,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              color: workflow == null ? scheme.error : scheme.onSurfaceVariant,
            ),
          ),
          if (_canChange) ...[
            const SizedBox(width: 4),
            Icon(Icons.unfold_more, size: 12, color: scheme.outline),
          ],
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Tooltip(
        message: _canChange
            ? 'Con qué workflow corre esta sesión'
            : 'La sesión ya arrancó con «$name»: el workflow queda fijo',
        child: _canChange
            ? InkWell(
                onTap: () => _pick(context),
                borderRadius: BorderRadius.circular(6),
                child: label,
              )
            : Opacity(opacity: 0.75, child: label),
      ),
    );
  }
}
