import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/sleep_audio_clip.dart';
import '../models/sleep_audio_event.dart';
import 'audio_event_classifier.dart';

/// Ночной монитор звуков сна.
///
/// Работает на непрерывном PCM-потоке (`record.startStream`): уровень
/// громкости считается в Dart по RMS, поэтому порог срабатывания и пиковые
/// значения реально совпадают с тем, что записано в файл. Каждое событие
/// сохраняется как самостоятельный WAV-файл, пригодный для воспроизведения
/// без какого-либо дополнительного перекодирования.
class SleepAudioRecorderService {
  static const String _prefsKey = 'saved_sleep_audio_clips';
  static const String _eventsKey = 'saved_sleep_audio_events';
  static const String _configDelayKey = 'sleep_audio_delay_minutes';
  static const String _configThresholdKey = 'sleep_audio_threshold_db';

  static const int _sampleRate = 16000;
  static const int _channels = 1;
  static const int _bitsPerSample = 16;
  static const int _bytesPerSample = _bitsPerSample ~/ 8;
  static const int _wavHeaderSize = 44;
  static const int _preRollSeconds = 2;
  static const int _retentionDays = 7;
  static const int _eventRetentionDays = 30;
  static const int _maxEvents = 5000;
  static const int _maxStorageBytes = 250 * 1024 * 1024; // ~250 МБ

  /// Окно оценки шумового пола и его перцентиль (спецификация v2).
  static const int _floorWindowSeconds = 60;
  static const double _floorPercentile = 0.10;

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
  String? _lastError;

  /// Адаптивный шумовой пол: 10-й перцентиль уровня чанков за ~60 с.
  double _noiseFloorDb = -60.0;
  final List<_LevelSample> _levelHistory = <_LevelSample>[];
  DateTime _lastFloorUpdate = DateTime.fromMillisecondsSinceEpoch(0);

  DateTime? _clipStartTime;
  double _currentClipPeakDb = -100.0;
  BytesBuilder? _clipBuffer;
  int _clipBytes = 0;

  /// Кольцевой буфер сырых PCM-байтов (~2 секунды до события), чтобы клип
  /// начинался не с середины звука.
  final List<Uint8List> _preRoll = [];
  int _preRollBytes = 0;

  int _sessionClipCount = 0;
  int _currentHour = -1;
  int _hourlyClipCount = 0;

  Timer? _delayTimer;
  Timer? _silenceTimer;
  Timer? _maxDurationTimer;
  StreamSubscription<Uint8List>? _pcmSubscription;

  /// Ограничитель частоты обновления UI индикатора уровня.
  DateTime _lastLevelNotify = DateTime.fromMillisecondsSinceEpoch(0);

  final List<SleepAudioClip> _clips = [];
  final List<SleepAudioEvent> _events = [];
  String? _playingClipId;

  // Callback для уведомления UI
  VoidCallback? onStateChanged;

  bool get isMonitoring => _isMonitoring;
  bool get isWaitingDelay => _isWaitingDelay;
  bool get isRecordingClip => _isRecordingClip;
  double get currentDb => _currentDb;
  int get sessionClipCount => _sessionClipCount;
  List<SleepAudioClip> get clips => List.unmodifiable(_clips);
  List<SleepAudioEvent> get events => List.unmodifiable(_events);
  String? get playingClipId => _playingClipId;
  AudioPlayer get player => _player;

  /// Текущая оценка шумового пола, dBFS.
  double get noiseFloorDb => _noiseFloorDb;

  /// Фактический порог старта: настраиваемая чувствительность (не ниже
  /// абсолютной границы) и шумовой пол + 10 дБ.
  double get triggerThresholdDb =>
      math.max(startThresholdDb, _noiseFloorDb + 10.0);

  /// Фактический порог удержания: пол + 6 дБ, но не выше старта − 4 дБ.
  double get holdThresholdDb =>
      math.max(startThresholdDb - 4.0, _noiseFloorDb + 6.0);

  /// Текст последней ошибки (микрофон/файл/воспроизведение) для UI.
  String? get lastError => _lastError;

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
          final resolved = await _clipAbsolutePath(clip);
          if (await File(resolved).exists()) {
            // Миграция старых записей: оставляем только имя файла.
            _clips.add(
              clip.filePath == clip.fileName
                  ? clip
                  : clip.copyWith(filePath: clip.fileName),
            );
          }
        }
        _clips.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      } catch (e) {
        debugPrint('Error loading sleep clips: $e');
      }
    }

    final rawEvents = prefs.getString(_eventsKey);
    if (rawEvents != null) {
      try {
        final List<dynamic> list = jsonDecode(rawEvents) as List<dynamic>;
        _events
          ..clear()
          ..addAll(
            list.map(
              (item) => SleepAudioEvent.fromJson(item as Map<String, dynamic>),
            ),
          );
        _trimEvents();
        _events.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      } catch (e) {
        debugPrint('Error loading sleep events: $e');
      }
    }

    try {
      await _enforceRetention();
      await _cleanupOrphanFiles();
    } catch (e) {
      debugPrint('Error cleaning sleep records: $e');
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

  Future<void> _saveEventsToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = _events.map((e) => e.toJson()).toList();
    await prefs.setString(_eventsKey, jsonEncode(jsonList));
  }

  void _trimEvents() {
    final cutoff =
        DateTime.now().subtract(const Duration(days: _eventRetentionDays));
    _events.removeWhere((event) => event.timestamp.isBefore(cutoff));
    if (_events.length > _maxEvents) {
      _events.removeRange(_maxEvents, _events.length);
    }
  }

  Future<bool> hasPermission() async {
    return await _recorder.hasPermission();
  }

  Future<Directory> _getRecordsDirectory() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}${Platform.pathSeparator}sleep_records');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<String> _clipAbsolutePath(SleepAudioClip clip) async {
    final dir = await _getRecordsDirectory();
    return clip.absolutePath(dir.path);
  }

  /// Старт ночной сессии мониторинга сна
  Future<bool> startMonitoring({bool bypassDelay = false}) async {
    if (_isMonitoring) return true;

    final perm = await hasPermission();
    if (!perm) {
      _lastError = 'Нет доступа к микрофону. Разрешите его в настройках iOS.';
      onStateChanged?.call();
      return false;
    }

    _isMonitoring = true;
    _isWaitingDelay = false;
    _lastError = null;
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

    return await _startListening();
  }

  /// Запуск непрерывного PCM-потока и анализ уровня звука.
  Future<bool> _startListening() async {
    if (!_isMonitoring) return false;

    _pcmSubscription?.cancel();
    _preRoll.clear();
    _preRollBytes = 0;
    _levelHistory.clear();
    _noiseFloorDb = -60.0;
    _lastFloorUpdate = DateTime.fromMillisecondsSinceEpoch(0);

    try {
      // Измерительный тракт: без AGC, шумоподавления и эхоподавления.
      // iOS: mode=measurement; Android: AudioSource.UNPROCESSED.
      final session = await AudioSession.instance;
      await session.configure(
        const AudioSessionConfiguration.speech().copyWith(
          avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
          avAudioSessionMode: AVAudioSessionMode.measurement,
        ),
      );
      await session.setActive(true);

      const baseConfig = RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: _sampleRate,
        numChannels: _channels,
        autoGain: false,
        echoCancel: false,
        noiseSuppress: false,
        // Не останавливать ночной монитор при системных уведомлениях.
        audioInterruption: AudioInterruptionMode.none,
      );

      Stream<Uint8List> stream;
      try {
        stream = await _recorder.startStream(
          baseConfig.copyWith(
            androidConfig: const AndroidRecordConfig(
              audioSource: AndroidAudioSource.unprocessed,
            ),
          ),
        );
      } catch (e) {
        // UNPROCESSED доступен не на всех устройствах/версиях Android.
        debugPrint('Unprocessed audio source unavailable, fallback: $e');
        try {
          if (await _recorder.isRecording()) await _recorder.stop();
        } catch (_) {}
        stream = await _recorder.startStream(baseConfig);
      }

      _pcmSubscription = stream.listen(
        _onPcmChunk,
        onError: (Object error) {
          debugPrint('Sleep audio stream error: $error');
          _lastError = 'Ошибка аудиопотока: $error';
          onStateChanged?.call();
        },
        cancelOnError: false,
      );

      _lastError = null;
      return true;
    } catch (e) {
      debugPrint('Error starting sound monitor: $e');
      _lastError = 'Не удалось запустить микрофон: $e';
      _isMonitoring = false;
      _isWaitingDelay = false;
      onStateChanged?.call();
      return false;
    }
  }

  void _onPcmChunk(Uint8List chunk) {
    if (chunk.isEmpty || !_isMonitoring) return;

    final level = _rmsToDb(chunk);
    _currentDb = level;

    final now = DateTime.now();
    _updateNoiseFloor(now, level);
    if (now.hour != _currentHour) {
      _currentHour = now.hour;
      _hourlyClipCount = 0;
    }

    if (_isRecordingClip) {
      _appendToClip(chunk);
      if (level > _currentClipPeakDb) {
        _currentClipPeakDb = level;
      }

      if (level >= holdThresholdDb) {
        _armSilenceTimer();
      }

      if (_clipDurationSeconds >= maxDurationSeconds) {
        // Защита от бесконечной записи.
        _finalizeCurrentClip();
      } else {
        _notifyLevel();
      }
      return;
    }

    if (level >= triggerThresholdDb) {
      _startClipRecording(chunk);
    } else {
      _addToPreRoll(chunk);
    }

    _notifyLevel();
  }

  /// PCM-поток приходит десятки раз в секунду; перерисовывать весь UI на
  /// каждый чанк незачем — достаточно ~5 кадров в секунду.
  void _notifyLevel() {
    final now = DateTime.now();
    if (now.difference(_lastLevelNotify).inMilliseconds < 200) return;
    _lastLevelNotify = now;
    onStateChanged?.call();
  }

  /// Оценка шумового пола по тихим чанкам скользящего окна ~60 с.
  ///
  /// Перцентиль устойчив к редким событиям, поэтому отдельная фильтрация
  /// «только тихих кадров» не нужна. Вниз пол идёт быстрее, вверх — медленно:
  /// так храп не поднимает порог и не маскирует следующие события.
  void _updateNoiseFloor(DateTime now, double level) {
    _levelHistory.add(_LevelSample(now, level));
    final cutoff = now.subtract(const Duration(seconds: _floorWindowSeconds));
    while (
        _levelHistory.isNotEmpty && _levelHistory.first.time.isBefore(cutoff)) {
      _levelHistory.removeAt(0);
    }
    if (now.difference(_lastFloorUpdate).inMilliseconds < 1000) return;
    _lastFloorUpdate = now;
    if (_levelHistory.length < 5) return;

    final List<double> values =
        _levelHistory.map((sample) => sample.db).toList()..sort();
    final int index = (_floorPercentile * (values.length - 1))
        .floor()
        .clamp(0, values.length - 1);
    final double percentile = values[index];
    final double next = percentile < _noiseFloorDb
        ? _noiseFloorDb * 0.5 + percentile * 0.5
        : _noiseFloorDb * 0.9 + percentile * 0.1;
    _noiseFloorDb = next.clamp(-100.0, -10.0);
  }

  bool _canSaveClip() {
    if (_sessionClipCount >= maxClipsPerSession) {
      debugPrint('Max session clips limit reached ($maxClipsPerSession)');
      return false;
    }
    if (_hourlyClipCount >= maxClipsPerHour) {
      debugPrint('Max hourly clips limit reached ($maxClipsPerHour)');
      return false;
    }
    return true;
  }

  double get _clipDurationSeconds =>
      _clipBytes / (_sampleRate * _channels * _bytesPerSample);

  void _addToPreRoll(Uint8List chunk) {
    _preRoll.add(chunk);
    _preRollBytes += chunk.length;

    const maxBytes =
        _preRollSeconds * _sampleRate * _channels * _bytesPerSample;
    while (_preRollBytes > maxBytes && _preRoll.isNotEmpty) {
      final removed = _preRoll.removeAt(0);
      _preRollBytes -= removed.length;
    }
  }

  void _startClipRecording(Uint8List firstChunk) {
    if (_isRecordingClip) return;

    _isRecordingClip = true;
    _currentClipPeakDb = _currentDb;
    _clipBuffer = BytesBuilder(copy: false);
    _clipBytes = 0;

    final preRollMs =
        ((_preRollBytes / (_sampleRate * _channels * _bytesPerSample)) * 1000)
            .round();
    _clipStartTime = DateTime.now().subtract(Duration(milliseconds: preRollMs));

    for (final chunk in _preRoll) {
      _clipBuffer!.add(chunk);
      _clipBytes += chunk.length;
    }
    _preRoll.clear();
    _preRollBytes = 0;

    _clipBuffer!.add(firstChunk);
    _clipBytes += firstChunk.length;

    _armSilenceTimer();

    _maxDurationTimer?.cancel();
    _maxDurationTimer = Timer(Duration(seconds: maxDurationSeconds), () {
      _finalizeCurrentClip();
    });

    onStateChanged?.call();
  }

  void _appendToClip(Uint8List chunk) {
    _clipBuffer?.add(chunk);
    _clipBytes += chunk.length;
  }

  void _armSilenceTimer() {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(Duration(seconds: silenceTimeoutSeconds), () {
      _finalizeCurrentClip();
    });
  }

  Future<void> _finalizeCurrentClip() async {
    if (!_isRecordingClip) return;

    _silenceTimer?.cancel();
    _maxDurationTimer?.cancel();

    final buffer = _clipBuffer;
    final startTime = _clipStartTime ?? DateTime.now();
    final peakDb = _currentClipPeakDb;
    final windowSeconds = _clipDurationSeconds;

    _isRecordingClip = false;
    _clipStartTime = null;
    _clipBuffer = null;
    _clipBytes = 0;

    if (buffer == null) {
      onStateChanged?.call();
      return;
    }
    final pcm = buffer.takeBytes();
    if (pcm.isEmpty) {
      onStateChanged?.call();
      return;
    }

    AudioClassification? classification;
    try {
      classification = await AudioEventClassifier.classifyAsync(
        pcm,
        sampleRate: _sampleRate,
      );
    } catch (e) {
      debugPrint('Error classifying sleep event: $e');
      _lastError = 'Не удалось классифицировать событие: $e';
    }

    // «Минимальная длительность» считается по активной части, а не по
    // всему окну с пред-записью и хвостом.
    final activeMs = classification?.features.activeDurationMs ??
        (windowSeconds * 1000).round();
    if (activeMs < 200) {
      onStateChanged?.call();
      return;
    }

    final SleepSoundType type = classification?.type ?? SleepSoundType.unknown;
    final double confidence = classification?.confidence ?? 0;
    final AudioFeatures features =
        classification?.features ?? AudioFeatures.empty;

    String? savedClipId;
    if (classification != null &&
        activeMs >= minDurationSeconds * 1000 &&
        _canSaveClip()) {
      try {
        final recordsDir = await _getRecordsDirectory();
        final fileName = 'sleep_clip_${startTime.millisecondsSinceEpoch}.wav';
        final file =
            File('${recordsDir.path}${Platform.pathSeparator}$fileName');
        await _writeWavFile(file, pcm);

        final clip = SleepAudioClip(
          id: _uuid.v4(),
          filePath: fileName,
          timestamp: startTime,
          durationSeconds: windowSeconds.round().clamp(1, maxDurationSeconds),
          peakDecibels: peakDb,
          soundType: type,
          confidence: confidence,
          segments: classification.segments,
          probabilities: <String, double>{
            for (final entry in classification.probabilities.entries)
              entry.key.name: entry.value,
          },
        );

        _clips.insert(0, clip);
        _sessionClipCount++;
        _hourlyClipCount++;
        savedClipId = clip.id;
        await _saveClipsToPrefs();
        await _enforceRetention();
        _lastError = null;
      } catch (e) {
        debugPrint('Error saving sleep clip: $e');
        _lastError = 'Не удалось сохранить фрагмент записи: $e';
      }
    }

    // Событие пишется всегда, даже когда WAV не сохранён из-за лимитов.
    final event = SleepAudioEvent(
      id: _uuid.v4(),
      timestamp: startTime,
      durationMs: activeMs,
      soundType: type,
      confidence: confidence,
      peakDecibels: peakDb,
      noiseFloorDb: features.noiseFloorDb,
      snrDb: features.snrDb,
      savedClipId: savedClipId,
    );
    _events.insert(0, event);
    _trimEvents();
    try {
      await _saveEventsToPrefs();
    } catch (e) {
      debugPrint('Error saving sleep event: $e');
    }

    onStateChanged?.call();
  }

  Future<void> _writeWavFile(File file, Uint8List pcm) async {
    final header = ByteData(_wavHeaderSize);
    _writeAscii(header, 0, 'RIFF');
    header.setUint32(4, 36 + pcm.length, Endian.little);
    _writeAscii(header, 8, 'WAVE');
    _writeAscii(header, 12, 'fmt ');
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little); // PCM
    header.setUint16(22, _channels, Endian.little);
    header.setUint32(24, _sampleRate, Endian.little);
    header.setUint32(
      28,
      _sampleRate * _channels * _bytesPerSample,
      Endian.little,
    );
    header.setUint16(32, _channels * _bytesPerSample, Endian.little);
    header.setUint16(34, _bitsPerSample, Endian.little);
    _writeAscii(header, 36, 'data');
    header.setUint32(40, pcm.length, Endian.little);

    final raf = await file.open(mode: FileMode.write);
    try {
      await raf.writeFrom(header.buffer.asUint8List());
      await raf.writeFrom(pcm);
      await raf.flush();
    } finally {
      await raf.close();
    }
  }

  void _writeAscii(ByteData data, int offset, String value) {
    for (var i = 0; i < value.length; i++) {
      data.setUint8(offset + i, value.codeUnitAt(i));
    }
  }

  /// RMS-уровень PCM16LE в dBFS (0 dB — максимальная амплитуда, -100 — тишина).
  double _rmsToDb(Uint8List chunk) {
    final sampleCount = chunk.length ~/ 2;
    if (sampleCount == 0) return -100.0;

    final data = ByteData.sublistView(chunk);
    double sumSquares = 0.0;
    for (var i = 0; i < sampleCount; i++) {
      final sample = data.getInt16(i * 2, Endian.little) / 32768.0;
      sumSquares += sample * sample;
    }

    final rms = math.sqrt(sumSquares / sampleCount);
    if (rms <= 0.0000001) return -100.0;
    return (20 * (math.log(rms) / math.ln10)).clamp(-100.0, 0.0);
  }

  /// Остановка ночного мониторинга
  Future<void> stopMonitoring() async {
    _delayTimer?.cancel();
    _silenceTimer?.cancel();
    _maxDurationTimer?.cancel();

    if (_isRecordingClip) {
      await _finalizeCurrentClip();
    }

    await _pcmSubscription?.cancel();
    _pcmSubscription = null;

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
    _preRoll.clear();
    _preRollBytes = 0;
    _levelHistory.clear();
    _noiseFloorDb = -60.0;
    onStateChanged?.call();
  }

  /// Воспроизведение конкретного клипа.
  ///
  /// Возвращает `null` при успехе либо текст ошибки для показа пользователю.
  Future<String?> playClip(SleepAudioClip clip) async {
    if (_isMonitoring && !_isWaitingDelay) {
      _lastError = 'Остановите ночной монитор, чтобы прослушать запись.';
      onStateChanged?.call();
      return _lastError;
    }

    if (_playingClipId == clip.id && _player.playing) {
      await _player.pause();
      _playingClipId = null;
      onStateChanged?.call();
      return null;
    }

    try {
      await _player.stop();

      final path = await _clipAbsolutePath(clip);
      final file = File(path);
      if (!await file.exists()) {
        _lastError = 'Файл записи не найден. Возможно, он удалён системой.';
        _playingClipId = null;
        onStateChanged?.call();
        return _lastError;
      }
      if (await file.length() <= _wavHeaderSize) {
        _lastError = 'Файл записи повреждён или пуст.';
        _playingClipId = null;
        onStateChanged?.call();
        return _lastError;
      }

      // just_audio не настраивает AVAudioSession category. Без этого звук
      // уходит в разговорный динамик или глушится переключателем «Бесшумно».
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.speech());
      await session.setActive(true);

      await _player.setFilePath(path);
      _playingClipId = clip.id;
      await _player.play();
      _lastError = null;
      onStateChanged?.call();
      return null;
    } catch (e) {
      debugPrint('Error playing clip: $e');
      _playingClipId = null;
      _lastError = 'Не удалось воспроизвести запись: $e';
      onStateChanged?.call();
      return _lastError;
    }
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
      await _deleteClipFile(clip);
      _clips.removeAt(index);
      await _saveClipsToPrefs();
      onStateChanged?.call();
    }
  }

  /// Удаление всех записей
  Future<void> clearAllClips() async {
    await stopPlaying();
    for (final clip in _clips) {
      await _deleteClipFile(clip);
    }
    _clips.clear();
    _events.clear();
    await _saveClipsToPrefs();
    await _saveEventsToPrefs();
    await _cleanupOrphanFiles();
    onStateChanged?.call();
  }

  Future<void> _deleteClipFile(SleepAudioClip clip) async {
    try {
      final file = File(await _clipAbsolutePath(clip));
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Error deleting sleep clip file: $e');
    }
  }

  /// Ограничение хранения: 7 дней и ~250 МБ.
  Future<void> _enforceRetention() async {
    final cutoff =
        DateTime.now().subtract(const Duration(days: _retentionDays));

    final kept = <SleepAudioClip>[];
    final removed = <SleepAudioClip>[];

    for (final clip in _clips) {
      if (clip.timestamp.isBefore(cutoff)) {
        removed.add(clip);
      } else {
        kept.add(clip);
      }
    }

    var totalBytes = 0;
    final sized = <SleepAudioClip>[];
    for (final clip in kept) {
      var size = 0;
      try {
        size = await File(await _clipAbsolutePath(clip)).length();
      } catch (_) {}
      if (totalBytes + size <= _maxStorageBytes) {
        totalBytes += size;
        sized.add(clip);
      } else {
        removed.add(clip);
      }
    }

    if (removed.isEmpty) return;

    for (final clip in removed) {
      await _deleteClipFile(clip);
    }

    _clips
      ..clear()
      ..addAll(sized);
    await _saveClipsToPrefs();
  }

  /// Удаляет временные и осиротевшие файлы (в т.ч. старый
  /// `temp_noise_monitor.m4a`, который больше не используется).
  Future<void> _cleanupOrphanFiles() async {
    final dir = await _getRecordsDirectory();
    final referenced = _clips.map((c) => c.fileName).toSet();
    final now = DateTime.now();

    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.last;

      if (name == 'temp_noise_monitor.m4a') {
        try {
          await entity.delete();
        } catch (_) {}
        continue;
      }

      if (referenced.contains(name)) continue;

      try {
        final stat = await entity.stat();
        // Не трогаем файл, который только что создан (идёт запись).
        if (now.difference(stat.modified) < const Duration(hours: 1)) {
          continue;
        }
        if (name.endsWith('.wav') || name.endsWith('.m4a')) {
          await entity.delete();
        }
      } catch (_) {}
    }
  }

  void dispose() {
    _delayTimer?.cancel();
    _silenceTimer?.cancel();
    _maxDurationTimer?.cancel();
    _pcmSubscription?.cancel();
    _recorder.dispose();
    _player.dispose();
  }
}

class _LevelSample {
  final DateTime time;
  final double db;

  const _LevelSample(this.time, this.db);
}
