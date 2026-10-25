import 'package:flutter_test/flutter_test.dart';
import 'package:somnia/models/sleep_diary_entry.dart';

void main() {
  test('Sleep efficiency calculation test', () {
    final entry = SleepDiaryEntry(
      id: 'test-1',
      date: DateTime.now(),
      bedHour: 23,
      bedMinute: 0,
      trySleepHour: 23,
      trySleepMinute: 15,
      solMinutes: 30, // 30 min to fall asleep
      awakeningsCount: 1,
      wasoMinutes: 30, // 30 min wake at night
      finalWakeHour: 7,
      finalWakeMinute: 0,
      outOfBedHour: 7,
      outOfBedMinute: 0,
      qualityRating: 4,
    );

    // Bed 23:00 to 07:00 = 8 hours = 480 min
    expect(entry.timeInBedMinutes, 480);
    // TST = 480 - 30 - 30 = 420 min (7 hours)
    expect(entry.totalSleepTimeMinutes, 420);
    // SE = 420 / 480 = 87.5%
    expect(entry.sleepEfficiency, 87.5);
  });
}
