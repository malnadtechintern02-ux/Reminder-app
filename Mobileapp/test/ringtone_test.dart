import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:reminder_app/features/settings/providers/settings_provider.dart';

void main() {
  group('Ringtone Provider and Helper Tests', () {
    test('formatRingtoneName should return expected names', () {
      // Null or empty returns default
      expect(formatRingtoneName(null), 'Morning Breeze');
      expect(formatRingtoneName(''), 'Morning Breeze');

      // Built-in tones return readable names
      expect(formatRingtoneName('morning_breeze'), 'Morning Breeze');
      expect(formatRingtoneName('calm_bell'), 'Calm Bell');
      expect(formatRingtoneName('classic_modern'), 'Classic Modern');

      // Custom tone file paths return basename
      expect(formatRingtoneName('/data/user/0/com.app/Ringtones/my_custom_ringtone.mp3'), 'my_custom_ringtone.mp3');
      expect(formatRingtoneName(r'C:\Users\test\Ringtones\alarm_melody.wav'), 'alarm_melody.wav');
    });

    test('builtInRingtones should contain 12 modern alarm tones', () {
      expect(builtInRingtones.length, 12);
      expect(builtInRingtones.any((r) => r.id == 'morning_breeze'), true);
      expect(builtInRingtones.any((r) => r.id == 'soft_sunrise'), true);
      expect(builtInRingtones.any((r) => r.id == 'bright_morning'), true);
    });

    test('SettingsNotifier should manage custom ringtones properly', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final notifier = SettingsNotifier(prefs);

      // Initially default ringtone is morning_breeze and custom list is empty
      expect(notifier.state.defaultRingtone, 'morning_breeze');
      expect(notifier.state.customRingtones, isEmpty);

      // Add a custom ringtone
      const customPath1 = '/storage/emulated/0/Ringtones/peaceful_bell.mp3';
      await notifier.addCustomRingtone(customPath1);
      expect(notifier.state.customRingtones, contains(customPath1));
      expect(prefs.getStringList('customRingtones'), contains(customPath1));

      // Adding duplicate custom ringtone should not duplicate in the list
      await notifier.addCustomRingtone(customPath1);
      expect(notifier.state.customRingtones.length, 1);

      // Add a second custom ringtone
      const customPath2 = '/storage/emulated/0/Ringtones/energetic_alarm.mp3';
      await notifier.addCustomRingtone(customPath2);
      expect(notifier.state.customRingtones.length, 2);

      // Set custom ringtone as default
      await notifier.setDefaultRingtone(customPath1);
      expect(notifier.state.defaultRingtone, customPath1);
      expect(prefs.getString('defaultRingtone'), customPath1);

      // Remove the non-active custom ringtone
      await notifier.removeCustomRingtone(customPath2);
      expect(notifier.state.customRingtones, isNot(contains(customPath2)));
      expect(notifier.state.defaultRingtone, customPath1);

      // Remove the currently active custom ringtone -> should fall back to morning_breeze
      await notifier.removeCustomRingtone(customPath1);
      expect(notifier.state.customRingtones, isNot(contains(customPath1)));
      expect(notifier.state.defaultRingtone, 'morning_breeze');
      expect(prefs.getString('defaultRingtone'), 'morning_breeze');
    });
  });
}
