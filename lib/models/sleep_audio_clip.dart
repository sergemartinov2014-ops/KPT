import 'dart:io';

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

  /// Имя файла записи (например, `sleep_clip_1712345678901.wav`).
  ///
  /// Исторически здесь хранился абсолютный путь. Для совместимости со
  /// старыми сохранениями поле сохранено, но новые записи содержат только
  /// имя файла: iOS меняет путь к sandbox-контейнеру между обновлениями,
  /// поэтому абсолютный путь быстро становится недействительным.
  final String filePath;
  final DateTime timestamp;
  final int durationSeconds;
  final double peakDecibels;
  final SleepSoundType soundType;

  /// Уверенность классификации 0…1. `null` у записей, созданных до
  /// появления DSP-классификатора.
  final double? confidence;

  const SleepAudioClip({
    required this.id,
    required this.filePath,
    required this.timestamp,
    required this.durationSeconds,
    required this.peakDecibels,
    required this.soundType,
    this.confidence,
  });

  /// Только имя файла — без каталога.
  String get fileName {
    final normalized = filePath.replaceAll('\\', '/');
    final index = normalized.lastIndexOf('/');
    return index == -1 ? normalized : normalized.substring(index + 1);
  }

  /// Абсолютный путь нужно вычислять во время выполнения: каталог документов
  /// приложения может измениться после переустановки/обновления.
  String absolutePath(String recordsDirectoryPath) =>
      '$recordsDirectoryPath${Platform.pathSeparator}$fileName';

  SleepAudioClip copyWith({
    String? id,
    String? filePath,
    DateTime? timestamp,
    int? durationSeconds,
    double? peakDecibels,
    SleepSoundType? soundType,
    double? confidence,
  }) {
    return SleepAudioClip(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      timestamp: timestamp ?? this.timestamp,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      peakDecibels: peakDecibels ?? this.peakDecibels,
      soundType: soundType ?? this.soundType,
      confidence: confidence ?? this.confidence,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'filePath': filePath,
        'timestamp': timestamp.toIso8601String(),
        'durationSeconds': durationSeconds,
        'peakDecibels': peakDecibels,
        'soundType': soundType.name,
        if (confidence != null) 'confidence': confidence,
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
        confidence: (json['confidence'] as num?)?.toDouble(),
      );
}
