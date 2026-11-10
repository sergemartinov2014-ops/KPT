import 'dart:io';

enum SleepSoundType {
  snore,
  talk,
  movement,
  ambient,
  unknown;

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
      case SleepSoundType.unknown:
        return 'Неопределённо';
    }
  }
}

/// Размеченная часть клипа: интервал и предсказанный класс.
class AudioSegment {
  final int startMs;
  final int endMs;
  final SleepSoundType type;
  final double confidence;

  const AudioSegment({
    required this.startMs,
    required this.endMs,
    required this.type,
    required this.confidence,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'startMs': startMs,
        'endMs': endMs,
        'type': type.name,
        'confidence': confidence,
      };

  factory AudioSegment.fromJson(Map<String, dynamic> json) => AudioSegment(
        startMs: (json['startMs'] as num).toInt(),
        endMs: (json['endMs'] as num).toInt(),
        type: SleepSoundType.values.firstWhere(
          (value) => value.name == json['type'],
          orElse: () => SleepSoundType.unknown,
        ),
        confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      );

  @override
  String toString() => 'AudioSegment($startMs..$endMs ms, ${type.name}, '
      '${(confidence * 100).toStringAsFixed(0)}%)';
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

  /// Сегменты внутри клипа со смешанным содержимым (v2).
  final List<AudioSegment> segments;

  /// Калиброванные вероятности классов (v2), ключи — имена
  /// [SleepSoundType]. Пустая карта у записей v1.
  final Map<String, double> probabilities;

  const SleepAudioClip({
    required this.id,
    required this.filePath,
    required this.timestamp,
    required this.durationSeconds,
    required this.peakDecibels,
    required this.soundType,
    this.confidence,
    this.segments = const <AudioSegment>[],
    this.probabilities = const <String, double>{},
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
    List<AudioSegment>? segments,
    Map<String, double>? probabilities,
  }) {
    return SleepAudioClip(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      timestamp: timestamp ?? this.timestamp,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      peakDecibels: peakDecibels ?? this.peakDecibels,
      soundType: soundType ?? this.soundType,
      confidence: confidence ?? this.confidence,
      segments: segments ?? this.segments,
      probabilities: probabilities ?? this.probabilities,
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
        if (segments.isNotEmpty)
          'segments': segments.map((segment) => segment.toJson()).toList(),
        if (probabilities.isNotEmpty) 'probabilities': probabilities,
      };

  factory SleepAudioClip.fromJson(Map<String, dynamic> json) => SleepAudioClip(
        id: json['id'] as String,
        filePath: json['filePath'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        durationSeconds: (json['durationSeconds'] as num).toInt(),
        peakDecibels: (json['peakDecibels'] as num).toDouble(),
        soundType: SleepSoundType.values.firstWhere(
          (e) => e.name == json['soundType'],
          orElse: () => SleepSoundType.unknown,
        ),
        confidence: (json['confidence'] as num?)?.toDouble(),
        segments: (json['segments'] as List<dynamic>?)
                ?.map((item) =>
                    AudioSegment.fromJson(item as Map<String, dynamic>))
                .toList() ??
            const <AudioSegment>[],
        probabilities: (json['probabilities'] as Map<String, dynamic>?)?.map(
              (key, value) => MapEntry(key, (value as num).toDouble()),
            ) ??
            const <String, double>{},
      );
}
