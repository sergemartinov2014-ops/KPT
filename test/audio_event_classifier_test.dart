import 'package:flutter_test/flutter_test.dart';
import 'package:somnia/models/sleep_audio_clip.dart';
import 'package:somnia/services/audio_event_classifier.dart';

import 'support/audio_fixtures.dart';
import 'support/audio_test_signals.dart';

void main() {
  final Map<String, dynamic> manifest = loadAudioFixtureManifest();
  final List<dynamic> clips = manifest['clips'] as List<dynamic>;
  final List<dynamic> synthClips = manifest['synth_clips'] as List<dynamic>;

  group('признаки', () {
    test('тон 1 кГц: centroid около 1000 Гц, высокая периодичность', () {
      final f = AudioEventClassifier.analyzeFeatures(
        withQuiet(tone(freq: 1000, seconds: 1, amplitude: 0.2)),
      );
      expect(f.centroidHz, inInclusiveRange(850, 1150));
      expect(f.pitchStrength, greaterThan(0.5));
      expect(f.zcr, closeTo(0.125, 0.03));
      expect(f.flatness, lessThan(0.2));
    });

    test('огибающая 0.4 Гц даёт энергию в полосе дыхания', () {
      final f = AudioEventClassifier.analyzeFeatures(
        withQuiet(amTone(modHz: 0.4, seconds: 6)),
      );
      expect(f.modulationPeakHz, closeTo(0.4, 0.2));
      // The breathing band is measured once the active span holds at least
      // two cycles (~3 s), so a 6 s envelope is valid.
      expect(f.modulationBreathValid, isTrue);
      expect(f.modulationBreath, greaterThan(0.2));
    });

    test('ровный гул: полоса дыхания валидна, но модуляции нет', () {
      final f = AudioEventClassifier.analyzeFeatures(
        withQuiet(tone(freq: 100, seconds: 6, amplitude: 0.05)),
      );
      expect(f.modulationBreathValid, isTrue,
          reason: 'steady sound must be measurable, not "unknown"');
      expect(f.modulationBreath, lessThan(0.05));
    });

    test('тишина не даёт NaN и активных кадров', () {
      final f = AudioEventClassifier.analyzeFeatures(silence());
      expect(f.durationMs, 2000);
      expect(f.activeRatio, 0);
      expect(f.centroidHz.isFinite, isTrue);
      expect(f.flatness.isFinite, isTrue);
      expect(f.rmsDb, lessThan(-90));
    });

    test('нечётная длина буфера не роняет анализ', () {
      final pcm = tone(seconds: 0.2);
      final odd = pcm.sublist(0, pcm.length - 1);
      expect(() => AudioEventClassifier.analyzeFeatures(odd), returnsNormally);
    });

    test('клиппованный сигнал не даёт пик выше 0 dBFS', () {
      final loud = AudioEventClassifier.analyzeFeatures(tone(amplitude: 3.0));
      expect(loud.peakDb, lessThanOrEqualTo(0.0));
      expect(loud.peakDb.isFinite, isTrue);
    });
  });

  group('классификация фикстур', () {
    for (final dynamic raw in [...clips, ...synthClips]) {
      final Map<String, dynamic> clip = raw as Map<String, dynamic>;
      final String expected = clip['expected_type'] as String;
      final String file = clip['file'] as String;

      test('$file → $expected', () {
        final r = AudioEventClassifier.classify(
          readWavPcm('$kAudioFixtureDirectory/$file'),
        );
        expect(r.type.name, expected);
        expect(r.probabilities, isNotEmpty);
        expect(
          r.probabilities.values.reduce((a, b) => a + b),
          closeTo(1.0, 1e-6),
        );
      });
    }
  });

  group('защита от типичных ложных срабатываний', () {
    test('громкий шорох не классифицируется как храп', () {
      final pcm = withQuiet(
        rustleSignal(seconds: 3, amplitude: 0.6),
        preSeconds: 1.5,
        postSeconds: 1.5,
      );
      final r = AudioEventClassifier.classify(pcm);
      expect(r.type, isNot(SleepSoundType.snore));
    });

    test('гул вентилятора 100 Гц не классифицируется как храп', () {
      final pcm = withQuiet(
        tone(freq: 100, seconds: 6, amplitude: 0.05),
        preSeconds: 1.5,
        postSeconds: 1.5,
      );
      final r = AudioEventClassifier.classify(pcm);
      expect(r.type, isNot(SleepSoundType.snore));
    });

    test('тихий низкочастотный храп распознаётся', () {
      final pcm = withQuiet(
        snoreSignal(seconds: 8, amplitude: 0.04),
        preSeconds: 1.0,
        postSeconds: 1.0,
      );
      final r = AudioEventClassifier.classify(pcm);
      expect(r.type, SleepSoundType.snore);
      expect(r.confidence, greaterThan(0.5));
    });

    test('щелчок короче 150 мс активного звука остаётся фоном', () {
      final pcm = withQuiet(
        tone(freq: 2000, seconds: 0.04, amplitude: 0.8),
        preSeconds: 1.5,
        postSeconds: 1.5,
      );
      final r = AudioEventClassifier.classify(pcm);
      expect(r.type, SleepSoundType.ambient);
      expect(r.confidence, lessThanOrEqualTo(0.5));
    });
  });

  test('тишина — ambient с нулевой уверенностью', () {
    final r = AudioEventClassifier.classify(silence());
    expect(r.type, SleepSoundType.ambient);
    expect(r.confidence, lessThanOrEqualTo(0.5));
    expect(r.probabilities[SleepSoundType.ambient], 1.0);
  });

  test('сегменты покрывают клип и имеют вероятности', () {
    final r = AudioEventClassifier.classify(
      readWavPcm('$kAudioFixtureDirectory/synth/movement.wav'),
    );
    expect(r.segments, isNotEmpty);
    expect(r.segments.first.startMs, 0);
    for (var i = 1; i < r.segments.length; i++) {
      expect(
        r.segments[i].startMs,
        lessThanOrEqualTo(r.segments[i - 1].endMs + 250),
      );
    }
    for (final segment in r.segments) {
      expect(segment.endMs, greaterThan(segment.startMs));
      expect(segment.confidence, inInclusiveRange(0, 1));
    }
  });

  test('асинхронная классификация совпадает с синхронной', () async {
    final pcm = readWavPcm('$kAudioFixtureDirectory/synth/snore.wav');
    final sync = AudioEventClassifier.classify(pcm);
    final async = await AudioEventClassifier.classifyAsync(pcm);
    expect(async.type, sync.type);
    expect(async.confidence, closeTo(sync.confidence, 1e-9));
    expect(async.segments.length, sync.segments.length);
  });

  test('45-секундный клип классифицируется без падения', () async {
    final pcm = snoreSignal(seconds: 45);
    final r = await AudioEventClassifier.classifyAsync(pcm);
    expect(r.confidence, inInclusiveRange(0, 1));
    expect(r.features.durationMs, closeTo(45000, 2));
  });
}
