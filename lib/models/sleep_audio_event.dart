import 'sleep_audio_clip.dart';

/// Лёгкая запись события ночи.
///
/// Событие сохраняется всегда, даже когда лимит WAV-файлов исчерпан.
/// Это не даёт лимитам записи искажать статистику храпа.
class SleepAudioEvent {
  final String id;
  final DateTime timestamp;

  /// Длительность активной части события, мс.
  final int durationMs;
  final SleepSoundType soundType;
  final double confidence;
  final double peakDecibels;
  final double noiseFloorDb;
  final double snrDb;

  /// Идентификатор сохранённого клипа, если WAV записан.
  final String? savedClipId;

  const SleepAudioEvent({
    required this.id,
    required this.timestamp,
    required this.durationMs,
    required this.soundType,
    required this.confidence,
    required this.peakDecibels,
    required this.noiseFloorDb,
    required this.snrDb,
    this.savedClipId,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'durationMs': durationMs,
        'soundType': soundType.name,
        'confidence': confidence,
        'peakDecibels': peakDecibels,
        'noiseFloorDb': noiseFloorDb,
        'snrDb': snrDb,
        if (savedClipId != null) 'savedClipId': savedClipId,
      };

  factory SleepAudioEvent.fromJson(Map<String, dynamic> json) =>
      SleepAudioEvent(
        id: json['id'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        durationMs: (json['durationMs'] as num?)?.toInt() ?? 0,
        soundType: SleepSoundType.values.firstWhere(
          (value) => value.name == json['soundType'],
          orElse: () => SleepSoundType.unknown,
        ),
        confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
        peakDecibels: (json['peakDecibels'] as num?)?.toDouble() ?? -100,
        noiseFloorDb: (json['noiseFloorDb'] as num?)?.toDouble() ?? -100,
        snrDb: (json['snrDb'] as num?)?.toDouble() ?? 0,
        savedClipId: json['savedClipId'] as String?,
      );
}
