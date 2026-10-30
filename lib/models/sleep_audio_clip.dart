enum SleepSoundType {
  snore,
  talk,
  movement,
  ambient;

  String get label {
    switch (this) {
      case SleepSoundType.snore:
        return 'Храп';
      case SleepSoundType.talk:
        return 'Разговор во сне';
      case SleepSoundType.movement:
        return 'Шорох / движение';
      case SleepSoundType.ambient:
        return 'Шум в комнате';
    }
  }
}

class SleepAudioClip {
  final String id;
  final String filePath;
  final DateTime timestamp;
  final int durationSeconds;
  final double peakDecibels;
  final SleepSoundType soundType;

  const SleepAudioClip({
    required this.id,
    required this.filePath,
    required this.timestamp,
    required this.durationSeconds,
    required this.peakDecibels,
    required this.soundType,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'filePath': filePath,
        'timestamp': timestamp.toIso8601String(),
        'durationSeconds': durationSeconds,
        'peakDecibels': peakDecibels,
        'soundType': soundType.name,
      };

  factory SleepAudioClip.fromJson(Map<String, dynamic> json) => SleepAudioClip(
        id: json['id'] as String,
        filePath: json['filePath'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        durationSeconds: (json['durationSeconds'] as num).toInt(),
        peakDecibels: (json['peakDecibels'] as num).toDouble(),
        soundType: SleepSoundType.values.firstWhere(
          (e) => e.name == json['soundType'],
          orElse: () => SleepSoundType.snore,
        ),
      );
}
