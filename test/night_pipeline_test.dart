import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:somnia/models/sleep_audio_clip.dart';
import 'package:somnia/services/audio_event_classifier.dart';
import 'package:somnia/services/night_sound_detector.dart';

import 'support/audio_test_signals.dart';

const int _chunkSamples = 336; // ~21 ms, the iOS plugin stream chunk

Uint8List _join(List<Uint8List> parts) {
  final builder = BytesBuilder(copy: false);
  for (final part in parts) {
    builder.add(part);
  }
  return builder.takeBytes();
}

Uint8List _room(double seconds, {double amplitude = 0.0004}) {
  final rnd = math.Random(seconds.hashCode & 0xffff);
  final count = (seconds * 16000).round();
  return pcm16(
    List<double>.generate(
      count,
      (_) => (rnd.nextDouble() * 2 - 1) * amplitude,
    ),
  );
}

class _NightResult {
  final List<DetectedClip> clips;
  final List<AudioClassification> classifications;
  const _NightResult(this.clips, this.classifications);
}

_NightResult _runNight(Uint8List pcm) {
  final detector = NightSoundDetector(sampleRate: 16000, sensitivityDb: 7.0)
    ..enabled = true;
  final clips = <DetectedClip>[];
  var ms = 0;
  final start = DateTime(2026, 3, 1, 23);
  for (var offset = 0; offset + 2 <= pcm.length; offset += _chunkSamples * 2) {
    final end = math.min(pcm.length, offset + _chunkSamples * 2);
    final chunk = Uint8List.sublistView(pcm, offset, end);
    ms += (end - offset) ~/ 2 * 1000 ~/ 16000;
    final clip = detector.addChunk(
      chunk,
      now: start.add(Duration(milliseconds: ms)),
    );
    if (clip != null) clips.add(clip);
  }
  final classifications = clips
      .map((clip) => AudioEventClassifier.classify(clip.pcm))
      .toList(growable: false);
  return _NightResult(clips, classifications);
}

void main() {
  test('ночь: храп, разговор и шорох сохраняются и распознаются', () {
    final night = _join(<Uint8List>[
      _room(8),
      snoreSignal(seconds: 4, amplitude: 0.05),
      _room(5),
      speechSignal(seconds: 3, amplitude: 0.08),
      _room(5),
      rustleSignal(seconds: 1, amplitude: 0.4),
      _room(6),
    ]);

    final result = _runNight(night);
    expect(result.clips.length, greaterThanOrEqualTo(3),
        reason: 'three audible events must produce clips');

    final types = result.classifications.map((c) => c.type).toList();
    expect(types, contains(SleepSoundType.snore));
    expect(types, contains(SleepSoundType.talk));
    expect(types, contains(SleepSoundType.movement));

    // Chronological order: snore first, then speech, then the rustle.
    final audible = types
        .where((type) =>
            type != SleepSoundType.ambient && type != SleepSoundType.unknown)
        .toList();
    expect(audible.first, SleepSoundType.snore);
    expect(audible[1], SleepSoundType.talk);
    expect(audible.last, SleepSoundType.movement);
  });

  test('ночь без событий не создаёт клипов', () {
    final night = _join(<Uint8List>[
      _room(20),
      _room(20),
      _room(20),
    ]);
    final result = _runNight(night);
    expect(result.clips, isEmpty);
  });

  test('клип короче 0.4 с активного звука отсеивается рекордером', () {
    // The detector may open a window for a click, but the recorder only saves
    // clips with at least 400 ms of active audio (a single tap is ~20 ms).
    final night = _join(<Uint8List>[
      _room(6),
      tone(freq: 1500, seconds: 0.02, amplitude: 0.6),
      _room(6),
    ]);
    final result = _runNight(night);
    for (final clip in result.clips) {
      expect(clip.activeSamples / 16000, lessThan(0.4));
    }
  });

  test('абсолютно тихая комната не даёт событий', () {
    final result = _runNight(silence(seconds: 30));
    expect(result.clips, isEmpty);
  });
}
