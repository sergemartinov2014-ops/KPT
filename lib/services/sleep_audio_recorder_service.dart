import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

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
import 'night_sound_detector.dart';

/// Ночной монитор звуков сна.
///
/// Работает на непрерывном PCM-потоке (`record.startStream`): анализ и
/// детекция события идут в Dart, поэтому то, что записано в файл, полностью
/// совпадает с тем, что проанализировано. Каждое событие сохраняется отдельным
/// WAV-файлом, пригодным для воспроизведения без перекодирования.
///
/// Ключевые решения:
///
/// * Аудиосессия открывается **сразу** при включении монитора, даже если
///   пользователь выбрал задержку 20 минут. Иначе iOS усыпляет приложение, и
///   `Timer` задержки не срабатывает до утра — самая частая причина «пустых»
///   ночей.
/// * Порог срабатывания относительный: превышение над локальным шумовым полом
///   (см. [NightSoundDetector]), а не абсолютная громкость, поэтому тихий храп
///   в тихой комнате фиксируется, а вентилятор — нет.
/// * Сторожевой таймер и подписка на прерывания возвращают поток после
///   звонка/Siri/смены маршрута, чтобы монитор не «умирал» молча.
class SleepAudioRecorderService {
  static const String _prefsKey = 'saved_sleep_audio_clips';
  static const String _eventsKey = 'saved_sleep_audio_events';
  static const String _configDelayKey = 'sleep_audio_delay_minutes';
  static const String _configSensitivityKey = 'sleep_audio_sensitivity_db';

  static const int _sampleRate = 16000;
  static const int _channels = 1;
  static const int _bitsPerSample = 16;
  static const int _bytesPerSample = _bitsPerSample ~/ 8;
  static const int _wavHeaderSize = 44;
  static const int _preRollSeconds = 2;
  static const int _retentionDays = 7;
  static const int _eventRetentionDays = 30;
  static const int _maxEvents = 5000;
  static const int _maxStorageBytes = 400 * 1024 * 1024; // ~400 МБ

  final AudioRecorder _recorder = AudioRecorder();
  final SleepAudioClipPlayer _player;
  final Uuid _uuid = const Uuid();

  /// Каталог записей; в тестах можно подменить временным.
  final Directory? _recordsDirectoryOverride;

  /// Клинические и системные лимиты (архитектура Moonap).
  double sensitivityDb = 7.0; // дБ над локальным шумовым полом
  /// Минимум активной части, чтобы сохранить WAV. Короткие щелчки и удары
  /// остаются только строкой в статистике, но переворачивание в постели
  /// обычно длится 0.4-1.5 с и должно попадать в запись.
  int minClipActiveMs = 400;
  int maxDurationSeconds = 20; // максимальная длина одного фрагмента
  int maxClipsPerHour = 150; // предохранитель от бесконечного потока
  int maxClipsPerSession = 600;
  int delayMinutes = 20;

  bool _isMonitoring = false;
  bool _isWaitingDelay = false;
  bool _isRecordingClip = false;
  bool _streamActive = false;
  double _currentDb = -100.0;
  String? _lastError;
  DateTime? _listenFrom;

  NightSoundDetector _detector = _makeDetector(7.0, 20);

  int _sessionClipCount = 0;
  int _currentHour = -1;
  int _hourlyClipCount = 0;

  int _storageBytes = 0;
  int _savedSinceStorageCheck = 0;

  Timer? _watchdogTimer;
  Timer? _delayTimer;
  StreamSubscription<Uint8List>? _pcmSubscription;
  StreamSubscription<AudioInterruptionEvent>? _interruptionSubscription;
  StreamSubscription<void>? _noisySubscription;

  /// Ограничитель частоты обновления UI индикатора уровня.
  DateTime _lastLevelNotify = DateTime.fromMillisecondsSinceEpoch(0);

  final List<SleepAudioClip> _clips = [];
  final List<SleepAudioEvent> _events = [];
  String? _playingClipId;

  /// Клип, который сейчас готовится к воспроизведению: файл уже выбран, но
  /// плеер ещё не начал играть. UI показывает на этой карточке индикатор,
  /// чтобы нажатие не выглядело «зависшим» переключением.
  String? _startingClipId;

  /// Токен текущего запроса на воспроизведение. Запрос устаревает, как только
  /// пользователь выбирает другой клип, поэтому старые операции не могут
  /// перезаписать актуальное состояние плеера.
  int _playRequestGeneration = 0;
  StreamSubscription<void>? _completionSubscription;

  VoidCallback? onStateChanged;

  bool get isMonitoring => _isMonitoring;
  bool get isWaitingDelay => _isWaitingDelay;
  bool get isRecordingClip => _isRecordingClip;
  double get currentDb => _currentDb;
  int get sessionClipCount => _sessionClipCount;
  List<SleepAudioClip> get clips => List.unmodifiable(_clips);
  List<SleepAudioEvent> get events => List.unmodifiable(_events);
  String? get playingClipId => _playingClipId;
  String? get startingClipId => _startingClipId;
  SleepAudioClipPlayer get player => _player;

  /// Оценка шумового пола за последнюю минуту, dBFS.
  double get noiseFloorDb => _detector.noiseFloorDb;

  /// Порог срабатывания с учётом фона — для индикатора в UI.
  double get triggerThresholdDb => _detector.triggerThresholdDb;

  /// Шумовой пол в полосе храпа (60–1200 Гц), dBFS.
  double get lowBandFloorDb => _detector.lowBandFloorDb;

  int get maxClipsPerSessionLimit => maxClipsPerSession;

  String? get lastError => _lastError;

  SleepAudioRecorderService({
    SleepAudioClipPlayer? clipPlayer,
    Directory? recordsDirectoryOverride,
  })  : _player = clipPlayer ?? JustAudioClipPlayer(),
        _recordsDirectoryOverride = recordsDirectoryOverride {
    _initPlayer();
  }

  static NightSoundDetector _makeDetector(
    double sensitivityDb,
    int maxSeconds,
  ) {
    return NightSoundDetector(
      sampleRate: _sampleRate,
      preRollSeconds: _preRollSeconds,
      silenceTimeoutSeconds: 3,
      maxDurationSeconds: maxSeconds,
      sensitivityDb: sensitivityDb,
    );
  }

  void _initPlayer() {
    _completionSubscription = _player.completedStream.listen((_) {
      if (_playingClipId == null) return;
      _playingClipId = null;
      onStateChanged?.call();
    });
  }

  Future<void> loadPersistedData() async {
    final prefs = await SharedPreferences.getInstance();
    delayMinutes = prefs.getInt(_configDelayKey) ?? 20;
    sensitivityDb = prefs.getDouble(_configSensitivityKey) ?? 7.0;
    _detector = _makeDetector(sensitivityDb, maxDurationSeconds);

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
        _storageBytes = await _measureStorage();
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

  Future<void> saveSettings({int? delay, double? sensitivity}) async {
    final prefs = await SharedPreferences.getInstance();
    if (delay != null) {
      delayMinutes = delay;
      await prefs.setInt(_configDelayKey, delay);
    }
    if (sensitivity != null) {
      sensitivityDb = sensitivity.clamp(3.0, 16.0);
      await prefs.setDouble(_configSensitivityKey, sensitivityDb);
      _detector.sensitivity = sensitivityDb;
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
    final dir = _recordsDirectoryOverride ??
        Directory(
          '${(await getApplicationDocumentsDirectory()).path}'
          '${Platform.pathSeparator}sleep_records',
        );
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<String> _clipAbsolutePath(SleepAudioClip clip) async {
    final dir = await _getRecordsDirectory();
    return clip.absolutePath(dir.path);
  }

  /// Старт ночной сессии мониторинга сна.
  ///
  /// `bypassDelay` используется кнопкой «Начать сейчас».
  Future<bool> startMonitoring({bool bypassDelay = false}) async {
    if (_isMonitoring) return true;

    final perm = await hasPermission();
    if (!perm) {
      _lastError = 'Нет доступа к микрофону. Разрешите его в настройках iOS.';
      onStateChanged?.call();
      return false;
    }

    _isMonitoring = true;
    _sessionClipCount = 0;
    _hourlyClipCount = 0;
    _currentHour = DateTime.now().hour;
    _lastError = null;

    final wait = delayMinutes > 0 && !bypassDelay;
    _isWaitingDelay = wait;
    _listenFrom =
        wait ? DateTime.now().add(Duration(minutes: delayMinutes)) : null;

    // Аудиопоток открывается немедленно в любом случае: только активная
    // аудиосессия не даёт iOS усыпить приложение вместе с таймером задержки.
    final started = await _startListening();
    if (!started) {
      _isMonitoring = false;
      _isWaitingDelay = false;
      _listenFrom = null;
      _lastError ??= 'Не удалось запустить микрофон.';
      onStateChanged?.call();
      return false;
    }

    _detector.enabled = !wait;
    _startWatchdog();
    _listenInterruptions();
    _delayTimer?.cancel();
    if (wait) {
      _delayTimer = Timer(Duration(minutes: delayMinutes), () {
        if (!_isMonitoring) return;
        _isWaitingDelay = false;
        _detector.enabled = true;
        onStateChanged?.call();
      });
    }
    onStateChanged?.call();
    return true;
  }

  /// Запуск непрерывного PCM-потока и анализа уровня звука.
  Future<bool> _startListening({bool keepFloor = false}) async {
    if (!_isMonitoring) return false;

    await _pcmSubscription?.cancel();
    _pcmSubscription = null;
    _streamActive = false;
    _detector.reset(keepFloor: keepFloor);

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
        // ~20 мс на чанк: детектору нужен короткий шаг по времени.
        streamBufferSize: 1024,
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
          _streamActive = false;
          _lastError = 'Ошибка аудиопотока: $error';
          onStateChanged?.call();
        },
        onDone: () {
          _streamActive = false;
        },
        cancelOnError: false,
      );

      _streamActive = true;
      _lastError = null;
      return true;
    } catch (e) {
      debugPrint('Error starting sound monitor: $e');
      _lastError = 'Не удалось запустить микрофон: $e';
      _streamActive = false;
      return false;
    }
  }

  void _startWatchdog() {
    _watchdogTimer?.cancel();
    _watchdogTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(_ensureStreamAlive());
    });
  }

  /// iOS может остановить AVAudioEngine после звонка, Siri или смены маршрута,
  /// не сообщая об ошибке. Раз в 30 секунд проверяем, что поток жив.
  Future<void> _ensureStreamAlive() async {
    if (!_isMonitoring) return;
    if (_streamActive) {
      try {
        if (await _recorder.isRecording()) return;
      } catch (_) {
        // Падение isRecording() тоже означает, что поток надо поднять заново.
      }
    }
    debugPrint('Night sound monitor watchdog: restarting audio stream');
    final restarted = await _startListening(keepFloor: true);
    if (restarted) {
      if (!_isWaitingDelay) _detector.enabled = true;
    } else {
      _lastError = 'Микрофон остановился, перезапуск не удался.';
      onStateChanged?.call();
    }
  }

  void _listenInterruptions() {
    unawaited(() async {
      try {
        final session = await AudioSession.instance;
        await _interruptionSubscription?.cancel();
        _interruptionSubscription =
            session.interruptionEventStream.listen((event) {
          if (event.begin) {
            _streamActive = false;
            return;
          }
          if (!_isMonitoring) return;
          unawaited(_ensureStreamAlive());
        });
        await _noisySubscription?.cancel();
        _noisySubscription = session.becomingNoisyEventStream.listen((_) {
          if (!_isMonitoring) return;
          unawaited(_ensureStreamAlive());
        });
      } catch (e) {
        debugPrint('Error listening to audio interruptions: $e');
      }
    }());
  }

  void _onPcmChunk(Uint8List chunk) {
    if (chunk.isEmpty || !_isMonitoring) return;

    final now = DateTime.now();
    if (_isWaitingDelay) {
      final from = _listenFrom;
      if (from != null && now.isBefore(from)) {
        // Ждём засыпания, но продолжаем учить шумовой пол.
        _detector.addChunk(chunk, now: now);
        _currentDb = _detector.currentDb;
        _notifyLevel();
        return;
      }
      _isWaitingDelay = false;
      _detector.enabled = true;
      onStateChanged?.call();
    }

    final DetectedClip? completed = _detector.addChunk(chunk, now: now);
    _currentDb = _detector.currentDb;
    _isRecordingClip = _detector.isRecording;

    if (now.hour != _currentHour) {
      _currentHour = now.hour;
      _hourlyClipCount = 0;
    }

    if (completed != null) {
      _isRecordingClip = false;
      unawaited(_finalizeClip(completed));
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

  Future<void> _finalizeClip(DetectedClip completed) async {
    final Uint8List pcm = completed.pcm;
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

    final int detectedActiveMs =
        (completed.activeSamples * 1000 / _sampleRate).round();
    // «Минимальная длительность» считается по активной части, а не по всему
    // окну с пред-записью и хвостом тишины.
    final int activeMs =
        classification?.features.activeDurationMs ?? detectedActiveMs;
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
        activeMs >= minClipActiveMs &&
        _canSaveClip()) {
      try {
        final recordsDir = await _getRecordsDirectory();
        final fileName =
            'sleep_clip_${completed.startTime.millisecondsSinceEpoch}.wav';
        final file =
            File('${recordsDir.path}${Platform.pathSeparator}$fileName');
        await _writeWavFile(file, pcm);

        final double durationSeconds = pcm.length / 2 / _sampleRate;
        final clip = SleepAudioClip(
          id: _uuid.v4(),
          filePath: fileName,
          timestamp: completed.startTime,
          durationSeconds: durationSeconds.round().clamp(1, maxDurationSeconds),
          peakDecibels: completed.peakDb,
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
        _storageBytes += pcm.length + _wavHeaderSize;
        _savedSinceStorageCheck++;
        savedClipId = clip.id;

        await _saveClipsToPrefs();
        if (_storageBytes > _maxStorageBytes || _savedSinceStorageCheck >= 10) {
          _savedSinceStorageCheck = 0;
          await _enforceRetention();
        }
        _lastError = null;
      } catch (e) {
        debugPrint('Error saving sleep clip: $e');
        _lastError = 'Не удалось сохранить фрагмент записи: $e';
      }
    }

    // Событие пишется всегда, даже когда WAV не сохранён из-за лимитов:
    // статистика ночи не должна зависеть от квоты файлов.
    final event = SleepAudioEvent(
      id: _uuid.v4(),
      timestamp: completed.startTime,
      durationMs: activeMs,
      soundType: type,
      confidence: confidence,
      peakDecibels: completed.peakDb,
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

  /// Остановка ночного мониторинга.
  Future<void> stopMonitoring() async {
    _watchdogTimer?.cancel();
    _watchdogTimer = null;
    _delayTimer?.cancel();
    _delayTimer = null;

    _detector.enabled = false;
    _detector.reset();
    _isRecordingClip = false;

    await _pcmSubscription?.cancel();
    _pcmSubscription = null;
    _streamActive = false;

    try {
      if (await _recorder.isRecording()) {
        await _recorder.stop();
      }
    } catch (e) {
      debugPrint('Error stopping recorder: $e');
    }

    _isMonitoring = false;
    _isWaitingDelay = false;
    _listenFrom = null;
    _currentDb = -100.0;
    try {
      // Release the recording session so the orange microphone indicator goes
      // away and other audio (music, calls) can take over.
      final session = await AudioSession.instance;
      await session.setActive(false);
    } catch (e) {
      debugPrint('Error deactivating audio session: $e');
    }
    onStateChanged?.call();
  }

  /// Воспроизведение конкретного клипа.
  ///
  /// Возвращает `null` при успехе либо текст ошибки для показа пользователю.
  Future<String?> playClip(SleepAudioClip clip) async {
    // Playback reconfigures AVAudioSession to a speech category.  Doing that
    // while the monitor is running would silently switch the recording chain
    // away from `measurement` mode (and its disabled AGC), so playback waits
    // until monitoring is stopped.
    if (_isMonitoring) {
      _lastError = 'Остановите ночной монитор, чтобы прослушать запись.';
      onStateChanged?.call();
      return _lastError;
    }

    if (_playingClipId == clip.id && _player.playing) {
      final request = ++_playRequestGeneration;
      _startingClipId = null;
      try {
        await _player.pause();
      } catch (e) {
        if (request != _playRequestGeneration) return null;
        debugPrint('Error pausing clip: $e');
        _playingClipId = null;
        _lastError = 'Не удалось остановить воспроизведение: $e';
        onStateChanged?.call();
        return _lastError;
      }
      if (request == _playRequestGeneration) {
        _playingClipId = null;
        onStateChanged?.call();
      }
      return null;
    }

    final request = ++_playRequestGeneration;

    // Предыдущая запись уже останавливается, поэтому её подсветку убираем
    // сразу: загрузка следующего файла занимает время, и если оставить старую
    // карточку «играющей», экран выглядит зависшим, а повторное нажатие по ней
    // перезапускает старый клип вместо выбранного.
    _playingClipId = null;
    _startingClipId = clip.id;
    onStateChanged?.call();

    try {
      await _player.stop();
      if (request != _playRequestGeneration) return null;

      final path = await _clipAbsolutePath(clip);
      if (request != _playRequestGeneration) return null;

      final file = File(path);
      if (!await file.exists()) {
        if (request != _playRequestGeneration) return null;
        _playingClipId = null;
        _startingClipId = null;
        _lastError = 'Файл записи не найден. Возможно, он удалён системой.';
        onStateChanged?.call();
        return _lastError;
      }
      if (await file.length() <= _wavHeaderSize) {
        if (request != _playRequestGeneration) return null;
        _playingClipId = null;
        _startingClipId = null;
        _lastError = 'Файл записи повреждён или пуст.';
        onStateChanged?.call();
        return _lastError;
      }

      await _player.activate();
      if (request != _playRequestGeneration) return null;

      await _player.setFilePath(path);
      if (request != _playRequestGeneration) return null;

      // Сообщаем UI о старте сразу: `AudioPlayer.play()` завершается только
      // вместе с воспроизведением, поэтому ждать его здесь нельзя.
      _startingClipId = null;
      _playingClipId = clip.id;
      _lastError = null;
      onStateChanged?.call();
      unawaited(_runPlayback(request));
      return null;
    } on PlayerInterruptedException {
      // Другой клип выбран раньше, чем завершилась загрузка текущего.
      if (request == _playRequestGeneration) {
        _startingClipId = null;
        onStateChanged?.call();
      }
      return null;
    } catch (e) {
      if (request != _playRequestGeneration) return null;
      debugPrint('Error playing clip: $e');
      _playingClipId = null;
      _startingClipId = null;
      _lastError = 'Не удалось воспроизвести запись: $e';
      onStateChanged?.call();
      return _lastError;
    }
  }

  Future<void> _runPlayback(int request) async {
    try {
      await _player.play();
    } on PlayerInterruptedException {
      // Ожидаемое прерывание при переключении на другой клип.
    } catch (e) {
      if (request != _playRequestGeneration) return;
      debugPrint('Error playing clip: $e');
      _playingClipId = null;
      _startingClipId = null;
      _lastError = 'Не удалось воспроизвести запись: $e';
      onStateChanged?.call();
    }
  }

  Future<void> stopPlaying() async {
    ++_playRequestGeneration;
    _startingClipId = null;
    await _player.stop();
    _playingClipId = null;
    onStateChanged?.call();
  }

  /// Удаление клипа.
  Future<void> deleteClip(String id) async {
    final index = _clips.indexWhere((c) => c.id == id);
    if (index != -1) {
      final clip = _clips[index];
      if (_playingClipId == id || _startingClipId == id) {
        await stopPlaying();
      }
      await _deleteClipFile(clip);
      _clips.removeAt(index);
      await _saveClipsToPrefs();
      onStateChanged?.call();
    }
  }

  /// Удаление всех записей.
  Future<void> clearAllClips() async {
    await stopPlaying();
    for (final clip in _clips) {
      await _deleteClipFile(clip);
    }
    _clips.clear();
    _events.clear();
    _storageBytes = 0;
    await _saveClipsToPrefs();
    await _saveEventsToPrefs();
    await _cleanupOrphanFiles();
    onStateChanged?.call();
  }

  Future<void> _deleteClipFile(SleepAudioClip clip) async {
    try {
      final file = File(await _clipAbsolutePath(clip));
      if (await file.exists()) {
        final size = await file.length();
        await file.delete();
        _storageBytes = math.max(0, _storageBytes - size);
      }
    } catch (e) {
      debugPrint('Error deleting sleep clip file: $e');
    }
  }

  Future<int> _measureStorage() async {
    var total = 0;
    for (final clip in _clips) {
      try {
        total += await File(await _clipAbsolutePath(clip)).length();
      } catch (_) {}
    }
    return total;
  }

  int _retentionPriority(SleepSoundType type) {
    switch (type) {
      case SleepSoundType.snore:
        return 3;
      case SleepSoundType.talk:
        return 2;
      case SleepSoundType.movement:
        return 1;
      case SleepSoundType.ambient:
      case SleepSoundType.unknown:
        return 0;
    }
  }

  /// Ограничение хранения: 7 дней и ~400 МБ.
  ///
  /// Когда места не хватает, первыми уходят фоновые записи, затем самые
  /// старые. Так ночь не начинается с удаления храпа.
  Future<void> _enforceRetention() async {
    final cutoff =
        DateTime.now().subtract(const Duration(days: _retentionDays));

    final removed = <SleepAudioClip>[];
    final kept = <SleepAudioClip>[];
    for (final clip in _clips) {
      if (clip.timestamp.isBefore(cutoff)) {
        removed.add(clip);
      } else {
        kept.add(clip);
      }
    }

    var total = _storageBytes;
    if (total > _maxStorageBytes) {
      final byPriority = List<SleepAudioClip>.from(kept)
        ..sort((a, b) {
          final int priority = _retentionPriority(a.soundType)
              .compareTo(_retentionPriority(b.soundType));
          return priority != 0 ? priority : a.timestamp.compareTo(b.timestamp);
        });
      for (final clip in byPriority) {
        if (total <= _maxStorageBytes) break;
        try {
          final file = File(await _clipAbsolutePath(clip));
          if (await file.exists()) {
            total -= await file.length();
          }
        } catch (_) {}
        removed.add(clip);
        kept.remove(clip);
      }
    }

    if (removed.isEmpty) return;

    for (final clip in removed) {
      await _deleteClipFile(clip);
    }

    _clips
      ..clear()
      ..addAll(kept);
    _storageBytes = await _measureStorage();
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
    _watchdogTimer?.cancel();
    _delayTimer?.cancel();
    _pcmSubscription?.cancel();
    _interruptionSubscription?.cancel();
    _noisySubscription?.cancel();
    _completionSubscription?.cancel();
    _recorder.dispose();
    unawaited(_player.dispose());
  }
}

/// Минимальный контракт плеера клипов.
///
/// Отделён от [AudioPlayer], чтобы логику переключения записей можно было
/// проверить без нативного аудиоплагина.
abstract class SleepAudioClipPlayer {
  bool get playing;

  /// Событие завершения текущего клипа.
  Stream<void> get completedStream;

  Future<void> activate();
  Future<void> setFilePath(String path);
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> dispose();
}

/// Реализация на just_audio для продакшена.
class JustAudioClipPlayer implements SleepAudioClipPlayer {
  final AudioPlayer _player = AudioPlayer();

  @override
  bool get playing => _player.playing;

  @override
  Stream<void> get completedStream => _player.playerStateStream
      .where((state) => state.processingState == ProcessingState.completed)
      .map((_) {});

  @override
  Future<void> activate() async {
    // just_audio не настраивает AVAudioSession category. Без этого звук
    // уходит в разговорный динамик или глушится переключателем «Бесшумно».
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.speech());
    await session.setActive(true);
  }

  @override
  Future<void> setFilePath(String path) => _player.setFilePath(path);

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> dispose() => _player.dispose();
}
