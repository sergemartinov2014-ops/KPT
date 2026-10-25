import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:somnia/models/sleep_diary_entry.dart';
import 'package:somnia/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('StorageService deduplicates entries for the same clinical date', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = StorageService(prefs);

    final sameDate = DateTime(2026, 10, 25, 7, 0);

    final entry1 = SleepDiaryEntry(
      id: 'entry-v1',
      date: sameDate,
      bedHour: 23,
      bedMinute: 0,
      trySleepHour: 23,
      trySleepMinute: 15,
      solMinutes: 30,
      awakeningsCount: 1,
      wasoMinutes: 20,
      finalWakeHour: 7,
      finalWakeMinute: 0,
      outOfBedHour: 7,
      outOfBedMinute: 0,
      qualityRating: 3,
      notes: 'First draft',
    );

    // Save initial entry
    await storage.saveDiaryEntry(entry1);
    var list = storage.loadDiaryEntries();
    expect(list.length, 1);
    expect(list.first.notes, 'First draft');

    // Save updated entry for the same night (e.g. user corrected a time)
    final entry2 = SleepDiaryEntry(
      id: 'entry-v2',
      date: sameDate,
      bedHour: 23,
      bedMinute: 30,
      trySleepHour: 23,
      trySleepMinute: 45,
      solMinutes: 20,
      awakeningsCount: 0,
      wasoMinutes: 0,
      finalWakeHour: 7,
      finalWakeMinute: 0,
      outOfBedHour: 7,
      outOfBedMinute: 0,
      qualityRating: 5,
      notes: 'Corrected draft',
    );

    await storage.saveDiaryEntry(entry2);
    list = storage.loadDiaryEntries();

    // Must still have exactly 1 entry (no duplicate!), with updated values
    expect(list.length, 1);
    expect(list.first.id, 'entry-v2');
    expect(list.first.notes, 'Corrected draft');
    expect(list.first.qualityRating, 5);
  });
}
