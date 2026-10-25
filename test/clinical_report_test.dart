import 'package:flutter_test/flutter_test.dart';
import 'package:somnia/models/sleep_diary_entry.dart';
import 'package:somnia/models/sleep_window.dart';
import 'package:somnia/services/clinical_report_service.dart';

void main() {
  group('ClinicalReportService Tests', () {
    final window = SleepWindow(
      bedHour: 23,
      bedMinute: 30,
      wakeHour: 7,
      wakeMinute: 0,
      lastUpdated: DateTime.now(),
    );

    test('Generates empty report without crashing', () {
      final report = ClinicalReportService.generateReport(
        entries: [],
        currentWindow: window,
        isiHistory: [],
        days: 14,
      );

      expect(report.contains('КЛИНИЧЕСКИЙ ОТЧЕТ ДНЕВНИКА СНА (CBT-i)'), isTrue);
      expect(report.contains('За выбранный период записи в дневнике отсутствуют'), isTrue);
      expect(report.contains('Время отбоя: 23:30'), isTrue);
    });

    test('Generates full clinical summary with metrics and ISI trend', () {
      final now = DateTime.now();
      final entries = [
        SleepDiaryEntry(
          id: '1',
          date: now.subtract(const Duration(days: 2)),
          bedHour: 23,
          bedMinute: 30,
          trySleepHour: 23,
          trySleepMinute: 45,
          solMinutes: 20,
          awakeningsCount: 1,
          wasoMinutes: 15,
          finalWakeHour: 7,
          finalWakeMinute: 0,
          outOfBedHour: 7,
          outOfBedMinute: 0,
          qualityRating: 4,
        ),
        SleepDiaryEntry(
          id: '2',
          date: now.subtract(const Duration(days: 1)),
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
          qualityRating: 5,
        ),
      ];

      final isiHistory = [
        {
          'score': 12,
          'title': 'Подпороговая инсомния',
          'date': now.subtract(const Duration(days: 3)).toIso8601String(),
        }
      ];

      final report = ClinicalReportService.generateReport(
        entries: entries,
        currentWindow: window,
        isiHistory: isiHistory,
        days: 14,
      );

      expect(report.contains('СВОДНЫЕ КЛИНИЧЕСКИЕ ПОКАЗАТЕЛИ ЗА 2 НОЧЕЙ'), isTrue);
      expect(report.contains('Средняя эффективность сна (SE):'), isTrue);
      expect(report.contains('ИНДЕКС ВЫРАЖЕННОСТИ БЕССОННИЦЫ (ISI, 0–28 баллов)'), isTrue);
      expect(report.contains('12 баллов — Подпороговая инсомния'), isTrue);
      expect(report.contains('ПОСУТОЧНЫЙ ЖУРНАЛ СНА'), isTrue);
    });
  });
}
