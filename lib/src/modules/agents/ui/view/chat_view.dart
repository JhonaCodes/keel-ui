import 'dart:async';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:multiselect_field/multiselect_field.dart';

import 'package:keel_ui/src/modules/agents/model/agent.dart';
import 'package:keel_ui/src/modules/agents/model/agent_model_option.dart';
import 'package:keel_ui/src/modules/agents/model/agent_provider.dart';
import 'package:keel_ui/src/integrations/llm/openai_compatible/remote_model_catalog.dart';
import 'package:keel_ui/src/modules/agents/service/chat_actions.dart';
import 'package:keel_ui/src/modules/agents/service/chat_attachment_store.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/chat_attachment_strip.dart';
import 'package:keel_ui/src/core/ui/confirm_card.dart';
import 'package:keel_ui/src/integrations/chat_references/chat_references.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/chat_reference_composer_field.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/chat_message_bubble.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/queued_messages_strip.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/agent_activity_indicator.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/agent_status_icon.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/context_usage_ring.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/effort_level_selector.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/fade_in_entrance.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/permission_request_banner.dart';
import 'package:keel_ui/src/modules/agents/ui/widget/reasoning_panel.dart';
import 'package:keel_ui/src/shared/shared.dart';

class ChatView extends StatefulWidget {
  const ChatView({
    super.key,
    required this.agent,
    this.controller,
    this.emptyState,
    this.actions = const LocalChatActions(),
    this.fontScaleOverride,
  });

  final Agent agent;

  /// Where the user's intents actually execute. The default talks to this
  /// engine's [AgentsService] singleton; the dedicated assistant window
  /// swaps in an RPC bridge because its engine's singletons are empty.
  final ChatActions actions;

  /// Lets a caller that also wants to fill the composer from outside (e.g.
  /// the Assistant panel's example prompts) own the controller instead of
  /// this widget creating its own. Defaults to an internally-owned one, so
  /// every other caller is unaffected.
  final TextEditingController? controller;

  /// Font scale to use instead of this engine's settings singleton. The
  /// assistant window has no database, so its settings hold defaults only —
  /// main sends the real value with the snapshot.
  final double? fontScaleOverride;

  /// Shown instead of the default "Escríbele algo a tu agente" text when
  /// [Agent.messages] is empty. Lets a caller (e.g. the Assistant panel)
  /// swap in something richer without this widget knowing what that is.
  final Widget? emptyState;

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  late final TextEditingController _controller =
      widget.controller ?? TextEditingController();

  bool get _ownsController => widget.controller == null;

  /// Images already copied into app storage, waiting to travel with the
  /// next message. Stored paths, not the originals — see
  /// [ChatAttachmentStore].
  final List<String> _attachments = [];
  final ScrollController _messageScroll = ScrollController();
  final RemoteModelCatalog _modelCatalog = RemoteModelCatalog();
  late Future<List<AgentModelOption>> _modelOptions = _modelCatalog.load(
    widget.agent.provider,
  );

  /// A drag is hovering the chat, so the drop hint is showing.
  bool _isDragging = false;
  bool _atLatest = true;

  @override
  void initState() {
    super.initState();
    _messageScroll.addListener(_watchMessagePosition);
  }

  @override
  void didUpdateWidget(covariant ChatView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.agent.provider != widget.agent.provider) {
      _modelOptions = _modelCatalog.load(widget.agent.provider);
    }
    // Contestado el permiso, el hueco que le tenía reservado el hilo se va
    // con él: si no, queda un espacio en blanco abajo hasta el próximo.
    if (widget.agent.pendingPermission == null && _permissionHeight != 0) {
      _permissionHeight = 0;
    }
  }

  @override
  void dispose() {
    _messageScroll
      ..removeListener(_watchMessagePosition)
      ..dispose();
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  void _watchMessagePosition() {
    if (!_messageScroll.hasClients) return;
    final atLatest = _messageScroll.offset <= 24;
    if (atLatest != _atLatest) setState(() => _atLatest = atLatest);
  }

  void _goToLatest() {
    _messageScroll.animateTo(
      0,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  }

  /// Sends, or QUEUES when the agent is mid-turn — the ViewModel decides.
  /// The composer never refuses input: a correction you thought of while
  /// the model works is exactly the one worth writing down.
  void _send() {
    final text = _controller.text;
    if (text.trim().isEmpty && _attachments.isEmpty) return;
    widget.actions.sendMessage(
      widget.agent.id,
      text,
      imagePaths: [..._attachments],
    );
    _controller.clear();
    setState(_attachments.clear);
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

  Future<void> _onDropDone(DropDoneDetails details) async {
    setState(() => _isDragging = false);
    await _attach([for (final file in details.files) file.path]);
  }

  /// Everything dropped or picked goes through here: non-images are
  /// discarded silently (a drag can carry a folder or a PDF) and the rest
  /// is copied into app storage before it is ever shown as a thumbnail.
  Future<void> _attach(List<String> paths) async {
    if (paths.isEmpty) return;
    final stored = await ChatAttachmentStore.adoptImages(paths);
    if (!mounted || stored.isEmpty) return;
    setState(() => _attachments.addAll(stored));
  }

  void _removeAttachment(String path) {
    setState(() => _attachments.remove(path));
    // Never sent, so the stored copy has no reason to survive.
    unawaited(ChatAttachmentStore.discard(path));
  }

  Future<void> _confirmAndDelete() async {
    final agent = widget.agent;
    final confirmed = await confirmWithCard(
      context,
      title: 'Eliminar agente',
      body: 'Se eliminará "${agent.name}" y su historial de chat.',
      destructive: true,
    );

    if (confirmed) {
      widget.actions.deleteAgent(agent.id);
    }
  }

  void _onModelChanged(List<Choice<String>> selected) {
    if (selected.isEmpty) return;
    final model = selected.first.key;
    if (model == null) return;
    widget.actions.setAgentModel(widget.agent.id, model);
  }

  void _onProviderChanged(List<Choice<AgentProvider>> selected) {
    if (selected.isEmpty) return;
    final provider = selected.first.metadata;
    if (provider == null) return;
    widget.actions.setAgentProvider(widget.agent.id, provider);
  }

  Future<void> _toggleFullFileSystemAccess() async {
    final agent = widget.agent;

    if (agent.fullFileSystemAccess) {
      widget.actions.setAgentFullFileSystemAccess(agent.id, false);
      return;
    }

    final confirmed = await confirmWithCard(
      context,
      title: 'Dar acceso a todo el sistema de archivos',
      body:
          '"${agent.name}" podrá leer y escribir en cualquier carpeta del '
          'computador, no solo en tu carpeta de usuario.',
      confirmLabel: 'Dar acceso',
    );

    if (confirmed) {
      widget.actions.setAgentFullFileSystemAccess(agent.id, true);
    }
  }

  /// Cuánto ocupa el pedido de permiso que está flotando, para que el hilo
  /// le reserve ese espacio abajo. Medido y no estimado: la tarjeta cambia
  /// de alto según la variante —un permiso de tool es una línea, un cambio
  /// de catálogo son cuatro— y un número inventado deja la última burbuja
  /// tapada o un hueco vacío.
  double _permissionHeight = 0;

  /// El hilo: las burbujas, o el cartel de bienvenida cuando todavía no hay
  /// ninguna. Sale del `build` para que el pedido de permiso pueda flotar
  /// encima suyo sin anidar tres Stacks en la misma expresión.
  Widget _conversation(Agent agent) {
    return agent.messages.isEmpty
        ? widget.emptyState ??
              const Center(child: Text('Escríbele algo a tu agente'))
        : Stack(
            children: [
              SelectionArea(
                child: ListView.builder(
                  controller: _messageScroll,
                  reverse: true,
                  padding: EdgeInsets.fromLTRB(
                    16,
                    16,
                    16,
                    16 + _permissionHeight,
                  ),
                  itemCount: agent.messages.length,
                  itemBuilder: (context, index) {
                    final msgIndex = agent.messages.length - 1 - index;
                    final message = agent.messages[msgIndex];
                    return FadeInEntrance(
                      key: ValueKey(message.timestamp.microsecondsSinceEpoch),
                      child: ChatMessageBubble(
                        message: message,
                        agentId: agent.id,
                        agentColor: agent.iconColor,
                        actions: widget.actions,
                        fontScaleOverride: widget.fontScaleOverride,
                      ),
                    );
                  },
                ),
              ),
              if (!_atLatest)
                Positioned(
                  right: 20,
                  bottom: 16,
                  child: FloatingActionButton.small(
                    tooltip: 'Ir al mensaje más reciente',
                    onPressed: _goToLatest,
                    child: const Icon(Icons.arrow_downward),
                  ),
                ),
            ],
          );
  }

  @override
  Widget build(BuildContext context) {
    final agent = widget.agent;

    // The drop area is the WHOLE chat, not just the composer: you drag a
    // screenshot at the conversation you are reading, not at a 40px input.
    return DropTarget(
      onDragEntered: (_) => setState(() => _isDragging = true),
      onDragExited: (_) => setState(() => _isDragging = false),
      onDragDone: _onDropDone,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(4),
                      child: AgentStatusIcon(
                        color: agent.iconColor,
                        selected: true,
                        isWorking: agent.isStreaming,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      agent.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(width: 6),
                    MultiSelectField<AgentProvider>.chip(
                      key: ValueKey('provider-${agent.provider.alias}'),
                      label: 'Proveedor',
                      singleSelection: true,
                      chipSize: ChipSize.small,
                      data: () => [
                        for (final provider in AgentProvider.values)
                          Choice(
                            provider.alias,
                            provider.label,
                            metadata: provider,
                          ),
                      ],
                      defaultData: [
                        Choice(
                          agent.provider.alias,
                          agent.provider.label,
                          metadata: agent.provider,
                        ),
                      ],
                      onChanged: _onProviderChanged,
                    ),
                    const SizedBox(width: 8),
                    // Each provider runs its own CLI with its own model
                    // names: a codex agent must never be offered `sonnet`.
                    FutureBuilder<List<AgentModelOption>>(
                      future: _modelOptions,
                      builder: (context, snapshot) {
                        final options =
                            snapshot.data ?? modelOptionsFor(agent.provider);
                        return MultiSelectField<String>.chip(
                          key: ValueKey('model-${agent.provider.alias}'),
                          label: 'Modelo',
                          singleSelection: true,
                          chipSize: ChipSize.small,
                          data: () => [
                            for (final option in options)
                              Choice(option.alias, option.label),
                          ],
                          defaultData: [
                            Choice(
                              initialModelFor(agent.provider, agent.model),
                              modelLabelFor(
                                agent.provider,
                                initialModelFor(agent.provider, agent.model),
                              ),
                            ),
                          ],
                          onChanged: _onModelChanged,
                        );
                      },
                    ),
                    const SizedBox(width: 4),
                    EffortLevelSelector(
                      effort: agent.effort,
                      onChanged: (effort) =>
                          widget.actions.setAgentEffort(agent.id, effort),
                    ),
                    const SizedBox(width: 4),
                    ContextUsageRing(
                      ratio: agent.contextUsageRatio,
                      onCompact: () => widget.actions.requestCompact(agent.id),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: agent.fullFileSystemAccess
                          ? 'Tiene acceso a todo el sistema de archivos (clic para quitarlo)'
                          : 'Dar acceso a todo el sistema de archivos',
                      icon: Icon(
                        agent.fullFileSystemAccess
                            ? Icons.folder_open
                            : Icons.folder_off_outlined,
                        color: agent.fullFileSystemAccess
                            ? Theme.of(context).colorScheme.error
                            : null,
                      ),
                      onPressed: _toggleFullFileSystemAccess,
                    ),
                    IconButton(
                      tooltip: 'Eliminar agente',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: _confirmAndDelete,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(child: _conversation(agent)),
                    // El pedido de permiso va ENCIMA de la conversación, y
                    // pegado al composer, que es donde está el ojo. Antes
                    // era una fila más arriba del listado, recortada a 160
                    // px: la variante de cambio de catálogo no entra en esa
                    // altura, así que se cortaba justo donde empiezan las
                    // burbujas —los botones quedaban del otro lado del
                    // corte— y se leía como si el chat lo tapara.
                    if (agent.pendingPermission case final request?)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: LayoutBuilder(
                          builder: (context, constraints) => ConstrainedBox(
                            // Un pedido larguísimo no se come la
                            // conversación entera: se desplaza adentro.
                            constraints: BoxConstraints(
                              maxHeight: constraints.maxHeight * 0.7,
                            ),
                            child: SingleChildScrollView(
                              reverse: true,
                              child: _MeasuredHeight(
                                onChanged: (height) {
                                  if (height == _permissionHeight) return;
                                  setState(() => _permissionHeight = height);
                                },
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: PermissionRequestBanner(
                                    request: request,
                                    onRespond: (grant) => widget.actions
                                        .respondToPermissionRequest(
                                          agent.id,
                                          grant: grant,
                                        ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (agent.liveReasoning != null &&
                  agent.liveReasoning!.isNotEmpty)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 140),
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: ReasoningPanel(
                          text: agent.liveReasoning!,
                          initiallyExpanded: true,
                        ),
                      ),
                    ),
                  ),
                ),
              if (agent.currentActivity != null)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 60),
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: AgentActivityIndicator(
                          activity: agent.currentActivity,
                        ),
                      ),
                    ),
                  ),
                ),
              SizedBox(
                height: 2,
                child: agent.isStreaming
                    ? const LinearProgressIndicator(minHeight: 2)
                    : Divider(
                        height: 2,
                        thickness: 1,
                        color: Theme.of(context).dividerColor,
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    QueuedMessagesStrip(
                      messages: agent.queuedMessages,
                      isStreaming: agent.isStreaming,
                      onRemove: (index) =>
                          widget.actions.removeQueuedMessage(agent.id, index),
                      onSendNow: () =>
                          widget.actions.sendQueuedMessages(agent.id),
                    ),
                    ChatAttachmentStrip(
                      paths: _attachments,
                      onRemove: _removeAttachment,
                    ),
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Adjuntar imagen',
                          icon: const Icon(Icons.image_outlined),
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
                            child: ChatReferenceComposerField(
                              controller: _controller,
                              // Sin proyecto: se pueden nombrar las carpetas
                              // de los proyectos registrados, las raíces
                              // conocidas y todo el catálogo.
                              scope: const GlobalReferenceScope(),
                              suggestionsResolver:
                                  widget.actions.referenceSuggestions,
                              onSend: _send,
                              hintText: agent.isStreaming
                                  ? 'Escribí y se envía cuando termine…'
                                  : 'Escribe un mensaje…',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Mid-turn both intents exist at once — stop what is
                        // running, or add to what comes next — so both get
                        // their own button instead of one that changes
                        // meaning under the cursor.
                        if (agent.isStreaming)
                          IconButton(
                            tooltip: 'Detener',
                            onPressed: () => widget.actions.stopAgent(agent.id),
                            icon: const Icon(Icons.stop_circle),
                          ),
                        IconButton.filled(
                          tooltip: agent.isStreaming
                              ? 'Encolar para cuando termine'
                              : null,
                          onPressed: _send,
                          icon: Icon(
                            agent.isStreaming
                                ? Icons.schedule_send
                                : Icons.send,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_isDragging) const ChatDropHint(),
        ],
      ),
    );
  }
}

/// Le avisa a quien lo envuelve cuánto mide su hijo, después de dibujarlo.
///
/// Existe por una sola cosa: el pedido de permiso flota sobre el hilo, y el
/// hilo tiene que reservar exactamente ese alto abajo para que la última
/// burbuja no quede debajo de la tarjeta.
class _MeasuredHeight extends StatefulWidget {
  const _MeasuredHeight({required this.child, required this.onChanged});

  final Widget child;
  final ValueChanged<double> onChanged;

  @override
  State<_MeasuredHeight> createState() => _MeasuredHeightState();
}

class _MeasuredHeightState extends State<_MeasuredHeight> {
  final _key = GlobalKey();

  @override
  void initState() {
    super.initState();
    _report();
  }

  @override
  void didUpdateWidget(_MeasuredHeight oldWidget) {
    super.didUpdateWidget(oldWidget);
    _report();
  }

  /// Después del frame, nunca durante: leer el tamaño mientras se construye
  /// es preguntarle a un render que todavía no existe.
  void _report() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = _key.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) return;
      widget.onChanged(box.size.height);
    });
  }

  @override
  Widget build(BuildContext context) =>
      KeyedSubtree(key: _key, child: widget.child);
}
