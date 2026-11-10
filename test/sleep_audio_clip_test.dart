import 'package:flutter_test/flutter_test.dart';
import 'package:somnia/models/sleep_audio_clip.dart';

void main() {
  group('SleepAudioClip Model Tests', () {
    test('Serializes and deserializes correctly', () {
      final now = DateTime(2026, 10, 30, 3, 42, 15);
      final clip = SleepAudioClip(
        id: 'test-clip-123',
        filePath: '/data/sleep_records/clip_1.m4a',
        timestamp: now,
        durationSeconds: 14,
        peakDecibels: -22.5,
        soundType: SleepSoundType.snore,
      );

      final json = clip.toJson();
      expect(json['id'], 'test-clip-123');
      expect(json['durationSeconds'], 14);
      expect(json['peakDecibels'], -22.5);
      expect(json['soundType'], 'snore');

      final restored = SleepAudioClip.fromJson(json);
      expect(restored.id, clip.id);
      expect(restored.filePath, clip.filePath);
      expect(restored.timestamp, clip.timestamp);
      expect(restored.durationSeconds, clip.durationSeconds);
      expect(restored.peakDecibels, clip.peakDecibels);
      expect(restored.soundType, SleepSoundType.snore);
      expect(restored.soundType.label, 'Храп');
    });

    test('Correct Russian labels for all sound types', () {
      expect(SleepSoundType.snore.label, 'Храп');
      expect(SleepSoundType.talk.label, 'Разговор во сне');
      expect(SleepSoundType.movement.label, 'Шорох / движение');
      expect(SleepSoundType.ambient.label, 'Шум в комнате');
      expect(SleepSoundType.unknown.label, 'Неопределённо');
    });

    test('confidence переживает JSON-сериализацию', () {
      final clip = SleepAudioClip(
        id: 'a',
        filePath: 'a.wav',
        timestamp: DateTime(2026, 1, 1),
        durationSeconds: 5,
        peakDecibels: -20,
        soundType: SleepSoundType.snore,
        confidence: 0.82,
      );
      expect(SleepAudioClip.fromJson(clip.toJson()).confidence, 0.82);
    });

    test('старый JSON без confidence читается', () {
      final json = <String, dynamic>{
        'id': 'a',
        'filePath': 'a.wav',
        'timestamp': '2026-01-01T00:00:00.000',
        'durationSeconds': 5,
        'peakDecibels': -20,
        'soundType': 'talk',
      };
      final restored = SleepAudioClip.fromJson(json);
      expect(restored.confidence, isNull);
      expect(restored.segments, isEmpty);
      expect(restored.probabilities, isEmpty);
    });

    test('неизвестный soundType читается как unknown', () {
      final json = <String, dynamic>{
        'id': 'a',
        'filePath': 'a.wav',
        'timestamp': '2026-01-01T00:00:00.000',
        'durationSeconds': 5,
        'peakDecibels': -20,
        'soundType': 'cough',
      };
      expect(SleepAudioClip.fromJson(json).soundType, SleepSoundType.unknown);
    });

    test('сегменты и вероятности переживают JSON', () {
      final clip = SleepAudioClip(
        id: 'a',
        filePath: 'a.wav',
        timestamp: DateTime(2026, 1, 1),
        durationSeconds: 5,
        peakDecibels: -20,
        soundType: SleepSoundType.snore,
        confidence: 0.9,
        segments: const [
          AudioSegment(
            startMs: 0,
            endMs: 1200,
            type: SleepSoundType.snore,
            confidence: 0.91,
          ),
        ],
        probabilities: const {
          'snore': 0.91,
          'talk': 0.02,
          'movement': 0.03,
          'ambient': 0.04,
        },
      );
      final restored = SleepAudioClip.fromJson(clip.toJson());
      expect(restored.segments, hasLength(1));
      expect(restored.segments.first.type, SleepSoundType.snore);
      expect(restored.segments.first.startMs, 0);
      expect(restored.segments.first.endMs, 1200);
      expect(restored.probabilities['snore'], 0.91);
    });
  });
}
