import 'package:intl/intl.dart';
import '../models/sleep_diary_entry.dart';
import '../models/sleep_window.dart';

class ClinicalReportService {
  /// Генерация стандартизированного клинического отчета для врача-сомнолога
  static String generateReport({
    required List<SleepDiaryEntry> entries,
    required SleepWindow currentWindow,
    required List<Map<String, dynamic>> isiHistory,
    int days = 14,
  }) {
    final now = DateTime.now();
    final startDate = now.subtract(Duration(days: days));
    final dateFormat = DateFormat('dd.MM.yyyy');

    // Фильтруем записи за период
    final periodEntries = entries.where((e) => e.date.isAfter(startDate)).toList()
      ..sort((a, b) => a.date.compareTo(b.date)); // Хронологический порядок

    final buffer = StringBuffer();

    buffer.writeln('========================================================');
    buffer.writeln('КЛИНИЧЕСКИЙ ОТЧЕТ ДНЕВНИКА СНА (CBT-i)');
    buffer.writeln('Приложение «Сомния» (Локальный экспорт)');
    buffer.writeln('Дата формирования: ${dateFormat.format(now)}');
    buffer.writeln('Период наблюдения: ${dateFormat.format(startDate)} — ${dateFormat.format(now)} ($days дней)');
    buffer.writeln('========================================================\n');

    buffer.writeln('1. ПРЕДПИСАННЫЙ РЕЖИМ СНА (Sleep Window):');
    buffer.writeln('• Время отбоя: ${currentWindow.formattedBedTime}');
    buffer.writeln('• Время подъема: ${currentWindow.formattedWakeTime}');
    buffer.writeln('• Окно в постели: ${currentWindow.formattedDuration}\n');

    if (periodEntries.isEmpty) {
      buffer.writeln('2. СВОДНЫЕ ПОКАЗАТЕЛИ:');
      buffer.writeln('За выбранный период записи в дневнике отсутствуют.\n');
      return buffer.toString();
    }

    // Расчет средних величин
    final int count = periodEntries.length;
    final int sumTIB = periodEntries.fold(0, (acc, e) => acc + e.timeInBedMinutes);
    final int sumTST = periodEntries.fold(0, (acc, e) => acc + e.totalSleepTimeMinutes);
    final int sumSOL = periodEntries.fold(0, (acc, e) => acc + e.solMinutes);
    final int sumWASO = periodEntries.fold(0, (acc, e) => acc + e.wasoMinutes);
    final double sumSE = periodEntries.fold(0.0, (acc, e) => acc + e.sleepEfficiency);

    final avgTIB = sumTIB ~/ count;
    final avgTST = sumTST ~/ count;
    final avgSOL = sumSOL ~/ count;
    final avgWASO = sumWASO ~/ count;
    final avgSE = sumSE / count;

    buffer.writeln('2. СВОДНЫЕ КЛИНИЧЕСКИЕ ПОКАЗАТЕЛИ ЗА $count НОЧЕЙ:');
    buffer.writeln('• Средняя эффективность сна (SE): ${avgSE.toStringAsFixed(1)}% (Норма: ≥ 85%)');
    buffer.writeln('• Среднее время в кровати (TIB): ${avgTIB ~/ 60} ч ${avgTIB % 60} мин');
    buffer.writeln('• Среднее чистое время сна (TST): ${avgTST ~/ 60} ч ${avgTST % 60} мин');
    buffer.writeln('• Среднее время засыпания (SOL): $avgSOL мин');
    buffer.writeln('• Среднее бодрствование ночью (WASO): $avgWASO мин\n');

    // Динамика ISI (Индекс тяжести бессонницы)
    if (isiHistory.isNotEmpty) {
      buffer.writeln('3. ИНДЕКС ВЫРАЖЕННОСТИ БЕССОННИЦЫ (ISI, 0–28 баллов):');
      for (var item in isiHistory) {
        final date = DateTime.tryParse(item['date'] ?? '') ?? now;
        buffer.writeln('• ${dateFormat.format(date)}: ${item['score']} баллов — ${item['title']}');
      }
      buffer.writeln();
    }

    // Посуточный лог ночей
    buffer.writeln('4. ПОСУТОЧНЫЙ ЖУРНАЛ СНА:');
    buffer.writeln('Дата       | Отбой | Подъем| В кровати | Чистый сон | SE %  | Качество');
    buffer.writeln('-----------+-------+-------+-----------+------------+-------+---------');

    for (var e in periodEntries) {
      final dateStr = DateFormat('dd.MM.yy').format(e.date);
      final bedStr = '${e.bedHour.toString().padLeft(2, '0')}:${e.bedMinute.toString().padLeft(2, '0')}';
      final outStr = '${e.outOfBedHour.toString().padLeft(2, '0')}:${e.outOfBedMinute.toString().padLeft(2, '0')}';
      final tibStr = '${e.timeInBedMinutes ~/ 60}ч ${(e.timeInBedMinutes % 60).toString().padLeft(2, '0')}м';
      final tstStr = '${e.totalSleepTimeMinutes ~/ 60}ч ${(e.totalSleepTimeMinutes % 60).toString().padLeft(2, '0')}м';
      final seStr = '${e.sleepEfficiency.toStringAsFixed(1)}%';
      final ratingStr = '${e.qualityRating}/5';

      buffer.writeln(
        '${dateStr.padRight(10)} | ${bedStr.padRight(5)} | ${outStr.padRight(5)} | ${tibStr.padRight(9)} | ${tstStr.padRight(10)} | ${seStr.padRight(5)} | $ratingStr',
      );
    }

    buffer.writeln('\n========================================================');
    buffer.writeln('ПРИМЕЧАНИЕ ДЛЯ СПЕЦИАЛИСТА:');
    buffer.writeln('Данные собраны пациентом самостоятельно с использованием протокола');
    buffer.writeln('когнитивно-поведенческой терапии бессонницы (CBT-i).');
    buffer.writeln('Все расчеты сформированы локально на устройстве без участия внешних серверов.');
    buffer.writeln('========================================================');

    return buffer.toString();
  }
}
