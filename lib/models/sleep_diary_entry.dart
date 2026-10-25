class SleepDiaryEntry {
  final String id;
  final DateTime date;
  
  // Times in Bed and Sleep
  final int bedHour;
  final int bedMinute;
  
  final int trySleepHour;
  final int trySleepMinute;
  
  final int solMinutes; // Sleep Onset Latency (минут до засыпания)
  final int awakeningsCount; // Количество ночных пробуждений
  final int wasoMinutes; // Wake After Sleep Onset (суммарно минут бодрствования ночью)
  
  final int finalWakeHour;
  final int finalWakeMinute;
  
  final int outOfBedHour;
  final int outOfBedMinute;
  
  final int qualityRating; // 1 to 5 (1 - ужасно, 5 - отлично)
  final int napMinutes; // Дневной сон в минутах
  final String notes;

  SleepDiaryEntry({
    required this.id,
    required this.date,
    required this.bedHour,
    required this.bedMinute,
    required this.trySleepHour,
    required this.trySleepMinute,
    required this.solMinutes,
    required this.awakeningsCount,
    required this.wasoMinutes,
    required this.finalWakeHour,
    required this.finalWakeMinute,
    required this.outOfBedHour,
    required this.outOfBedMinute,
    required this.qualityRating,
    this.napMinutes = 0,
    this.notes = '',
  });

  /// Суммарное время, проведенное в кровати (Time In Bed, TIB) в минутах
  int get timeInBedMinutes {
    int bedTotal = bedHour * 60 + bedMinute;
    int outTotal = outOfBedHour * 60 + outOfBedMinute;
    
    // Если легли до полуночи, а встали после
    if (outTotal < bedTotal) {
      return (24 * 60 - bedTotal) + outTotal;
    }
    return outTotal - bedTotal;
  }

  /// Время в кровати после финального пробуждения до подъема
  int get morningAwakeMinutes {
    int wakeTotal = finalWakeHour * 60 + finalWakeMinute;
    int outTotal = outOfBedHour * 60 + outOfBedMinute;
    if (outTotal >= wakeTotal) {
      return outTotal - wakeTotal;
    }
    return 0;
  }

  /// Чистое время сна (Total Sleep Time, TST) в минутах
  int get totalSleepTimeMinutes {
    int tst = timeInBedMinutes - solMinutes - wasoMinutes - morningAwakeMinutes;
    return tst > 0 ? tst : 0;
  }

  /// Эффективность сна (Sleep Efficiency, SE) в процентах
  double get sleepEfficiency {
    if (timeInBedMinutes <= 0) return 0.0;
    double se = (totalSleepTimeMinutes / timeInBedMinutes) * 100.0;
    if (se > 100.0) return 100.0;
    if (se < 0.0) return 0.0;
    return se;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'bedHour': bedHour,
      'bedMinute': bedMinute,
      'trySleepHour': trySleepHour,
      'trySleepMinute': trySleepMinute,
      'solMinutes': solMinutes,
      'awakeningsCount': awakeningsCount,
      'wasoMinutes': wasoMinutes,
      'finalWakeHour': finalWakeHour,
      'finalWakeMinute': finalWakeMinute,
      'outOfBedHour': outOfBedHour,
      'outOfBedMinute': outOfBedMinute,
      'qualityRating': qualityRating,
      'napMinutes': napMinutes,
      'notes': notes,
    };
  }

  factory SleepDiaryEntry.fromJson(Map<String, dynamic> json) {
    return SleepDiaryEntry(
      id: json['id'],
      date: DateTime.parse(json['date']),
      bedHour: json['bedHour'],
      bedMinute: json['bedMinute'],
      trySleepHour: json['trySleepHour'],
      trySleepMinute: json['trySleepMinute'],
      solMinutes: json['solMinutes'],
      awakeningsCount: json['awakeningsCount'],
      wasoMinutes: json['wasoMinutes'],
      finalWakeHour: json['finalWakeHour'],
      finalWakeMinute: json['finalWakeMinute'],
      outOfBedHour: json['outOfBedHour'],
      outOfBedMinute: json['outOfBedMinute'],
      qualityRating: json['qualityRating'],
      napMinutes: json['napMinutes'] ?? 0,
      notes: json['notes'] ?? '',
    );
  }
}
