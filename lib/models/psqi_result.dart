/// Результат Питтсбургского индекса качества сна (PSQI).
///
/// Оцениваются 7 стандартных компонентов C1–C7, каждый 0–3 балла.
/// Итоговый индекс: 0–21; значение выше 5 считается клинически значимым
/// нарушением качества сна за последний месяц.
class PsqiResult {
  final DateTime date;
  final int c1;
  final int c2;
  final int c3;
  final int c4;
  final int c5;
  final int c6;
  final int c7;
  final int total;

  final double sleepEfficiency;
  final double hoursSlept;
  final int latencyMinutes;

  const PsqiResult({
    required this.date,
    required this.c1,
    required this.c2,
    required this.c3,
    required this.c4,
    required this.c5,
    required this.c6,
    required this.c7,
    required this.total,
    required this.sleepEfficiency,
    required this.hoursSlept,
    required this.latencyMinutes,
  });

  bool get isPoorSleep => total > 5;

  String get title {
    if (total <= 5) return 'Хорошее качество сна';
    if (total <= 10) return 'Умеренно нарушенное качество сна';
    if (total <= 15) return 'Плохое качество сна';
    return 'Очень плохое качество сна';
  }

  String get description {
    if (total <= 5) {
      return 'Индекс PSQI не превышает клинический порог. Сон за последний месяц '
          'восстанавливающий, продолжайте поддерживать регулярный режим.';
    }
    if (total <= 10) {
      return 'Есть отдельные нарушения сна. Полезно усилить гигиену сна, '
          'стимульный контроль и вести дневник сна для отслеживания динамики.';
    }
    if (total <= 15) {
      return 'Качество сна заметно снижено. Рекомендуется продолжить программу '
          'CBT-i и обсудить результаты с врачом-сомнологом.';
    }
    return 'Выраженное нарушение качества сна. Настоятельно рекомендуется '
        'очная консультация сомнолога в сочетании с протоколом CBT-i.';
  }

  List<Map<String, dynamic>> get components => [
        {'label': 'C1 · Субъективное качество сна', 'score': c1},
        {'label': 'C2 · Латентность сна', 'score': c2},
        {'label': 'C3 · Длительность сна', 'score': c3},
        {'label': 'C4 · Эффективность сна', 'score': c4},
        {'label': 'C5 · Нарушения сна', 'score': c5},
        {'label': 'C6 · Приём снотворных', 'score': c6},
        {'label': 'C7 · Дневная дисфункция', 'score': c7},
      ];

  /// Расчет результата по «сырым» ответам опросника.
  factory PsqiResult.calculate({
    required DateTime date,
    required int subjectiveQuality, // Q6, 0–3
    required int latencyMinutes, // Q2
    required int sleepLatencyFrequency, // Q5a, 0–3
    required double hoursSlept, // Q4
    required DateTime bedTime, // Q1
    required DateTime wakeTime, // Q3
    required int sleepDisturbanceSum, // сумма Q5b–Q5j, 0–27
    required int medicationFrequency, // Q7, 0–3
    required int daytimeSleepinessFrequency, // Q8, 0–3
    required int enthusiasmDifficulty, // Q9, 0–3
  }) {
    // C1 — субъективное качество сна.
    final c1 = subjectiveQuality.clamp(0, 3);

    // C2 — латентность: код времени засыпания + частота Q5a.
    final latencyCode = latencyMinutes <= 15
        ? 0
        : (latencyMinutes <= 30 ? 1 : (latencyMinutes <= 60 ? 2 : 3));
    final c2 = _bucketComponent(latencyCode + sleepLatencyFrequency);

    // C3 — фактическая длительность сна.
    final c3 = hoursSlept > 7
        ? 0
        : (hoursSlept >= 6 ? 1 : (hoursSlept >= 5 ? 2 : 3));

    // C4 — эффективность сна (TST / TIB).
    var tibMinutes = wakeTime.difference(bedTime).inMinutes;
    if (tibMinutes <= 0) tibMinutes += 24 * 60;
    if (tibMinutes <= 0) tibMinutes = 1;
    final tstMinutes = (hoursSlept * 60).clamp(0, tibMinutes.toDouble());
    final efficiency = (tstMinutes / tibMinutes * 100).clamp(0.0, 100.0);
    final c4 = efficiency >= 85
        ? 0
        : (efficiency >= 75 ? 1 : (efficiency >= 65 ? 2 : 3));

    // C5 — сумма нарушений сна Q5b–Q5j.
    final c5 = sleepDisturbanceSum <= 0
        ? 0
        : (sleepDisturbanceSum <= 9
            ? 1
            : (sleepDisturbanceSum <= 18 ? 2 : 3));

    // C6 — приём снотворных.
    final c6 = medicationFrequency.clamp(0, 3);

    // C7 — дневная дисфункция (Q8 + Q9).
    final daytimeSum =
        (daytimeSleepinessFrequency + enthusiasmDifficulty).clamp(0, 6);
    final c7 = daytimeSum == 0
        ? 0
        : (daytimeSum <= 2 ? 1 : (daytimeSum <= 4 ? 2 : 3));

    final total = c1 + c2 + c3 + c4 + c5 + c6 + c7;

    return PsqiResult(
      date: date,
      c1: c1,
      c2: c2,
      c3: c3,
      c4: c4,
      c5: c5,
      c6: c6,
      c7: c7,
      total: total,
      sleepEfficiency: double.parse(efficiency.toStringAsFixed(1)),
      hoursSlept: hoursSlept,
      latencyMinutes: latencyMinutes,
    );
  }

  static int _bucketComponent(int sum) {
    if (sum <= 0) return 0;
    if (sum <= 2) return 1;
    if (sum <= 4) return 2;
    return 3;
  }

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'c1': c1,
        'c2': c2,
        'c3': c3,
        'c4': c4,
        'c5': c5,
        'c6': c6,
        'c7': c7,
        'total': total,
        'sleepEfficiency': sleepEfficiency,
        'hoursSlept': hoursSlept,
        'latencyMinutes': latencyMinutes,
      };

  factory PsqiResult.fromJson(Map<String, dynamic> json) => PsqiResult(
        date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
        c1: (json['c1'] as num?)?.toInt() ?? 0,
        c2: (json['c2'] as num?)?.toInt() ?? 0,
        c3: (json['c3'] as num?)?.toInt() ?? 0,
        c4: (json['c4'] as num?)?.toInt() ?? 0,
        c5: (json['c5'] as num?)?.toInt() ?? 0,
        c6: (json['c6'] as num?)?.toInt() ?? 0,
        c7: (json['c7'] as num?)?.toInt() ?? 0,
        total: (json['total'] as num?)?.toInt() ?? 0,
        sleepEfficiency:
            (json['sleepEfficiency'] as num?)?.toDouble() ?? 0.0,
        hoursSlept: (json['hoursSlept'] as num?)?.toDouble() ?? 0.0,
        latencyMinutes: (json['latencyMinutes'] as num?)?.toInt() ?? 0,
      );
}
