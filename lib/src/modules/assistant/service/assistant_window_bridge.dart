import 'dart:async';
import 'dart:convert';

import 'package:logger_rs/logger_rs.dart';

import 'package:keel_ui/src/core/services/app_window_service.dart';
import 'package:keel_ui/src/modules/agent_profiles/model/agent_profile.dart';
import 'package:keel_ui/src/modules/agent_profiles/viewmodel/agent_profiles_viewmodel.dart';
import 'package:keel_ui/src/modules/agents/model/agent.dart';
import 'package:keel_ui/src/modules/agents/model/chat_message.dart';
import 'package:keel_ui/src/modules/agents/model/file_edit.dart';
import 'package:keel_ui/src/modules/agents/viewmodel/agents_viewmodel.dart';
import 'package:keel_ui/src/modules/assistant/model/assistant_window_arguments.dart';
import 'package:keel_ui/src/modules/assistant/model/assistant_window_state.dart';
import 'package:keel_ui/src/modules/settings/viewmodel/settings_viewmodel.dart';

/// MAIN-engine side of the assistant window: owns which Keel AI session the
/// window shows, listens to [AgentsService] and pushes coalesced
/// [AssistantWindowState] snapshots, and executes every `assistant.*` intent
/// the window sends back over the bridge channel.
///
/// A plain singleton, not a ReactiveNotifier: nothing in THIS engine's
/// widget tree renders it — its one consumer is a different Flutter engine
/// reached by method channel.
class AssistantWindowBridge {
  AssistantWindowBridge._();

  static final AssistantWindowBridge instance = AssistantWindowBridge._();

  /// Coalesces the token-by-token streaming updates into a sane push rate.
  static const _pushDebounce = Duration(milliseconds: 30);

  /// Above this the wire snapshot drops its oldest messages — the channel
  /// would survive more, but serializing MBs per streaming tick would not.
  static const _maxWireChars = 1000000;

  String? _activeAgentId;
  int _seq = 0;
  AssistantWindowState? _lastContent;
  Timer? _debounce;
  bool _listening = false;
  Future<void>? _opening;

  AgentsViewModel get _agents => AgentsService.instance.notifier;

  /// Opens (or focuses) the assistant window. Call from an event handler,
  /// never from build — resolving the Keel AI session can mutate
  /// [AgentsViewModel], same rule the old side panel documented.
  Future<void> open() {
    return _opening ??= _open().whenComplete(() => _opening = null);
  }

  Future<void> _open() async {
    _activeAgentId = _agents.resolveKeelAiSession() ?? _activeAgentId;
    _ensureListening();

    // El nudge es SOLO para una ventana que ya existía: su engine no se
    // vuelve a attachear solo. Una ventana nueva se conecta por su cuenta
    // en el init de su ViewModel, y empujarle un método antes de que
    // registre su handler no llega a nadie — además de tirar un error que
    // hace que la demos por muerta y borremos su registro.
    final existed =
        await liveWindowController(AssistantWindowArguments.id) != null;
    await openOrFocusAppWindow(AssistantWindowArguments());
    if (existed) {
      await invokeOnWindow(AssistantWindowArguments.id, 'assistantFocus', '{}');
    }
  }

  /// Abre la ventana de Keel AI con el pedido ya hecho.
  ///
  /// Existe para los lugares que ofrecen «pediselo a Keel AI»: si el botón
  /// solo abriera la ventana, quedarías frente a un cursor teniendo que
  /// redactar vos lo que el botón ya sabía pedir. El mensaje entra por el
  /// mismo camino que si lo hubieras escrito.
  Future<void> openAsking(String request) async {
    await open();
    final agentId = _activeAgentId;
    if (agentId == null) return;
    unawaited(_agents.sendMessage(agentId, request));
  }

  /// Dispatches one `assistant.<method>` bridge call. Returns a JSON-encoded
  /// [AssistantWindowState] for the methods whose UI needs the answer
  /// immediately (attach + session changes), null for fire-and-forget ones.
  Future<String?> handleCall(String method, String payloadJson) async {
    final payload = payloadJson.isEmpty
        ? const <String, dynamic>{}
        : jsonDecode(payloadJson) as Map<String, dynamic>;
    final agentId = payload['agentId'] as String?;

    switch (method) {
      case 'attach':
        _ensureListening();
        _activeAgentId ??= _agents.resolveKeelAiSession();
        return _encodeWireState();

      case 'sendMessage':
        unawaited(
          _agents.sendMessage(
            agentId!,
            payload['text'] as String,
            imagePaths:
                (payload['imagePaths'] as List?)?.cast<String>() ?? const [],
          ),
        );
        return null;

      case 'sendQueued':
        unawaited(_agents.sendQueuedMessages(agentId!));
        return null;

      case 'removeQueued':
        _agents.removeQueuedMessage(agentId!, payload['index'] as int);
        return null;

      case 'stop':
        _agents.stopAgent(agentId!);
        return null;

      case 'deleteMessage':
        _agents.deleteMessage(
          agentId!,
          DateTime.fromMicrosecondsSinceEpoch(payload['timestampUs'] as int),
        );
        return null;

      case 'setModel':
        _agents.setAgentModel(agentId!, payload['model'] as String);
        return null;

      case 'setEffort':
        _agents.setAgentEffort(agentId!, payload['effort'] as String);
        return null;

      case 'requestCompact':
        _agents.requestCompact(agentId!);
        return null;

      case 'respondPermission':
        _agents.respondToPermissionRequest(
          agentId!,
          grant: payload['grant'] as bool,
        );
        return null;

      case 'setFullFileSystemAccess':
        _agents.setAgentFullFileSystemAccess(
          agentId!,
          payload['enabled'] as bool,
        );
        return null;

      case 'deleteAgent':
        _agents.deleteAgent(agentId!);
        // Never leave the window pointing at a ghost: fall through to the
        // most recent surviving session (or a fresh one).
        _activeAgentId = _agents.resolveKeelAiSession();
        return _encodeWireState();

      case 'newSession':
        _activeAgentId = _agents.startNewKeelAiSession() ?? _activeAgentId;
        return _encodeWireState();

      case 'selectSession':
        _activeAgentId = agentId;
        return _encodeWireState();

      case 'askAboutLine':
        unawaited(
          _agents.askAboutLine(
            agentId!,
            filePath: payload['filePath'] as String,
            lineNumber: payload['lineNumber'] as int,
            lineContent: payload['lineContent'] as String,
            question: payload['question'] as String,
          ),
        );
        return null;

      case 'recordManualEdit':
        _agents.recordManualEdit(
          agentId!,
          FileEdit(
            path: payload['filePath'] as String,
            beforeContent: payload['beforeContent'] as String,
            afterContent: payload['afterContent'] as String,
          ),
        );
        return null;

      default:
        Log.w('Unknown assistant bridge method: $method');
        return null;
    }
  }

  void _ensureListening() {
    if (_listening) return;
    _listening = true;
    _agents.addListener(_onAgentsChanged);
  }

  void _detach() {
    if (!_listening) return;
    _listening = false;
    _debounce?.cancel();
    _debounce = null;
    _lastContent = null;
    _agents.removeListener(_onAgentsChanged);
  }

  void _onAgentsChanged() {
    final content = _buildContent();
    if (content == _lastContent) return;
    _debounce?.cancel();
    _debounce = Timer(_pushDebounce, () => unawaited(_pushNow()));
  }

  Future<void> _pushNow() async {
    final json = _encodeWireState();
    final delivered = await invokeOnWindow(
      AssistantWindowArguments.id,
      'assistantState',
      json,
    );
    // Nobody listening anymore — stop paying for snapshots until the next
    // open()/attach re-engages.
    if (!delivered) _detach();
  }

  /// Stamps the next seq onto the current content and encodes it. Also
  /// records the content so the listener can skip no-op pushes.
  String _encodeWireState() {
    final content = _buildContent();
    _lastContent = content;
    final wire = AssistantWindowState(
      seq: ++_seq,
      activeAgentId: content.activeAgentId,
      agent: content.agent,
      sessions: content.sessions,
      chatFontScale: content.chatFontScale,
      language: content.language,
    );
    return jsonEncode(wire.toJson());
  }

  /// Current window content with seq 0 — comparable across ticks.
  AssistantWindowState _buildContent() {
    final keelAiProfileId = AgentProfilesService.instance.notifier.data.profiles
        .where((profile) => profile.name == kKeelAiHandle)
        .firstOrNull
        ?.id;

    final sessions =
        _agents.data.agents
            .where((agent) => agent.profileId == keelAiProfileId)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    Agent? active = sessions
        .where((agent) => agent.id == _activeAgentId)
        .firstOrNull;
    active ??= sessions.firstOrNull;

    return AssistantWindowState(
      activeAgentId: active?.id,
      agent: active == null ? null : _boundedSnapshot(active),
      // Resuelto acá: en main la base sí está, en la sub-ventana no.
      chatFontScale: SettingsService.instance.notifier.data.chatFontScale,
      language: SettingsService.instance.notifier.data.language,
      sessions: [
        for (final session in sessions)
          AssistantSessionSummary.fromAgent(session),
      ],
    );
  }

  /// Snapshot with the oldest messages dropped if the encoded form is huge.
  /// The real thread in main is untouched — this only bounds the wire.
  AssistantAgentSnapshot _boundedSnapshot(Agent agent) {
    var snapshot = AssistantAgentSnapshot.fromAgent(agent);
    while (jsonEncode(snapshot.toJson()).length > _maxWireChars &&
        snapshot.messages.length > 20) {
      final kept = snapshot.messages.sublist(snapshot.messages.length ~/ 2);
      snapshot = AssistantAgentSnapshot(
        id: snapshot.id,
        name: snapshot.name,
        model: snapshot.model,
        effort: snapshot.effort,
        fullFileSystemAccess: snapshot.fullFileSystemAccess,
        isStreaming: snapshot.isStreaming,
        iconColor: snapshot.iconColor,
        messages: [
          ChatMessage(
            role: ChatRole.system,
            text:
                '… historial truncado en esta ventana; el hilo completo '
                'sigue en la app principal.',
            timestamp: kept.first.timestamp,
          ),
          ...kept,
        ],
        liveReasoning: snapshot.liveReasoning,
        currentActivity: snapshot.currentActivity,
        pendingPermission: snapshot.pendingPermission,
        contextUsedTokens: snapshot.contextUsedTokens,
        contextWindowTokens: snapshot.contextWindowTokens,
        // Se rearma el snapshot para recortar el historial: lo que NO es
        // historial tiene que sobrevivir el recorte, o la cola desaparece
        // de la ventana justo en los hilos largos.
        queuedMessages: snapshot.queuedMessages,
      );
    }
    return snapshot;
  }
}
