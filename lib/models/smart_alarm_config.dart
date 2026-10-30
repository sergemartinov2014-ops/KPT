import 'package:flutter/foundation.dart';

/// Опция звука будильника
class AlarmSoundOption {
  final String id;
  final String title;
  final String subtitle;
  final String assetPath;

  const AlarmSoundOption({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.assetPath,
  });

  static const List<AlarmSoundOption> available = [
    AlarmSoundOption(
      id: 'morning_breeze',
      title: 'Утренний бриз',
      subtitle: 'Мягкие переливы колокольчиков (Moonap)',
      assetPath: 'assets/audio/alarm/morning_breeze.mp3',
    ),
    AlarmSoundOption(
      id: 'gentle_dawn',
      title: 'Чистый рассвет',
      subtitle: 'Плавная мелодия пробуждения (Moonap)',
      assetPath: 'assets/audio/alarm/gentle_dawn.mp3',
    ),
    AlarmSoundOption(
      id: 'zen_chime',
      title: 'Дзен-колокол',
      subtitle: 'Медитативный гармоничный перезвон',
      assetPath: 'assets/audio/alarm/zen_chime.mp3',
    ),
    AlarmSoundOption(
      id: 'forest_morning',
      title: 'Утро в лесу',
      subtitle: 'Пение птиц и живая природа',
      assetPath: 'assets/audio/alarm/forest_morning.mp3',
    ),
    AlarmSoundOption(
      id: 'tibetan_bowl',
      title: 'Поющая чаша',
      subtitle: 'Глубокий резонансный обертон',
      assetPath: 'assets/audio/ambient/long_bowl.mp3',
    ),
  ];

  static AlarmSoundOption findById(String id) {
    return available.firstWhere(
      (s) => s.id == id,
      orElse: () => available.first,
    );
  }
}

/// Статус состояния умного будильника
enum SmartAlarmState {
  idle,                 // Выключен или ожидает наступления ночи
  scheduled,            // Активен, ожидает окна пробуждения
  monitoringLightSleep, // Внутри окна пробуждения, отслеживает лёгкий сон
  ringing,              // Звенит (идёт плавное нарастание или полная громкость)
  snoozed,              // Отложен на несколько минут
}

/// Конфигурация умного будильника
@immutable
class SmartAlarmConfig {
  final bool isEnabled;
  final int wakeHour;
  final int wakeMinute;
  final int smartWindowMinutes; // 0, 15, 20, 30, 45
  final String soundId;
  final int rampUpDurationSeconds; // 0, 30, 60, 120
  final bool vibrate;
  final int snoozeDurationMinutes; // 5, 9
  final int maxSnoozeCount; // По стандарту CBT-i: максимум 2 повтора
  final List<int> repeatDays; // 1 = Пн, ..., 7 = Вс
  final bool syncWithCbtiWindow; // Синхронизация с целевым подъёмом CBT-i

  const SmartAlarmConfig({
    this.isEnabled = true,
    this.wakeHour = 7,
    this.wakeMinute = 0,
    this.smartWindowMinutes = 30,
    this.soundId = 'morning_breeze',
    this.rampUpDurationSeconds = 60,
    this.vibrate = true,
    this.snoozeDurationMinutes = 5,
    this.maxSnoozeCount = 2,
    this.repeatDays = const [1, 2, 3, 4, 5, 6, 7],
    this.syncWithCbtiWindow = true,
  });

  String get formattedTime =>
      '${wakeHour.toString().padLeft(2, '0')}:${wakeMinute.toString().padLeft(2, '0')}';

  AlarmSoundOption get soundOption => AlarmSoundOption.findById(soundId);

  /// Начало окна умного пробуждения (час:минута)
  String get formattedWindowStart {
    if (smartWindowMinutes == 0) return formattedTime;
    final totalMinutes = wakeHour * 60 + wakeMinute - smartWindowMinutes;
    final normalized = (totalMinutes % (24 * 60) + (24 * 60)) % (24 * 60);
    final h = normalized ~/ 60;
    final m = normalized % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  String get smartWindowLabel {
    if (smartWindowMinutes == 0) {
      return 'Точный сигнал в $formattedTime';
    }
    return '$smartWindowMinutes мин ($formattedWindowStart – $formattedTime)';
  }

  String get repeatDaysLabel {
    if (repeatDays.isEmpty) return 'Один раз';
    if (repeatDays.length == 7) return 'Каждый день';
    if (listEquals(repeatDays, [1, 2, 3, 4, 5])) return 'По будням';
    if (listEquals(repeatDays, [6, 7])) return 'По выходным';
    const dayNames = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    return repeatDays.map((d) => dayNames[d - 1]).join(', ');
  }

  SmartAlarmConfig copyWith({
    bool? isEnabled,
    int? wakeHour,
    int? wakeMinute,
    int? smartWindowMinutes,
    String? soundId,
    int? rampUpDurationSeconds,
    bool? vibrate,
    int? snoozeDurationMinutes,
    int? maxSnoozeCount,
    List<int>? repeatDays,
    bool? syncWithCbtiWindow,
  }) {
    return SmartAlarmConfig(
      isEnabled: isEnabled ?? this.isEnabled,
      wakeHour: wakeHour ?? this.wakeHour,
      wakeMinute: wakeMinute ?? this.wakeMinute,
      smartWindowMinutes: smartWindowMinutes ?? this.smartWindowMinutes,
      soundId: soundId ?? this.soundId,
      rampUpDurationSeconds:
          rampUpDurationSeconds ?? this.rampUpDurationSeconds,
      vibrate: vibrate ?? this.vibrate,
      snoozeDurationMinutes:
          snoozeDurationMinutes ?? this.snoozeDurationMinutes,
      maxSnoozeCount: maxSnoozeCount ?? this.maxSnoozeCount,
      repeatDays: repeatDays ?? this.repeatDays,
      syncWithCbtiWindow: syncWithCbtiWindow ?? this.syncWithCbtiWindow,
    );
  }

  Map<String, dynamic> toJson() => {
        'isEnabled': isEnabled,
        'wakeHour': wakeHour,
        'wakeMinute': wakeMinute,
        'smartWindowMinutes': smartWindowMinutes,
        'soundId': soundId,
        'rampUpDurationSeconds': rampUpDurationSeconds,
        'vibrate': vibrate,
        'snoozeDurationMinutes': snoozeDurationMinutes,
        'maxSnoozeCount': maxSnoozeCount,
        'repeatDays': repeatDays,
        'syncWithCbtiWindow': syncWithCbtiWindow,
      };

  factory SmartAlarmConfig.fromJson(Map<String, dynamic> json) =>
      SmartAlarmConfig(
        isEnabled: json['isEnabled'] as bool? ?? true,
        wakeHour: json['wakeHour'] as int? ?? 7,
        wakeMinute: json['wakeMinute'] as int? ?? 0,
        smartWindowMinutes: json['smartWindowMinutes'] as int? ?? 30,
        soundId: json['soundId'] as String? ?? 'morning_breeze',
        rampUpDurationSeconds: json['rampUpDurationSeconds'] as int? ?? 60,
        vibrate: json['vibrate'] as bool? ?? true,
        snoozeDurationMinutes: json['snoozeDurationMinutes'] as int? ?? 5,
        maxSnoozeCount: json['maxSnoozeCount'] as int? ?? 2,
        repeatDays: (json['repeatDays'] as List<dynamic>?)
                ?.map((e) => e as int)
                .toList() ??
            const [1, 2, 3, 4, 5, 6, 7],
        syncWithCbtiWindow: json['syncWithCbtiWindow'] as bool? ?? true,
      );
}
