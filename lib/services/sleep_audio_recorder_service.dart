import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/sleep_audio_clip.dart';

class SleepAudioRecorderService {
  static const String _prefsKey = 'saved_sleep_audio_clips';
  static const String _configDelayKey = 'sleep_audio_delay_minutes';
  static const String _configThresholdKey = 'sleep_audio_threshold_db';

  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  final Uuid _uuid = const Uuid();

  // Клинические и системные лимиты (архитектура Moonap)
  double startThresholdDb = -32.0; // Порог активации записи
  double prolongThresholdDb = -36.0; // Порог продления записи
  int silenceTimeoutSeconds = 3; // Таймаут тишины перед остановкой
  int minDurationSeconds = 2; // Минимум (короче 2 сек отсекаются)
  int maxDurationSeconds = 45; // Максимальная длина одного фрагмента
  int maxClipsPerHour = 8; // Лимит записей в час
  int maxClipsPerSession = 50; // Лимит записей за ночь
  int delayMinutes = 20; // Задержка перед началом мониторинга

  bool _isMonitoring = false;
  bool _isWaitingDelay = false;
  bool _isRecordingClip = false;
  double _currentDb = -100.0;

  DateTime? _clipStartTime;
  double _currentClipPeakDb = -100.0;
  String? _currentClipPath;

  int _sessionClipCount = 0;
  int _currentHour = -1;
  int _hourlyClipCount = 0;

  Timer? _delayTimer;
  Timer? _silenceTimer;
  Timer? _maxDurationTimer;
  StreamSubscription<Amplitude>? _amplitudeSubscription;

  final List<SleepAudioClip> _clips = [];
  String? _playingClipId;

  // Callback для уведомления UI
  VoidCallback? onStateChanged;

  bool get isMonitoring => _isMonitoring;
  bool get isWaitingDelay => _isWaitingDelay;
  bool get isRecordingClip => _isRecordingClip;
  double get currentDb => _currentDb;
  int get sessionClipCount => _sessionClipCount;
  List<SleepAudioClip> get clips => List.unmodifiable(_clips);
  String? get playingClipId => _playingClipId;
  AudioPlayer get player => _player;

  SleepAudioRecorderService() {
    _initPlayer();
  }

  void _initPlayer() {
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _playingClipId = null;
        onStateChanged?.call();
      }
    });
  }

  Future<void> loadPersistedData() async {
    final prefs = await SharedPreferences.getInstance();
    delayMinutes = prefs.getInt(_configDelayKey) ?? 20;
    startThresholdDb = prefs.getDouble(_configThresholdKey) ?? -32.0;

    final rawJson = prefs.getString(_prefsKey);
    if (rawJson != null) {
      try {
        final List<dynamic> list = jsonDecode(rawJson) as List<dynamic>;
        _clips.clear();
        for (final item in list) {
          final clip = SleepAudioClip.fromJson(item as Map<String, dynamic>);
          if (File(clip.filePath).existsSync()) {
            _clips.add(clip);
          }
        }
        // Сортировка по времени (свежие сверху)
        _clips.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      } catch (e) {
        debugPrint('Error loading sleep clips: $e');
      }
    }
    onStateChanged?.call();
  }

  Future<void> saveSettings({int? delay, double? threshold}) async {
    final prefs = await SharedPreferences.getInstance();
    if (delay != null) {
      delayMinutes = delay;
      await prefs.setInt(_configDelayKey, delay);
    }
    if (threshold != null) {
      startThresholdDb = threshold;
      await prefs.setDouble(_configThresholdKey, threshold);
    }
    onStateChanged?.call();
  }

  Future<void> _saveClipsToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = _clips.map((c) => c.toJson()).toList();
    await prefs.setString(_prefsKey, jsonEncode(jsonList));
  }

  Future<bool> hasPermission() async {
    return await _recorder.hasPermission();
  }

  Future<Directory> _getRecordsDirectory() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/sleep_records');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Старт ночной сессии мониторинга сна
  Future<bool> startMonitoring({bool bypassDelay = false}) async {
    if (_isMonitoring) return true;

    final perm = await hasPermission();
    if (!perm) return false;

    _isMonitoring = true;
    _sessionClipCount = 0;
    _hourlyClipCount = 0;
    _currentHour = DateTime.now().hour;

    if (delayMinutes > 0 && !bypassDelay) {
      _isWaitingDelay = true;
      onStateChanged?.call();

      _delayTimer?.cancel();
      _delayTimer = Timer(Duration(minutes: delayMinutes), () {
        _isWaitingDelay = false;
        _startListening();
        onStateChanged?.call();
      });
      return true;
    }

    _isWaitingDelay = false;
    await _startListening();
    onStateChanged?.call();
    return true;
  }

  /// Запуск непрерывного прослушивания уровня звука
  Future<void> _startListening() async {
    if (!_isMonitoring) return;

    // Стриминг амплитуды каждые 200 миллисекунд
    _amplitudeSubscription?.cancel();
    _amplitudeSubscription = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 200))
        .listen((amp) {
      _processAmplitude(amp.current);
    });

    // Начинаем тихую запись для чтения амплитуды
    final recordsDir = await _getRecordsDirectory();
    final tempMonitorFile = '${recordsDir.path}/temp_noise_monitor.m4a';

    try {
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 44100,
          bitRate: 64000,
        ),
        path: tempMonitorFile,
      );
    } catch (e) {
      debugPrint('Error starting sound monitor: $e');
    }
  }

  void _processAmplitude(double currentAmplitudeDb) {
    _currentDb = currentAmplitudeDb;

    final now = DateTime.now();
    if (now.hour != _currentHour) {
      _currentHour = now.hour;
      _hourlyClipCount = 0;
    }

    // Если прямо сейчас идет запись фрагмента события:
    if (_isRecordingClip) {
      if (currentAmplitudeDb > _currentClipPeakDb) {
        _currentClipPeakDb = currentAmplitudeDb;
      }

      // Продлеваем запись, если шум продолжается
      if (currentAmplitudeDb >= prolongThresholdDb) {
        _silenceTimer?.cancel();
        _silenceTimer = Timer(Duration(seconds: silenceTimeoutSeconds), () {
          _finalizeCurrentClip();
        });
      }
      onStateChanged?.call();
      return;
    }

    // Если запись фрагмента не идет — проверяем превышение порога шума
    if (currentAmplitudeDb >= startThresholdDb) {
      if (_sessionClipCount >= maxClipsPerSession) {
        debugPrint('Max session clips limit reached ($maxClipsPerSession)');
        return;
      }
      if (_hourlyClipCount >= maxClipsPerHour) {
        debugPrint('Max hourly clips limit reached ($maxClipsPerHour)');
        return;
      }

      _startClipRecording();
    }

    onStateChanged?.call();
  }

  Future<void> _startClipRecording() async {
    if (_isRecordingClip) return;
    _isRecordingClip = true;
    _clipStartTime = DateTime.now();
    _currentClipPeakDb = _currentDb;

    final recordsDir = await _getRecordsDirectory();
    final timestampStr = _clipStartTime!.millisecondsSinceEpoch;
    _currentClipPath = '${recordsDir.path}/sleep_clip_$timestampStr.m4a';

    // Таймаут тишины
    _silenceTimer?.cancel();
    _silenceTimer = Timer(Duration(seconds: silenceTimeoutSeconds), () {
      _finalizeCurrentClip();
    });

    // Защита от бесконечной записи
    _maxDurationTimer?.cancel();
    _maxDurationTimer = Timer(Duration(seconds: maxDurationSeconds), () {
      _finalizeCurrentClip();
    });

    onStateChanged?.call();
  }

  Future<void> _finalizeCurrentClip() async {
    if (!_isRecordingClip) return;

    _silenceTimer?.cancel();
    _maxDurationTimer?.cancel();

    final startTime = _clipStartTime ?? DateTime.now();
    final durationSec = DateTime.now().difference(startTime).inSeconds;

    _isRecordingClip = false;
    _clipStartTime = null;

    // Фильтр отсечки слишком коротких звуков (< 2 сек)
    if (durationSec < minDurationSeconds) {
      if (_currentClipPath != null) {
        final f = File(_currentClipPath!);
        if (f.existsSync()) {
          try {
            await f.delete();
          } catch (_) {}
        }
      }
      _currentClipPath = null;
      onStateChanged?.call();
      return;
    }

    // Сохраняем полноценный клип
    if (_currentClipPath != null) {
      // Классификация типа звука
      SleepSoundType type;
      if (durationSec > 6 && _currentClipPeakDb > -26) {
        type = SleepSoundType.snore;
      } else if (durationSec > 3 && _currentClipPeakDb > -22) {
        type = SleepSoundType.talk;
      } else {
        type = SleepSoundType.movement;
      }

      final clip = SleepAudioClip(
        id: _uuid.v4(),
        filePath: _currentClipPath!,
        timestamp: startTime,
        durationSeconds: durationSec,
        peakDecibels: _currentClipPeakDb,
        soundType: type,
      );

      _clips.insert(0, clip);
      _sessionClipCount++;
      _hourlyClipCount++;
      await _saveClipsToPrefs();
    }

    _currentClipPath = null;
    onStateChanged?.call();
  }

  /// Остановка ночного мониторинга
  Future<void> stopMonitoring() async {
    _delayTimer?.cancel();
    _silenceTimer?.cancel();
    _maxDurationTimer?.cancel();
    await _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;

    if (_isRecordingClip) {
      await _finalizeCurrentClip();
    }

    try {
      if (await _recorder.isRecording()) {
        await _recorder.stop();
      }
    } catch (e) {
      debugPrint('Error stopping recorder: $e');
    }

    _isMonitoring = false;
    _isWaitingDelay = false;
    _isRecordingClip = false;
    _currentDb = -100.0;
    onStateChanged?.call();
  }

  /// Воспроизведение конкретного клипа
  Future<void> playClip(SleepAudioClip clip) async {
    if (_playingClipId == clip.id && _player.playing) {
      await _player.pause();
      _playingClipId = null;
      onStateChanged?.call();
      return;
    }

    try {
      await _player.stop();
      await _player.setFilePath(clip.filePath);
      _playingClipId = clip.id;
      await _player.play();
    } catch (e) {
      debugPrint('Error playing clip: $e');
      _playingClipId = null;
    }
    onStateChanged?.call();
  }

  Future<void> stopPlaying() async {
    await _player.stop();
    _playingClipId = null;
    onStateChanged?.call();
  }

  /// Удаление клипа
  Future<void> deleteClip(String id) async {
    final index = _clips.indexWhere((c) => c.id == id);
    if (index != -1) {
      final clip = _clips[index];
      if (_playingClipId == id) {
        await stopPlaying();
      }
      final file = File(clip.filePath);
      if (file.existsSync()) {
        try {
          await file.delete();
        } catch (_) {}
      }
      _clips.removeAt(index);
      await _saveClipsToPrefs();
      onStateChanged?.call();
    }
  }

  /// Удаление всех записей
  Future<void> clearAllClips() async {
    await stopPlaying();
    for (final clip in _clips) {
      final file = File(clip.filePath);
      if (file.existsSync()) {
        try {
          await file.delete();
        } catch (_) {}
      }
    }
    _clips.clear();
    await _saveClipsToPrefs();
    onStateChanged?.call();
  }

  void dispose() {
    _delayTimer?.cancel();
    _silenceTimer?.cancel();
    _maxDurationTimer?.cancel();
    _amplitudeSubscription?.cancel();
    _recorder.dispose();
    _player.dispose();
  }
}
