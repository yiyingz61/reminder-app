import 'package:flutter/material.dart';

/// 日程数据模型，对应数据库表 schedules。
class Schedule {
  final int? id;
  final String title;
  final String? note;
  final DateTime start; // 开始时间（含日期）
  final DateTime? end; // 结束时间，可为空
  final bool allDay; // 是否全天
  final int colorValue; // 分类色，存为 ARGB int
  final bool done; // 是否已完成

  Schedule({
    this.id,
    required this.title,
    this.note,
    required this.start,
    this.end,
    this.allDay = false,
    this.colorValue = 0xFF5B8DEF,
    this.done = false,
  });

  Color get color => Color(colorValue);

  /// 该日程所属的“日”（去掉时分秒），用于按天分组查询。
  String get dayKey =>
      '${start.year.toString().padLeft(4, '0')}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';

  Schedule copyWith({
    int? id,
    String? title,
    String? note,
    DateTime? start,
    DateTime? end,
    bool? allDay,
    int? colorValue,
    bool? done,
  }) {
    return Schedule(
      id: id ?? this.id,
      title: title ?? this.title,
      note: note ?? this.note,
      start: start ?? this.start,
      end: end ?? this.end,
      allDay: allDay ?? this.allDay,
      colorValue: colorValue ?? this.colorValue,
      done: done ?? this.done,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'title': title,
      'note': note,
      'start_ms': start.millisecondsSinceEpoch,
      'end_ms': end?.millisecondsSinceEpoch,
      'day_key': dayKey,
      'all_day': allDay ? 1 : 0,
      'color': colorValue,
      'done': done ? 1 : 0,
    };
  }

  factory Schedule.fromMap(Map<String, Object?> m) {
    return Schedule(
      id: m['id'] as int?,
      title: m['title'] as String,
      note: m['note'] as String?,
      start: DateTime.fromMillisecondsSinceEpoch(m['start_ms'] as int),
      end: m['end_ms'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(m['end_ms'] as int),
      allDay: (m['all_day'] as int) == 1,
      colorValue: m['color'] as int,
      done: (m['done'] as int) == 1,
    );
  }
}
