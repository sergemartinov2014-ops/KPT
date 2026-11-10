import 'package:flutter_test/flutter_test.dart';
import 'package:somnia/models/sleep_audio_clip.dart';
import 'package:somnia/services/audio_event_classifier.dart';
import 'package:somnia/services/sleep_audio_model.dart';

import 'support/audio_fixtures.dart';
import 'support/audio_test_signals.dart';

void main() {
  final Map<String, dynamic> manifest = loadAudioFixtureManifest();
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

    test('огибающая 1 Гц даёт пик модуляционного спектра на 1 Гц', () {
      final f = AudioEventClassifier.analyzeFeatures(
        withQuiet(amTone(modHz: 1, seconds: 4)),
      );
      expect(f.modulationPeakHz, closeTo(1, 0.15));
      expect(f.modulationBreathValid, isFalse); // короче 8 с
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

  group('классификация синтетических клипов как в рекордере', () {
    for (final dynamic raw in synthClips) {
      final Map<String, dynamic> clip = raw as Map<String, dynamic>;
      final String truth = clip['true_label'] as String;

      test(truth, () {
        final r = AudioEventClassifier.classify(
          readWavPcm('$kAudioFixtureDirectory/${clip['file']}'),
        );
        expect(r.type.name, clip['expected_type']);
        expect(r.type.name, truth);
        expect(r.probabilities, isNotEmpty);
        expect(
          r.probabilities.values.reduce((a, b) => a + b),
          closeTo(1.0, 1e-6),
        );
      });
    }
  });

  test('низкая уверенность даёт unknown, а не ложный храп', () {
    final clip = (manifest['clips'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .firstWhere((item) => item['file'] == 'snore.wav');
    final r = AudioEventClassifier.classify(
      readWavPcm('$kAudioFixtureDirectory/snore.wav'),
    );
    expect(clip['expected_type'], 'unknown');
    expect(r.type, SleepSoundType.unknown);
    expect(r.confidence, lessThan(kSleepAudioUnknownThreshold));
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
