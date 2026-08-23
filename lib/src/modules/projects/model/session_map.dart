import 'package:keel_ui/src/core/services/claude_stream_events.dart';
import 'package:keel_ui/src/modules/agent_profiles/model/agent_profile.dart';
import 'package:keel_ui/src/modules/agents/model/agent_tool_activity.dart';
import 'package:keel_ui/src/modules/agents/model/chat_message.dart';
import 'package:keel_ui/src/modules/projects/model/session.dart';
import 'package:keel_ui/src/modules/projects/model/session_live_turn.dart';
import 'package:keel_ui/src/modules/projects/model/session_subagent.dart';
import 'package:keel_ui/src/modules/workflows/model/workflow.dart';

/// Cuántos subagentes se dibujan por padre antes de agruparlos.
///
/// Es un tope de DIBUJO y nada más: no limita cuántos puede abrir un agente
/// ni cambia lo que corre. Un padre que largó doce llenaría el carril y
/// taparía a los demás; los que no entran se cuentan en una píldora que se
/// abre.
const kSubagentsDrawn = 4;

enum MapNodeKind { you, step, free, subagent, end }

/// Los ocho estados de un nodo. Es el mismo cuadro cambiando de estado: nada
/// se apila, nada se acumula.
enum MapNodeState {
  idle,
  thinking,
  working,
  writing,
  replying,
  waiting,
  done,
  failed,
}

/// Un evento del mapa, un tipo de línea. Trazo continuo avanza, guiones
/// largos piden, puntos contestan.
enum MapEdgeKind {
  /// El paso del workflow cambió de dueño.
  forward,

  /// Alguien volvió a llamar a un nodo de un paso anterior.
  back,

  /// El llamado contestó y devolvió el turno.
  answer,

  /// Un miembro abrió un subagente con `Task`.
  delegate,

  /// El subagente entregó.
  delegateBack,

  /// Relación de elenco: quién registró a quién. Nunca se anima.
  spawn,

  /// El último paso cerró.
  finish,

  /// Error de turno, hook que bloquea o permiso negado.
  failed,

  /// El camino existe pero nadie pasó todavía.
  untraveled,
}

class MapNode {
  final String id;
  final MapNodeKind kind;

  /// Qué se ve en el cuadro: el handle del miembro, el tipo de subagente.
  final String label;

  final String? profileId;

  /// Índice del miembro en el elenco, para el color. -1 cuando no es un
  /// miembro (vos, el fin, un subagente).
  final int colorIndex;

  final int column;

  /// 0 es la fila principal; 1 es el carril de abajo, el de los subagentes.
  final int lane;

  /// Orden dentro del carril, para que dos subagentes del mismo padre no se
  /// dibujen encima.
  final int laneSlot;

  final int? stepIndex;
  final String stepTitle;

  final MapNodeState state;

  /// La primera frase de lo que escribió. No es un resumen generado: pedirle
  /// al modelo que se resuma cuesta otro turno y puede mentir.
  final String resolved;

  final String reasoning;
  final AgentToolActivity? activity;
  final Duration elapsed;
  final double costUsd;

  /// Cuántas idas y vueltas hacia atrás tocaron a este nodo. Los cuadros
  /// cerrados no se dibujan: se cuentan.
  final int backCalls;

  /// Cuántos subagentes abrió, contando los que no entran en el carril.
  final int subagentCount;

  /// Los que quedaron afuera del dibujo, para la píldora que los abre.
  final int hiddenSubagents;

  /// El subagente detrás de este nodo, cuando [kind] es [MapNodeKind.subagent].
  final SessionSubagent? subagent;

  const MapNode({
    required this.id,
    required this.kind,
    required this.label,
    required this.column,
    this.lane = 0,
    this.laneSlot = 0,
    this.profileId,
    this.colorIndex = -1,
    this.stepIndex,
    this.stepTitle = '',
    this.state = MapNodeState.idle,
    this.resolved = '',
    this.reasoning = '',
    this.activity,
    this.elapsed = Duration.zero,
    this.costUsd = 0,
    this.backCalls = 0,
    this.subagentCount = 0,
    this.hiddenSubagents = 0,
    this.subagent,
  });

  bool get isLive => switch (state) {
    MapNodeState.thinking ||
    MapNodeState.working ||
    MapNodeState.writing ||
    MapNodeState.replying ||
    MapNodeState.waiting => true,
    _ => false,
  };

  /// La fase equivalente del turno, para reusar los mismos indicadores
  /// animados que ya muestra el chat en vez de dibujar otros.
  TurnPhase? get phase => switch (state) {
    MapNodeState.thinking || MapNodeState.replying => TurnPhase.thinking,
    MapNodeState.working => TurnPhase.working,
    MapNodeState.writing => TurnPhase.writing,
    _ => null,
  };
}

class MapEdge {
  final String fromId;
  final String toId;
  final MapEdgeKind kind;

  /// Qué se pidió, cuando la línea es una réplica hacia atrás. Vacío en el
  /// resto: una flecha de avance no necesita texto.
  final String label;

  /// Si algo está viajando por acá AHORA. Solo entonces la línea se mueve:
  /// cuando llega se apaga, y el que se mueve pasa a ser el nodo.
  final bool live;

  const MapEdge({
    required this.fromId,
    required this.toId,
    required this.kind,
    this.label = '',
    this.live = false,
  });
}

/// La sesión vista como un recorrido, con carriles fijos: arriba vuelve, al
/// medio avanza, abajo se delega.
///
/// Las columnas son PASOS, no agentes: un workflow puede darle cuatro pasos
/// al mismo miembro, y colapsarlos en un solo cuadro convierte una línea
/// recta en un nudo de flechas que vuelven sobre sí mismas.
class SessionMap {
  final List<MapNode> nodes;
  final List<MapEdge> edges;

  const SessionMap({required this.nodes, required this.edges});

  bool get isEmpty => nodes.length <= 2;

  int get columns =>
      nodes.fold(0, (best, node) => node.column > best ? node.column : best) +
      1;

  int get laneSlots => nodes
      .where((node) => node.lane > 0)
      .fold(0, (best, node) => node.laneSlot > best ? node.laneSlot : best);

  MapNode? nodeById(String id) {
    for (final node in nodes) {
      if (node.id == id) return node;
    }
    return null;
  }

  factory SessionMap.from({
    required Session? session,
    required List<AgentProfile> members,
    required Workflow? workflow,
    Set<String> expandedParents = const {},
  }) {
    final messages = session?.messages ?? const <ChatMessage>[];
    final subagents = session?.subagents ?? const <SessionSubagent>[];
    final live = session?.isRunning == true ? session?.liveTurn : null;
    final waiting = session?.pendingPermission != null;

    final colorOf = <String, int>{
      for (var index = 0; index < members.length; index++)
        members[index].id: index,
    };

    final posts = _postsOf(
      messages: messages,
      members: members,
      workflow: workflow,
    );
    final firstPostOf = <String, String>{};
    for (final post in posts) {
      firstPostOf.putIfAbsent(post.profileId, () => post.id);
    }

    final nodes = <MapNode>[
      const MapNode(id: 'you', kind: MapNodeKind.you, label: 'vos', column: 0),
    ];
    final edges = <MapEdge>[];

    // ── la fila principal ────────────────────────────────────────────────
    var previousId = 'you';
    for (var index = 0; index < posts.length; index++) {
      final post = posts[index];
      final isFirstPost = firstPostOf[post.profileId] == post.id;
      final own = [
        for (final message in messages)
          if (_belongsTo(message, post, isFirstPost: isFirstPost)) message,
      ];
      final isCurrent =
          live != null &&
          live.profileId == post.profileId &&
          _isCurrentPost(post, session, posts, live);

      final backCalls = own
          .where((message) => message.consultOfProfileId != null)
          .length;
      final mine = [
        for (final subagent in subagents)
          if (subagent.parentProfileId == post.profileId &&
              subagent.parentStepIndex == post.stepIndex)
            subagent,
      ];

      final drawn = expandedParents.contains(post.id)
          ? mine.length
          : (mine.length > kSubagentsDrawn ? kSubagentsDrawn : mine.length);

      nodes.add(
        MapNode(
          id: post.id,
          kind: post.kind,
          label: post.label,
          column: index + 1,
          profileId: post.profileId,
          colorIndex: colorOf[post.profileId] ?? -1,
          stepIndex: post.stepIndex,
          stepTitle: post.stepTitle,
          state: _stateOf(
            own: own,
            live: isCurrent ? live : null,
            waiting: waiting && isCurrent,
          ),
          resolved: own.isEmpty ? '' : firstSentenceOf(own.last.text),
          reasoning: own.isEmpty ? '' : (own.last.reasoning ?? ''),
          activity: isCurrent ? live.activity : null,
          elapsed: Duration(
            milliseconds: own.fold(
              0,
              (total, message) => total + (message.durationMs ?? 0),
            ),
          ),
          costUsd: own.fold(
            0.0,
            (total, message) => total + (message.costUsd ?? 0),
          ),
          backCalls: backCalls,
          subagentCount: mine.length,
          hiddenSubagents: mine.length - drawn,
        ),
      );

      edges.add(
        MapEdge(
          fromId: previousId,
          toId: post.id,
          kind: own.isEmpty ? MapEdgeKind.untraveled : MapEdgeKind.forward,
          live: isCurrent && own.isEmpty,
        ),
      );
      previousId = post.id;

      // ── el carril de abajo ─────────────────────────────────────────────
      for (var slot = 0; slot < drawn; slot++) {
        final subagent = mine[slot];
        nodes.add(
          MapNode(
            id: 'sub:${subagent.id}',
            kind: MapNodeKind.subagent,
            label: subagent.agentType,
            column: index + 1,
            lane: 1,
            laneSlot: slot,
            profileId: post.profileId,
            state: _subagentStateOf(subagent),
            resolved: subagent.phase == SubagentPhase.done
                ? firstSentenceOf(subagent.result)
                : '',
            reasoning: subagent.reasoning,
            activity: subagent.activity,
            elapsed: subagent.elapsed,
            subagent: subagent,
          ),
        );
        edges.add(
          MapEdge(
            fromId: post.id,
            toId: 'sub:${subagent.id}',
            kind: subagent.isRunning
                ? MapEdgeKind.delegate
                : MapEdgeKind.delegateBack,
            label: subagent.ask,
            live: subagent.isRunning,
          ),
        );
      }
    }

    // ── el final ─────────────────────────────────────────────────────────
    final finished = session?.status == SessionStatus.finished;
    final failed = session?.status == SessionStatus.failed;
    nodes.add(
      MapNode(
        id: 'end',
        kind: MapNodeKind.end,
        label: 'fin',
        column: posts.length + 1,
        state: switch (session?.status) {
          SessionStatus.finished => MapNodeState.done,
          SessionStatus.failed => MapNodeState.failed,
          _ => MapNodeState.idle,
        },
      ),
    );
    edges.add(
      MapEdge(
        fromId: previousId,
        toId: 'end',
        kind: switch ((finished, failed)) {
          (true, _) => MapEdgeKind.finish,
          (_, true) => MapEdgeKind.failed,
          _ => MapEdgeKind.untraveled,
        },
      ),
    );

    edges.addAll(_backEdges(messages: messages, posts: posts, live: live));
    edges.addAll(_spawnEdges(members: members, posts: posts));

    return SessionMap(nodes: nodes, edges: edges);
  }
}

/// Un lugar donde pasa trabajo: un paso del workflow, o un miembro que habló
/// fuera de todo paso.
class _Post {
  final String id;
  final MapNodeKind kind;
  final String label;
  final String profileId;
  final int? stepIndex;
  final String stepTitle;

  const _Post({
    required this.id,
    required this.kind,
    required this.label,
    required this.profileId,
    required this.stepIndex,
    this.stepTitle = '',
  });
}

/// Si este mensaje cuelga de este nodo.
///
/// [isFirstPost] importa por las respuestas a consultas: llevan el paso del
/// que PREGUNTÓ, no el del que contestó, así que se cuelgan del primer nodo
/// del que contestó y no de un paso ajeno —ni de los cuatro que ese miembro
/// tenga en el workflow.
bool _belongsTo(ChatMessage message, _Post post, {required bool isFirstPost}) {
  if (message.role != ChatRole.assistant) return false;
  if (message.authorProfileId != post.profileId) return false;
  if (message.consultOfProfileId != null) return isFirstPost;
  return message.stepIndex == post.stepIndex;
}

/// Las columnas, en orden. Con workflow son sus pasos; sin workflow, los
/// miembros en el orden en que aparecen. Los que hablaron sin paso se cuelgan
/// al final, antes del fin.
List<_Post> _postsOf({
  required List<ChatMessage> messages,
  required List<AgentProfile> members,
  required Workflow? workflow,
}) {
  final posts = <_Post>[];
  final placed = <String>{};

  final steps = workflow?.steps ?? const <WorkflowStep>[];
  for (var index = 0; index < steps.length; index++) {
    final owner = memberForRole(members, steps[index].role);
    if (owner == null) continue;
    posts.add(
      _Post(
        id: 'step:$index',
        kind: MapNodeKind.step,
        label: owner.name,
        profileId: owner.id,
        stepIndex: index,
        stepTitle: steps[index].title,
      ),
    );
    placed.add(owner.id);
  }

  // Sin workflow no hay columnas prestadas: el elenco se ordena por quién
  // habló primero, y los que todavía no hablaron van detrás, en reposo.
  final spoke = <String>[];
  for (final message in messages) {
    final author = message.authorProfileId;
    if (message.role != ChatRole.assistant || author == null) continue;
    if (!spoke.contains(author)) spoke.add(author);
  }

  for (final id in [
    ...spoke,
    if (workflow == null)
      for (final member in members) member.id,
  ]) {
    if (placed.contains(id)) continue;
    final member = members.where((entry) => entry.id == id).firstOrNull;
    if (member == null) continue;
    placed.add(id);
    posts.add(
      _Post(
        id: 'free:$id',
        kind: MapNodeKind.free,
        label: member.name,
        profileId: id,
        stepIndex: null,
      ),
    );
  }

  return posts;
}

bool _isCurrentPost(
  _Post post,
  Session? session,
  List<_Post> posts,
  SessionLiveTurn live,
) {
  // Un turno de consulta no está parado en el paso en curso: está parado
  // donde vive el que contesta.
  if (live.consultOfProfileId != null) {
    final first = posts.firstWhere(
      (entry) => entry.profileId == live.profileId,
      orElse: () => post,
    );
    return first.id == post.id;
  }
  if (post.stepIndex == null) {
    return posts.every(
      (entry) => entry.profileId != post.profileId || entry.stepIndex == null,
    );
  }
  return post.stepIndex == session?.currentStepIndex;
}

MapNodeState _stateOf({
  required List<ChatMessage> own,
  required SessionLiveTurn? live,
  required bool waiting,
}) {
  if (waiting) return MapNodeState.waiting;
  if (live != null) {
    if (live.consultOfProfileId != null) return MapNodeState.replying;
    return switch (live.phase) {
      TurnPhase.thinking => MapNodeState.thinking,
      TurnPhase.working => MapNodeState.working,
      TurnPhase.writing => MapNodeState.writing,
    };
  }
  if (own.isEmpty) return MapNodeState.idle;
  return MapNodeState.done;
}

MapNodeState _subagentStateOf(SessionSubagent subagent) =>
    switch (subagent.phase) {
      SubagentPhase.thinking => MapNodeState.thinking,
      SubagentPhase.working => MapNodeState.working,
      SubagentPhase.writing => MapNodeState.writing,
      SubagentPhase.done => MapNodeState.done,
      SubagentPhase.failed => MapNodeState.failed,
    };

/// Las réplicas hacia atrás y sus respuestas.
///
/// En el lienzo hay como mucho UN par vivo entre dos nodos: las cerradas se
/// cuentan en el pie del nodo, no se dibujan. Sin esa regla una sesión larga
/// termina siendo una pared de globos, que es justamente de lo que el mapa
/// tenía que sacarnos.
List<MapEdge> _backEdges({
  required List<ChatMessage> messages,
  required List<_Post> posts,
  required SessionLiveTurn? live,
}) {
  String? postIdOf(String profileId) =>
      posts.where((post) => post.profileId == profileId).firstOrNull?.id;

  final edges = <MapEdge>[];
  final seen = <String>{};

  for (var index = 0; index < messages.length; index++) {
    final message = messages[index];
    final asker = message.consultOfProfileId;
    final answerer = message.authorProfileId;
    if (asker == null || answerer == null) continue;

    final from = postIdOf(asker);
    final to = postIdOf(answerer);
    if (from == null || to == null || from == to) continue;
    if (!seen.add('$from>$to')) continue;

    edges.add(
      MapEdge(
        fromId: from,
        toId: to,
        kind: MapEdgeKind.back,
        label: _askedIn(messages.take(index), asker),
      ),
    );
    edges.add(MapEdge(fromId: to, toId: from, kind: MapEdgeKind.answer));
  }

  // La consulta en vuelo: todavía no hay mensaje que la cuente, y es
  // justamente el momento en el que uno quiere verla.
  final asker = live?.consultOfProfileId;
  if (asker != null) {
    final from = postIdOf(asker);
    final to = postIdOf(live!.profileId);
    if (from != null && to != null && from != to) {
      edges.removeWhere(
        (edge) => edge.fromId == from && edge.toId == to && !edge.live,
      );
      edges.add(
        MapEdge(
          fromId: from,
          toId: to,
          kind: MapEdgeKind.back,
          label: _askedIn(messages, asker),
          live: true,
        ),
      );
    }
  }
  return edges;
}

/// Qué le preguntó. Es la frase donde el que preguntó nombró al otro, que es
/// literalmente lo que disparó el turno.
String _askedIn(Iterable<ChatMessage> before, String askerId) {
  for (final message in before.toList().reversed) {
    if (message.authorProfileId != askerId) continue;
    if (message.consultOfProfileId != null) continue;
    final sentence = _sentenceWithMention(message.text);
    if (sentence.isNotEmpty) return sentence;
  }
  return '';
}

final RegExp _mentionSentence = RegExp(r'[^.!?\n]*@[a-z0-9_-]+[^.!?\n]*[.!?]?');

String _sentenceWithMention(String text) {
  final match = _mentionSentence.firstMatch(text);
  if (match == null) return '';
  return firstSentenceOf(match.group(0) ?? '');
}

/// Quién registró a quién. No es un salto: es una relación de elenco, se ve
/// desde que abrís el mapa y nunca se anima.
List<MapEdge> _spawnEdges({
  required List<AgentProfile> members,
  required List<_Post> posts,
}) {
  String? postIdOf(String profileId) =>
      posts.where((post) => post.profileId == profileId).firstOrNull?.id;

  return [
    for (final member in members)
      if (member.createdByProfileId case final creator?)
        if (postIdOf(creator) case final from?)
          if (postIdOf(member.id) case final to?)
            if (from != to)
              MapEdge(fromId: from, toId: to, kind: MapEdgeKind.spawn),
  ];
}
