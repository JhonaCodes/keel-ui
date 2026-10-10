import 'package:flutter/foundation.dart';

import 'package:keel_ui/src/integrations/keel_api/keel_api.dart';
import 'package:keel_ui/src/modules/keel_remote/model/remote_task.dart';

/// The task queue as the «Tareas» tab shows it: one page, newest first,
/// optionally filtered by status.
@immutable
class RemoteTasksState {
  const RemoteTasksState({
    this.tasks = const <RemoteTask>[],
    this.filter,
    this.loading = false,
    this.failure,
  });

  final List<RemoteTask> tasks;

  /// Null shows every status.
  final RemoteTaskStatus? filter;
  final bool loading;

  /// The last call that failed; the tasks on screen stay.
  final KeelApiFailure? failure;

  RemoteTasksState copyWith({
    List<RemoteTask>? tasks,
    RemoteTaskStatus? filter,
    bool clearFilter = false,
    bool? loading,
    KeelApiFailure? failure,
    bool clearFailure = false,
  }) => RemoteTasksState(
    tasks: tasks ?? this.tasks,
    filter: clearFilter ? null : (filter ?? this.filter),
    loading: loading ?? this.loading,
    failure: clearFailure ? null : (failure ?? this.failure),
  );

  factory RemoteTasksState.fromJson(Map<String, dynamic> json) =>
      RemoteTasksState(
        tasks: <RemoteTask>[
          for (final row in json['tasks'] as List<Object?>? ?? const [])
            if (row is Map<String, dynamic>) RemoteTask.fromJson(row),
        ],
        filter: switch (json['filter']) {
          final String wire => RemoteTaskStatus.fromWire(wire),
          _ => null,
        },
        loading: KeelJson.decodeBool(json['loading']),
        failure: switch (json['failure']) {
          final Map<String, dynamic> failure => KeelApiFailure.fromJson(
            failure,
          ),
          _ => null,
        },
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'tasks': tasks.map((task) => task.toJson()).toList(),
    'filter': filter?.wireValue,
    'loading': loading,
    'failure': failure?.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RemoteTasksState &&
          listEquals(tasks, other.tasks) &&
          filter == other.filter &&
          loading == other.loading &&
          failure == other.failure;

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(tasks), filter, loading, failure);
}

/// The one task the central area follows (the remote-task lens).
@immutable
class RemoteTaskFollowState {
  const RemoteTaskFollowState({
    this.taskId,
    this.task,
    this.events = const <RemoteTaskEvent>[],
    this.loading = false,
    this.failure,
  });

  /// What is followed; null before anything was opened.
  final String? taskId;

  /// Null until its first read.
  final RemoteTask? task;
  final List<RemoteTaskEvent> events;
  final bool loading;
  final KeelApiFailure? failure;

  RemoteTaskFollowState copyWith({
    String? taskId,
    RemoteTask? task,
    List<RemoteTaskEvent>? events,
    bool? loading,
    KeelApiFailure? failure,
    bool clearFailure = false,
  }) => RemoteTaskFollowState(
    taskId: taskId ?? this.taskId,
    task: task ?? this.task,
    events: events ?? this.events,
    loading: loading ?? this.loading,
    failure: clearFailure ? null : (failure ?? this.failure),
  );

  factory RemoteTaskFollowState.fromJson(Map<String, dynamic> json) =>
      RemoteTaskFollowState(
        taskId: json['task_id'] as String?,
        task: switch (json['task']) {
          final Map<String, dynamic> task => RemoteTask.fromJson(task),
          _ => null,
        },
        events: <RemoteTaskEvent>[
          for (final row in json['events'] as List<Object?>? ?? const [])
            if (row is Map<String, dynamic>) RemoteTaskEvent.fromJson(row),
        ],
        loading: KeelJson.decodeBool(json['loading']),
        failure: switch (json['failure']) {
          final Map<String, dynamic> failure => KeelApiFailure.fromJson(
            failure,
          ),
          _ => null,
        },
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'task_id': taskId,
    'task': task?.toJson(),
    'events': events.map((event) => event.toJson()).toList(),
    'loading': loading,
    'failure': failure?.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RemoteTaskFollowState &&
          taskId == other.taskId &&
          task == other.task &&
          listEquals(events, other.events) &&
          loading == other.loading &&
          failure == other.failure;

  @override
  int get hashCode =>
      Object.hash(taskId, task, Object.hashAll(events), loading, failure);
}
