enum Priority {
  low,
  medium,
  high;

  static Priority fromString(String value) {
    return Priority.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => Priority.low,
    );
  }
}

enum RepeatType {
  none,
  daily,
  weekly,
  monthly;

  static RepeatType fromString(String value) {
    return RepeatType.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => RepeatType.none,
    );
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
  final bool hasAlarm;
  final bool alarmEnabled;
  final bool alarmSoundEnabled;
  final bool alarmVibrationEnabled;
  final int snoozeMinutes;
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
    required this.hasAlarm,
    required this.alarmEnabled,
    required this.alarmSoundEnabled,
    required this.alarmVibrationEnabled,
    required this.snoozeMinutes,
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
    bool? hasAlarm,
    bool? alarmEnabled,
    bool? alarmSoundEnabled,
    bool? alarmVibrationEnabled,
    int? snoozeMinutes,
    bool? warningEnabled,
    String? ringtone,
    DateTime? createdAt,
  }) {
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
      hasAlarm: hasAlarm ?? this.hasAlarm,
      alarmEnabled: alarmEnabled ?? this.alarmEnabled,
      alarmSoundEnabled: alarmSoundEnabled ?? this.alarmSoundEnabled,
      alarmVibrationEnabled: alarmVibrationEnabled ?? this.alarmVibrationEnabled,
      snoozeMinutes: snoozeMinutes ?? this.snoozeMinutes,
      warningEnabled: warningEnabled ?? this.warningEnabled,
      ringtone: ringtone ?? this.ringtone,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
