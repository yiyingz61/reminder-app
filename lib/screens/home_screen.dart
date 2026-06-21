import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/app_database.dart';
import '../models/schedule.dart';
import 'schedule_edit_screen.dart';

/// 首页“我的一天”：顶部可切换日期，下面列出当天日程。
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  DateTime _selected = _dateOnly(DateTime.now());
  late Future<List<Schedule>> _future;

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  void initState() {
    super.initState();
    _future = AppDatabase.instance.schedulesForDay(_selected);
  }

  /// 供外壳在新建/编辑后调用，刷新当前列表。
  void reload() {
    setState(() {
      _future = AppDatabase.instance.schedulesForDay(_selected);
    });
  }

  void _pick(DateTime d) {
    setState(() {
      _selected = _dateOnly(d);
      _future = AppDatabase.instance.schedulesForDay(_selected);
    });
  }

  Future<void> _openCalendar() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selected,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: '选择日期',
    );
    if (picked != null) _pick(picked);
  }

  Future<void> _edit(Schedule s) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            ScheduleEditScreen(initialDate: _selected, existing: s),
        fullscreenDialog: true,
      ),
    );
    if (changed == true) reload();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isToday = _selected == _dateOnly(DateTime.now());
    final titleText = isToday
        ? '我的一天'
        : DateFormat('M月d日 EEEE', 'zh').format(_selected);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(titleText,
                            style: const TextStyle(
                                fontSize: 26, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(
                          DateFormat('yyyy年M月d日 EEEE', 'zh')
                              .format(_selected),
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: _openCalendar,
                    icon: const Icon(Icons.calendar_month),
                    tooltip: '选择日期',
                  ),
                ],
              ),
            ),
            _WeekStrip(selected: _selected, onPick: _pick),
            const SizedBox(height: 4),
            Expanded(
              child: FutureBuilder<List<Schedule>>(
                future: _future,
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final items = snap.data!;
                  if (items.isEmpty) {
                    return _EmptyDay(color: scheme.primary);
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _ScheduleCard(
                      schedule: items[i],
                      onTap: () => _edit(items[i]),
                      onToggle: () async {
                        final s = items[i];
                        await AppDatabase.instance
                            .updateSchedule(s.copyWith(done: !s.done));
                        reload();
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 顶部一周日期条，可左右滑动，点选切换日期。
class _WeekStrip extends StatelessWidget {
  final DateTime selected;
  final ValueChanged<DateTime> onPick;
  const _WeekStrip({required this.selected, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final today = DateTime.now();
    // 以选中日为中心，展示前后各 15 天。
    final base = DateTime(selected.year, selected.month, selected.day)
        .subtract(const Duration(days: 15));
    return SizedBox(
      height: 76,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: 31,
        itemBuilder: (_, i) {
          final d = base.add(Duration(days: i));
          final isSel = d.year == selected.year &&
              d.month == selected.month &&
              d.day == selected.day;
          final isToday = d.year == today.year &&
              d.month == today.month &&
              d.day == today.day;
          return GestureDetector(
            onTap: () => onPick(d),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 52,
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
              decoration: BoxDecoration(
                color: isSel ? scheme.primary : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isToday && !isSel
                      ? scheme.primary
                      : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('EEE', 'zh').format(d),
                    style: TextStyle(
                        fontSize: 11,
                        color: isSel ? Colors.white70 : Colors.grey.shade500),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${d.day}',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isSel ? Colors.white : const Color(0xFF1B1D28)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  final Schedule schedule;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  const _ScheduleCard(
      {required this.schedule, required this.onTap, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final timeLabel = schedule.allDay
        ? '全天'
        : DateFormat('HH:mm').format(schedule.start) +
            (schedule.end != null
                ? ' - ${DateFormat('HH:mm').format(schedule.end!)}'
                : '');
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 5,
                height: 46,
                decoration: BoxDecoration(
                  color: schedule.color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      schedule.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        decoration: schedule.done
                            ? TextDecoration.lineThrough
                            : null,
                        color: schedule.done
                            ? Colors.grey
                            : const Color(0xFF1B1D28),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.schedule,
                            size: 14, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(timeLabel,
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey.shade600)),
                      ],
                    ),
                    if (schedule.note != null &&
                        schedule.note!.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(schedule.note!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey.shade600)),
                    ],
                  ],
                ),
              ),
              IconButton(
                onPressed: onToggle,
                icon: Icon(
                  schedule.done
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: schedule.done ? schedule.color : Colors.grey.shade400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyDay extends StatelessWidget {
  final Color color;
  const _EmptyDay({required this.color});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event_available, size: 72, color: color.withOpacity(0.4)),
          const SizedBox(height: 16),
          const Text('这一天还没有日程',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text('点击下方 + 按钮添加',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
        ],
      ),
    );
  }
}
