import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:somnia/models/psqi_result.dart';
import 'package:somnia/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PsqiResult scoring', () {
    test('Healthy sleeper gets zero PSQI and good quality', () {
      final result = PsqiResult.calculate(
        date: DateTime(2026, 11, 1),
        subjectiveQuality: 0,
        latencyMinutes: 10,
        sleepLatencyFrequency: 0,
        hoursSlept: 8,
        bedTime: DateTime(2000, 1, 1, 23, 0),
        wakeTime: DateTime(2000, 1, 1, 7, 0),
        sleepDisturbanceSum: 0,
        medicationFrequency: 0,
        daytimeSleepinessFrequency: 0,
        enthusiasmDifficulty: 0,
      );

      expect(result.c1, 0);
      expect(result.c2, 0);
      expect(result.c3, 0);
      expect(result.c4, 0);
      expect(result.c5, 0);
      expect(result.c6, 0);
      expect(result.c7, 0);
      expect(result.total, 0);
      expect(result.isPoorSleep, isFalse);
      expect(result.title, 'Хорошее качество сна');
    });

    test('Severe insomnia reaches 19 points and poor sleep', () {
      final result = PsqiResult.calculate(
        date: DateTime(2026, 11, 1),
        subjectiveQuality: 3,
        latencyMinutes: 90,
        sleepLatencyFrequency: 3,
        hoursSlept: 4.5,
        bedTime: DateTime(2000, 1, 1, 1, 0),
        wakeTime: DateTime(2000, 1, 1, 7, 0),
        sleepDisturbanceSum: 20,
        medicationFrequency: 3,
        daytimeSleepinessFrequency: 3,
        enthusiasmDifficulty: 3,
      );

      expect(result.c1, 3);
      expect(result.c2, 3); // latency code 3 + Q5a 3 = 6
      expect(result.c3, 3); // < 5 часов
      expect(result.c4, 1); // SE = 75%
      expect(result.c5, 3); // 20 баллов нарушений
      expect(result.c6, 3);
      expect(result.c7, 3); // Q8 + Q9 = 6
      expect(result.total, 19);
      expect(result.isPoorSleep, isTrue);
    });

    test('Latency component follows the 0–3 bucketing', () {
      final result = PsqiResult.calculate(
        date: DateTime(2026, 11, 1),
        subjectiveQuality: 1,
        latencyMinutes: 45, // code 2
        sleepLatencyFrequency: 1, // сумма 3
        hoursSlept: 6.5,
        bedTime: DateTime(2000, 1, 1, 23, 30),
        wakeTime: DateTime(2000, 1, 1, 7, 0),
        sleepDisturbanceSum: 9,
        medicationFrequency: 1,
        daytimeSleepinessFrequency: 1,
        enthusiasmDifficulty: 1,
      );

      expect(result.c1, 1);
      expect(result.c2, 2);
      expect(result.c3, 1); // 6–7 часов
      expect(result.c5, 1); // 1–9 нарушений
      expect(result.c7, 1); // сумма 2
    });

    test('Serialization round-trip preserves all components', () {
      final result = PsqiResult.calculate(
        date: DateTime(2026, 10, 15),
        subjectiveQuality: 2,
        latencyMinutes: 30,
        sleepLatencyFrequency: 2,
        hoursSlept: 6,
        bedTime: DateTime(2000, 1, 1, 0, 0),
        wakeTime: DateTime(2000, 1, 1, 7, 0),
        sleepDisturbanceSum: 12,
        medicationFrequency: 1,
        daytimeSleepinessFrequency: 2,
        enthusiasmDifficulty: 1,
      );

      final restored = PsqiResult.fromJson(result.toJson());

      expect(restored.date, result.date);
      expect(restored.c1, result.c1);
      expect(restored.c2, result.c2);
      expect(restored.c3, result.c3);
      expect(restored.c4, result.c4);
      expect(restored.c5, result.c5);
      expect(restored.c6, result.c6);
      expect(restored.c7, result.c7);
      expect(restored.total, result.total);
      expect(restored.sleepEfficiency, result.sleepEfficiency);
    });
  });

  group('PSQI storage', () {
    test('Saves history and clears it with all user data', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = StorageService(prefs);

      final result = PsqiResult.calculate(
        date: DateTime(2026, 11, 1),
        subjectiveQuality: 1,
        latencyMinutes: 20,
        sleepLatencyFrequency: 1,
        hoursSlept: 7,
        bedTime: DateTime(2000, 1, 1, 23, 0),
        wakeTime: DateTime(2000, 1, 1, 7, 0),
        sleepDisturbanceSum: 5,
        medicationFrequency: 0,
        daytimeSleepinessFrequency: 1,
        enthusiasmDifficulty: 1,
      );

      await storage.savePsqiResult(result.toJson());
      final history = storage.loadPsqiHistory();
      expect(history.length, 1);
      expect(history.first['total'], result.total);

      await storage.clearAllData();
      expect(storage.loadPsqiHistory(), isEmpty);
    });
  });
}
