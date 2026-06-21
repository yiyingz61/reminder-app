import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/app_database.dart';
import '../models/todo.dart';

/// 待办页：列出全部待办，支持新建、勾选完成、设优先级与截止时间、删除。
class TodoScreen extends StatefulWidget {
  const TodoScreen({super.key});

  @override
  State<TodoScreen> createState() => TodoScreenState();
}

class TodoScreenState extends State<TodoScreen> {
  late Future<List<Todo>> _future;

  @override
  void initState() {
    super.initState();
    _future = AppDatabase.instance.allTodos();
  }

  void reload() {
    setState(() => _future = AppDatabase.instance.allTodos());
  }

  Future<void> _openCreateSheet() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _TodoCreateSheet(),
    );
    if (created == true) reload();
  }

  Future<void> _toggle(Todo t) async {
    await AppDatabase.instance.updateTodo(t.copyWith(done: !t.done));
    reload();
  }

  Future<void> _delete(Todo t) async {
    await AppDatabase.instance.deleteTodo(t.id!);
    reload();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Text('待办',
                  style:
                      TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
            ),
            Expanded(
              child: FutureBuilder<List<Todo>>(
                future: _future,
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final items = snap.data!;
                  if (items.isEmpty) {
                    return _EmptyTodos(color: scheme.primary);
                  }
                  final pending = items.where((t) => !t.done).length;
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 140),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                        child: Text('还有 $pending 项未完成',
                            style: TextStyle(
                                color: Colors.grey.shade600, fontSize: 13)),
                      ),
                      ...items.map((t) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _TodoTile(
                              todo: t,
                              onToggle: () => _toggle(t),
                              onDelete: () => _delete(t),
                            ),
                          )),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 76),
        child: FloatingActionButton.extended(
          heroTag: 'create-todo',
          onPressed: _openCreateSheet,
          icon: const Icon(Icons.add),
          label: const Text('新建待办'),
        ),
      ),
    );
  }
}

class _TodoTile extends StatelessWidget {
  final Todo todo;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  const _TodoTile(
      {required this.todo, required this.onToggle, required this.onDelete});

  static const _priorityLabels = ['普通', '重要', '紧急'];
  static const _priorityColors = [
    Color(0xFF9AA0B4),
    Color(0xFFF5A623),
    Color(0xFFEB5757),
  ];

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(todo.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: const Color(0xFFEB5757),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => onDelete(),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              IconButton(
                onPressed: onToggle,
                icon: Icon(
                  todo.done
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: todo.done
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey.shade400,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      todo.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        decoration:
                            todo.done ? TextDecoration.lineThrough : null,
                        color: todo.done ? Colors.grey : const Color(0xFF1B1D28),
                      ),
                    ),
                    if (todo.dueAt != null) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(Icons.alarm,
                              size: 13, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('M月d日 HH:mm').format(todo.dueAt!),
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (todo.priority > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: _priorityColors[todo.priority].withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _priorityLabels[todo.priority],
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _priorityColors[todo.priority]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyTodos extends StatelessWidget {
  final Color color;
  const _EmptyTodos({required this.color});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.checklist_rtl, size: 72, color: color.withOpacity(0.4)),
          const SizedBox(height: 16),
          const Text('暂无待办',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text('点击右下角按钮添加一项',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
        ],
      ),
    );
  }
}

/// 底部弹出的新建待办表单。
class _TodoCreateSheet extends StatefulWidget {
  const _TodoCreateSheet();

  @override
  State<_TodoCreateSheet> createState() => _TodoCreateSheetState();
}

class _TodoCreateSheetState extends State<_TodoCreateSheet> {
  final _controller = TextEditingController();
  int _priority = 0;
  DateTime? _dueAt;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickDue() async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d == null) return;
    if (!mounted) return;
    final t = await showTimePicker(
        context: context, initialTime: TimeOfDay.now());
    setState(() {
      _dueAt = DateTime(d.year, d.month, d.day, t?.hour ?? 9, t?.minute ?? 0);
    });
  }

  Future<void> _save() async {
    final title = _controller.text.trim();
    if (title.isEmpty) return;
    await AppDatabase.instance.insertTodo(Todo(
      title: title,
      priority: _priority,
      createdAt: DateTime.now(),
      dueAt: _dueAt,
    ));
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    const labels = ['普通', '重要', '紧急'];
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('新建待办',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: '要做什么？'),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 16),
          Text('优先级',
              style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: List.generate(3, (i) {
              final sel = _priority == i;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(labels[i]),
                  selected: sel,
                  onSelected: (_) => setState(() => _priority = i),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _pickDue,
                icon: const Icon(Icons.alarm, size: 18),
                label: Text(_dueAt == null
                    ? '设置截止时间'
                    : DateFormat('M月d日 HH:mm').format(_dueAt!)),
              ),
              if (_dueAt != null)
                IconButton(
                  onPressed: () => setState(() => _dueAt = null),
                  icon: const Icon(Icons.close, size: 18),
                ),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _save,
            style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16))),
            child: const Text('添加',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
