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
    });
  });
}
