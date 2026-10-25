import 'package:flutter_test/flutter_test.dart';
import 'package:somnia/models/sleep_diary_entry.dart';
import 'package:somnia/models/sleep_window.dart';
import 'package:somnia/services/sleep_calculator.dart';

void main() {
  group('SleepDiaryEntry mathematical calculations', () {
    test('Midnight crossing: Bed 23:30, Wake 07:00', () {
      final entry = SleepDiaryEntry(
        id: '1',
        date: DateTime.now(),
        bedHour: 23,
        bedMinute: 30,
        trySleepHour: 23,
        trySleepMinute: 45,
        solMinutes: 30, // 30 min to sleep
        awakeningsCount: 2,
        wasoMinutes: 30, // 30 min wake
        finalWakeHour: 6,
        finalWakeMinute: 45,
        outOfBedHour: 7,
        outOfBedMinute: 0, // 15 min in bed in morning
        qualityRating: 3,
      );

      // TIB: 23:30 to 07:00 = 7.5 hours = 450 min
      expect(entry.timeInBedMinutes, 450);
      // Morning awake: 06:45 to 07:00 = 15 min
      expect(entry.morningAwakeMinutes, 15);
      // TST: 450 - 30 - 30 - 15 = 375 min (6.25 hours)
      expect(entry.totalSleepTimeMinutes, 375);
      // SE: (375 / 450) * 100 = 83.33%
      expect(entry.sleepEfficiency, closeTo(83.33, 0.05));
    });

    test('Zero sleep / sleepless night: TST cannot be negative', () {
      final entry = SleepDiaryEntry(
        id: '2',
        date: DateTime.now(),
        bedHour: 0,
        bedMinute: 0,
        trySleepHour: 0,
        trySleepMinute: 0,
        solMinutes: 300,
        awakeningsCount: 0,
        wasoMinutes: 200,
        finalWakeHour: 6,
        finalWakeMinute: 0,
        outOfBedHour: 6,
        outOfBedMinute: 0,
        qualityRating: 1,
      );

      expect(entry.timeInBedMinutes, 360);
      expect(entry.totalSleepTimeMinutes, 0); // never negative
      expect(entry.sleepEfficiency, 0.0);
    });

    test('Zero TIB does not throw divide-by-zero', () {
      final entry = SleepDiaryEntry(
        id: '3',
        date: DateTime.now(),
        bedHour: 7,
        bedMinute: 0,
        trySleepHour: 7,
        trySleepMinute: 0,
        solMinutes: 0,
        awakeningsCount: 0,
        wasoMinutes: 0,
        finalWakeHour: 7,
        finalWakeMinute: 0,
        outOfBedHour: 7,
        outOfBedMinute: 0,
        qualityRating: 1,
      );

      expect(entry.timeInBedMinutes, 0);
      expect(entry.sleepEfficiency, 0.0);
    });
  });

  group('CBT-i Sleep Titration Protocol (SRT)', () {
    final baseWindow = SleepWindow(
      bedHour: 23,
      bedMinute: 30,
      wakeHour: 7,
      wakeMinute: 0,
      lastUpdated: DateTime.now(),
    );

    test('Fewer than 5 nights returns needMoreData', () {
      final entries = [
        SleepDiaryEntry(
          id: '1',
          date: DateTime.now().subtract(const Duration(days: 1)),
          bedHour: 23,
          bedMinute: 30,
          trySleepHour: 23,
          trySleepMinute: 30,
          solMinutes: 15,
          awakeningsCount: 0,
          wasoMinutes: 0,
          finalWakeHour: 7,
          finalWakeMinute: 0,
          outOfBedHour: 7,
          outOfBedMinute: 0,
          qualityRating: 4,
        ),
      ];

      final result = SleepCalculator.evaluateWeeklyTitration(
        recentEntries: entries,
        currentWindow: baseWindow,
      );

      expect(result.action, TitrationAction.needMoreData);
      expect(result.daysCount, 1);
    });

    test('SE >= 85.0% expands window by 15 min earlier bedtime', () {
      final entries = List.generate(6, (i) {
        return SleepDiaryEntry(
          id: '$i',
          date: DateTime.now().subtract(Duration(days: i + 1)),
          bedHour: 23,
          bedMinute: 30,
          trySleepHour: 23,
          trySleepMinute: 30,
          solMinutes: 15, // High efficiency
          awakeningsCount: 0,
          wasoMinutes: 10,
          finalWakeHour: 7,
          finalWakeMinute: 0,
          outOfBedHour: 7,
          outOfBedMinute: 0,
          qualityRating: 5,
        );
      });

      final result = SleepCalculator.evaluateWeeklyTitration(
        recentEntries: entries,
        currentWindow: baseWindow,
      );

      expect(result.action, TitrationAction.expandWindow);
      expect(result.averageSleepEfficiency, greaterThanOrEqualTo(85.0));
      // 23:30 shifted 15 min earlier = 23:15
      expect(result.recommendedWindow?.bedHour, 23);
      expect(result.recommendedWindow?.bedMinute, 15);
      expect(result.recommendedWindow?.wakeHour, 7);
    });

    test('SE < 80.0% restricts window by 15 min later bedtime', () {
      final entries = List.generate(5, (i) {
        return SleepDiaryEntry(
          id: '$i',
          date: DateTime.now().subtract(Duration(days: i + 1)),
          bedHour: 23,
          bedMinute: 30,
          trySleepHour: 23,
          trySleepMinute: 30,
          solMinutes: 90, // Low efficiency (90 min awake + 60 min waso)
          awakeningsCount: 3,
          wasoMinutes: 60,
          finalWakeHour: 6,
          finalWakeMinute: 30,
          outOfBedHour: 7,
          outOfBedMinute: 0,
          qualityRating: 2,
        );
      });

      final result = SleepCalculator.evaluateWeeklyTitration(
        recentEntries: entries,
        currentWindow: baseWindow,
      );

      expect(result.action, TitrationAction.restrictWindow);
      expect(result.averageSleepEfficiency, lessThan(80.0));
      // 23:30 shifted 15 min later = 23:45
      expect(result.recommendedWindow?.bedHour, 23);
      expect(result.recommendedWindow?.bedMinute, 45);
    });

    test('300-minute safety floor: Never restrict below 5 hours', () {
      // 5-hour window: 02:00 to 07:00 = 300 min
      final narrowWindow = SleepWindow(
        bedHour: 2,
        bedMinute: 0,
        wakeHour: 7,
        wakeMinute: 0,
        lastUpdated: DateTime.now(),
      );

      final entries = List.generate(5, (i) {
        return SleepDiaryEntry(
          id: '$i',
          date: DateTime.now().subtract(Duration(days: i + 1)),
          bedHour: 2,
          bedMinute: 0,
          trySleepHour: 2,
          trySleepMinute: 0,
          solMinutes: 60,
          awakeningsCount: 2,
          wasoMinutes: 60,
          finalWakeHour: 7,
          finalWakeMinute: 0,
          outOfBedHour: 7,
          outOfBedMinute: 0,
          qualityRating: 2,
        );
      });

      final result = SleepCalculator.evaluateWeeklyTitration(
        recentEntries: entries,
        currentWindow: narrowWindow,
      );

      // Must NOT restrict below 300 minutes, must maintain window!
      expect(result.action, TitrationAction.maintainWindow);
      expect(result.recommendedWindow?.windowDurationMinutes, 300);
    });

    test('Safe-SRT Mode: Never restrict below 390 minutes (6.5 hours)', () {
      // 6.5-hour window: 00:30 to 07:00 = 390 min
      final safeWindow = SleepWindow(
        bedHour: 0,
        bedMinute: 30,
        wakeHour: 7,
        wakeMinute: 0,
        lastUpdated: DateTime.now(),
      );

      final entries = List.generate(5, (i) {
        return SleepDiaryEntry(
          id: 'safe-$i',
          date: DateTime.now().subtract(Duration(days: i + 1)),
          bedHour: 0,
          bedMinute: 30,
          trySleepHour: 0,
          trySleepMinute: 30,
          solMinutes: 60,
          awakeningsCount: 2,
          wasoMinutes: 60,
          finalWakeHour: 7,
          finalWakeMinute: 0,
          outOfBedHour: 7,
          outOfBedMinute: 0,
          qualityRating: 2,
        );
      });

      final result = SleepCalculator.evaluateWeeklyTitration(
        recentEntries: entries,
        currentWindow: safeWindow,
        isSafeModeSRT: true, // Включен щадящий режим
      );

      // Must NOT restrict below 390 minutes, must maintain window!
      expect(result.action, TitrationAction.maintainWindow);
      expect(result.recommendedWindow?.windowDurationMinutes, 390);
      expect(result.title.contains('6.5 часов'), isTrue);
    });
  });
}
