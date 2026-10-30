import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/smart_alarm_config.dart';
import 'sleep_audio_recorder_service.dart';

/// Сервис умного будильника (Moonap Smart Alarm Engine)
class SmartAlarmService {
  static const String _prefsKey = 'somnia_smart_alarm_config';

  final AudioPlayer _player = AudioPlayer();
  final SleepAudioRecorderService? _sleepRecorderService;

  SmartAlarmConfig _config = const SmartAlarmConfig();
  SmartAlarmState _state = SmartAlarmState.idle;

  // Текущая сессия звонка
  int _currentSnoozeCount = 0;
  String? _wakeUpReason; // 'smart_window' | 'target_time' | 'test'
  DateTime? _wakeUpTriggerTime;
  double _currentVolume = 0.0;
  Timer? _rampUpTimer;
  Timer? _vibrationTimer;
  Timer? _scheduleCheckerTimer;

  // Колбэки для UI и провайдера
  VoidCallback? onStateChanged;
  void Function(String reason)? onAlarmTriggered;

  SmartAlarmService({SleepAudioRecorderService? sleepRecorderService})
      : _sleepRecorderService = sleepRecorderService;

  SmartAlarmConfig get config => _config;
  SmartAlarmState get state => _state;
  bool get isRinging => _state == SmartAlarmState.ringing;
  int get currentSnoozeCount => _currentSnoozeCount;
  String? get wakeUpReason => _wakeUpReason;
  DateTime? get wakeUpTriggerTime => _wakeUpTriggerTime;
  double get currentVolume => _currentVolume;

  /// Инициализация сервиса и загрузка сохранённой конфигурации
  Future<void> init() async {
    await _loadConfig();
    _startScheduleChecker();
  }

  /// Загрузка настроек из SharedPreferences
  Future<void> _loadConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_prefsKey);
      if (jsonStr != null) {
        final Map<String, dynamic> map = jsonDecode(jsonStr);
        _config = SmartAlarmConfig.fromJson(map);
      }
    } catch (e) {
      debugPrint('[SmartAlarmService] Error loading config: $e');
    }
    _updateInitialState();
  }

  /// Сохранение настроек в SharedPreferences
  Future<void> saveConfig(SmartAlarmConfig newConfig) async {
    _config = newConfig;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(_config.toJson()));
    } catch (e) {
      debugPrint('[SmartAlarmService] Error saving config: $e');
    }
    _updateInitialState();
    onStateChanged?.call();
  }

  void _updateInitialState() {
    if (!_config.isEnabled) {
      _state = SmartAlarmState.idle;
    } else if (_state != SmartAlarmState.ringing &&
        _state != SmartAlarmState.snoozed) {
      _state = SmartAlarmState.scheduled;
    }
  }

  /// Запуск периодической проверки времени и окна лёгкого сна
  void _startScheduleChecker() {
    _scheduleCheckerTimer?.cancel();
    _scheduleCheckerTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _evaluateAlarmSchedule(),
    );
  }

  /// Вычисление времени следующего срабатывания
  DateTime getNextWakeTime() {
    final now = DateTime.now();
    var target = DateTime(
      now.year,
      now.month,
      now.day,
      _config.wakeHour,
      _config.wakeMinute,
    );

    // Если время сегодня уже прошло, переносим на завтра
    if (target.isBefore(now)) {
      target = target.add(const Duration(days: 1));
    }

    // Проверка дней недели (1 = Пн, 7 = Вс)
    if (_config.repeatDays.isNotEmpty) {
      while (!_config.repeatDays.contains(target.weekday)) {
        target = target.add(const Duration(days: 1));
      }
    }

    return target;
  }

  /// Начало окна умного пробуждения
  DateTime getWindowStartTime() {
    final next = getNextWakeTime();
    return next.subtract(Duration(minutes: _config.smartWindowMinutes));
  }

  /// Оценка расписания и фазы сна
  void _evaluateAlarmSchedule() {
    if (!_config.isEnabled) return;
    if (_state == SmartAlarmState.ringing || _state == SmartAlarmState.snoozed) {
      return;
    }

    final now = DateTime.now();
    final targetTime = getNextWakeTime();
    final windowStartTime = getWindowStartTime();

    // 1. Наступило целевое время будильника
    if (now.isAfter(targetTime) ||
        now.difference(targetTime).abs() < const Duration(seconds: 10)) {
      triggerAlarm(reason: 'target_time');
      return;
    }

    // 2. Мы внутри умного окна пробуждения
    if (_config.smartWindowMinutes > 0 &&
        now.isAfter(windowStartTime) &&
        now.isBefore(targetTime)) {
      if (_state != SmartAlarmState.monitoringLightSleep) {
        _state = SmartAlarmState.monitoringLightSleep;
        onStateChanged?.call();
      }

      // Проверка активности лёгкого сна (микродвижения / звуки сна из рекордера)
      _checkLightSleepActivity();
    } else {
      if (_state == SmartAlarmState.monitoringLightSleep) {
        _state = SmartAlarmState.scheduled;
        onStateChanged?.call();
      }
    }
  }

  /// Детекция перехода в лёгкий сон
  /// (Адаптированный алгоритм Moonap: всплеск децибел от движения или ворочания)
  void _checkLightSleepActivity() {
    if (_sleepRecorderService == null) return;

    final currentDb = _sleepRecorderService.currentDb;
    // Порог детекции ворочания/пробуждения в окне сна: -36 dB
    const lightSleepTriggerDb = -36.0;

    if (currentDb > lightSleepTriggerDb && currentDb < -5.0) {
      debugPrint(
        '[SmartAlarmService] Light sleep motion/arousal detected ($currentDb dB)! Triggering smart wake.',
      );
      triggerAlarm(reason: 'smart_window');
    }
  }

  /// Запуск звонка будильника
  Future<void> triggerAlarm({required String reason}) async {
    if (_state == SmartAlarmState.ringing) return;

    _state = SmartAlarmState.ringing;
    _wakeUpReason = reason;
    _wakeUpTriggerTime = DateTime.now();
    onStateChanged?.call();
    onAlarmTriggered?.call(reason);

    await _startRingingAudio();
  }

  /// Воспроизведение звука с плавным нарастанием громкости (Volume Ramp-Up)
  Future<void> _startRingingAudio() async {
    try {
      final soundOption = _config.soundOption;
      await _player.stop();
      await _player.setAsset(soundOption.assetPath);
      await _player.setLoopMode(LoopMode.all);

      final rampSeconds = _config.rampUpDurationSeconds;
      if (rampSeconds > 0) {
        _currentVolume = 0.05; // Старт с 5% громкости
        await _player.setVolume(_currentVolume);
        await _player.play();

        _rampUpTimer?.cancel();
        final step = (1.0 - 0.05) / rampSeconds;
        _rampUpTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
          _currentVolume += step;
          if (_currentVolume >= 1.0) {
            _currentVolume = 1.0;
            timer.cancel();
          }
          try {
            await _player.setVolume(_currentVolume);
          } catch (_) {}
          onStateChanged?.call();
        });
      } else {
        _currentVolume = 1.0;
        await _player.setVolume(1.0);
        await _player.play();
      }

      // Вибрация
      if (_config.vibrate && !kIsWeb) {
        _vibrationTimer?.cancel();
        _vibrationTimer = Timer.periodic(const Duration(seconds: 2), (_) {
          HapticFeedback.vibrate();
        });
      }
    } catch (e) {
      debugPrint('[SmartAlarmService] Error playing alarm sound: $e');
    }
  }

  /// Отложить будильник (Snooze)
  void snooze() {
    if (_currentSnoozeCount >= _config.maxSnoozeCount) {
      // Превышен лимит повторов по стандарту CBT-i
      return;
    }

    _stopRingingInternal();
    _currentSnoozeCount++;
    _state = SmartAlarmState.snoozed;
    onStateChanged?.call();

    Timer(Duration(minutes: _config.snoozeDurationMinutes), () {
      if (_state == SmartAlarmState.snoozed) {
        triggerAlarm(reason: 'snooze_repeat');
      }
    });
  }

  /// Полное отключение будильника (Dismiss)
  Future<void> dismiss() async {
    _stopRingingInternal();
    _currentSnoozeCount = 0;
    _wakeUpReason = null;
    _state = _config.isEnabled ? SmartAlarmState.scheduled : SmartAlarmState.idle;

    // Сквозная интеграция: остановка ночной аудиозаписи сна (как в Moonap)
    if (_sleepRecorderService != null && _sleepRecorderService.isMonitoring) {
      await _sleepRecorderService.stopMonitoring();
      debugPrint(
        '[SmartAlarmService] SleepAudioRecorderService automatically stopped upon alarm dismissal.',
      );
    }

    onStateChanged?.call();
  }

  void _stopRingingInternal() {
    _rampUpTimer?.cancel();
    _vibrationTimer?.cancel();
    try {
      _player.stop();
    } catch (_) {}
  }

  /// Тестовый запуск будильника для предварительного прослушивания
  Future<void> testAlarm() async {
    await triggerAlarm(reason: 'test');
  }

  /// Освобождение ресурсов
  void dispose() {
    _scheduleCheckerTimer?.cancel();
    _rampUpTimer?.cancel();
    _vibrationTimer?.cancel();
    _player.dispose();
  }
}
