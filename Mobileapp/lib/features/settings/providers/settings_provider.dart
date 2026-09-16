import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;

import '../../../../app/theme/theme_provider.dart';

final packageInfoProvider = FutureProvider<PackageInfo>((ref) async {
  return await PackageInfo.fromPlatform();
});

class BuiltInRingtone {
  final String id;
  final String name;

  const BuiltInRingtone({required this.id, required this.name});
}

const List<BuiltInRingtone> builtInRingtones = [
  BuiltInRingtone(id: 'morning_breeze', name: 'Morning Breeze'),
  BuiltInRingtone(id: 'soft_sunrise', name: 'Soft Sunrise'),
  BuiltInRingtone(id: 'bright_morning', name: 'Bright Morning'),
  BuiltInRingtone(id: 'gentle_wake', name: 'Gentle Wake'),
  BuiltInRingtone(id: 'happy_start', name: 'Happy Start'),
  BuiltInRingtone(id: 'fresh_day', name: 'Fresh Day'),
  BuiltInRingtone(id: 'digital_pulse', name: 'Digital Pulse'),
  BuiltInRingtone(id: 'calm_bell', name: 'Calm Bell'),
  BuiltInRingtone(id: 'energy_wake', name: 'Energy Wake'),
  BuiltInRingtone(id: 'daily_beat', name: 'Daily Beat'),
  BuiltInRingtone(id: 'focus_start', name: 'Focus Start'),
  BuiltInRingtone(id: 'classic_modern', name: 'Classic Modern'),
];

String formatRingtoneName(String? ringtoneId) {
  if (ringtoneId == null || ringtoneId.isEmpty) {
    return 'Morning Breeze';
  }
  for (final r in builtInRingtones) {
    if (r.id == ringtoneId) return r.name;
  }
  final base = p.basename(ringtoneId);
  return base.isNotEmpty ? base : ringtoneId;
}


class SettingsState {
  final int defaultSnoozeDuration;
  final bool vibrateOnAlarm;
  final bool use24HourFormat;
  
  // New features
  final int workDuration;
  final int shortBreakDuration;
  final int longBreakDuration;
  final bool startOfWeekMonday;
  final int accentColorIndex;
  final int? customAccentColor;

  // New Alarm & Notifications features
  final bool notificationsEnabled;
  final bool fiveMinuteWarningEnabled;
  final bool alarmSoundEnabled;
  final bool alarmVibrationEnabled;
  final String defaultRingtone;
  final List<String> customRingtones;

  SettingsState({
    this.defaultSnoozeDuration = 10,
    this.vibrateOnAlarm = true,
    this.use24HourFormat = false,
    this.workDuration = 25,
    this.shortBreakDuration = 5,
    this.longBreakDuration = 15,
    this.startOfWeekMonday = true,
    this.accentColorIndex = 0,
    this.customAccentColor,
    this.notificationsEnabled = true,
    this.fiveMinuteWarningEnabled = true,
    this.alarmSoundEnabled = true,
    this.alarmVibrationEnabled = true,
    this.defaultRingtone = 'morning_breeze',
    this.customRingtones = const [],
  });

  SettingsState copyWith({
    int? defaultSnoozeDuration,
    bool? vibrateOnAlarm,
    bool? use24HourFormat,
    int? workDuration,
    int? shortBreakDuration,
    int? longBreakDuration,
    bool? startOfWeekMonday,
    int? accentColorIndex,
    int? customAccentColor,
    bool? notificationsEnabled,
    bool? fiveMinuteWarningEnabled,
    bool? alarmSoundEnabled,
    bool? alarmVibrationEnabled,
    String? defaultRingtone,
    List<String>? customRingtones,
  }) {
    return SettingsState(
      defaultSnoozeDuration: defaultSnoozeDuration ?? this.defaultSnoozeDuration,
      vibrateOnAlarm: vibrateOnAlarm ?? this.vibrateOnAlarm,
      use24HourFormat: use24HourFormat ?? this.use24HourFormat,
      workDuration: workDuration ?? this.workDuration,
      shortBreakDuration: shortBreakDuration ?? this.shortBreakDuration,
      longBreakDuration: longBreakDuration ?? this.longBreakDuration,
      startOfWeekMonday: startOfWeekMonday ?? this.startOfWeekMonday,
      accentColorIndex: accentColorIndex ?? this.accentColorIndex,
      customAccentColor: customAccentColor ?? this.customAccentColor,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      fiveMinuteWarningEnabled: fiveMinuteWarningEnabled ?? this.fiveMinuteWarningEnabled,
      alarmSoundEnabled: alarmSoundEnabled ?? this.alarmSoundEnabled,
      alarmVibrationEnabled: alarmVibrationEnabled ?? this.alarmVibrationEnabled,
      defaultRingtone: defaultRingtone ?? this.defaultRingtone,
      customRingtones: customRingtones ?? this.customRingtones,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  final SharedPreferences _prefs;

  SettingsNotifier(this._prefs) : super(SettingsState()) {
    _loadSettings();
  }

  void _loadSettings() {
    state = SettingsState(
      defaultSnoozeDuration: _prefs.getInt('defaultSnoozeDuration') ?? 10,
      vibrateOnAlarm: _prefs.getBool('vibrateOnAlarm') ?? true,
      use24HourFormat: _prefs.getBool('use24HourFormat') ?? false,
      workDuration: _prefs.getInt('workDuration') ?? 25,
      shortBreakDuration: _prefs.getInt('shortBreakDuration') ?? 5,
      longBreakDuration: _prefs.getInt('longBreakDuration') ?? 15,
      startOfWeekMonday: _prefs.getBool('startOfWeekMonday') ?? true,
      accentColorIndex: _prefs.getInt('accentColorIndex') ?? 0,
      customAccentColor: _prefs.getInt('customAccentColor'),
      notificationsEnabled: _prefs.getBool('notificationsEnabled') ?? true,
      fiveMinuteWarningEnabled: _prefs.getBool('fiveMinuteWarningEnabled') ?? true,
      alarmSoundEnabled: _prefs.getBool('alarmSoundEnabled') ?? true,
      alarmVibrationEnabled: _prefs.getBool('alarmVibrationEnabled') ?? true,
      defaultRingtone: _prefs.getString('defaultRingtone') ?? 'morning_breeze',
      customRingtones: _prefs.getStringList('customRingtones') ?? [],
    );
  }

  Future<void> setDefaultSnoozeDuration(int minutes) async {
    state = state.copyWith(defaultSnoozeDuration: minutes);
    await _prefs.setInt('defaultSnoozeDuration', minutes);
  }

  Future<void> setVibrateOnAlarm(bool vibrate) async {
    state = state.copyWith(vibrateOnAlarm: vibrate);
    await _prefs.setBool('vibrateOnAlarm', vibrate);
  }

  Future<void> setUse24HourFormat(bool use24Hour) async {
    state = state.copyWith(use24HourFormat: use24Hour);
    await _prefs.setBool('use24HourFormat', use24Hour);
  }

  Future<void> setWorkDuration(int minutes) async {
    state = state.copyWith(workDuration: minutes);
    await _prefs.setInt('workDuration', minutes);
  }

  Future<void> setShortBreakDuration(int minutes) async {
    state = state.copyWith(shortBreakDuration: minutes);
    await _prefs.setInt('shortBreakDuration', minutes);
  }

  Future<void> setLongBreakDuration(int minutes) async {
    state = state.copyWith(longBreakDuration: minutes);
    await _prefs.setInt('longBreakDuration', minutes);
  }

  Future<void> setStartOfWeekMonday(bool isMonday) async {
    state = state.copyWith(startOfWeekMonday: isMonday);
    await _prefs.setBool('startOfWeekMonday', isMonday);
  }

  Future<void> setAccentColorIndex(int index) async {
    state = state.copyWith(accentColorIndex: index);
    await _prefs.setInt('accentColorIndex', index);
  }

  Future<void> setCustomAccentColor(int colorValue) async {
    state = state.copyWith(customAccentColor: colorValue, accentColorIndex: -1);
    await _prefs.setInt('customAccentColor', colorValue);
    await _prefs.setInt('accentColorIndex', -1);
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    state = state.copyWith(notificationsEnabled: enabled);
    await _prefs.setBool('notificationsEnabled', enabled);
  }

  Future<void> setFiveMinuteWarningEnabled(bool enabled) async {
    state = state.copyWith(fiveMinuteWarningEnabled: enabled);
    await _prefs.setBool('fiveMinuteWarningEnabled', enabled);
  }

  Future<void> setAlarmSoundEnabled(bool enabled) async {
    state = state.copyWith(alarmSoundEnabled: enabled);
    await _prefs.setBool('alarmSoundEnabled', enabled);
  }

  Future<void> setAlarmVibrationEnabled(bool enabled) async {
    state = state.copyWith(alarmVibrationEnabled: enabled);
    await _prefs.setBool('alarmVibrationEnabled', enabled);
  }

  Future<void> setDefaultRingtone(String ringtone) async {
    state = state.copyWith(defaultRingtone: ringtone);
    await _prefs.setString('defaultRingtone', ringtone);
  }

  Future<void> addCustomRingtone(String path) async {
    if (!state.customRingtones.contains(path)) {
      final updated = [...state.customRingtones, path];
      state = state.copyWith(customRingtones: updated);
      await _prefs.setStringList('customRingtones', updated);
    }
  }

  Future<void> removeCustomRingtone(String path) async {
    final updated = state.customRingtones.where((p) => p != path).toList();
    state = state.copyWith(customRingtones: updated);
    await _prefs.setStringList('customRingtones', updated);
    if (state.defaultRingtone == path) {
      await setDefaultRingtone('morning_breeze');
    }
  }
}

final settingsNotifierProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SettingsNotifier(prefs);
});
