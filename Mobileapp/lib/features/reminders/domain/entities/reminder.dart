class Priority {
  final String id;
  final String name;
  final int level;

  const Priority({
    required this.name,
    this.id = '',
    this.level = 1,
  });

  static const Priority low = Priority(name: 'low', level: 1);
  static const Priority medium = Priority(name: 'medium', level: 2);
  static const Priority high = Priority(name: 'high', level: 3);
  static const Priority urgent = Priority(name: 'urgent', level: 4);

  static const List<Priority> defaultPriorities = [low, medium, high, urgent];

  static Priority fromString(String? value) {
    if (value == null || value.trim().isEmpty) return Priority.low;
    final clean = value.trim().toLowerCase();
    switch (clean) {
      case 'urgent':
        return Priority.urgent;
      case 'high':
        return Priority.high;
      case 'medium':
        return Priority.medium;
      case 'low':
        return Priority.low;
      default:
        return Priority(name: clean, level: 2);
    }
  }

  factory Priority.fromMap(Map<String, dynamic> map) {
    int parseLevel(dynamic val) {
      if (val is int) return val;
      return int.tryParse(val?.toString() ?? '1') ?? 1;
    }

    final rawName = map['name']?.toString().trim() ?? 'low';
    return Priority(
      id: map['id']?.toString() ?? '',
      name: rawName,
      level: parseLevel(map['level']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id.isNotEmpty ? id : name.toLowerCase(),
      'name': name,
      'level': level,
      'status': 1,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Priority && name.toLowerCase() == other.name.toLowerCase());

  @override
  int get hashCode => name.toLowerCase().hashCode;

  @override
  String toString() => name;
}

enum RepeatType {
  none,
  daily,
  weekdays,
  weekends,
  weekly,
  monthly,
  custom;

  static RepeatType fromString(String value) {
    final clean = value.toLowerCase().trim();
    return RepeatType.values.firstWhere(
      (e) => e.name == clean,
      orElse: () => RepeatType.none,
    );
  }

  String get displayName {
    switch (this) {
      case RepeatType.none:
        return 'Once';
      case RepeatType.daily:
        return 'Every day';
      case RepeatType.weekdays:
        return 'Weekdays (Mon-Fri)';
      case RepeatType.weekends:
        return 'Weekends (Sat-Sun)';
      case RepeatType.weekly:
        return 'Weekly';
      case RepeatType.monthly:
        return 'Monthly';
      case RepeatType.custom:
        return 'Custom days';
    }
  }
}

class Reminder {
  final String id;
  final String title;
  final String? description;
  final DateTime scheduledAt;
  final DateTime? endTime;
  final String categoryId;
  final Priority priority;
  final bool isCompleted;
  final bool isRepeating;
  final RepeatType repeatType;
  final List<int>? repeatDays; // 1 = Monday, ..., 7 = Sunday
  final bool hasAlarm;
  final bool alarmEnabled;
  final bool alarmSoundEnabled;
  final bool alarmVibrationEnabled;
  final String vibrationPattern; // 'off', 'short', 'medium', 'long', 'strong'
  final int snoozeMinutes;
  final int advanceMinutes; // 0 = Off, 5, 10, 15, 30
  final bool warningEnabled;
  final String? ringtone;
  final DateTime createdAt;

  const Reminder({
    required this.id,
    required this.title,
    this.description,
    required this.scheduledAt,
    this.endTime,
    required this.categoryId,
    required this.priority,
    required this.isCompleted,
    required this.isRepeating,
    required this.repeatType,
    this.repeatDays,
    required this.hasAlarm,
    required this.alarmEnabled,
    required this.alarmSoundEnabled,
    required this.alarmVibrationEnabled,
    this.vibrationPattern = 'medium',
    required this.snoozeMinutes,
    this.advanceMinutes = 5,
    required this.warningEnabled,
    this.ringtone,
    required this.createdAt,
  });

  Reminder copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? scheduledAt,
    DateTime? endTime,
    String? categoryId,
    Priority? priority,
    bool? isCompleted,
    bool? isRepeating,
    RepeatType? repeatType,
    List<int>? repeatDays,
    bool? hasAlarm,
    bool? alarmEnabled,
    bool? alarmSoundEnabled,
    bool? alarmVibrationEnabled,
    String? vibrationPattern,
    int? snoozeMinutes,
    int? advanceMinutes,
    bool? warningEnabled,
    String? ringtone,
    DateTime? createdAt,
  }) {
    final newAdvanceMinutes = advanceMinutes ?? this.advanceMinutes;
    return Reminder(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      endTime: endTime ?? this.endTime,
      categoryId: categoryId ?? this.categoryId,
      priority: priority ?? this.priority,
      isCompleted: isCompleted ?? this.isCompleted,
      isRepeating: isRepeating ?? this.isRepeating,
      repeatType: repeatType ?? this.repeatType,
      repeatDays: repeatDays ?? this.repeatDays,
      hasAlarm: hasAlarm ?? this.hasAlarm,
      alarmEnabled: alarmEnabled ?? this.alarmEnabled,
      alarmSoundEnabled: alarmSoundEnabled ?? this.alarmSoundEnabled,
      alarmVibrationEnabled: alarmVibrationEnabled ?? this.alarmVibrationEnabled,
      vibrationPattern: vibrationPattern ?? this.vibrationPattern,
      snoozeMinutes: snoozeMinutes ?? this.snoozeMinutes,
      advanceMinutes: newAdvanceMinutes,
      warningEnabled: warningEnabled ?? (newAdvanceMinutes > 0),
      ringtone: ringtone ?? this.ringtone,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
