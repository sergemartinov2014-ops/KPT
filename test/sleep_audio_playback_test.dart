import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:somnia/models/sleep_audio_clip.dart';
import 'package:somnia/services/sleep_audio_recorder_service.dart';

class _FakeClipPlayer implements SleepAudioClipPlayer {
  final StreamController<void> _completed = StreamController<void>.broadcast();
  Completer<void>? _playCompleter;

  /// Позволяет задержать загрузку файла и проверить состояние переключения.
  Completer<void>? loadGate;

  /// Позволяет проверить реакцию на ошибку паузы.
  bool throwOnPause = false;

  /// Новый stop()/setFilePath() прерывает незавершённую загрузку, как в
  /// just_audio (`PlayerInterruptedException`).
  int _loadEpoch = 0;

  String? loadedPath;
  bool _playing = false;
  int pauseCalls = 0;

  @override
  bool get playing => _playing;

  @override
  Stream<void> get completedStream => _completed.stream;

  @override
  Future<void> activate() async {}

  @override
  Future<void> setFilePath(String path) async {
    final epoch = ++_loadEpoch;
    final gate = loadGate;
    if (gate != null) await gate.future;
    if (epoch != _loadEpoch) {
      throw PlayerInterruptedException('interrupted by another operation');
    }
    loadedPath = path;
  }

  @override
  Future<void> play() {
    _playing = true;
    final completer = Completer<void>();
    _playCompleter = completer;
    return completer.future;
  }

  @override
  Future<void> pause() async {
    if (throwOnPause) {
      throw StateError('pause failed');
    }
    pauseCalls++;
    _playing = false;
    _finishPlay();
  }

  @override
  Future<void> stop() async {
    _loadEpoch++;
    _playing = false;
    final completer = _playCompleter;
    _playCompleter = null;
    if (completer != null && !completer.isCompleted) {
      completer.completeError(
        PlayerInterruptedException('interrupted by stop'),
      );
    }
  }

  void emitCompleted() {
    _playing = false;
    _finishPlay();
    _completed.add(null);
  }

  void _finishPlay() {
    final completer = _playCompleter;
    _playCompleter = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }

  @override
  Future<void> dispose() async {
    _finishPlay();
    await _completed.close();
  }
}

Future<void> _waitFor(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 2));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('condition was not met in 2 s');
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const recordChannel = MethodChannel('com.llfbandit.record/messages');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(recordChannel, (call) async => null);

  late Directory recordsDir;
  late _FakeClipPlayer player;
  late SleepAudioRecorderService service;

  SleepAudioClip clip(String id) => SleepAudioClip(
        id: id,
        filePath: '$id.wav',
        timestamp: DateTime(2026, 11, 11, 23, 30),
        durationSeconds: 5,
        peakDecibels: -12,
        soundType: SleepSoundType.snore,
      );

  setUp(() {
    recordsDir = Directory.systemTemp.createTempSync('somnia_playback_');
    for (final id in ['a', 'b']) {
      File(
        '${recordsDir.path}${Platform.pathSeparator}$id.wav',
      ).writeAsBytesSync(List<int>.filled(100, 0));
    }
    player = _FakeClipPlayer();
    service = SleepAudioRecorderService(
      clipPlayer: player,
      recordsDirectoryOverride: recordsDir,
    );
  });

  tearDown(() async {
    await player.dispose();
    recordsDir.deleteSync(recursive: true);
  });

  group('SleepAudioRecorderService playback', () {
    test('starts playback without waiting for the clip to finish', () async {
      final error = await service.playClip(clip('a')).timeout(
            const Duration(seconds: 1),
          );

      expect(error, isNull);
      expect(service.playingClipId, 'a');
      expect(player.playing, isTrue);
      expect(player.loadedPath, endsWith('a.wav'));
      expect(service.lastError, isNull);
    });

    test('switching clips ignores interruption of the previous request',
        () async {
      await service.playClip(clip('a'));

      final error = await service.playClip(clip('b')).timeout(
            const Duration(seconds: 1),
          );
      // Дать устаревшему запросу завершиться после stop().
      await Future<void>.delayed(Duration.zero);

      expect(error, isNull);
      expect(service.playingClipId, 'b');
      expect(service.startingClipId, isNull);
      expect(player.loadedPath, endsWith('b.wav'));
      expect(service.lastError, isNull);
    });

    test('switch drops the previous highlight before the next clip is ready',
        () async {
      await service.playClip(clip('a'));

      final gate = Completer<void>();
      player.loadGate = gate;
      final next = service.playClip(clip('b'));
      await _waitFor(() => service.startingClipId == 'b');

      // Предыдущая запись уже остановлена и не должна выглядеть играющей:
      // иначе экран выглядит зависшим, а нажатие по ней перезапускает старый клип.
      expect(service.playingClipId, isNull);

      gate.complete();
      await next;

      expect(service.startingClipId, isNull);
      expect(service.playingClipId, 'b');
      expect(player.loadedPath, endsWith('b.wav'));
    });

    test('stale completion during a switch does not clear the new clip',
        () async {
      await service.playClip(clip('a'));

      final gate = Completer<void>();
      player.loadGate = gate;
      final next = service.playClip(clip('b'));
      await _waitFor(() => service.startingClipId == 'b');

      player.emitCompleted();
      await Future<void>.delayed(Duration.zero);

      expect(service.startingClipId, 'b');

      gate.complete();
      await next;
      expect(service.playingClipId, 'b');
      expect(player.loadedPath, endsWith('b.wav'));
    });

    test('rapid taps leave the last selected clip playing', () async {
      final first = service.playClip(clip('a'));
      final second = service.playClip(clip('b'));

      await Future.wait<String?>([first, second]);

      expect(service.playingClipId, 'b');
      expect(service.startingClipId, isNull);
      expect(service.lastError, isNull);
      expect(player.loadedPath, endsWith('b.wav'));
    });

    test('missing file clears pending state and reports an error', () async {
      final error = await service.playClip(clip('missing'));

      expect(error, isNotNull);
      expect(service.playingClipId, isNull);
      expect(service.startingClipId, isNull);
    });

    test('pause failure clears the active clip and reports an error', () async {
      await service.playClip(clip('a'));

      player.throwOnPause = true;
      final error = await service.playClip(clip('a'));

      expect(error, isNotNull);
      expect(service.playingClipId, isNull);
      expect(service.startingClipId, isNull);
    });

    test('tapping the active clip pauses it', () async {
      await service.playClip(clip('a'));
      await service.playClip(clip('a'));

      expect(player.pauseCalls, 1);
      expect(player.playing, isFalse);
      expect(service.playingClipId, isNull);
    });

    test('completion clears the active clip', () async {
      await service.playClip(clip('a'));

      player.emitCompleted();
      await Future<void>.delayed(Duration.zero);

      expect(service.playingClipId, isNull);
    });
  });
}
