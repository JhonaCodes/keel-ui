import 'dart:async';
import 'dart:convert';

import 'package:logger_rs/logger_rs.dart';

import 'package:keel_ui/src/core/services/app_window_service.dart';
import 'package:keel_ui/src/integrations/chat_references/chat_references.dart';
import 'package:keel_ui/src/modules/agent_profiles/model/agent_profile.dart';
import 'package:keel_ui/src/modules/agent_profiles/viewmodel/agent_profiles_viewmodel.dart';
import 'package:keel_ui/src/modules/agents/model/agent.dart';
import 'package:keel_ui/src/modules/agents/model/agent_provider.dart';
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

  /// La huella del último estado empujado. Barata a propósito: comparar los
  /// snapshots enteros era recorrer todo el transcripto en cada tecla.
  String? _lastFingerprint;
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
    _activeAgentId = _liveActiveAgentId();
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

  /// Qué chat tiene que mostrar la ventana, respetando el que elegiste.
  ///
  /// Esto era `_activeAgentId = resolveKeelAiSession()` a secas, y
  /// `resolveKeelAiSession` devuelve **el más reciente**. Como `_open()`
  /// corre en cada apertura —y el botón de Keel AI del rail abre aunque la
  /// ventana ya esté abierta—, tocarlo mientras leías una conversación vieja
  /// te tiraba de golpe a la última: la ventana cambiaba de chat sola.
  ///
  /// Solo se vuelve a resolver cuando no hay ninguno elegido, o cuando el que
  /// había ya no existe —lo borraste desde la app principal— y quedarse con
  /// él sería mostrar una ventana vacía para siempre.
  String? _liveActiveAgentId() =>
      _resolveActiveAgent()?.id ?? _agents.resolveKeelAiSession();

  /// Las conversaciones de Keel AI, de la más nueva a la más vieja.
  List<Agent> _keelAiSessions() {
    final keelAiProfileId = AgentProfilesService.instance.notifier.data.profiles
        .where((profile) => profile.name == kKeelAiHandle)
        .firstOrNull
        ?.id;
    return _agents.data.agents
        .where((agent) => agent.profileId == keelAiProfileId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// El chat que la ventana muestra, resuelto en UN solo lugar.
  ///
  /// La huella y el contenido lo calculaban por separado: la huella buscaba
  /// entre TODOS los agentes por id, y el contenido solo entre las sesiones
  /// de Keel AI, con un «si no lo encuentro, mostrá la más reciente»
  /// silencioso. Cuando los dos no coincidían, la ventana terminaba mostrando
  /// una conversación mientras el puente creía que mostraba otra — y como la
  /// huella miraba la equivocada, un cambio real podía no empujarse nunca.
  ///
  /// La caída a la más reciente se conserva (mostrar algo es mejor que
  /// mostrar un hueco) pero **se anota**: si la ventana cambió de chat, el
  /// puente tiene que saberlo, porque es lo que usa para mandar un pedido
  /// desde afuera.
  Agent? _resolveActiveAgent() {
    final sessions = _keelAiSessions();
    final chosen = sessions
        .where((agent) => agent.id == _activeAgentId)
        .firstOrNull;
    if (chosen != null) return chosen;

    final fallback = sessions.firstOrNull;
    _activeAgentId = fallback?.id;
    return fallback;
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
        _activeAgentId = _liveActiveAgentId();
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

      case 'referenceSuggestions':
        // El catálogo se arma de este lado: la ventana no tiene base.
        final suggestions = await ChatReferenceService.suggestions(
          scope: const GlobalReferenceScope(),
          query: ChatReferenceQuery.fromJson(payload),
        );
        return jsonEncode([
          for (final suggestion in suggestions) suggestion.toJson(),
        ]);

      case 'sendQueued':
        unawaited(_agents.sendQueuedMessages(agentId!));
        return null;

      case 'removeQueued':
        _agents.removeQueuedMessage(agentId!, payload['messageId'] as String);
        return null;

      case 'editQueued':
        _agents.editQueuedMessage(
          agentId!,
          payload['messageId'] as String,
          payload['text'] as String,
        );
        return null;

      case 'holdQueued':
        _agents.holdQueuedMessage(agentId!, payload['messageId'] as String);
        return null;

      case 'sendQueuedAfterTurn':
        unawaited(
          _agents.sendQueuedMessageAfterTurn(
            agentId!,
            payload['messageId'] as String,
          ),
        );
        return null;

      case 'sendQueuedNow':
        unawaited(
          _agents.sendQueuedMessageNow(
            agentId!,
            payload['messageId'] as String,
          ),
        );
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

      case 'setProvider':
        _agents.setAgentProvider(
          agentId!,
          AgentProvider.fromAlias(payload['provider'] as String),
        );
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

      case 'setPlanMode':
        _agents.setAgentPlanMode(agentId!, payload['enabled'] as bool);
        return null;

      case 'implementPlan':
        _agents.implementPlan(agentId!);
        return null;

      case 'keepPlanning':
        _agents.keepPlanning(agentId!);
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
    _lastFingerprint = null;
    _agents.removeListener(_onAgentsChanged);
  }

  /// Llega en CADA cambio de estado del chat, incluido cada pedazo de texto
  /// que el agente va escribiendo. O sea: decenas de veces por segundo.
  ///
  /// Por eso acá no se arma nada. Antes esta función construía el snapshot
  /// entero y lo comparaba con el anterior —una comparación que recorre
  /// mensaje por mensaje y texto por texto— y recién después programaba el
  /// timer. El debounce demoraba el envío, que es lo barato, mientras lo
  /// caro se pagaba igual en cada cambio: la ventana quedaba pastosa
  /// mientras el agente escribía, y aprobar un permiso —que dispara varios
  /// cambios seguidos— congelaba la app unos segundos.
  ///
  /// Lo único que se mira acá es una huella barata: cuántos mensajes hay,
  /// cuánto mide el último y si cambió lo que se ve alrededor. Dos estados
  /// distintos con la misma huella son, para esta ventana, el mismo estado.
  void _onAgentsChanged() {
    final fingerprint = _fingerprint();
    if (fingerprint == _lastFingerprint) return;
    _lastFingerprint = fingerprint;
    // Ya hay un envío programado: este cambio viaja en ese.
    if (_debounce?.isActive ?? false) return;
    _debounce = Timer(_pushDebounce, () => unawaited(_pushNow()));
  }

  /// Lo que hace distinto a un estado de otro, sin serializar nada.
  ///
  /// El largo del último mensaje es lo que se mueve mientras el agente
  /// escribe; el resto son los cambios que se ven de golpe.
  String _fingerprint() {
    final agents = _agents.data.agents;
    final active = _resolveActiveAgent();
    final last = active?.messages.lastOrNull;
    return [
      agents.length,
      _activeAgentId ?? '',
      active?.messages.length ?? 0,
      last?.text.length ?? 0,
      last?.reasoning?.length ?? 0,
      active?.isStreaming ?? false,
      active?.liveReasoning?.length ?? 0,
      active?.currentActivity?.label ?? '',
      active?.pendingPermission?.message ?? '',
      active?.model ?? '',
      active?.provider.alias ?? '',
      active?.effort ?? '',
      active?.fullFileSystemAccess ?? false,
      // Sin estos dos, el modo plan se prende en la app principal y esta
      // ventana no se entera nunca: el empuje se descarta por huella igual.
      active?.planMode ?? false,
      active?.planAwaitingDecision ?? false,
      SettingsService.instance.notifier.data.chatFontScale,
      SettingsService.instance.notifier.data.language,
    ].join('|');
  }

  Future<void> _pushNow() async {
    // Se arma y se serializa UNA sola vez, acá, del lado barato del timer.
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

  /// Stamps the next seq onto the current content and encodes it.
  String _encodeWireState() {
    final content = _buildContent();
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
    final sessions = _keelAiSessions();
    final active = _resolveActiveAgent();

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

  /// Cuánto va a pesar el snapshot en el cable, sin armarlo.
  ///
  /// Solo suma lo que crece sin techo —el texto, el razonamiento y las
  /// ediciones de archivo de cada mensaje—; los campos fijos son ruido al
  /// lado de un hilo largo. El margen por mensaje cubre las claves del JSON.
  ///
  /// Las ediciones se cuentan aunque ya vengan acotadas por el snapshot: doce
  /// diffs de 64 KB son 768 KB, más que de sobra para pasarse del techo del
  /// cable. Sin sumarlas, el recorte de historial creería que hay lugar.
  int _estimatedChars(AssistantAgentSnapshot snapshot) {
    var total = 0;
    for (final message in snapshot.messages) {
      total += message.text.length + (message.reasoning?.length ?? 0) + 120;
      for (final edit in message.fileEdits) {
        total +=
            (edit.beforeContent?.length ?? 0) + edit.afterContent.length + 60;
      }
    }
    return total;
  }

  /// Snapshot with the oldest messages dropped if the encoded form is huge.
  /// The real thread in main is untouched — this only bounds the wire.
  ///
  /// El tamaño se ESTIMA sumando los largos de texto, no serializando. La
  /// condición de este `while` llamaba a `jsonEncode` sobre el transcripto
  /// entero, así que se pagaba un encode completo siempre —incluso cuando el
  /// hilo era corto y no había nada que recortar— solo para medirlo. Estimar
  /// se equivoca en el margen; serializar para medir se equivocaba en el
  /// costo, que es lo que se notaba.
  AssistantAgentSnapshot _boundedSnapshot(Agent agent) {
    var snapshot = AssistantAgentSnapshot.fromAgent(agent);
    while (_estimatedChars(snapshot) > _maxWireChars &&
        snapshot.messages.length > 20) {
      final kept = snapshot.messages.sublist(snapshot.messages.length ~/ 2);
      snapshot = AssistantAgentSnapshot(
        id: snapshot.id,
        name: snapshot.name,
        model: snapshot.model,
        provider: snapshot.provider,
        effort: snapshot.effort,
        fullFileSystemAccess: snapshot.fullFileSystemAccess,
        planMode: snapshot.planMode,
        planAwaitingDecision: snapshot.planAwaitingDecision,
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
