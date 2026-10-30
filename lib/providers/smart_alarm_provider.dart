import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../models/smart_alarm_config.dart';
import '../services/sleep_audio_recorder_service.dart';
import '../services/smart_alarm_service.dart';

/// Провайдер умного будильника для UI компонентов
class SmartAlarmProvider extends ChangeNotifier {
  late final SmartAlarmService _service;
  final AudioPlayer _previewPlayer = AudioPlayer();
  String? _currentlyPreviewingSoundId;
  Timer? _countdownTimer;

  SmartAlarmProvider({SleepAudioRecorderService? sleepRecorderService}) {
    _service = SmartAlarmService(sleepRecorderService: sleepRecorderService);
    _service.onStateChanged = notifyListeners;
    _service.onAlarmTriggered = (reason) {
      notifyListeners();
    };
    _init();
    _startCountdownTicker();
  }

  Future<void> _init() async {
    await _service.init();
    notifyListeners();
  }

  void _startCountdownTicker() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_service.config.isEnabled) {
        notifyListeners();
      }
    });
  }

  // Getters
  SmartAlarmConfig get config => _service.config;
  SmartAlarmState get state => _service.state;
  bool get isRinging => _service.isRinging;
  int get currentSnoozeCount => _service.currentSnoozeCount;
  double get currentVolume => _service.currentVolume;
  String? get wakeUpReason => _service.wakeUpReason;
  String? get currentlyPreviewingSoundId => _currentlyPreviewingSoundId;

  DateTime get nextWakeTime => _service.getNextWakeTime();
  DateTime get windowStartTime => _service.getWindowStartTime();

  /// Оставшееся время до будильника
  Duration get timeRemaining {
    final now = DateTime.now();
    final next = nextWakeTime;
    final diff = next.difference(now);
    return diff.isNegative ? Duration.zero : diff;
  }

  String get formattedCountdown {
    final rem = timeRemaining;
    final hours = rem.inHours;
    final minutes = rem.inMinutes % 60;
    if (hours > 0) {
      return 'Через $hours ч $minutes мин';
    }
    return 'Через $minutes мин';
  }

  // Действия
  Future<void> updateConfig(SmartAlarmConfig newConfig) async {
    await _service.saveConfig(newConfig);
    notifyListeners();
  }

  Future<void> toggleEnabled(bool enabled) async {
    await updateConfig(config.copyWith(isEnabled: enabled));
  }

  Future<void> setWakeTime(int hour, int minute) async {
    await updateConfig(config.copyWith(
      wakeHour: hour,
      wakeMinute: minute,
    ));
  }

  Future<void> setSmartWindow(int minutes) async {
    await updateConfig(config.copyWith(smartWindowMinutes: minutes));
  }

  Future<void> setSound(String soundId) async {
    await updateConfig(config.copyWith(soundId: soundId));
  }

  Future<void> setRampUpDuration(int seconds) async {
    await updateConfig(config.copyWith(rampUpDurationSeconds: seconds));
  }

  Future<void> toggleVibration(bool vibrate) async {
    await updateConfig(config.copyWith(vibrate: vibrate));
  }

  Future<void> setRepeatDays(List<int> days) async {
    await updateConfig(config.copyWith(repeatDays: days));
  }

  void snooze() {
    _service.snooze();
    notifyListeners();
  }

  Future<void> dismiss() async {
    await _service.dismiss();
    notifyListeners();
  }

  Future<void> testAlarm() async {
    await stopPreview();
    await _service.testAlarm();
    notifyListeners();
  }

  /// Предварительное прослушивание звука в диалоге выбора
  Future<void> previewSound(String soundId) async {
    if (_currentlyPreviewingSoundId == soundId) {
      await stopPreview();
      return;
    }

    try {
      final opt = AlarmSoundOption.findById(soundId);
      await _previewPlayer.stop();
      await _previewPlayer.setAsset(opt.assetPath);
      await _previewPlayer.setVolume(0.8);
      await _previewPlayer.play();
      _currentlyPreviewingSoundId = soundId;
      notifyListeners();
    } catch (e) {
      debugPrint('[SmartAlarmProvider] Error previewing sound: $e');
    }
  }

  Future<void> stopPreview() async {
    try {
      await _previewPlayer.stop();
    } catch (_) {}
    _currentlyPreviewingSoundId = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _previewPlayer.dispose();
    _service.dispose();
    super.dispose();
  }
}
