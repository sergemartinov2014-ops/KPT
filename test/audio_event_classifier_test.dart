import 'package:flutter_test/flutter_test.dart';
import 'package:somnia/models/sleep_audio_clip.dart';
import 'package:somnia/services/audio_event_classifier.dart';

import 'support/audio_test_signals.dart';

void main() {
  test('тон 1 кГц: centroid около 1000 Гц, высокая периодичность', () {
    final f = AudioEventClassifier.analyzeFeatures(
      tone(freq: 1000, seconds: 1, amplitude: 0.2),
    );
    expect(f.centroidHz, inInclusiveRange(850, 1150));
    expect(f.pitchStrength, greaterThan(0.5));
    expect(f.zcr, closeTo(0.125, 0.03));
    expect(f.flatness, lessThan(0.2));
  });

  test('огибающая 1 Гц распознаётся как модуляция', () {
    final f = AudioEventClassifier.analyzeFeatures(
      amTone(modHz: 1, seconds: 4),
    );
    expect(f.envelopeModulation, greaterThan(0.4));
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

  test('храп определяется как snore', () {
    final r = AudioEventClassifier.classify(snoreSignal());
    expect(r.type, SleepSoundType.snore);
    expect(r.confidence, greaterThan(0.35));
  });

  test('тихий храп не уходит в шорох', () {
    final r = AudioEventClassifier.classify(snoreSignal(amplitude: 0.02));
    expect(r.type, SleepSoundType.snore);
  });

  test('речь определяется как talk', () {
    final r = AudioEventClassifier.classify(speechSignal());
    expect(r.type, SleepSoundType.talk);
  });

  test('шорох определяется как movement', () {
    final r = AudioEventClassifier.classify(rustleSignal());
    expect(r.type, SleepSoundType.movement);
  });

  test('громкий шорох не считается храпом', () {
    final r = AudioEventClassifier.classify(rustleSignal(amplitude: 0.6));
    expect(r.type, SleepSoundType.movement);
  });

  test('стационарный фон и гул 100 Гц — ambient, не snore', () {
    expect(
      AudioEventClassifier.classify(ambientSignal()).type,
      SleepSoundType.ambient,
    );
    expect(
      AudioEventClassifier.classify(
        tone(freq: 100, seconds: 10, amplitude: 0.02),
      ).type,
      SleepSoundType.ambient,
    );
  });

  test('тишина — ambient с нулевой уверенностью', () {
    final r = AudioEventClassifier.classify(silence());
    expect(r.type, SleepSoundType.ambient);
    expect(r.confidence, lessThanOrEqualTo(0.5));
  });

  test('очень короткий клип — movement', () {
    expect(
      AudioEventClassifier.classify(tone(seconds: 0.05)).type,
      SleepSoundType.movement,
    );
  });

  test('тихий высокочастотный шорох — movement, не храп', () {
    expect(
      AudioEventClassifier.classify(rustleSignal(amplitude: 0.03)).type,
      SleepSoundType.movement,
    );
  });

  test('асинхронная классификация не блокирует UI-изолят', () async {
    final pcm = snoreSignal(seconds: 45);
    final r = await AudioEventClassifier.classifyAsync(pcm);
    expect(r.type, SleepSoundType.snore);
    expect(r.confidence, greaterThan(0.35));
  });
}
