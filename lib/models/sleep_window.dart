class SleepWindow {
  final int bedHour;
  final int bedMinute;
  final int wakeHour;
  final int wakeMinute;
  final DateTime lastUpdated;
  final bool isActive;

  const SleepWindow({
    required this.bedHour,
    required this.bedMinute,
    required this.wakeHour,
    required this.wakeMinute,
    required this.lastUpdated,
    this.isActive = true,
  });

  /// Длительность назначенного окна сна в минутах
  int get windowDurationMinutes {
    int bedTotal = bedHour * 60 + bedMinute;
    int wakeTotal = wakeHour * 60 + wakeMinute;
    if (wakeTotal < bedTotal) {
      return (24 * 60 - bedTotal) + wakeTotal;
    }
    return wakeTotal - bedTotal;
  }

  String get formattedBedTime =>
      '${bedHour.toString().padLeft(2, '0')}:${bedMinute.toString().padLeft(2, '0')}';

  String get formattedWakeTime =>
      '${wakeHour.toString().padLeft(2, '0')}:${wakeMinute.toString().padLeft(2, '0')}';

  String get formattedDuration {
    int hours = windowDurationMinutes ~/ 60;
    int mins = windowDurationMinutes % 60;
    if (mins == 0) return '$hours ч';
    return '$hours ч $mins мин';
  }

  Map<String, dynamic> toJson() => {
        'bedHour': bedHour,
        'bedMinute': bedMinute,
        'wakeHour': wakeHour,
        'wakeMinute': wakeMinute,
        'lastUpdated': lastUpdated.toIso8601String(),
        'isActive': isActive,
      };

  factory SleepWindow.fromJson(Map<String, dynamic> json) => SleepWindow(
        bedHour: json['bedHour'],
        bedMinute: json['bedMinute'],
        wakeHour: json['wakeHour'],
        wakeMinute: json['wakeMinute'],
        lastUpdated: DateTime.parse(json['lastUpdated']),
        isActive: json['isActive'] ?? true,
      );

  static SleepWindow defaultWindow() => SleepWindow(
        bedHour: 23,
        bedMinute: 30,
        wakeHour: 7,
        wakeMinute: 0,
        lastUpdated: DateTime.now(),
        isActive: true,
      );
}
