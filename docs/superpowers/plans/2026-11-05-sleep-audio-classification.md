# Классификация ночных звуков Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Заменить классификацию по длительности и громкости на DSP-анализ и точнее относить клипы к храпу, речи, шороху и фоновому шуму.

**Architecture:** Новый чистый Dart-модуль режет PCM на кадры 32 мс, считает спектральные и временные признаки (FFT 512, полосы энергии, centroid/flatness/flux, ZCR, автокорреляция F0, модуляция огибающей), затем выбирает тип по взвешенным оценкам. `SleepAudioRecorderService` вызывает его при финализации клипа.

**Tech Stack:** Dart 3.4, Flutter, `dart:typed_data`, `dart:math`, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-11-05-sleep-audio-classification-design.md`

## Global Constraints

- Никаких новых зависимостей в `pubspec.yaml`.
- Классификатор работает только на устройстве, без сети.
- Формат PCM: 16-бит little-endian, моно, 16000 Гц (`_sampleRate`).
- Порог запуска записи и прочие настройки мониторинга не меняются.
- Старые JSON-записи без `confidence` должны читаться без ошибок.
- Все команды запускать из `D:\ANTI\somnia`.
- Flutter: `C:\flutter\bin\flutter.bat`.

## Review Focus

- Почти тишина и DC-смещение: тип `ambient`, без NaN и деления на ноль.
- Обрезанный/клиппованный сигнал (пик 0 dBFS): без падения.
- Очень короткий клип (< 100 мс) и нечётная длина байтов: без RangeError.
- Стационарный гул вентилятора/трансформатора (100 Гц без модуляции): `ambient`, не `snore`.
- Тонкий шорох высокой частоты: `movement`, не `snore`.

---

### Task 1: Признаки сигнала

**Files:**
- Create: `lib/services/audio_event_classifier.dart`
- Create: `test/support/audio_test_signals.dart`
- Test: `test/audio_event_classifier_test.dart`

**Interfaces:**
- Consumes: ничего.
- Produces:
  - `class AudioFeatures` с полями `durationMs`, `activeRatio`, `rmsDb`, `peakDb`, `zcr`, `centroidHz`, `flatness`, `flux`, `pitchStrength`, `f0Hz`, `lowRatio`, `midRatio`, `highRatio`, `envelopeModulation`, `syllableRateHz`, `tonalStability` (`double`/`int`).
  - `static AudioFeatures AudioEventClassifier.analyzeFeatures(Uint8List pcm, {int sampleRate = 16000})`.
  - `static const int AudioEventClassifier.frameSize = 512`, `hopSize = 256`.

- [ ] **Step 1: Написать генераторы тестовых сигналов**

`test/support/audio_test_signals.dart`:

```dart
import 'dart:math' as math;
import 'dart:typed_data';

const int kTestSampleRate = 16000;

Uint8List pcm16(List<double> samples) {
  final data = ByteData(samples.length * 2);
  for (var i = 0; i < samples.length; i++) {
    final v = (samples[i].clamp(-1.0, 1.0) * 32767).round();
    data.setInt16(i * 2, v, Endian.little);
  }
  return data.buffer.asUint8List();
}

Uint8List tone({double freq = 1000, double seconds = 1, double amplitude = 0.2}) {
  final n = (kTestSampleRate * seconds).round();
  return pcm16(List.generate(n, (i) => amplitude * math.sin(2 * math.pi * freq * i / kTestSampleRate)));
}

Uint8List amTone({double freq = 1000, double modHz = 1, double seconds = 4, double amplitude = 0.2}) {
  final n = (kTestSampleRate * seconds).round();
  return pcm16(List.generate(n, (i) {
    final t = i / kTestSampleRate;
    return amplitude * (0.5 + 0.5 * math.sin(2 * math.pi * modHz * t)) * math.sin(2 * math.pi * freq * t);
  }));
}

Uint8List snoreSignal({double seconds = 8, double amplitude = 0.15}) {
  final rnd = math.Random(7);
  final n = (kTestSampleRate * seconds).round();
  return pcm16(List.generate(n, (i) {
    final t = i / kTestSampleRate;
    final env = 0.35 + 0.65 * (0.5 + 0.5 * math.sin(2 * math.pi * 0.8 * t));
    final body = math.sin(2 * math.pi * 80 * t) +
        0.6 * math.sin(2 * math.pi * 160 * t) +
        0.35 * math.sin(2 * math.pi * 240 * t);
    return amplitude * env * body * 0.5 + (rnd.nextDouble() - 0.5) * 0.004;
  }));
}

Uint8List speechSignal({double seconds = 5, double amplitude = 0.2}) {
  final rnd = math.Random(11);
  final n = (kTestSampleRate * seconds).round();
  const formants = <double>[700, 1200, 2600];
  return pcm16(List.generate(n, (i) {
    final t = i / kTestSampleRate;
    final syllable = (0.5 + 0.5 * math.sin(2 * math.pi * 4 * t));
    final gate = syllable > 0.25 ? 1.0 : 0.0;
    double v = 0;
    for (var h = 1; h <= 30; h++) {
      final f = 130.0 * h;
      if (f > 7000) break;
      double w = 0.02;
      for (final formant in formants) {
        w += math.exp(-math.pow((f - formant) / 350.0, 2));
      }
      v += (w / h) * math.sin(2 * math.pi * f * t);
    }
    return amplitude * gate * v / 3.0 + (rnd.nextDouble() - 0.5) * 0.006;
  }));
}

Uint8List rustleSignal({double seconds = 3, double amplitude = 0.3}) {
  final rnd = math.Random(19);
  final n = (kTestSampleRate * seconds).round();
  var prev = 0.0;
  return pcm16(List.generate(n, (i) {
    final t = i / kTestSampleRate;
    final burst = (t * 2) % 1.0 < 0.5 ? 1.0 : 0.0;
    final white = rnd.nextDouble() - 0.5;
    final high = white - prev * 0.9; // подчёркиваем верхние частоты
    prev = white;
    return amplitude * burst * high;
  }));
}

Uint8List ambientSignal({double seconds = 10, double amplitude = 0.012}) {
  final rnd = math.Random(23);
  final n = (kTestSampleRate * seconds).round();
  return pcm16(List.generate(n, (i) {
    final t = i / kTestSampleRate;
    return amplitude * (rnd.nextDouble() - 0.5) + 0.01 * math.sin(2 * math.pi * 100 * t);
  }));
}

Uint8List silence({double seconds = 2}) => pcm16(List.filled((kTestSampleRate * seconds).round(), 0.0));
```

- [ ] **Step 2: Написать падающие тесты признаков**

`test/audio_event_classifier_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:somnia/services/audio_event_classifier.dart';
import 'support/audio_test_signals.dart';

void main() {
  test('тон 1 кГц: centroid около 1000 Гц, высокая периодичность', () {
    final f = AudioEventClassifier.analyzeFeatures(tone(freq: 1000, seconds: 1, amplitude: 0.2));
    expect(f.centroidHz, inInclusiveRange(850, 1150));
    expect(f.pitchStrength, greaterThan(0.5));
    expect(f.zcr, closeTo(0.125, 0.03));
    expect(f.flatness, lessThan(0.2));
  });

  test('огибающая 1 Гц распознаётся как модуляция', () {
    final f = AudioEventClassifier.analyzeFeatures(amTone(modHz: 1, seconds: 4));
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
}
```

- [ ] **Step 3: Запустить тесты, убедиться что падают**

Run: `C:\flutter\bin\flutter.bat test test\audio_event_classifier_test.dart -r expanded`
Expected: FAIL — `audio_event_classifier.dart` не найден / метод не определён.

- [ ] **Step 4: Реализовать признаки**

`lib/services/audio_event_classifier.dart`, каркас:

```dart
import 'dart:math' as math;
import 'dart:typed_data';

class AudioFeatures {
  final int durationMs;
  final double activeRatio;
  final double rmsDb;
  final double peakDb;
  final double zcr;
  final double centroidHz;
  final double flatness;
  final double flux;
  final double pitchStrength;
  final double f0Hz;
  final double lowRatio;
  final double midRatio;
  final double highRatio;
  final double envelopeModulation;
  final double syllableRateHz;
  final double tonalStability;

  const AudioFeatures({...});
}

class AudioEventClassifier {
  static const int frameSize = 512;
  static const int hopSize = 256;

  static AudioFeatures analyzeFeatures(Uint8List pcm, {int sampleRate = 16000}) {
    // ...
  }
}
```

Алгоритм:
- обрезать хвост до целого числа сэмплов; кадры длиной 512 с шагом 256, последний кадр дополнить нулями; окно Ханна; FFT radix-2 на 512 точек (собственная реализация с предвычисленными twiddle-факторами).
- на кадр: RMS dBFS, ZCR, мощность по полосам 40–160/160–400/400–1000/1000–3000/3000–6000/6000–8000 Гц, centroid, flatness, flux (L2-разность нормированных магнитуд с предыдущим кадром), автокорреляция для лагов `sampleRate/320 … sampleRate/40` → `pitchStrength` = максимум нормированной корреляции, `f0Hz` = соответствующий лаг.
- шумовой порог: медиана RMS по кадрам + 6 дБ; `activeRatio` = доля кадров выше порога.
- агрегаты признаков — медиана по активным кадрам; при отсутствии активных кадров вернуть нули/`-100 dB` без делений на ноль.
- `envelopeModulation` и `syllableRateHz`: автокорреляция огибающей RMS (кадры 16 мс) в диапазоне 0.25–8 Гц, нормированная в 0…1.
- `tonalStability` = 1 − нормированный разброс `f0Hz` по активным кадрам (0…1).

- [ ] **Step 5: Запустить тесты признаков**

Run: `C:\flutter\bin\flutter.bat test test\audio_event_classifier_test.dart -r expanded`
Expected: PASS.

- [ ] **Step 6: Коммит**

```bash
git add lib/services/audio_event_classifier.dart test/audio_event_classifier_test.dart test/support/audio_test_signals.dart
git commit -m "feat(audio): extract spectral and temporal features for sleep sound analysis"
```

---

### Task 2: Классификация и уверенность

**Files:**
- Modify: `lib/services/audio_event_classifier.dart`
- Test: `test/audio_event_classifier_test.dart`

**Interfaces:**
- Consumes: `AudioFeatures`, `AudioEventClassifier.analyzeFeatures`.
- Produces:
  - `class AudioClassification` с полями `SleepSoundType type`, `double confidence`, `AudioFeatures features`.
  - `static AudioClassification AudioEventClassifier.classify(Uint8List pcm, {int sampleRate = 16000})`.
  - Импорт `../models/sleep_audio_clip.dart` для `SleepSoundType`.

- [ ] **Step 1: Написать падающие тесты классификации**

Добавить в `test/audio_event_classifier_test.dart`:

```dart
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
    expect(AudioEventClassifier.classify(ambientSignal()).type, SleepSoundType.ambient);
    expect(AudioEventClassifier.classify(tone(freq: 100, seconds: 10, amplitude: 0.02)).type, SleepSoundType.ambient);
  });

  test('тишина — ambient с нулевой уверенностью', () {
    final r = AudioEventClassifier.classify(silence());
    expect(r.type, SleepSoundType.ambient);
    expect(r.confidence, lessThanOrEqualTo(0.5));
  });

  test('очень короткий клип — movement', () {
    expect(AudioEventClassifier.classify(tone(seconds: 0.05)).type, SleepSoundType.movement);
  });

  test('тихий высокочастотный шорох — movement, не храп', () {
    expect(AudioEventClassifier.classify(rustleSignal(amplitude: 0.03)).type, SleepSoundType.movement);
  });
```

Импорт модели в тесте: `import 'package:somnia/models/sleep_audio_clip.dart';`

- [ ] **Step 2: Запустить тесты, убедиться что падают**

Run: `C:\flutter\bin\flutter.bat test test\audio_event_classifier_test.dart -r expanded`
Expected: FAIL — `classify` не определён.

- [ ] **Step 3: Реализовать классификацию**

Правила (все пороги — константы класса, документированы комментарием):

- Сначала жёсткие предохранители:
  - `peakDb < -55` или `activeRatio == 0` → `ambient`, `confidence = 0`.
  - `durationMs < 400` → `movement`.
- Затем баллы `0…1` для каждого типа по формулам от признаков:
  - `snoreScore`: доминирует `lowRatio` (40–400 Гц), `pitchStrength`, `tonalStability`, низкие `flatness`, `flux`, `zcr`, `highRatio`; вычитается `midRatio` сверх 0.45 и `syllableRateHz` выше 5 Гц.
  - `talkScore`: доминируют `midRatio`, `syllableRateHz` (2–6 Гц), `flux`, умеренные `pitchStrength`/`flatness`, `tonalStability` ниже, чем у храпа; вычитается `lowRatio` сверх 0.6.
  - `movementScore`: доминируют `flatness`, `highRatio`, `flux`, низкий `pitchStrength`; вычитается `tonalStability`.
  - `ambientScore`: низкие `rmsDb` и `activeRatio`, низкий `flux`, отсутствие `pitchStrength`; стационарность.
- Выбрать максимум; `confidence = topScore / (sum(scores) + 1e-6)`, ограничить `0…1`.
- Для `snore` добавить отсечку: если `pitchStrength < 0.12` или `lowRatio < 0.25`, балл умножить на 0.4.
- Для `movement` добавить отсечку: если `highRatio < 0.15` и `flatness < 0.25`, балл умножить на 0.5.

- [ ] **Step 4: Запустить тесты и подобрать веса**

Run: `C:\flutter\bin\flutter.bat test test\audio_event_classifier_test.dart -r expanded`
Expected: PASS. Если синтетический кейс не проходит — менять только веса/пороги, не тесты.

- [ ] **Step 5: Коммит**

```bash
git add lib/services/audio_event_classifier.dart test/audio_event_classifier_test.dart
git commit -m "feat(audio): classify snore, speech, rustle and ambient events"
```

---

### Task 3: Поле `confidence` в модели и хранилище

**Files:**
- Modify: `lib/models/sleep_audio_clip.dart`
- Test: `test/sleep_audio_clip_test.dart`

**Interfaces:**
- Produces: `final double? confidence;` в `SleepAudioClip`, параметр конструктора `double? confidence`, `copyWith({double? confidence})`, JSON-ключ `confidence` (опускается, если `null`).

- [ ] **Step 1: Написать падающие тесты**

Добавить в `test/sleep_audio_clip_test.dart`:

```dart
  test('confidence переживает JSON-сериализацию', () {
    final clip = SleepAudioClip(
      id: 'a', filePath: 'a.wav', timestamp: DateTime(2026, 1, 1),
      durationSeconds: 5, peakDecibels: -20, soundType: SleepSoundType.snore,
      confidence: 0.82,
    );
    expect(SleepAudioClip.fromJson(clip.toJson()).confidence, 0.82);
  });

  test('старый JSON без confidence читается', () {
    final json = {
      'id': 'a', 'filePath': 'a.wav', 'timestamp': '2026-01-01T00:00:00.000',
      'durationSeconds': 5, 'peakDecibels': -20, 'soundType': 'talk',
    };
    expect(SleepAudioClip.fromJson(json).confidence, isNull);
  });
```

- [ ] **Step 2: Запустить, убедиться что падают**

Run: `C:\flutter\bin\flutter.bat test test\sleep_audio_clip_test.dart -r expanded`
Expected: FAIL — у `SleepAudioClip` нет параметра `confidence`.

- [ ] **Step 3: Добавить поле**

`confidence` — последний необязательный параметр конструктора; в `toJson` добавлять ключ только при `!= null`; в `fromJson` — `(json['confidence'] as num?)?.toDouble()`; в `copyWith` — `confidence: confidence ?? this.confidence`.

- [ ] **Step 4: Запустить тесты**

Run: `C:\flutter\bin\flutter.bat test test\sleep_audio_clip_test.dart -r expanded`
Expected: PASS.

- [ ] **Step 5: Коммит**

```bash
git add lib/models/sleep_audio_clip.dart test/sleep_audio_clip_test.dart
git commit -m "feat(model): persist sound classification confidence"
```

---

### Task 4: Интеграция в ночной монитор

**Files:**
- Modify: `lib/services/sleep_audio_recorder_service.dart:417-433`

**Interfaces:**
- Consumes: `AudioEventClassifier.classify(Uint8List pcm, {int sampleRate})`, `AudioClassification.type`, `.confidence`.
- Produces: клипы с типом из DSP-классификатора и заполненным `confidence`.

- [ ] **Step 1: Заменить эвристику**

В `_finalizeCurrentClip` вместо блока `if (roundedDuration > 6 ...)`:

```dart
final classification = AudioEventClassifier.classify(
  pcm,
  sampleRate: _sampleRate,
);
```

В конструктор `SleepAudioClip` добавить `soundType: classification.type` и `confidence: classification.confidence`.

- [ ] **Step 2: Проверить компиляцию и существующие тесты**

Run: `C:\flutter\bin\flutter.bat analyze lib\services\sleep_audio_recorder_service.dart lib\services\audio_event_classifier.dart`
Expected: `No issues found!`

Run: `C:\flutter\bin\flutter.bat test`
Expected: все тесты PASS.

- [ ] **Step 3: Коммит**

```bash
git add lib/services/sleep_audio_recorder_service.dart
git commit -m "feat(audio): use DSP classifier for recorded night sounds"
```

---

### Task 5: Показать уверенность в карточке

**Files:**
- Modify: `lib/screens/tools/sleep_audio_screen.dart:506-509`

- [ ] **Step 1: Добавить процент уверенности**

После текста `Пик … dB` вывести, если `clip.confidence != null`:

```dart
const Text(' • ', style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted)),
Text(
  'Уверенность ${(clip.confidence! * 100).round()}%',
  style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
),
```

- [ ] **Step 2: Проверить анализ**

Run: `C:\flutter\bin\flutter.bat analyze lib\screens\tools\sleep_audio_screen.dart`
Expected: `No issues found!`

- [ ] **Step 3: Коммит**

```bash
git add lib/screens/tools/sleep_audio_screen.dart
git commit -m "feat(ui): show night sound classification confidence"
```

---

### Task 6: Финальная проверка

- [ ] **Step 1: Полный прогон**

Run: `C:\flutter\bin\flutter.bat analyze`
Expected: без новых ошибок относительно `git stash`-базовой линии; в изменённых файлах — `No issues found!`

Run: `C:\flutter\bin\flutter.bat test`
Expected: все тесты PASS, включая 7 новых кейсов классификации.

- [ ] **Step 2: Проверить диф**

Run: `git diff HEAD~5 --stat`
Expected: изменения только в `lib/services/audio_event_classifier.dart`, `lib/services/sleep_audio_recorder_service.dart`, `lib/models/sleep_audio_clip.dart`, `lib/screens/tools/sleep_audio_screen.dart`, тестах и `docs/superpowers/`.
