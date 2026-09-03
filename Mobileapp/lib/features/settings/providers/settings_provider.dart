import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../app/theme/theme_provider.dart';

final packageInfoProvider = FutureProvider<PackageInfo>((ref) async {
  return await PackageInfo.fromPlatform();
});

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
}

final settingsNotifierProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SettingsNotifier(prefs);
});
