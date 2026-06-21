import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/app_database.dart';
import '../models/schedule.dart';
import '../theme.dart';

/// 新建 / 编辑日程页。existing 为空时是新建。
class ScheduleEditScreen extends StatefulWidget {
  final DateTime initialDate;
  final Schedule? existing;
  const ScheduleEditScreen(
      {super.key, required this.initialDate, this.existing});

  @override
  State<ScheduleEditScreen> createState() => _ScheduleEditScreenState();
}

class _ScheduleEditScreenState extends State<ScheduleEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _title;
  late TextEditingController _note;

  late DateTime _date;
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 10, minute: 0);
  bool _allDay = false;
  int _color = AppTheme.palette.first;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _note = TextEditingController(text: e?.note ?? '');
    _date = DateTime(
      (e?.start ?? widget.initialDate).year,
      (e?.start ?? widget.initialDate).month,
      (e?.start ?? widget.initialDate).day,
    );
    if (e != null) {
      _startTime = TimeOfDay.fromDateTime(e.start);
      if (e.end != null) _endTime = TimeOfDay.fromDateTime(e.end!);
      _allDay = e.allDay;
      _color = e.colorValue;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  DateTime _combine(DateTime d, TimeOfDay t) =>
      DateTime(d.year, d.month, d.day, t.hour, t.minute);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime({required bool start}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: start ? _startTime : _endTime,
    );
    if (picked != null) {
      setState(() {
        if (start) {
          _startTime = picked;
          // 若开始晚于结束，自动把结束顺延一小时。
          final s = _combine(_date, _startTime);
          final en = _combine(_date, _endTime);
          if (!en.isAfter(s)) {
            _endTime = TimeOfDay(
                hour: (picked.hour + 1) % 24, minute: picked.minute);
          }
        } else {
          _endTime = picked;
        }
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final start = _allDay
        ? DateTime(_date.year, _date.month, _date.day, 0, 0)
        : _combine(_date, _startTime);
    final end = _allDay ? null : _combine(_date, _endTime);

    final s = Schedule(
      id: widget.existing?.id,
      title: _title.text.trim(),
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      start: start,
      end: end,
      allDay: _allDay,
      colorValue: _color,
      done: widget.existing?.done ?? false,
    );
    if (_isEdit) {
      await AppDatabase.instance.updateSchedule(s);
    } else {
      await AppDatabase.instance.insertSchedule(s);
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('删除日程'),
        content: const Text('确定要删除这条日程吗？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('删除')),
        ],
      ),
    );
    if (ok == true) {
      await AppDatabase.instance.deleteSchedule(widget.existing!.id!);
      if (mounted) Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? '编辑日程' : '新建日程'),
        actions: [
          if (_isEdit)
            IconButton(
                onPressed: _delete,
                icon: const Icon(Icons.delete_outline),
                tooltip: '删除'),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(
                  hintText: '日程标题', prefixIcon: Icon(Icons.edit_outlined)),
              textInputAction: TextInputAction.next,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '请输入标题' : null,
            ),
            const SizedBox(height: 16),
            _Tile(
              icon: Icons.event,
              label: '日期',
              value: DateFormat('yyyy年M月d日 EEEE', 'zh').format(_date),
              onTap: _pickDate,
            ),
            const SizedBox(height: 12),
            Card(
              child: SwitchListTile(
                value: _allDay,
                onChanged: (v) => setState(() => _allDay = v),
                title: const Text('全天'),
                secondary: const Icon(Icons.wb_sunny_outlined),
                shape:
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
            ),
            if (!_allDay) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _Tile(
                      icon: Icons.play_arrow_rounded,
                      label: '开始',
                      value: _startTime.format(context),
                      onTap: () => _pickTime(start: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Tile(
                      icon: Icons.stop_rounded,
                      label: '结束',
                      value: _endTime.format(context),
                      onTap: () => _pickTime(start: false),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 8),
              child: Text('颜色标记',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            Wrap(
              spacing: 12,
              children: AppTheme.palette.map((c) {
                final sel = c == _color;
                return GestureDetector(
                  onTap: () => setState(() => _color = c),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Color(c),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: sel ? Colors.black87 : Colors.transparent,
                          width: 2.5),
                    ),
                    child: sel
                        ? const Icon(Icons.check, color: Colors.white, size: 20)
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _note,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                  hintText: '备注（可选）',
                  alignLabelWithHint: true),
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16))),
              child: Text(_isEdit ? '保存修改' : '创建日程',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  const _Tile(
      {required this.icon,
      required this.label,
      required this.value,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade500)),
                  const SizedBox(height: 2),
                  Text(value,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
