import 'dart:math' as math;
import 'dart:typed_data';

/// Акустические признаки фрагмента, посчитанные по PCM 16-бит моно.
class AudioFeatures {
  /// Длительность фрагмента, мс.
  final int durationMs;

  /// Доля кадров выше адаптивного шумового порога (0…1).
  final double activeRatio;

  /// Средний RMS по всему фрагменту, dBFS.
  final double rmsDb;

  /// Пиковый уровень, dBFS.
  final double peakDb;

  /// Средняя доля переходов через ноль на сэмпл.
  final double zcr;

  /// Спектральный центроид, Гц.
  final double centroidHz;

  /// Спектральная плоскостность (0 — тон, 1 — белый шум).
  final double flatness;

  /// Нормированная спектральная изменчивость между кадрами.
  final double flux;

  /// Сила периодичности по автокорреляции (0…1).
  final double pitchStrength;

  /// Основной тон, Гц.
  final double f0Hz;

  /// Доля энергии 40–400 Гц.
  final double lowRatio;

  /// Доля энергии 400–3000 Гц.
  final double midRatio;

  /// Доля энергии 3000–8000 Гц.
  final double highRatio;

  /// Глубина/регулярность модуляции огибающей (0…1).
  final double envelopeModulation;

  /// Частота модуляции огибающей, Гц.
  final double syllableRateHz;

  /// Стабильность основного тона (0…1).
  final double tonalStability;

  const AudioFeatures({
    required this.durationMs,
    required this.activeRatio,
    required this.rmsDb,
    required this.peakDb,
    required this.zcr,
    required this.centroidHz,
    required this.flatness,
    required this.flux,
    required this.pitchStrength,
    required this.f0Hz,
    required this.lowRatio,
    required this.midRatio,
    required this.highRatio,
    required this.envelopeModulation,
    required this.syllableRateHz,
    required this.tonalStability,
  });

  static const AudioFeatures empty = AudioFeatures(
    durationMs: 0,
    activeRatio: 0,
    rmsDb: -100,
    peakDb: -100,
    zcr: 0,
    centroidHz: 0,
    flatness: 0,
    flux: 0,
    pitchStrength: 0,
    f0Hz: 0,
    lowRatio: 0,
    midRatio: 0,
    highRatio: 0,
    envelopeModulation: 0,
    syllableRateHz: 0,
    tonalStability: 0,
  );

  @override
  String toString() {
    return 'AudioFeatures(dur=$durationMs ms, active=${activeRatio.toStringAsFixed(2)}, '
        'rms=${rmsDb.toStringAsFixed(1)} dB, peak=${peakDb.toStringAsFixed(1)} dB, '
        'zcr=${zcr.toStringAsFixed(3)}, centroid=${centroidHz.toStringAsFixed(0)} Hz, '
        'flat=${flatness.toStringAsFixed(3)}, flux=${flux.toStringAsFixed(3)}, '
        'pitch=${pitchStrength.toStringAsFixed(2)} @ ${f0Hz.toStringAsFixed(0)} Hz, '
        'low=${lowRatio.toStringAsFixed(2)}, mid=${midRatio.toStringAsFixed(2)}, '
        'high=${highRatio.toStringAsFixed(2)}, mod=${envelopeModulation.toStringAsFixed(2)} '
        '@ ${syllableRateHz.toStringAsFixed(2)} Hz)';
  }
}

/// Анализ ночных звуков: признаки сигнала и классификация события.
class AudioEventClassifier {
  static const int frameSize = 512;
  static const int hopSize = 256;

  static const double _eps = 1e-12;
  static const double _minDb = -100.0;

  /// Считает признаки по PCM16LE моно.
  static AudioFeatures analyzeFeatures(
    Uint8List pcm, {
    int sampleRate = 16000,
  }) {
    final int sampleCount = pcm.length ~/ 2;
    if (sampleCount < 32 || sampleRate <= 0) return AudioFeatures.empty;

    final Int16List samples = Int16List(sampleCount);
    final ByteData bytes = ByteData.sublistView(pcm);
    for (var i = 0; i < sampleCount; i++) {
      samples[i] = bytes.getInt16(i * 2, Endian.little);
    }

    final int durationMs = (sampleCount * 1000 / sampleRate).round();
    final int frameCount = sampleCount <= frameSize
        ? 1
        : 1 + (sampleCount - frameSize) ~/ hopSize;

    final Float64List frameDb = Float64List(frameCount);
    final Float64List frameZcr = Float64List(frameCount);
    final Float64List frameCentroid = Float64List(frameCount);
    final Float64List frameFlatness = Float64List(frameCount);
    final Float64List frameFlux = Float64List(frameCount);
    final Float64List framePitch = Float64List(frameCount);
    final Float64List frameF0 = Float64List(frameCount);
    final Float64List frameLow = Float64List(frameCount);
    final Float64List frameMid = Float64List(frameCount);
    final Float64List frameHigh = Float64List(frameCount);
    final Float64List envelope = Float64List(frameCount);

    final Float64List hann = _hannWindow(frameSize);
    final List<double> re = List<double>.filled(frameSize, 0);
    final List<double> im = List<double>.filled(frameSize, 0);
    List<double> prevMagnitudes = List<double>.filled(frameSize ~/ 2, 0);

    double peak = 0;
    for (var i = 0; i < sampleCount; i++) {
      final v = samples[i].abs() / 32768.0;
      if (v > peak) peak = v;
    }

    final int minLag = math.max(1, sampleRate ~/ 320);
    final int maxLag = math.min(sampleRate ~/ 40, frameSize - 1);

    for (var f = 0; f < frameCount; f++) {
      final int start = f * hopSize;
      final double sumSquares = _fillFrame(samples, start, re, hann);
      final double frameRms = math.sqrt(sumSquares / frameSize);
      frameDb[f] = _linearToDb(frameRms);
      envelope[f] = frameRms;

      frameZcr[f] = _zeroCrossingRate(samples, start);
      final _PitchResult pitch = _estimatePitch(
        samples,
        start,
        minLag,
        maxLag,
        sampleRate,
      );
      framePitch[f] = pitch.strength;
      frameF0[f] = pitch.f0;

      im.fillRange(0, frameSize, 0.0);
      _fft(re, im);

      final _Spectrum spectrum = _spectrumStats(
        re,
        im,
        sampleRate,
        prevMagnitudes,
        frameSize ~/ 2,
      );
      frameCentroid[f] = spectrum.centroid;
      frameFlatness[f] = spectrum.flatness;
      frameFlux[f] = spectrum.flux;
      frameLow[f] = spectrum.low;
      frameMid[f] = spectrum.mid;
      frameHigh[f] = spectrum.high;
      prevMagnitudes = spectrum.magnitudes;
    }

    // Адаптивный шумовой порог: медиана кадров + 6 дБ, но не выше -70 dB.
    final Float64List sortedDb = Float64List.fromList(frameDb)..sort();
    final double medianDb = sortedDb[sortedDb.length ~/ 2];
    final double threshold = math.min(medianDb + 6.0, -70.0);

    final List<int> active = <int>[];
    for (var f = 0; f < frameCount; f++) {
      if (frameDb[f] > threshold) active.add(f);
    }

    double overallRms;
    double sumSquaresAll = 0;
    for (var i = 0; i < sampleCount; i++) {
      final v = samples[i] / 32768.0;
      sumSquaresAll += v * v;
    }
    overallRms = math.sqrt(sumSquaresAll / sampleCount);

    final double activeRatio = active.isEmpty ? 0.0 : active.length / frameCount;

    final _Modulation modulation = _envelopeModulation(
      envelope,
      sampleRate,
      hopSize,
    );

    if (active.isEmpty) {
      return AudioFeatures(
        durationMs: durationMs,
        activeRatio: 0,
        rmsDb: _linearToDb(overallRms),
        peakDb: _linearToDb(peak),
        zcr: 0,
        centroidHz: 0,
        flatness: 0,
        flux: 0,
        pitchStrength: 0,
        f0Hz: 0,
        lowRatio: 0,
        midRatio: 0,
        highRatio: 0,
        envelopeModulation: modulation.depth,
        syllableRateHz: modulation.rateHz,
        tonalStability: 0,
      );
    }

    double medianOf(Float64List values) {
      final picked = Float64List(active.length);
      for (var i = 0; i < active.length; i++) {
        picked[i] = values[active[i]];
      }
      picked.sort();
      return picked[picked.length ~/ 2];
    }

    double meanOf(Float64List values) {
      double sum = 0;
      for (final i in active) {
        sum += values[i];
      }
      return sum / active.length;
    }

    final double low = meanOf(frameLow);
    final double mid = meanOf(frameMid);
    final double high = meanOf(frameHigh);
    final double lowSum = low + mid + high + _eps;

    final List<double> voicedF0 = <double>[];
    for (final i in active) {
      if (framePitch[i] > 0.3 && frameF0[i] > 0) voicedF0.add(frameF0[i]);
    }
    double tonalStability = 0;
    if (voicedF0.length >= 3) {
      voicedF0.sort();
      final double median = voicedF0[voicedF0.length ~/ 2];
      final double q1 = voicedF0[voicedF0.length ~/ 4];
      final double q3 = voicedF0[(voicedF0.length * 3) ~/ 4];
      if (median > 0) {
        tonalStability = (1.0 - (q3 - q1) / median).clamp(0.0, 1.0);
      }
    }

    return AudioFeatures(
      durationMs: durationMs,
      activeRatio: activeRatio,
      rmsDb: _linearToDb(overallRms),
      peakDb: _linearToDb(peak),
      zcr: medianOf(frameZcr),
      centroidHz: medianOf(frameCentroid),
      flatness: medianOf(frameFlatness),
      flux: meanOf(frameFlux),
      pitchStrength: medianOf(framePitch),
      f0Hz: medianOf(frameF0),
      lowRatio: low / lowSum,
      midRatio: mid / lowSum,
      highRatio: high / lowSum,
      envelopeModulation: modulation.depth,
      syllableRateHz: modulation.rateHz,
      tonalStability: tonalStability,
    );
  }

  static double _fillFrame(
    Int16List samples,
    int start,
    List<double> re,
    Float64List hann,
  ) {
    double sumSquares = 0;
    for (var i = 0; i < frameSize; i++) {
      final int index = start + i;
      final double v =
          index < samples.length ? samples[index] / 32768.0 : 0.0;
      sumSquares += v * v;
      re[i] = v * hann[i];
    }
    return sumSquares;
  }

  static Float64List _hannWindow(int size) {
    final Float64List window = Float64List(size);
    for (var i = 0; i < size; i++) {
      window[i] = 0.5 * (1 - math.cos(2 * math.pi * i / (size - 1)));
    }
    return window;
  }

  static double _zeroCrossingRate(Int16List samples, int start) {
    var crossings = 0;
    var previous = 0;
    var counted = 0;
    for (var i = 0; i < frameSize; i++) {
      final int index = start + i;
      if (index >= samples.length) break;
      final int sample = samples[index];
      if (i > 0 && ((sample >= 0) != (previous >= 0))) crossings++;
      previous = sample;
      counted++;
    }
    return counted <= 1 ? 0.0 : crossings / (counted - 1);
  }

  static _PitchResult _estimatePitch(
    Int16List samples,
    int start,
    int minLag,
    int maxLag,
    int sampleRate,
  ) {
    if (maxLag <= minLag) return const _PitchResult(0, 0);
    double energy = 0;
    for (var i = 0; i < frameSize; i++) {
      final int index = start + i;
      if (index >= samples.length) break;
      final double v = samples[index] / 32768.0;
      energy += v * v;
    }
    if (energy < 1e-8) return const _PitchResult(0, 0);

    double best = 0;
    int bestLag = 0;
    for (var lag = minLag; lag <= maxLag; lag++) {
      double cross = 0;
      double energyLag = 0;
      for (var i = 0; i + lag < frameSize; i++) {
        final int a = start + i;
        final int b = start + i + lag;
        if (b >= samples.length) break;
        final double va = samples[a] / 32768.0;
        final double vb = samples[b] / 32768.0;
        cross += va * vb;
        energyLag += vb * vb;
      }
      if (energyLag <= 0) continue;
      final double normalized = cross / math.sqrt(energy * energyLag + _eps);
      if (normalized > best) {
        best = normalized;
        bestLag = lag;
      }
    }
    if (bestLag == 0) return const _PitchResult(0, 0);
    return _PitchResult(best.clamp(0.0, 1.0), sampleRate / bestLag);
  }

  static _Spectrum _spectrumStats(
    List<double> re,
    List<double> im,
    int sampleRate,
    List<double> previousMagnitudes,
    int binCount,
  ) {
    final int binHz = sampleRate ~/ frameSize;
    final Float64List magnitudes = Float64List(binCount);
    final Float64List power = Float64List(binCount);

    for (var i = 0; i < binCount; i++) {
      final double p = re[i] * re[i] + im[i] * im[i];
      power[i] = p;
      magnitudes[i] = math.sqrt(p);
    }

    final int lowStart = math.max(1, 40 ~/ math.max(1, binHz));
    final int lowEnd = 400 ~/ math.max(1, binHz);
    final int midEnd = 3000 ~/ math.max(1, binHz);
    final int highEnd = math.min(binCount - 1, 8000 ~/ math.max(1, binHz));

    double low = 0;
    double mid = 0;
    double high = 0;
    double total = 0;
    double weighted = 0;
    double logSum = 0;
    var counted = 0;

    for (var i = lowStart; i <= highEnd; i++) {
      final double p = power[i];
      final double hz = i * binHz.toDouble();
      total += p;
      weighted += hz * p;
      logSum += math.log(p + _eps);
      counted++;
      if (i <= lowEnd) {
        low += p;
      } else if (i <= midEnd) {
        mid += p;
      } else {
        high += p;
      }
    }

    final double centroid = total > _eps ? weighted / total : 0;
    final double arithmetic = counted > 0 ? total / counted : 0;
    final double flatness = arithmetic > _eps
        ? (math.exp(logSum / math.max(1, counted)) / arithmetic).clamp(0.0, 1.0)
        : 0.0;

    double flux = 0;
    double magnitudeSum = 0;
    if (previousMagnitudes.length == binCount) {
      double diff = 0;
      for (var i = 1; i < binCount; i++) {
        diff += (magnitudes[i] - previousMagnitudes[i]).abs();
        magnitudeSum += magnitudes[i];
      }
      flux = magnitudeSum > _eps ? (diff / magnitudeSum).clamp(0.0, 1.0) : 0;
    }

    return _Spectrum(
      centroid: centroid,
      flatness: flatness,
      flux: flux,
      low: low,
      mid: mid,
      high: high,
      magnitudes: magnitudes,
    );
  }

  static _Modulation _envelopeModulation(
    Float64List envelope,
    int sampleRate,
    int hop,
  ) {
    final int n = envelope.length;
    if (n < 8) return const _Modulation(0, 0);

    double mean = 0;
    for (final v in envelope) {
      mean += v;
    }
    mean /= n;

    double variance = 0;
    for (final v in envelope) {
      final double d = v - mean;
      variance += d * d;
    }
    if (variance <= _eps) return const _Modulation(0, 0);

    final double frameRate = sampleRate / hop;
    final int minLag = math.max(1, (frameRate / 8).round());
    final int maxLag = math.min(n ~/ 2, (frameRate / 0.25).round());
    if (maxLag <= minLag) return const _Modulation(0, 0);

    double best = 0;
    int bestLag = 0;
    for (var lag = minLag; lag <= maxLag; lag++) {
      double cross = 0;
      for (var i = 0; i + lag < n; i++) {
        cross += (envelope[i] - mean) * (envelope[i + lag] - mean);
      }
      final double normalized = cross / variance;
      if (normalized > best) {
        best = normalized;
        bestLag = lag;
      }
    }
    if (bestLag == 0) return const _Modulation(0, 0);
    return _Modulation(best.clamp(0.0, 1.0), frameRate / bestLag);
  }

  /// Итеративное БПФ радикс-2 на месте.
  static void _fft(List<double> re, List<double> im) {
    final int n = re.length;
    var j = 0;
    for (var i = 0; i < n - 1; i++) {
      if (i < j) {
        final double tr = re[i];
        re[i] = re[j];
        re[j] = tr;
        final double ti = im[i];
        im[i] = im[j];
        im[j] = ti;
      }
      var m = n >> 1;
      while (m >= 1 && j >= m) {
        j -= m;
        m >>= 1;
      }
      j += m;
    }

    for (var len = 2; len <= n; len <<= 1) {
      final double angle = -2 * math.pi / len;
      final double wRe = math.cos(angle);
      final double wIm = math.sin(angle);
      for (var i = 0; i < n; i += len) {
        double curRe = 1;
        double curIm = 0;
        final int half = len >> 1;
        for (var k = 0; k < half; k++) {
          final int a = i + k;
          final int b = a + half;
          final double uRe = re[a];
          final double uIm = im[a];
          final double vRe = re[b] * curRe - im[b] * curIm;
          final double vIm = re[b] * curIm + im[b] * curRe;
          re[a] = uRe + vRe;
          im[a] = uIm + vIm;
          re[b] = uRe - vRe;
          im[b] = uIm - vIm;
          final double nextRe = curRe * wRe - curIm * wIm;
          curIm = curRe * wIm + curIm * wRe;
          curRe = nextRe;
        }
      }
    }
  }

  static double _linearToDb(double linear) {
    if (linear <= 0.0000001) return _minDb;
    return (20 * (math.log(linear) / math.ln10)).clamp(_minDb, 0.0);
  }
}

class _PitchResult {
  final double strength;
  final double f0;
  const _PitchResult(this.strength, this.f0);
}

class _Spectrum {
  final double centroid;
  final double flatness;
  final double flux;
  final double low;
  final double mid;
  final double high;
  final Float64List magnitudes;
  const _Spectrum({
    required this.centroid,
    required this.flatness,
    required this.flux,
    required this.low,
    required this.mid,
    required this.high,
    required this.magnitudes,
  });
}

class _Modulation {
  final double depth;
  final double rateHz;
  const _Modulation(this.depth, this.rateHz);
}
