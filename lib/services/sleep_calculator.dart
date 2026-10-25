import '../models/sleep_diary_entry.dart';
import '../models/sleep_window.dart';

enum TitrationAction {
  needMoreData,
  expandWindow,
  maintainWindow,
  restrictWindow,
}

class TitrationResult {
  final TitrationAction action;
  final double averageSleepEfficiency;
  final int averageTstMinutes;
  final int averageTibMinutes;
  final int daysCount;
  final String title;
  final String explanation;
  final SleepWindow? recommendedWindow;

  TitrationResult({
    required this.action,
    required this.averageSleepEfficiency,
    required this.averageTstMinutes,
    required this.averageTibMinutes,
    required this.daysCount,
    required this.title,
    required this.explanation,
    this.recommendedWindow,
  });
}

class SleepCalculator {
  static const int minSafetyWindowMinutesStandard = 300; // 5.0 часов — стандартный порог
  static const int minSafetyWindowMinutesSafeMode = 390; // 6.5 часов — щадящий порог при противопоказаниях
  static const int minRequiredDays = 5; // Минимум 5 ночей за последние 7 дней

  /// Вычисление еженедельной рекомендации титрации окна сна по клиническому протоколу CBT-i
  static TitrationResult evaluateWeeklyTitration({
    required List<SleepDiaryEntry> recentEntries,
    required SleepWindow currentWindow,
    bool isSafeModeSRT = false,
  }) {
    final int minSafetyFloor = isSafeModeSRT
        ? minSafetyWindowMinutesSafeMode
        : minSafetyWindowMinutesStandard;

    // Берем записи за последние 7 дней
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    
    final validEntries = recentEntries.where((e) => e.date.isAfter(sevenDaysAgo)).toList();

    if (validEntries.length < minRequiredDays) {
      return TitrationResult(
        action: TitrationAction.needMoreData,
        averageSleepEfficiency: 0,
        averageTstMinutes: 0,
        averageTibMinutes: 0,
        daysCount: validEntries.length,
        title: 'Недостаточно данных',
        explanation: 'Для клинического расчета окна сна требуется минимум 5 заполненных ночей за неделю. Сейчас заполнено: ${validEntries.length}.',
      );
    }

    double sumSE = 0;
    int sumTST = 0;
    int sumTIB = 0;

    for (var e in validEntries) {
      sumSE += e.sleepEfficiency;
      sumTST += e.totalSleepTimeMinutes;
      sumTIB += e.timeInBedMinutes;
    }

    final double avgSE = sumSE / validEntries.length;
    final int avgTST = sumTST ~/ validEntries.length;
    final int avgTIB = sumTIB ~/ validEntries.length;

    if (avgSE >= 85.0) {
      // Расширяем окно на 15 минут раньше
      final newWindow = _shiftBedtime(currentWindow, -15);
      return TitrationResult(
        action: TitrationAction.expandWindow,
        averageSleepEfficiency: avgSE,
        averageTstMinutes: avgTST,
        averageTibMinutes: avgTIB,
        daysCount: validEntries.length,
        title: 'Расширение окна сна (+15 мин)',
        explanation: 'Превосходно! Ваша средняя эффективность сна составила ${avgSE.toStringAsFixed(1)}% (цель: выше 85%). Мы сдвигаем отбой на 15 минут раньше.',
        recommendedWindow: newWindow,
      );
    } else if (avgSE < 80.0) {
      // Проверяем лимит безопасности (300 минут или 390 минут в Safe-SRT)
      if (currentWindow.windowDurationMinutes - 15 < minSafetyFloor) {
        return TitrationResult(
          action: TitrationAction.maintainWindow,
          averageSleepEfficiency: avgSE,
          averageTstMinutes: avgTST,
          averageTibMinutes: avgTIB,
          daysCount: validEntries.length,
          title: isSafeModeSRT
              ? 'Достигнут щадящий порог (6.5 часов)'
              : 'Достигнут безопасный лимит (5 часов)',
          explanation: isSafeModeSRT
              ? 'Включен щадящий режим Safe-SRT: сокращение окна сна ниже 6.5 часов исключено для защиты здоровья. Сохраняем текущий график и фокусируемся на стимульном контроле.'
              : 'Средняя эффективность сна ${avgSE.toStringAsFixed(1)}%, но окно сна уже достигло безопасного предела в 5 часов. Сохраняем текущий режим и усиливаем стимульный контроль.',
          recommendedWindow: currentWindow,
        );
      }

      // Сужаем окно на 15 минут позже
      final newWindow = _shiftBedtime(currentWindow, 15);
      return TitrationResult(
        action: TitrationAction.restrictWindow,
        averageSleepEfficiency: avgSE,
        averageTstMinutes: avgTST,
        averageTibMinutes: avgTIB,
        daysCount: validEntries.length,
        title: 'Консолидация сна (-15 мин)',
        explanation: 'Эффективность сна составила ${avgSE.toStringAsFixed(1)}% (меньше 80%). Чтобы сон стал более глубоким и непрерывным, мы временно сдвигаем отбой на 15 минут позже.',
        recommendedWindow: newWindow,
      );
    } else {
      // 80% - 85% — идеальная стабилизация
      return TitrationResult(
        action: TitrationAction.maintainWindow,
        averageSleepEfficiency: avgSE,
        averageTstMinutes: avgTST,
        averageTibMinutes: avgTIB,
        daysCount: validEntries.length,
        title: 'Стабилизация режима',
        explanation: 'Эффективность сна составляет ${avgSE.toStringAsFixed(1)}% — это оптимальная зона (80–85%). Режим сна остается неизменным.',
        recommendedWindow: currentWindow,
      );
    }
  }

  static SleepWindow _shiftBedtime(SleepWindow window, int shiftMinutes) {
    int totalBedMinutes = window.bedHour * 60 + window.bedMinute + shiftMinutes;
    if (totalBedMinutes < 0) totalBedMinutes += 24 * 60;
    if (totalBedMinutes >= 24 * 60) totalBedMinutes -= 24 * 60;

    return SleepWindow(
      bedHour: totalBedMinutes ~/ 60,
      bedMinute: totalBedMinutes % 60,
      wakeHour: window.wakeHour,
      wakeMinute: window.wakeMinute,
      lastUpdated: DateTime.now(),
      isActive: true,
    );
  }
}
