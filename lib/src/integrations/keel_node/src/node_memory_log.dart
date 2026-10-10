part of '../keel_node.dart';

/// One line of [NodeMemoryLog].
final class NodeMemoryLine implements NodeLogLine {
  const NodeMemoryLine({
    required this.id,
    required this.at,
    required this.kind,
    required this.level,
    required this.title,
    required this.detail,
    this.count = 1,
  });

  @override
  final int id;
  @override
  final DateTime at;
  @override
  final String kind;
  @override
  final String level;
  @override
  final String title;
  @override
  final String detail;

  /// How many times it happened in a row (a poll that finds nothing).
  final int count;

  factory NodeMemoryLine.fromJson(Map<String, dynamic> json) => NodeMemoryLine(
    id: json['id'] as int? ?? 0,
    at: DateTime.tryParse('${json['at']}') ?? DateTime.now(),
    kind: json['kind'] as String? ?? '',
    level: json['level'] as String? ?? 'info',
    title: json['title'] as String? ?? '',
    detail: json['detail'] as String? ?? '',
    count: json['count'] as int? ?? 1,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'at': at.toUtc().toIso8601String(),
    'kind': kind,
    'level': level,
    'title': title,
    'detail': detail,
    'count': count,
  };

  NodeMemoryLine copyWith({
    int? id,
    DateTime? at,
    String? kind,
    String? level,
    String? title,
    String? detail,
    int? count,
  }) => NodeMemoryLine(
    id: id ?? this.id,
    at: at ?? this.at,
    kind: kind ?? this.kind,
    level: level ?? this.level,
    title: title ?? this.title,
    detail: detail ?? this.detail,
    count: count ?? this.count,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NodeMemoryLine &&
          id == other.id &&
          at == other.at &&
          kind == other.kind &&
          level == other.level &&
          title == other.title &&
          detail == other.detail &&
          count == other.count;

  @override
  int get hashCode => Object.hash(id, at, kind, level, title, detail, count);
}

/// The node link's log, kept in memory only: the last [capacity] lines, for
/// the Keel panel's status. Nothing of it reaches the disk.
///
/// A line written with the `repeat` key of a recent one counts one more on
/// it and moves to the end, as keel-server's activity log does, so a poll
/// that keeps finding nothing is one line.
final class NodeMemoryLog implements NodeLinkLog {
  NodeMemoryLog({this.capacity = 120, this.onChange});

  final int capacity;

  /// Called after every line written.
  final void Function()? onChange;

  /// A line's detail is the request and its answer: what the status needs
  /// of it is far less.
  static const int _maxDetail = 2000;

  /// keel-core's link writes `task <id> taken: <type> …` once per task it
  /// acknowledges.
  static final RegExp _taken = RegExp(r'^task \S+ taken: ');

  final List<NodeMemoryLine> _lines = [];
  final Map<int, String> _repeats = {};
  int _next = 1;
  int _tasksTaken = 0;

  /// The tasks this node took since it started.
  int get tasksTaken => _tasksTaken;

  @override
  void add(
    String kind,
    String title, {
    String level = 'info',
    String detail = '',
    String? repeat,
  }) {
    if (kind == 'task' && _taken.hasMatch(title)) _tasksTaken++;
    final now = DateTime.now();
    final index = repeat == null
        ? -1
        : _lines.lastIndexWhere((line) => _repeats[line.id] == repeat);
    if (index >= 0) {
      final again = _lines.removeAt(index);
      _lines.add(again.copyWith(at: now, count: again.count + 1));
    } else {
      final line = NodeMemoryLine(
        id: _next++,
        at: now,
        kind: kind,
        level: level,
        title: title,
        detail: detail.length <= _maxDetail
            ? detail
            : '${detail.substring(0, _maxDetail)}…',
      );
      _lines.add(line);
      if (repeat != null) _repeats[line.id] = repeat;
      while (_lines.length > capacity) {
        _repeats.remove(_lines.removeAt(0).id);
      }
    }
    onChange?.call();
  }

  @override
  List<NodeMemoryLine> tail(int count) => _lines.length > count
      ? _lines.sublist(_lines.length - count)
      : List.of(_lines);
}
