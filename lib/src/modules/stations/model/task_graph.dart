import 'package:keel_ui/src/modules/agent_profiles/model/agent_profile.dart';
import 'package:keel_ui/src/modules/agents/model/chat_message.dart';

enum TaskGraphEdgeKind { step, consult, spawn }

/// One node of the map: a station member, or the user at the origin.
class TaskGraphNode {
  final String id;
  final String label;
  final String role;
  final int memberIndex;
  final bool isUser;

  /// Set when another member asked for this agent to exist. The map draws it
  /// hanging off its creator so you can tell at a glance which agents you
  /// registered and which ones the station grew on its own.
  final String? createdById;

  const TaskGraphNode({
    required this.id,
    required this.label,
    required this.role,
    required this.memberIndex,
    this.isUser = false,
    this.createdById,
  });

  static const userId = '__user__';
}

/// One hop of the conversation: a workflow hand-off, or a `@handle` consult.
class TaskGraphEdge {
  final String fromId;
  final String toId;
  final TaskGraphEdgeKind kind;
  final String label;

  /// Index into [TaskGraph.messages] of the message that produced this hop —
  /// what drives the playback order.
  final int order;

  const TaskGraphEdge({
    required this.fromId,
    required this.toId,
    required this.kind,
    required this.label,
    required this.order,
  });
}

/// The conversation seen as a network, derived entirely from the task's
/// thread — no extra state is recorded while a task runs. Each assistant
/// message names its author, its workflow step, and (for a consult) who
/// asked, which is exactly what an edge needs.
class TaskGraph {
  final List<TaskGraphNode> nodes;
  final List<TaskGraphEdge> edges;

  const TaskGraph({required this.nodes, required this.edges});

  bool get isEmpty => edges.isEmpty;

  TaskGraphNode? nodeById(String id) {
    for (final node in nodes) {
      if (node.id == id) return node;
    }
    return null;
  }

  factory TaskGraph.fromMessages({
    required List<ChatMessage> messages,
    required List<AgentProfile> members,
    required List<String> stepTitles,
  }) {
    final nodes = <TaskGraphNode>[
      const TaskGraphNode(
        id: TaskGraphNode.userId,
        label: 'Vos',
        role: '',
        memberIndex: -1,
        isUser: true,
      ),
    ];
    for (var index = 0; index < members.length; index++) {
      final member = members[index];
      nodes.add(
        TaskGraphNode(
          id: member.id,
          label: member.name,
          role: member.role,
          memberIndex: index,
          createdById: member.createdByProfileId,
        ),
      );
    }

    final edges = <TaskGraphEdge>[];

    // Who brought whom. This one edge is not derived from the thread: the
    // relationship lives on the profile, so it shows even in a task where the
    // subagent has not spoken yet. Negative order keeps it ahead of every
    // message during playback — it is a fact about the cast, not a hop.
    for (final member in members) {
      final creator = member.createdByProfileId;
      if (creator == null) continue;
      if (members.every((other) => other.id != creator)) continue;
      edges.add(
        TaskGraphEdge(
          fromId: creator,
          toId: member.id,
          kind: TaskGraphEdgeKind.spawn,
          label: 'creó',
          order: -1,
        ),
      );
    }
    String? lastStepOwner;

    for (var index = 0; index < messages.length; index++) {
      final message = messages[index];

      // Anything you write hands the work back to you, so the next answer
      // draws an edge from you — that is what makes a follow-up question
      // show up on the map instead of vanishing into the last hand-off.
      if (message.role == ChatRole.user) {
        lastStepOwner = null;
        continue;
      }

      final author = message.authorProfileId;
      if (message.role != ChatRole.assistant || author == null) continue;
      if (nodes.every((node) => node.id != author)) continue;

      final asker = message.consultOfProfileId;
      if (asker != null) {
        edges.add(
          TaskGraphEdge(
            fromId: asker,
            toId: author,
            kind: TaskGraphEdgeKind.consult,
            label: 'consulta',
            order: index,
          ),
        );
        continue;
      }

      // Every hand-off is its own edge, including a repeat between the same
      // pair — asking again is a new interaction and has to show on the map.
      final from = lastStepOwner ?? TaskGraphNode.userId;
      if (from != author) {
        edges.add(
          TaskGraphEdge(
            fromId: from,
            toId: author,
            kind: TaskGraphEdgeKind.step,
            label: _stepLabelFor(message.stepIndex, stepTitles),
            order: index,
          ),
        );
      }
      lastStepOwner = author;
    }

    return TaskGraph(nodes: nodes, edges: edges);
  }

  static String _stepLabelFor(int? stepIndex, List<String> stepTitles) {
    if (stepIndex == null) return 'entrega';
    if (stepIndex >= stepTitles.length) return 'paso ${stepIndex + 1}';
    return 'paso ${stepIndex + 1} · ${stepTitles[stepIndex]}';
  }
}
