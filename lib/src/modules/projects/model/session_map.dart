import 'package:keel_ui/src/core/services/claude_stream_events.dart';
import 'package:keel_ui/src/modules/agent_profiles/model/agent_profile.dart';
import 'package:keel_ui/src/modules/agents/model/agent_tool_activity.dart';
import 'package:keel_ui/src/modules/agents/model/chat_message.dart';
import 'package:keel_ui/src/modules/projects/model/session.dart';
import 'package:keel_ui/src/modules/projects/model/session_live_turn.dart';
import 'package:keel_ui/src/modules/projects/model/session_subagent.dart';
import 'package:keel_ui/src/modules/projects/model/work_node.dart';
import 'package:keel_ui/src/modules/workflows/model/workflow.dart';

/// Cuántos subagentes se dibujan por padre antes de agruparlos.
///
/// Es un tope de DIBUJO y nada más: no limita cuántos puede abrir un agente
/// ni cambia lo que corre. Un padre que largó doce llenaría el carril y
/// taparía a los demás; los que no entran se cuentan en una píldora que se
/// abre.
const kSubagentsDrawn = kMaxSubagentsPerNode;

enum MapNodeKind { you, work, free, consultation, subagent, end }

/// Los nueve estados de un nodo. Es el mismo cuadro cambiando de estado: nada
/// se apila, nada se acumula.
///
/// `receiving` es el instante del viaje: el paquete está llegando y el nodo
/// todavía no lo procesa. Dura lo que dura la línea en vuelo; después salta a
/// pensar, trabajar o escribir.
enum MapNodeState {
  idle,
  receiving,
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
  /// Una dependencia del grafo quedó satisfecha.
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

/// Una ida y vuelta cerrada: qué le pidieron a este nodo y qué contestó.
///
/// El mapa dibuja como mucho UN cuadro por par, y solo mientras está viva.
/// Las cerradas se cuentan —diez consultas son una píldora que dice 10, no
/// diez cuadros encimados— pero el texto tiene que seguir estando en algún
/// lado, porque «qué se preguntaron» es exactamente lo que uno viene a
/// buscar cuando abre el mapa de una sesión que ya terminó. Vive acá y se
/// lee en el panel del nodo, que es lo que abre esa píldora.
class MapConsult {
  const MapConsult({
    required this.askedBy,
    required this.ask,
    required this.answer,
  });

  /// El handle del que preguntó, para el encabezado del cuadro.
  final String askedBy;

  /// La frase donde nombró al otro: literalmente lo que disparó el turno.
  final String ask;

  final String answer;
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

  /// 0 es el tronco principal; 1..N son la profundidad del árbol local.
  final int lane;

  /// Orden vertical dentro del árbol de su WorkNode.
  final int laneSlot;

  /// Nodo del que nace esta rama. Solo es null en el tronco principal.
  ///
  /// Una consulta pertenece al [WorkNode] que la pidió, aunque el perfil
  /// consultado tenga además otro nodo principal. Un subagente pertenece al
  /// turno que lo abrió: puede ser un nodo principal o una consulta.
  final String? parentId;

  final String? workNodeId;
  final String nodeTitle;

  /// El encargo persistido del nodo. El título es solo su nombre visible.
  final String nodeInstruction;

  final MapNodeState state;

  /// La primera frase de lo que escribió. No es un resumen generado: pedirle
  /// al modelo que se resuma cuesta otro turno y puede mentir.
  ///
  /// Es lo que entra en el cuadro del lienzo, donde hay ciento y pico de
  /// puntos de ancho. Para leerlo entero está [said].
  final String resolved;

  /// Todo lo que escribió, tal cual, con su markdown.
  ///
  /// [resolved] es esto aplanado y cortado en la primera frase: sirve para el
  /// cuadro y para nada más. Adentro de la ficha no hay límite de ancho, y
  /// mostrar ahí el recorte es esconder lo que la ficha existe para mostrar.
  final String said;

  /// Si lo único que dijo fue contestar una consulta. Un miembro puede
  /// contestar desde un paso que todavía no le tocó, y decir «resolvió» ahí
  /// sería decir que ese paso ya pasó.
  final bool answeredOnly;

  final String reasoning;
  final AgentToolActivity? activity;
  final Duration elapsed;
  final double costUsd;

  /// Las idas y vueltas hacia atrás que tocaron a este nodo, en orden. Los
  /// cuadros cerrados no se dibujan en el lienzo: se cuentan, y el texto se
  /// lee entrando al nodo.
  final List<MapConsult> consults;

  /// Cuántas fueron. Es [consults] contado, no un campo aparte que se pueda
  /// desincronizar del otro.
  int get backCalls => consults.length;

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
    this.parentId,
    this.profileId,
    this.colorIndex = -1,
    this.workNodeId,
    this.nodeTitle = '',
    this.nodeInstruction = '',
    this.state = MapNodeState.idle,
    this.resolved = '',
    this.said = '',
    this.answeredOnly = false,
    this.reasoning = '',
    this.activity,
    this.elapsed = Duration.zero,
    this.costUsd = 0,
    this.consults = const [],
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

/// La sesión vista como un recorrido: el `ResolutionCase` forma el tronco y
/// cada WorkNode tiene debajo su árbol de consultas y delegaciones.
///
/// Las columnas representan la profundidad de las dependencias, no agentes ni
/// índices. Dos nodos independientes comparten columna y conservan su grafo.
/// El cuadro punteado de una réplica: qué se preguntaron dos nodos.
///
/// **Uno por par y nunca dos.** Cuando el mismo par vuelve a hablar, este
/// cuadro se reescribe —no aparece otro debajo—, que es la regla que evita
/// que una sesión de cuarenta mensajes termine siendo una pared de globos.
///
/// Y se queda cuando la ida y vuelta cierra, apagado y mostrando la
/// RESPUESTA. El dibujo aprobado lo hacía desaparecer, dejando el arco tenue
/// y un contador; con la sesión terminada eso deja el mapa sin decir nunca
/// qué se preguntaron, que es justo lo que uno viene a buscar. El contador
/// sigue estando para las que quedaron atrás.
class MapCallout {
  const MapCallout({
    required this.fromId,
    required this.toId,
    required this.title,
    required this.text,
    required this.live,
  });

  /// Quién habla en el cuadro y a quién. Con la consulta en vuelo es el que
  /// preguntó; cerrada, el que contestó.
  final String fromId;
  final String toId;

  /// `rn-expert → arquitecto`, ya armado.
  final String title;

  final String text;

  /// Si todavía se está esperando la respuesta.
  final bool live;

  /// El nodo que se queda con esta ida y vuelta anotada.
  ///
  /// Es siempre el que CONTESTA, que es donde vive la lista de consultas: con
  /// la consulta cerrada ya habla él ([fromId]), y en vuelo todavía habla el
  /// que preguntó, así que el que va a contestar es el otro. Tocar el cuadro
  /// abre su ficha, y ahí está el intercambio entero.
  String get answererId => live ? toId : fromId;

  /// La clave del PAR, sin dirección: la ida y la vuelta comparten cuadro.
  String get pairId {
    final ends = [fromId, toId]..sort();
    return ends.join('>');
  }
}

class SessionMap {
  final List<MapNode> nodes;
  final List<MapEdge> edges;

  /// Los cuadros de réplica, uno por par que se haya hablado.
  final List<MapCallout> callouts;

  const SessionMap({
    required this.nodes,
    required this.edges,
    this.callouts = const [],
  });

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
    final handleOf = <String, String>{
      for (final member in members) member.id: member.name,
    };

    final posts = _postsOf(
      messages: messages,
      members: members,
      session: session,
      workflow: workflow,
    );
    final firstPostOf = <String, String>{};
    for (final post in posts) {
      firstPostOf.putIfAbsent(post.profileId, () => post.id);
    }

    final workById = {
      for (final node in session?.resolutionCase?.nodes ?? const <WorkNode>[])
        node.id: node,
    };
    final workDepth = <String, int>{};
    int depthOf(String id, [Set<String>? visiting]) {
      final cached = workDepth[id];
      if (cached != null) return cached;
      final work = workById[id];
      final seen = {...?visiting};
      if (work == null || !seen.add(id)) return 0;
      var depth = 0;
      for (final dependencyId in work.dependencyIds) {
        final dependencyDepth = depthOf(dependencyId, seen);
        if (dependencyDepth > depth) depth = dependencyDepth;
      }
      return workDepth[id] = depth + 1;
    }

    final nodes = <MapNode>[
      const MapNode(id: 'you', kind: MapNodeKind.you, label: 'vos', column: 0),
    ];
    final edges = <MapEdge>[];
    final postByWorkNodeId = <String, _Post>{
      for (final post in posts)
        if (post.workNodeId != null) post.workNodeId!: post,
    };

    // ── resolución de colisiones de columna ──────────────────────────────
    // `depthOf` da la profundidad en el DAG, no un carril: dos capacidades
    // paralelas (ninguna depende de la otra) comparten esa profundidad y
    // caerían en la misma columna, dibujadas superpuestas en el tronco. Esta
    // segunda pasada, en el orden temporal de `posts`, corre cada nodo a la
    // siguiente columna libre. La secuencia lineal —el caso del mockup— queda
    // exactamente igual, porque cada nodo ya ocupa una columna distinta.
    final columnOf = <String, int>{};
    final usedColumns = <int>{0}; // 'you' ocupa la columna 0.
    for (var index = 0; index < posts.length; index++) {
      final post = posts[index];
      var column = post.workNodeId == null
          ? index + 1
          : depthOf(post.workNodeId!);
      while (usedColumns.contains(column)) {
        column++;
      }
      usedColumns.add(column);
      columnOf[post.id] = column;
    }

    // ── los nodos de trabajo ─────────────────────────────────────────────
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

      // Cada mensaje de este nodo que contesta una consulta ES una ida y
      // vuelta: el pedido se busca hacia atrás, en el último turno del que
      // preguntó donde lo nombró.
      final consults = [
        for (final message in own)
          if (message.consultOfProfileId case final askerId?)
            MapConsult(
              askedBy: handleOf[askerId] ?? askerId,
              ask: _askedIn(
                messages.take(messages.indexOf(message)),
                askerId,
                targetHandle: handleOf[message.authorProfileId],
              ),
              answer: message.text.trim(),
            ),
      ];
      final mine = [
        for (final subagent in subagents)
          if (subagent.parentProfileId == post.profileId &&
              subagent.parentWorkNodeId == post.workNodeId)
            subagent,
      ];

      final drawn = expandedParents.contains(post.id)
          ? mine.length
          : (mine.length > kSubagentsDrawn ? kSubagentsDrawn : mine.length);

      // Contestar una consulta no satisface una dependencia ni completa el
      // nodo. Por eso se distingue de trabajo efectivo del nodo.
      final tookTheStep = own.any(
        (message) => message.consultOfProfileId == null,
      );

      nodes.add(
        MapNode(
          id: post.id,
          kind: post.kind,
          label: post.label,
          column: columnOf[post.id]!,
          profileId: post.profileId,
          colorIndex: colorOf[post.profileId] ?? -1,
          workNodeId: post.workNodeId,
          nodeTitle: post.nodeTitle,
          nodeInstruction: post.instruction,
          state: _stateOf(
            own: own,
            live: isCurrent ? live : null,
            waiting: waiting && isCurrent,
            receiving: isCurrent && !tookTheStep,
          ),
          resolved: own.isEmpty ? '' : firstSentenceOf(own.last.text),
          said: own.isEmpty ? '' : own.last.text.trim(),
          answeredOnly: own.isNotEmpty && !tookTheStep,
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
          consults: consults,
          subagentCount: mine.length,
          hiddenSubagents: mine.length - drawn,
        ),
      );

      final dependencies = post.workNodeId == null
          ? const <String>[]
          : workById[post.workNodeId]?.dependencyIds ?? const <String>[];
      final relationKind =
          post.workNodeId != null &&
              workById[post.workNodeId]?.status != WorkNodeStatus.pending
          ? MapEdgeKind.forward
          : tookTheStep
          ? MapEdgeKind.forward
          : MapEdgeKind.untraveled;
      if (dependencies.isEmpty) {
        edges.add(
          MapEdge(
            fromId: 'you',
            toId: post.id,
            kind: relationKind,
            live: isCurrent && !tookTheStep,
          ),
        );
      } else {
        for (final dependencyId in dependencies) {
          final dependency = postByWorkNodeId[dependencyId];
          if (dependency == null) continue;
          edges.add(
            MapEdge(
              fromId: dependency.id,
              toId: post.id,
              kind: relationKind,
              live: isCurrent && !tookTheStep,
            ),
          );
        }
      }

      // ── el carril de abajo ─────────────────────────────────────────────
      for (var slot = 0; slot < drawn; slot++) {
        final subagent = mine[slot];
        nodes.add(
          MapNode(
            id: 'sub:${subagent.id}',
            kind: MapNodeKind.subagent,
            label: subagent.agentType,
            column: columnOf[post.id]!,
            lane: 1,
            laneSlot: slot,
            parentId: post.id,
            profileId: post.profileId,
            nodeInstruction: subagent.ask,
            state: _subagentStateOf(subagent),
            resolved: subagent.phase == SubagentPhase.done
                ? firstSentenceOf(subagent.result)
                : '',
            said: subagent.phase == SubagentPhase.done
                ? subagent.result.trim()
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

    // Las consultas no son candidatos del workflow esperando en la fila.
    // Nacen del WorkNode que las pidió y forman, junto con los subagentes que
    // ellas mismas abran, el árbol local de ese trabajo.
    if (workById.isNotEmpty) {
      final branches = _consultationBranches(
        messages: messages,
        members: members,
        session: session,
        posts: posts,
        existingNodes: nodes,
        subagents: subagents,
        expandedParents: expandedParents,
        colorOf: colorOf,
        handleOf: handleOf,
      );
      nodes.addAll(branches.nodes);
      edges.addAll(branches.edges);
    }

    // ── el final ─────────────────────────────────────────────────────────
    final finished = session?.status == SessionStatus.finished;
    final failed = session?.status == SessionStatus.failed;
    nodes.add(
      MapNode(
        id: 'end',
        kind: MapNodeKind.end,
        label: 'fin',
        column:
            nodes.fold(
              0,
              (last, node) => node.column > last ? node.column : last,
            ) +
            1,
        state: switch (session?.status) {
          SessionStatus.finished => MapNodeState.done,
          SessionStatus.failed => MapNodeState.failed,
          _ => MapNodeState.idle,
        },
      ),
    );
    final dependedOn = {
      for (final node in workById.values) ...node.dependencyIds,
    };
    final terminals = postByWorkNodeId.entries
        .where((entry) => !dependedOn.contains(entry.key))
        .map((entry) => entry.value)
        .toList();
    for (final terminal in terminals.isEmpty ? posts : terminals) {
      edges.add(
        MapEdge(
          fromId: terminal.id,
          toId: 'end',
          kind: switch ((finished, failed)) {
            (true, _) => MapEdgeKind.finish,
            (_, true) => MapEdgeKind.failed,
            _ => MapEdgeKind.untraveled,
          },
        ),
      );
    }

    final back = workById.isEmpty
        ? _backEdges(
            messages: messages,
            posts: posts,
            live: live,
            handleOf: handleOf,
          )
        : (edges: const <MapEdge>[], callouts: const <MapCallout>[]);
    edges.addAll(back.edges);
    if (workById.isEmpty) {
      edges.addAll(_spawnEdges(members: members, posts: posts));
    }

    return SessionMap(nodes: nodes, edges: edges, callouts: back.callouts);
  }
}

/// Actividad que cuelga de un nodo principal.
///
/// El `ResolutionCase` define el tronco; este traductor reconstruye sus ramas
/// desde evidencia persistida del hilo. No inventa candidatos a consultar: un
/// perfil aparece únicamente cuando hubo una consulta real o existe una en
/// vuelo.
({List<MapNode> nodes, List<MapEdge> edges}) _consultationBranches({
  required List<ChatMessage> messages,
  required List<AgentProfile> members,
  required Session? session,
  required List<_Post> posts,
  required List<MapNode> existingNodes,
  required List<SessionSubagent> subagents,
  required Set<String> expandedParents,
  required Map<String, int> colorOf,
  required Map<String, String> handleOf,
}) {
  final answersByKey = <String, List<({ChatMessage message, String ask})>>{};
  final askerByKey = <String, String>{};
  final targetByKey = <String, String>{};
  final workByKey = <String, String>{};

  for (var index = 0; index < messages.length; index++) {
    final message = messages[index];
    final asker = message.consultOfProfileId;
    final target = message.authorProfileId;
    final workNodeId = message.workNodeId;
    if (message.role != ChatRole.assistant ||
        asker == null ||
        target == null ||
        workNodeId == null ||
        asker == target) {
      continue;
    }
    final key = _consultationKey(workNodeId, asker, target);
    askerByKey[key] = asker;
    targetByKey[key] = target;
    workByKey[key] = workNodeId;
    answersByKey.putIfAbsent(key, () => []).add((
      message: message,
      ask: _askedIn(
        messages.take(index),
        asker,
        targetHandle: handleOf[target],
      ),
    ));
  }

  String? liveKey;
  final live = session?.isRunning == true ? session?.liveTurn : null;
  final liveAsker = live?.consultOfProfileId;
  if (live != null && liveAsker != null && liveAsker != live.profileId) {
    final workNodeId = _workNodeOfLiveConsult(
      session: session,
      messages: messages,
      askerId: liveAsker,
    );
    if (workNodeId != null) {
      liveKey = _consultationKey(workNodeId, liveAsker, live.profileId);
      askerByKey[liveKey] = liveAsker;
      targetByKey[liveKey] = live.profileId;
      workByKey[liveKey] = workNodeId;
      answersByKey.putIfAbsent(liveKey, () => []);
    }
  }

  final allNodes = <String, MapNode>{
    for (final node in existingNodes) node.id: node,
  };
  final actorAtWork = <String, String>{
    for (final post in posts)
      if (post.workNodeId != null)
        _actorAtWorkKey(post.profileId, post.workNodeId!): post.id,
  };

  String rootIdOf(MapNode node) {
    var current = node;
    final seen = <String>{};
    while (true) {
      final parentId = current.parentId;
      if (parentId == null) break;
      if (!seen.add(parentId)) break;
      final parent = allNodes[parentId];
      if (parent == null) break;
      current = parent;
    }
    return current.id;
  }

  final nextSlotByRoot = <String, int>{};
  for (final node in existingNodes.where((node) => node.lane > 0)) {
    final rootId = rootIdOf(node);
    final next = node.laneSlot + 1;
    if (next > (nextSlotByRoot[rootId] ?? 0)) nextSlotByRoot[rootId] = next;
  }

  int takeSlot(MapNode parent) {
    final rootId = rootIdOf(parent);
    final slot = nextSlotByRoot[rootId] ?? 0;
    nextSlotByRoot[rootId] = slot + 1;
    return slot;
  }

  final nodes = <MapNode>[];
  final edges = <MapEdge>[];
  final drawnSubagents = {
    for (final node in existingNodes)
      if (node.subagent != null) node.subagent!.id,
  };
  final maxSubagentsByParent = <String, int>{};

  for (final entry in answersByKey.entries) {
    final key = entry.key;
    final asker = askerByKey[key]!;
    final target = targetByKey[key]!;
    final workNodeId = workByKey[key]!;
    final parentId = actorAtWork[_actorAtWorkKey(asker, workNodeId)];
    final parent = parentId == null ? null : allNodes[parentId];
    final member = members.where((item) => item.id == target).firstOrNull;
    if (parent == null || member == null) continue;

    final id = 'consult:$workNodeId:$asker:$target';
    final answers = entry.value;
    final latest = answers.lastOrNull;
    final isLive = key == liveKey;
    final ask = isLive
        ? _askedIn(messages, asker, targetHandle: member.name)
        : (latest?.ask ?? '').trim();
    final matchingSubagents = [
      for (final subagent in subagents)
        if (!drawnSubagents.contains(subagent.id) &&
            subagent.parentProfileId == target &&
            subagent.parentWorkNodeId == workNodeId)
          subagent,
    ];
    final drawn = expandedParents.contains(id)
        ? matchingSubagents.length
        : _minInt(matchingSubagents.length, kSubagentsDrawn);
    maxSubagentsByParent[id] = drawn;

    final node = MapNode(
      id: id,
      kind: MapNodeKind.consultation,
      label: member.name,
      column: parent.column,
      lane: parent.lane + 1,
      laneSlot: takeSlot(parent),
      parentId: parent.id,
      profileId: member.id,
      colorIndex: colorOf[member.id] ?? -1,
      workNodeId: workNodeId,
      nodeTitle: parent.nodeTitle,
      nodeInstruction: ask,
      state: isLive ? MapNodeState.replying : MapNodeState.done,
      resolved: latest == null ? '' : firstSentenceOf(latest.message.text),
      said: latest?.message.text.trim() ?? '',
      answeredOnly: true,
      reasoning: isLive
          ? (live?.reasoning ?? '')
          : (latest?.message.reasoning ?? ''),
      activity: isLive ? live?.activity : null,
      elapsed: Duration(
        milliseconds: answers.fold(
          0,
          (total, answer) => total + (answer.message.durationMs ?? 0),
        ),
      ),
      costUsd: answers.fold(
        0.0,
        (total, answer) => total + (answer.message.costUsd ?? 0),
      ),
      consults: [
        for (final answer in answers)
          MapConsult(
            askedBy: handleOf[asker] ?? asker,
            ask: answer.ask,
            answer: answer.message.text.trim(),
          ),
      ],
      subagentCount: matchingSubagents.length,
      hiddenSubagents: matchingSubagents.length - drawn,
    );
    nodes.add(node);
    allNodes[id] = node;
    actorAtWork[_actorAtWorkKey(target, workNodeId)] = id;

    edges.add(
      MapEdge(
        fromId: parent.id,
        toId: id,
        kind: MapEdgeKind.back,
        label: ask,
        live: isLive,
      ),
    );
    if (answers.isNotEmpty) {
      edges.add(MapEdge(fromId: id, toId: parent.id, kind: MapEdgeKind.answer));
    }
  }

  final childIndexByParent = <String, int>{};
  for (final subagent in subagents) {
    if (drawnSubagents.contains(subagent.id)) continue;
    final workNodeId = subagent.parentWorkNodeId;
    if (workNodeId == null) continue;
    final parentId =
        actorAtWork[_actorAtWorkKey(subagent.parentProfileId, workNodeId)];
    final parent = parentId == null ? null : allNodes[parentId];
    if (parent == null) continue;
    final childIndex = childIndexByParent.update(
      parent.id,
      (value) => value + 1,
      ifAbsent: () => 0,
    );
    final maximum = maxSubagentsByParent[parent.id] ?? kSubagentsDrawn;
    if (childIndex >= maximum) continue;

    final node = MapNode(
      id: 'sub:${subagent.id}',
      kind: MapNodeKind.subagent,
      label: subagent.agentType,
      column: parent.column,
      lane: parent.lane + 1,
      laneSlot: takeSlot(parent),
      parentId: parent.id,
      profileId: subagent.parentProfileId,
      nodeInstruction: subagent.ask,
      state: _subagentStateOf(subagent),
      resolved: subagent.phase == SubagentPhase.done
          ? firstSentenceOf(subagent.result)
          : '',
      said: subagent.phase == SubagentPhase.done ? subagent.result.trim() : '',
      reasoning: subagent.reasoning,
      activity: subagent.activity,
      elapsed: subagent.elapsed,
      subagent: subagent,
    );
    nodes.add(node);
    allNodes[node.id] = node;
    edges.add(
      MapEdge(
        fromId: parent.id,
        toId: node.id,
        kind: subagent.isRunning
            ? MapEdgeKind.delegate
            : MapEdgeKind.delegateBack,
        label: subagent.ask,
        live: subagent.isRunning,
      ),
    );
  }

  return (nodes: nodes, edges: edges);
}

String _consultationKey(String workNodeId, String askerId, String targetId) =>
    '$workNodeId\u0000$askerId\u0000$targetId';

String _actorAtWorkKey(String profileId, String workNodeId) =>
    '$profileId\u0000$workNodeId';

String? _workNodeOfLiveConsult({
  required Session? session,
  required List<ChatMessage> messages,
  required String askerId,
}) {
  for (final message in messages.reversed) {
    if (message.authorProfileId == askerId &&
        message.consultOfProfileId == null &&
        message.workNodeId != null) {
      return message.workNodeId;
    }
  }
  return session?.resolutionCase?.nodes
      .where((node) => node.status == WorkNodeStatus.running)
      .firstOrNull
      ?.id;
}

int _minInt(int left, int right) => left < right ? left : right;

/// Un lugar donde pasa trabajo: un nodo de resolución o un miembro que habló
/// fuera de un caso.
class _Post {
  final String id;
  final MapNodeKind kind;
  final String label;
  final String profileId;
  final String? workNodeId;
  final String nodeTitle;
  final String instruction;

  const _Post({
    required this.id,
    required this.kind,
    required this.label,
    required this.profileId,
    required this.workNodeId,
    this.nodeTitle = '',
    this.instruction = '',
  });
}

/// Si este mensaje cuelga de este nodo.
///
/// [isFirstPost] importa por las respuestas a consultas: se cuelgan del primer
/// nodo del que contestó y no del nodo del que preguntó.
bool _belongsTo(ChatMessage message, _Post post, {required bool isFirstPost}) {
  if (message.role != ChatRole.assistant) return false;
  if (message.authorProfileId != post.profileId) return false;
  // En una sesión sin caso el perfil libre sigue siendo su único nodo. Con
  // un caso, las respuestas consultadas viven en una rama propia del nodo que
  // hizo la pregunta; sumarlas al primer trabajo del consultado es lo que
  // falseaba el tronco y su estado.
  if (message.consultOfProfileId != null) {
    return post.kind == MapNodeKind.free && isFirstPost;
  }
  return message.workNodeId == post.workNodeId;
}

/// Los nodos del caso se ordenan visualmente por dependencias. Fuera de un
/// caso, los miembros se agregan detrás según su primera intervención.
List<_Post> _postsOf({
  required List<ChatMessage> messages,
  required List<AgentProfile> members,
  required Session? session,
  required Workflow? workflow,
}) {
  final posts = <_Post>[];
  final placed = <String>{};

  final work = session?.resolutionCase?.nodes ?? const <WorkNode>[];
  for (var index = 0; index < work.length; index++) {
    final persistedOwner = work[index].ownerProfileId.isEmpty
        ? null
        : members
              .where((member) => member.id == work[index].ownerProfileId)
              .firstOrNull;
    final owner =
        persistedOwner ??
        memberForRole(members, work[index].ownerRole) ??
        members.firstOrNull;
    if (owner == null) continue;
    posts.add(
      _Post(
        id: 'node:${work[index].id}',
        kind: MapNodeKind.work,
        label: owner.name,
        profileId: owner.id,
        workNodeId: work[index].id,
        nodeTitle: work[index].title.isEmpty
            ? work[index].kind.name
            : work[index].title,
        instruction: work[index].instruction,
      ),
    );
    placed.add(owner.id);
  }

  // Un caso activo ya tiene su elenco de ejecución en los WorkNode. Los
  // demás miembros son posibilidades de consulta, no etapas del workflow:
  // aparecen recién cuando un nodo los llama, como ramas de ese nodo.
  if (work.isNotEmpty) return posts;

  // Fuera de un caso, el elenco se ordena por quién habló primero; quien no
  // habló todavía queda detrás, en reposo.
  final spoke = <String>[];
  for (final message in messages) {
    final author = message.authorProfileId;
    if (message.role != ChatRole.assistant || author == null) continue;
    if (!spoke.contains(author)) spoke.add(author);
  }

  for (final id in [...spoke, for (final member in members) member.id]) {
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
        workNodeId: null,
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
  // Un turno de consulta no pertenece al nodo activo: vive donde contesta.
  if (live.consultOfProfileId != null) {
    if (post.kind != MapNodeKind.free) return false;
    final first = posts.firstWhere(
      (entry) => entry.profileId == live.profileId,
      orElse: () => post,
    );
    return first.id == post.id;
  }
  if (post.workNodeId == null) {
    return posts.every(
      (entry) => entry.profileId != post.profileId || entry.workNodeId == null,
    );
  }
  final runningNodeId = session?.resolutionCase?.nodes
      .where((node) => node.status == WorkNodeStatus.running)
      .firstOrNull
      ?.id;
  return post.workNodeId == runningNodeId;
}

MapNodeState _stateOf({
  required List<ChatMessage> own,
  required SessionLiveTurn? live,
  required bool waiting,
  required bool receiving,
}) {
  if (waiting) return MapNodeState.waiting;
  if (live != null) {
    if (receiving) return MapNodeState.receiving;
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

/// Las réplicas hacia atrás, sus respuestas, y el cuadro de cada par.
///
/// En el lienzo hay como mucho UN cuadro por par de nodos: cuando el mismo
/// par vuelve a hablar se reescribe. Sin esa regla una sesión larga termina
/// siendo una pared de globos, que es justamente de lo que el mapa tenía que
/// sacarnos.
({List<MapEdge> edges, List<MapCallout> callouts}) _backEdges({
  required List<ChatMessage> messages,
  required List<_Post> posts,
  required SessionLiveTurn? live,
  required Map<String, String> handleOf,
}) {
  String? postIdOf(String profileId) =>
      posts.where((post) => post.profileId == profileId).firstOrNull?.id;

  final edges = <MapEdge>[];
  final seen = <String>{};

  /// El último intercambio de cada par, en el orden en que apareció el par.
  final callouts = <String, MapCallout>{};

  for (var index = 0; index < messages.length; index++) {
    final message = messages[index];
    final asker = message.consultOfProfileId;
    final answerer = message.authorProfileId;
    if (asker == null || answerer == null) continue;

    final from = postIdOf(asker);
    final to = postIdOf(answerer);
    if (from == null || to == null || from == to) continue;

    if (seen.add('$from>$to')) {
      edges.add(
        MapEdge(
          fromId: from,
          toId: to,
          kind: MapEdgeKind.back,
          label: _askedIn(
            messages.take(index),
            asker,
            targetHandle: handleOf[answerer],
          ),
        ),
      );
      edges.add(MapEdge(fromId: to, toId: from, kind: MapEdgeKind.answer));
    }

    // Se pisa a propósito: el cuadro muestra la ÚLTIMA ida y vuelta del par.
    final closed = MapCallout(
      fromId: to,
      toId: from,
      title: '${handleOf[answerer] ?? answerer} → ${handleOf[asker] ?? asker}',
      text: firstSentenceOf(message.text.trim(), maxLength: 150),
      live: false,
    );
    callouts[closed.pairId] = closed;
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
      final ask = _askedIn(
        messages,
        asker,
        targetHandle: handleOf[live.profileId],
      );
      edges.add(
        MapEdge(
          fromId: from,
          toId: to,
          kind: MapEdgeKind.back,
          label: ask,
          live: true,
        ),
      );
      final open = MapCallout(
        fromId: from,
        toId: to,
        title:
            '${handleOf[asker] ?? asker} → '
            '${handleOf[live.profileId] ?? live.profileId}',
        text: ask,
        live: true,
      );
      // La que está pasando gana sobre la cerrada del mismo par: un cuadro
      // por par, y el de ahora manda.
      callouts[open.pairId] = open;
    }
  }

  return (
    edges: edges,
    callouts: callouts.values.where((c) => c.text.isNotEmpty).toList(),
  );
}

/// Qué le preguntó. Es la frase donde el que preguntó nombró al otro, que es
/// literalmente lo que disparó el turno.
String _askedIn(
  Iterable<ChatMessage> before,
  String askerId, {
  String? targetHandle,
}) {
  for (final message in before.toList().reversed) {
    if (message.authorProfileId != askerId) continue;
    // Sin destino explícito se conserva la semántica del modo libre: una
    // respuesta no se interpreta como consulta nueva. En el árbol conocemos
    // el destino y sí debemos aceptar una consulta encadenada desde esa
    // respuesta, buscando exactamente su @handle.
    if (targetHandle == null && message.consultOfProfileId != null) continue;
    final sentence = _sentenceWithMention(
      message.text,
      targetHandle: targetHandle,
    );
    if (sentence.isNotEmpty) return sentence;
  }
  return '';
}

final RegExp _mentionSentence = RegExp(r'[^.!?\n]*@[a-z0-9_-]+[^.!?\n]*[.!?]?');

String _sentenceWithMention(String text, {String? targetHandle}) {
  for (final match in _mentionSentence.allMatches(text)) {
    final sentence = match.group(0) ?? '';
    if (targetHandle != null &&
        !RegExp(
          '@${RegExp.escape(targetHandle)}(?=\$|[^a-z0-9_-])',
          caseSensitive: false,
        ).hasMatch(sentence)) {
      continue;
    }
    return firstSentenceOf(sentence);
  }
  return '';
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
