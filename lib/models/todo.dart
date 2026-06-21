/// 待办数据模型，对应数据库表 todos。
class Todo {
  final int? id;
  final String title;
  final bool done;
  final int priority; // 0 普通, 1 重要, 2 紧急
  final DateTime createdAt;
  final DateTime? dueAt; // 截止时间，可为空

  Todo({
    this.id,
    required this.title,
    this.done = false,
    this.priority = 0,
    required this.createdAt,
    this.dueAt,
  });

  Todo copyWith({
    int? id,
    String? title,
    bool? done,
    int? priority,
    DateTime? createdAt,
    DateTime? dueAt,
    bool clearDue = false,
  }) {
    return Todo(
      id: id ?? this.id,
      title: title ?? this.title,
      done: done ?? this.done,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      dueAt: clearDue ? null : (dueAt ?? this.dueAt),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'title': title,
      'done': done ? 1 : 0,
      'priority': priority,
      'created_ms': createdAt.millisecondsSinceEpoch,
      'due_ms': dueAt?.millisecondsSinceEpoch,
    };
  }

  factory Todo.fromMap(Map<String, Object?> m) {
    return Todo(
      id: m['id'] as int?,
      title: m['title'] as String,
      done: (m['done'] as int) == 1,
      priority: m['priority'] as int,
      createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_ms'] as int),
      dueAt: m['due_ms'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(m['due_ms'] as int),
    );
  }
}
