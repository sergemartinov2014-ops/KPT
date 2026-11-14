import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:somnia/services/night_sound_detector.dart';

const int _rate = 16000;
const int _chunkSamples = 336; // ~21 ms, like the iOS plugin stream

/// Deterministic PCM mixer for the detector tests.
class _Signal {
  final math.Random _rnd;
  final List<double> _samples = <double>[];

  _Signal(int seed) : _rnd = math.Random(seed);

  void room({
    required double seconds,
    double amplitude = 0.002,
    double humHz = 0,
    double humAmplitude = 0,
  }) {
    final n = (seconds * _rate).round();
    for (var i = 0; i < n; i++) {
      final t = i / _rate;
      final noise = (_rnd.nextDouble() * 2 - 1) * amplitude;
      final hum = humAmplitude * math.sin(2 * math.pi * humHz * t);
      _samples.add(noise + hum);
    }
  }

  void hiss({required double seconds, double amplitude = 0.05}) {
    final n = (seconds * _rate).round();
    for (var i = 0; i < n; i++) {
      _samples.add((_rnd.nextDouble() * 2 - 1) * amplitude);
    }
  }

  /// Low-frequency pulsed snore: harmonics 90/180/270 Hz, ~0.7 Hz envelopes.
  void snore({
    required double seconds,
    double amplitude = 0.03,
    double pulseHz = 0.7,
    double baseHz = 90,
  }) {
    final n = (seconds * _rate).round();
    for (var i = 0; i < n; i++) {
      final t = i / _rate;
      final env =
          0.25 + 0.75 * (0.5 + 0.5 * math.sin(2 * math.pi * pulseHz * t));
      final body = math.sin(2 * math.pi * baseHz * t) +
          0.55 * math.sin(2 * math.pi * baseHz * 2 * t) +
          0.3 * math.sin(2 * math.pi * baseHz * 3 * t);
      final turbulence = (_rnd.nextDouble() * 2 - 1) * 0.35;
      _samples.add(amplitude * env * (body * 0.45 + turbulence * 0.2));
    }
  }

  void click({double amplitude = 0.5, double seconds = 0.02}) {
    final n = (seconds * _rate).round();
    for (var i = 0; i < n; i++) {
      _samples.add((_rnd.nextDouble() * 2 - 1) * amplitude);
    }
  }

  Uint8List build() {
    final bytes = ByteData(_samples.length * 2);
    for (var i = 0; i < _samples.length; i++) {
      bytes.setInt16(
          i * 2, (_samples[i].clamp(-1.0, 1.0) * 32767).round(), Endian.little);
    }
    return bytes.buffer.asUint8List();
  }
}

class _Harness {
  final NightSoundDetector detector;
  final List<DetectedClip> clips = <DetectedClip>[];
  final List<double> levels = <double>[];
  final List<double> floors = <double>[];
  final DateTime _t0 = DateTime(2026, 1, 1, 23);
  int _ms = 0;

  _Harness({double sensitivityDb = 7.0, int maxDurationSeconds = 45})
      : detector = NightSoundDetector(
          sampleRate: _rate,
          sensitivityDb: sensitivityDb,
          maxDurationSeconds: maxDurationSeconds,
        ) {
    detector.enabled = true;
  }

  void feed(Uint8List pcm) {
    for (var offset = 0;
        offset + 2 <= pcm.length;
        offset += _chunkSamples * 2) {
      final int end = math.min(pcm.length, offset + _chunkSamples * 2);
      final chunk = Uint8List.sublistView(pcm, offset, end);
      _ms += ((end - offset) ~/ 2 * 1000 / _rate).round();
      final clip = detector.addChunk(
        chunk,
        now: _t0.add(Duration(milliseconds: _ms)),
      );
      levels.add(detector.currentDb);
      floors.add(detector.noiseFloorDb);
      if (clip != null) clips.add(clip);
    }
  }
}

void main() {
  test('low-level snore triggers a clip and keeps the noise floor', () {
    final signal = _Signal(1)
      ..room(seconds: 6, amplitude: 0.002, humHz: 100, humAmplitude: 0.001)
      ..snore(seconds: 3, amplitude: 0.03)
      ..room(seconds: 5, amplitude: 0.002, humHz: 100, humAmplitude: 0.001);
    final harness = _Harness()..feed(signal.build());

    expect(harness.clips, isNotEmpty,
        reason: 'a snore 20+ dB above the room floor must be recorded');
    final clip = harness.clips.first;
    expect(clip.peakDb, greaterThan(-45));
    // Pre-roll means the clip starts before the trigger chunk.
    expect(clip.pcm.length, greaterThan(3 * _rate * 2));
    expect(clip.activeSamples / _rate, greaterThan(2.0),
        reason: 'the snore itself must count as active audio');
    // The floor must stay near the room level, not the snore level.
    expect(harness.detector.noiseFloorDb, lessThan(-48));
  });

  test('steady fan hum never triggers', () {
    final signal = _Signal(2)
      ..room(seconds: 2, amplitude: 0.003)
      ..room(seconds: 40, amplitude: 0.003, humHz: 100, humAmplitude: 0.05);
    final harness = _Harness()..feed(signal.build());
    expect(harness.clips, isEmpty);
  });

  test('steady broadband hiss never triggers', () {
    final signal = _Signal(3)
      ..room(seconds: 2, amplitude: 0.003)
      ..hiss(seconds: 40, amplitude: 0.05);
    final harness = _Harness()..feed(signal.build());
    expect(harness.clips, isEmpty);
  });

  test('a short click opens at most a sub-second event', () {
    final signal = _Signal(4)
      ..room(seconds: 4, amplitude: 0.002)
      ..click(amplitude: 0.6)
      ..room(seconds: 6, amplitude: 0.002);
    final harness = _Harness()..feed(signal.build());
    for (final clip in harness.clips) {
      expect(clip.activeSamples / _rate, lessThan(1.0),
          reason: 'the recorder drops events shorter than 2 s of active audio');
    }
  });

  test('continuous snore produces repeated clips instead of self-masking', () {
    final signal = _Signal(5)
      ..room(seconds: 5, amplitude: 0.002)
      ..snore(seconds: 100, amplitude: 0.03);
    final harness = _Harness(maxDurationSeconds: 20)..feed(signal.build());
    expect(harness.clips.length, greaterThanOrEqualTo(4));
    for (final clip in harness.clips) {
      final seconds = clip.pcm.length / 2 / _rate;
      expect(seconds, lessThanOrEqualTo(22.0));
    }
    expect(harness.detector.noiseFloorDb, lessThan(-45),
        reason: 'a continuous snore must not lift the learned floor');
  });

  test('disabled detector learns the floor but records nothing', () {
    final signal = _Signal(6)
      ..room(seconds: 5, amplitude: 0.002)
      ..snore(seconds: 5, amplitude: 0.03);
    final harness = _Harness();
    harness.detector.enabled = false;
    harness.feed(signal.build());
    expect(harness.clips, isEmpty);
    expect(harness.detector.noiseFloorDb, lessThan(-45));
    expect(harness.detector.isRecording, isFalse);
  });

  test('high sensitivity ignores what a strict setting still records', () {
    final signal = _Signal(7)
      ..room(seconds: 5, amplitude: 0.002, humHz: 100, humAmplitude: 0.0015)
      ..snore(seconds: 4, amplitude: 0.008)
      ..room(seconds: 4, amplitude: 0.002);
    final pcm = signal.build();
    final strict = _Harness(sensitivityDb: 14)..feed(pcm);
    final sensitive = _Harness(sensitivityDb: 6)..feed(pcm);
    expect(strict.clips.length <= sensitive.clips.length, isTrue);
    expect(sensitive.clips, isNotEmpty);
  });
}
