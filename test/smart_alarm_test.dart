import 'package:flutter_test/flutter_test.dart';
import 'package:somnia/models/smart_alarm_config.dart';

void main() {
  group('SmartAlarmConfig Tests', () {
    test('Default configuration matches clinical CBT-i and Moonap defaults', () {
      const config = SmartAlarmConfig();

      expect(config.isEnabled, true);
      expect(config.wakeHour, 7);
      expect(config.wakeMinute, 0);
      expect(config.smartWindowMinutes, 30);
      expect(config.soundId, 'morning_breeze');
      expect(config.rampUpDurationSeconds, 60);
      expect(config.vibrate, true);
      expect(config.snoozeDurationMinutes, 5);
      expect(config.maxSnoozeCount, 2); // CBT-i anti-fragmentation limit
      expect(config.repeatDays.length, 7);
      expect(config.formattedTime, '07:00');
      expect(config.formattedWindowStart, '06:30');
    });

    test('Window calculation handles midnight crossing correctly', () {
      const config = SmartAlarmConfig(
        wakeHour: 0,
        wakeMinute: 15,
        smartWindowMinutes: 30,
      );

      expect(config.formattedTime, '00:15');
      expect(config.formattedWindowStart, '23:45');
    });

    test('Exact time alarm (0 min window) formats correctly', () {
      const config = SmartAlarmConfig(
        wakeHour: 8,
        wakeMinute: 30,
        smartWindowMinutes: 0,
      );

      expect(config.smartWindowLabel, 'Точный сигнал в 08:30');
    });

    test('Repeat days labels format properly', () {
      const everyday = SmartAlarmConfig(repeatDays: [1, 2, 3, 4, 5, 6, 7]);
      expect(everyday.repeatDaysLabel, 'Каждый день');

      const workdays = SmartAlarmConfig(repeatDays: [1, 2, 3, 4, 5]);
      expect(workdays.repeatDaysLabel, 'По будням');

      const weekends = SmartAlarmConfig(repeatDays: [6, 7]);
      expect(weekends.repeatDaysLabel, 'По выходным');

      const once = SmartAlarmConfig(repeatDays: []);
      expect(once.repeatDaysLabel, 'Один раз');
    });

    test('Serialization and deserialization preserve all properties', () {
      const original = SmartAlarmConfig(
        isEnabled: false,
        wakeHour: 6,
        wakeMinute: 45,
        smartWindowMinutes: 20,
        soundId: 'zen_chime',
        rampUpDurationSeconds: 120,
        vibrate: false,
        snoozeDurationMinutes: 9,
        maxSnoozeCount: 1,
        repeatDays: [1, 3, 5],
        syncWithCbtiWindow: false,
      );

      final json = original.toJson();
      final restored = SmartAlarmConfig.fromJson(json);

      expect(restored.isEnabled, original.isEnabled);
      expect(restored.wakeHour, original.wakeHour);
      expect(restored.wakeMinute, original.wakeMinute);
      expect(restored.smartWindowMinutes, original.smartWindowMinutes);
      expect(restored.soundId, original.soundId);
      expect(restored.rampUpDurationSeconds, original.rampUpDurationSeconds);
      expect(restored.vibrate, original.vibrate);
      expect(restored.snoozeDurationMinutes, original.snoozeDurationMinutes);
      expect(restored.maxSnoozeCount, original.maxSnoozeCount);
      expect(restored.repeatDays, original.repeatDays);
      expect(restored.syncWithCbtiWindow, original.syncWithCbtiWindow);
    });

    test('AlarmSoundOption finds all available sounds with fallback', () {
      expect(AlarmSoundOption.available.length, 5);

      final sound1 = AlarmSoundOption.findById('morning_breeze');
      expect(sound1.title, 'Утренний бриз');
      expect(sound1.assetPath, 'assets/audio/alarm/morning_breeze.mp3');

      final sound2 = AlarmSoundOption.findById('gentle_dawn');
      expect(sound2.title, 'Чистый рассвет');

      final fallback = AlarmSoundOption.findById('unknown_sound');
      expect(fallback.id, 'morning_breeze');
    });
  });
}
