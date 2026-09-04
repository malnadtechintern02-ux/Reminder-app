import '../../domain/entities/reminder.dart';

class ReminderModel extends Reminder {
  const ReminderModel({
    required super.id,
    required super.title,
    super.description,
    required super.scheduledAt,
    super.endTime,
    required super.categoryId,
    required super.priority,
    required super.isCompleted,
    required super.isRepeating,
    required super.repeatType,
    required super.hasAlarm,
    required super.alarmEnabled,
    required super.alarmSoundEnabled,
    required super.alarmVibrationEnabled,
    required super.snoozeMinutes,
    required super.warningEnabled,
    super.ringtone,
    required super.createdAt,
  });

  factory ReminderModel.fromMap(Map<String, dynamic> map) {
    return ReminderModel(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      scheduledAt: DateTime.parse(map['scheduled_at'] as String),
      endTime: map['end_time'] != null ? DateTime.parse(map['end_time'] as String) : null,
      categoryId: map['category_id'] as String,
      priority: Priority.fromString(map['priority'] as String),
      isCompleted: (map['is_completed'] as int) == 1,
      isRepeating: (map['is_repeating'] as int) == 1,
      repeatType: RepeatType.fromString(map['repeat_type'] as String),
      hasAlarm: map['has_alarm'] == null || (map['has_alarm'] as int) == 1,
      alarmEnabled: map['alarm_enabled'] != null && (map['alarm_enabled'] as int) == 1,
      alarmSoundEnabled: map['alarm_sound_enabled'] == null || (map['alarm_sound_enabled'] as int) == 1,
      alarmVibrationEnabled: map['alarm_vibration_enabled'] == null || (map['alarm_vibration_enabled'] as int) == 1,
      snoozeMinutes: map['snooze_minutes'] as int? ?? 5,
      warningEnabled: map['warning_enabled'] == null || (map['warning_enabled'] as int) == 1,
      ringtone: map['ringtone'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'scheduled_at': scheduledAt.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'category_id': categoryId,
      'priority': priority.name,
      'is_completed': isCompleted ? 1 : 0,
      'is_repeating': isRepeating ? 1 : 0,
      'repeat_type': repeatType.name,
      'has_alarm': hasAlarm ? 1 : 0,
      'alarm_enabled': alarmEnabled ? 1 : 0,
      'alarm_sound_enabled': alarmSoundEnabled ? 1 : 0,
      'alarm_vibration_enabled': alarmVibrationEnabled ? 1 : 0,
      'snooze_minutes': snoozeMinutes,
      'warning_enabled': warningEnabled ? 1 : 0,
      'ringtone': ringtone,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory ReminderModel.fromEntity(Reminder entity) {
    return ReminderModel(
      id: entity.id,
      title: entity.title,
      description: entity.description,
      scheduledAt: entity.scheduledAt,
      endTime: entity.endTime,
      categoryId: entity.categoryId,
      priority: entity.priority,
      isCompleted: entity.isCompleted,
      isRepeating: entity.isRepeating,
      repeatType: entity.repeatType,
      hasAlarm: entity.hasAlarm,
      alarmEnabled: entity.alarmEnabled,
      alarmSoundEnabled: entity.alarmSoundEnabled,
      alarmVibrationEnabled: entity.alarmVibrationEnabled,
      snoozeMinutes: entity.snoozeMinutes,
      warningEnabled: entity.warningEnabled,
      ringtone: entity.ringtone,
      createdAt: entity.createdAt,
    );
  }
}
