import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import '../models/sleep_audio_clip.dart';

/// Feature vector order.  Keep in sync with `tools/somnia_audio/features.py`;
/// the order is part of the offline-analysis contract.
const List<String> kAudioFeatureNames = <String>[
  'duration_s',
  'active_duration_s',
  'snr_db',
  'duty_cycle',
  'active_frame_ratio',
  'onset_rate',
  'segment_duration_median_ms',
  'segment_duration_iqr_ms',
  'gap_cv',
  'crest_factor',
  'envelope_kurtosis',
  'short_broadband_ratio',
  'zcr_median',
  'centroid_median_hz',
  'centroid_iqr_hz',
  'rolloff_median_hz',
  'spectral_slope_db_per_khz',
  'flatness_median',
  'flatness_iqr',
  'flux_median',
  'band_50_150',
  'band_150_400',
  'band_400_1000',
  'band_1000_2500',
  'band_2500_5000',
  'band_5000_8000',
  'voicing_median',
  'voiced_frame_ratio',
  'f0_median_hz',
  'f0_std_semitones',
  'modulation_syllable_ratio',
  'modulation_breath_ratio',
  'modulation_breath_valid',
  'modulation_peak_hz',
];

/// Acoustic description of a night-sound event.
///
/// All spectral values are computed on *active* frames only: the recorder's
/// 2 s pre-roll and 3 s tail are excluded.  That was the central defect of
/// classifier v1.
class AudioFeatures {
  final int durationMs;
  final int activeDurationMs;
  final double activeRatio;
  final double rmsDb;
  final double peakDb;
  final double noiseFloorDb;
  final double snrDb;
  final double zcr;
  final double centroidHz;
  final double centroidIqrHz;
  final double rolloffHz;
  final double spectralSlopeDbPerKhz;
  final double flatness;
  final double flatnessIqr;
  final double flux;
  final List<double> bandRatios;
  final double voicing;
  final double voicedFrameRatio;
  final double f0Hz;
  final double f0StdSemitones;
  final double modulationSyllable;
  final double modulationBreath;
  final bool modulationBreathValid;
  final double modulationPeakHz;
  final double onsetRate;
  final double segmentDurationMedianMs;
  final double segmentDurationIqrMs;
  final double gapCv;
  final double crestFactor;
  final double envelopeKurtosis;
  final double shortBroadbandRatio;
  final int activeStartMs;
  final int activeEndMs;

  const AudioFeatures({
    required this.durationMs,
    required this.activeDurationMs,
    required this.activeRatio,
    required this.rmsDb,
    required this.peakDb,
    required this.noiseFloorDb,
    required this.snrDb,
    required this.zcr,
    required this.centroidHz,
    required this.centroidIqrHz,
    required this.rolloffHz,
    required this.spectralSlopeDbPerKhz,
    required this.flatness,
    required this.flatnessIqr,
    required this.flux,
    required this.bandRatios,
    required this.voicing,
    required this.voicedFrameRatio,
    required this.f0Hz,
    required this.f0StdSemitones,
    required this.modulationSyllable,
    required this.modulationBreath,
    required this.modulationBreathValid,
    required this.modulationPeakHz,
    required this.onsetRate,
    required this.segmentDurationMedianMs,
    required this.segmentDurationIqrMs,
    required this.gapCv,
    required this.crestFactor,
    required this.envelopeKurtosis,
    required this.shortBroadbandRatio,
    required this.activeStartMs,
    required this.activeEndMs,
  });

  /// Compatibility getter for v1 callers/tests.
  double get pitchStrength => voicing;

  /// Fraction of energy below 400 Hz (diagnostic only, not a classifier rule).
  double get lowRatio => bandRatios[0] + bandRatios[1];

  static const AudioFeatures empty = AudioFeatures(
    durationMs: 0,
    activeDurationMs: 0,
    activeRatio: 0,
    rmsDb: -100,
    peakDb: -100,
    noiseFloorDb: -100,
    snrDb: 0,
    zcr: 0,
    centroidHz: 0,
    centroidIqrHz: 0,
    rolloffHz: 0,
    spectralSlopeDbPerKhz: 0,
    flatness: 0,
    flatnessIqr: 0,
    flux: 0,
    bandRatios: <double>[0, 0, 0, 0, 0, 0],
    voicing: 0,
    voicedFrameRatio: 0,
    f0Hz: 0,
    f0StdSemitones: 0,
    modulationSyllable: 0,
    modulationBreath: 0,
    modulationBreathValid: false,
    modulationPeakHz: 0,
    onsetRate: 0,
    segmentDurationMedianMs: 0,
    segmentDurationIqrMs: 0,
    gapCv: 0,
    crestFactor: 0,
    envelopeKurtosis: 0,
    shortBroadbandRatio: 0,
    activeStartMs: 0,
    activeEndMs: 0,
  );

  /// Feature vector in [kAudioFeatureNames] order.
  ///
  /// This order is part of the model contract.  Keep it in sync with
  /// `tools/somnia_audio/features.py`.
  List<double> toVector() {
    return <double>[
      durationMs / 1000.0,
      activeDurationMs / 1000.0,
      snrDb,
      activeDurationMs / math.max(1, durationMs),
      activeRatio,
      onsetRate,
      segmentDurationMedianMs,
      segmentDurationIqrMs,
      gapCv,
      crestFactor,
      envelopeKurtosis,
      shortBroadbandRatio,
      zcr,
      centroidHz,
      centroidIqrHz,
      rolloffHz,
      spectralSlopeDbPerKhz,
      flatness,
      flatnessIqr,
      flux,
      bandRatios[0],
      bandRatios[1],
      bandRatios[2],
      bandRatios[3],
      bandRatios[4],
      bandRatios[5],
      voicing,
      voicedFrameRatio,
      f0Hz,
      f0StdSemitones,
      modulationSyllable,
      modulationBreath,
      modulationBreathValid ? 1.0 : 0.0,
      modulationPeakHz,
    ];
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        for (var i = 0; i < kAudioFeatureNames.length; i++)
          kAudioFeatureNames[i]: toVector()[i],
      };

  @override
  String toString() {
    return 'AudioFeatures(dur=$durationMs ms, active=$activeDurationMs ms, '
        'snr=${snrDb.toStringAsFixed(1)} dB, '
        'centroid=${centroidHz.toStringAsFixed(0)} Hz, '
        'flat=${flatness.toStringAsFixed(3)}, flux=${flux.toStringAsFixed(3)}, '
        'voicing=${voicing.toStringAsFixed(2)} @ ${f0Hz.toStringAsFixed(0)} Hz, '
        'breath=${modulationBreath.toStringAsFixed(2)} '
        '(valid=$modulationBreathValid), syllable=${modulationSyllable.toStringAsFixed(2)})';
  }
}

/// A contiguous part of a clip with one predicted class.
///
/// [AudioSegment] itself lives in `sleep_audio_clip.dart` so clips can
/// persist segments without importing the classifier.

/// Result of a classification run.
class AudioClassification {
  final SleepSoundType type;

  /// Calibrated top-1 probability (0…1).
  final double confidence;

  final AudioFeatures features;

  /// Calibrated probabilities for the four acoustic classes.
  final Map<SleepSoundType, double> probabilities;

  /// Per-second segments inside a mixed clip.
  final List<AudioSegment> segments;

  const AudioClassification({
    required this.type,
    required this.confidence,
    required this.features,
    this.probabilities = const <SleepSoundType, double>{},
    this.segments = const <AudioSegment>[],
  });

  @override
  String toString() {
    return 'AudioClassification(${type.name}, '
        '${(confidence * 100).toStringAsFixed(0)}%, '
        '${segments.length} segments) $features';
  }
}

/// Night-sound analysis: segmentation, features and a DSP classifier.
///
/// Feature extraction is a direct port of `tools/somnia_audio/features.py`.
/// Classification is a transparent score fusion over acoustic cues, not a
/// trained model:
///
/// * a snore is low and pulsed — energy below 400 Hz, low centroid and
///   zero-crossing rate, low mid-band energy, breathing-rate envelope
///   modulation;
/// * speech has mid-band formant energy, 2–8 Hz syllable modulation and many
///   onsets;
/// * a rustle is a short, bright, broadband transient;
/// * everything else is room tone.
///
/// The previous classifier was a logistic regression trained on synthetic
/// audio. On real snoring clips it recalled 3 % of the events: the synthetic
/// spectrum was far too bright and harmonic, so the learned decision boundary
/// never saw a real snore. Score fusion is slower to overfit a synthetic
/// generator and can be inspected feature by feature on a device.
class AudioEventClassifier {
  static const int frameSize = 400; // 25 ms at 16 kHz
  static const int hopSize = 160; // 10 ms
  static const int fftSize = 512;
  static const int _acfDecimation = 4;
  static const int _acfWindow = 640; // 40 ms
  static const int _acfMinLag = 10;
  static const int _acfMaxLag = 57;

  static const double _eps = 1e-12;
  static const double _minDb = -100.0;

  /// Softmax temperature applied to the fused scores.  Higher values make the
  /// reported confidence less sharp.
  static const double scoreTemperature = 1.6;

  /// Confidence below which the clip is reported as [SleepSoundType.unknown].
  static const double unknownConfidenceThreshold = 0.34;

  /// Below this much active audio there is nothing to classify.
  static const int minimumActiveMs = 150;

  static final Float64List _hann400 = _hann(frameSize);
  static final Float64List _cosTable = _cosTableFor(fftSize);
  static final Float64List _sinTable = _sinTableFor(fftSize);
  static final List<int> _bitReverse = _bitReverseTable(fftSize);

  /// Counts features over the whole clip (active frames only).
  static AudioFeatures analyzeFeatures(
    Uint8List pcm, {
    int sampleRate = 16000,
  }) {
    final _Analysis? analysis = _analyze(pcm, sampleRate);
    if (analysis == null) return AudioFeatures.empty;
    return analysis.aggregate(
      frameStart: 0,
      frameEnd: analysis.frameCount - 1,
      sampleStart: 0,
      sampleEnd: analysis.sampleCount,
      durationMs: analysis.durationMs,
    );
  }

  /// Classifies a PCM16LE mono clip.
  static AudioClassification classify(
    Uint8List pcm, {
    int sampleRate = 16000,
  }) {
    final _Analysis? analysis = _analyze(pcm, sampleRate);
    if (analysis == null || analysis.firstActive < 0) {
      return const AudioClassification(
        type: SleepSoundType.ambient,
        confidence: 0,
        features: AudioFeatures.empty,
        probabilities: <SleepSoundType, double>{
          SleepSoundType.snore: 0,
          SleepSoundType.talk: 0,
          SleepSoundType.movement: 0,
          SleepSoundType.ambient: 1,
        },
      );
    }

    final AudioFeatures features = analysis.aggregate(
      frameStart: 0,
      frameEnd: analysis.frameCount - 1,
      sampleStart: 0,
      sampleEnd: analysis.sampleCount,
      durationMs: analysis.durationMs,
    );
    if (features.activeDurationMs < minimumActiveMs) {
      return AudioClassification(
        type: SleepSoundType.ambient,
        confidence: 0,
        features: features,
        probabilities: const <SleepSoundType, double>{
          SleepSoundType.snore: 0,
          SleepSoundType.talk: 0,
          SleepSoundType.movement: 0,
          SleepSoundType.ambient: 1,
        },
      );
    }
    final List<AudioSegment> segments = _buildSegments(analysis);
    final List<double> probabilities = _probabilities(features);
    var best = 0;
    for (var i = 1; i < probabilities.length; i++) {
      if (probabilities[i] > probabilities[best]) best = i;
    }
    var type = _typeForIndex(best);
    var confidence = probabilities[best];
    if (confidence < unknownConfidenceThreshold) {
      type = SleepSoundType.unknown;
    }

    return AudioClassification(
      type: type,
      confidence: confidence,
      features: features,
      probabilities: <SleepSoundType, double>{
        for (var i = 0; i < probabilities.length; i++)
          _typeForIndex(i): probabilities[i],
      },
      segments: segments,
    );
  }

  /// Runs classification in a background isolate.
  static Future<AudioClassification> classifyAsync(
    Uint8List pcm, {
    int sampleRate = 16000,
  }) {
    return Isolate.run(() => classify(pcm, sampleRate: sampleRate));
  }

  // ------------------------------------------------------------- prediction

  /// Class order of the score vector.
  static const List<SleepSoundType> classOrder = <SleepSoundType>[
    SleepSoundType.snore,
    SleepSoundType.talk,
    SleepSoundType.movement,
    SleepSoundType.ambient,
  ];

  static SleepSoundType _typeForIndex(int index) => classOrder[index];

  /// Fused, unnormalised evidence for each class, in [classOrder].
  ///
  /// Exposed for tests and for an on-device diagnostics screen: a wrong label
  /// can be traced to the cue that produced it.
  static List<double> scores(AudioFeatures f) {
    if (f.activeDurationMs < minimumActiveMs || f.durationMs <= 0) {
      return const <double>[0, 0, 0, 4.0];
    }
    final double low = f.bandRatios[0] + f.bandRatios[1];
    final double mid = f.bandRatios[2] + f.bandRatios[3];
    final double high = f.bandRatios[4] + f.bandRatios[5];
    final double activeS = f.activeDurationMs / 1000.0;
    final double breath = f.modulationBreathValid ? f.modulationBreath : 0.0;

    // Real snores come in two shapes: a low rumble (most clip recordings) and
    // a brighter, raspier snore close to the microphone (a phone on the
    // nightstand).  The low-band terms catch the first; the breathing-rate
    // pulse plus the absence of syllable rhythm catch the second.
    var snore = 1.5 * _up(low, 0.30, 0.65) +
        1.0 * _down(f.centroidHz, 1300.0, 300.0) +
        1.2 * _down(f.zcr, 0.14, 0.04) +
        1.0 * _down(f.flatness, 0.22, 0.03) +
        1.6 * _down(mid, 0.40, 0.10) +
        0.6 * _up(activeS, 0.30, 1.00) +
        0.5 * _down(f.shortBroadbandRatio, 0.15, 0.0) +
        0.5 * _up(breath, 0.10, 0.35) +
        1.0 * _down(f.modulationSyllable, 0.30, 0.08) +
        0.3 * _up(f.voicedFrameRatio, 0.30, 0.70);

    var talk = 2.0 * _up(mid, 0.40, 0.70) +
        2.0 * _up(f.modulationSyllable, 0.40, 0.70) +
        1.2 * _up(f.onsetRate, 4.0, 9.0) +
        0.8 * _up(f.centroidHz, 800.0, 1300.0) +
        0.6 * _up(f.voicedFrameRatio, 0.70, 0.95) +
        0.6 * _down(low, 0.60, 0.20) +
        0.5 * _down(f.flatness, 0.30, 0.10);

    var movement = 2.2 * _up(f.centroidHz, 1800.0, 3000.0) +
        2.0 * _up(f.flatness, 0.18, 0.35) +
        1.5 * _up(f.zcr, 0.22, 0.38) +
        1.0 * _up(high, 0.15, 0.45) +
        0.8 * _up(f.envelopeKurtosis, 2.5, 6.0) +
        0.8 * _up(f.centroidIqrHz, 150.0, 500.0) +
        0.6 * _down(activeS, 1.5, 0.3) +
        0.5 * _up(f.shortBroadbandRatio, 0.02, 0.15) +
        0.4 * _down(breath, 0.40, 0.10);

    final double ambient = 1.5 +
        1.0 * _down(f.flux, 0.45, 0.20) +
        1.0 * _down(f.crestFactor, 2.2, 1.4) +
        0.8 * _down(f.modulationSyllable, 0.30, 0.10) +
        0.6 * _up(f.activeRatio, 0.55, 0.90) +
        0.5 * _down(f.shortBroadbandRatio, 0.10, 0.0) +
        1.0 * _steadyBonus(breath, f.modulationBreathValid);

    // When the active span is long enough to resolve the breathing band, a
    // snore must pulse.  A 100 Hz hum or a fan has no such pulse and is fully
    // described by the room-tone score.
    if (f.modulationBreathValid) {
      snore *= 0.25 + 0.75 * _up(breath, 0.06, 0.25);
    }
    // Speech is syllabic by definition.  A mid-band, voiced sound without any
    // 2–8 Hz rhythm is much more likely a raspy snore than a conversation.
    talk *= 0.45 + 0.55 * _up(f.modulationSyllable, 0.08, 0.30);

    // A silent or almost silent window has centroid 0, zcr 0 and flatness 0 —
    // without this gate every empty window would look like a perfect snore.
    final double evidence = _up(activeS, 0.15, 0.50);
    snore *= evidence;
    talk *= evidence;
    movement *= _up(activeS, 0.05, 0.25);

    return <double>[snore, talk, movement, ambient];
  }

  /// Room tone bonus for a steady envelope: high when the breathing band is
  /// resolvable and shows no pulse.
  static double _steadyBonus(double breath, bool valid) {
    if (!valid) return 0;
    return _down(breath, 0.35, 0.05);
  }

  /// Softmax over [scores] with [scoreTemperature].
  static List<double> _probabilities(AudioFeatures features) {
    final List<double> raw = scores(features);
    final double maxScore = raw.reduce(math.max);
    double sum = 0.0;
    for (final value in raw) {
      sum += math.exp((value - maxScore) / scoreTemperature);
    }
    final List<double> result = List<double>.filled(raw.length, 0);
    for (var i = 0; i < raw.length; i++) {
      result[i] = math.exp((raw[i] - maxScore) / scoreTemperature) / sum;
    }
    return result;
  }

  /// Linear ramp from 0 at [lo] to 1 at [hi].
  static double _up(double value, double lo, double hi) {
    if (!value.isFinite || hi <= lo) return 0;
    return ((value - lo) / (hi - lo)).clamp(0.0, 1.0);
  }

  /// Linear ramp from 1 at [lo] to 0 at [hi].
  static double _down(double value, double hi, double lo) =>
      1.0 - _up(value, lo, hi);

  // ------------------------------------------------------------- segments

  static List<AudioSegment> _buildSegments(_Analysis analysis) {
    const int windowMs = 1000;
    const int stepMs = 500;
    final int durationMs = analysis.durationMs;
    final List<int> starts = <int>[];
    if (durationMs <= windowMs) {
      starts.add(0);
    } else {
      for (var start = 0; start + windowMs <= durationMs; start += stepMs) {
        starts.add(start);
      }
      if (starts.isEmpty) starts.add(0);
    }

    final List<List<double>> raw = <List<double>>[];
    final List<int> ends = <int>[];
    for (final start in starts) {
      final int end = math.min(durationMs, start + windowMs);
      final int sampleStart = (start * analysis.sampleRate / 1000).round();
      final int sampleEnd = (end * analysis.sampleRate / 1000).round();
      final int frameStart = math.max(0, (sampleStart / hopSize).floor());
      final int frameEnd = math.min(
        analysis.frameCount - 1,
        math.max(frameStart, (sampleEnd - 1) ~/ hopSize),
      );
      final AudioFeatures windowFeatures = analysis.aggregate(
        frameStart: frameStart,
        frameEnd: frameEnd,
        sampleStart: sampleStart,
        sampleEnd: sampleEnd,
        durationMs: end - start,
      );
      if (windowFeatures.activeDurationMs < 100) {
        raw.add(<double>[0, 0, 0, 1]);
      } else {
        raw.add(_probabilities(windowFeatures));
      }
      ends.add(end);
    }

    // Median filter across three windows to remove one-window flicker.
    final List<List<double>> smoothed = <List<double>>[];
    for (var i = 0; i < raw.length; i++) {
      final List<double> values = List<double>.filled(4, 0);
      for (var c = 0; c < 4; c++) {
        final List<double> neighbourhood = <double>[];
        for (var offset = -1; offset <= 1; offset++) {
          final int index = i + offset;
          if (index >= 0 && index < raw.length) {
            neighbourhood.add(raw[index][c]);
          }
        }
        neighbourhood.sort();
        values[c] = neighbourhood[neighbourhood.length ~/ 2];
      }
      smoothed.add(values);
    }

    final List<AudioSegment> segments = <AudioSegment>[];
    for (var i = 0; i < smoothed.length; i++) {
      final List<double> probabilities = smoothed[i];
      var best = 0;
      for (var c = 1; c < probabilities.length; c++) {
        if (probabilities[c] > probabilities[best]) best = c;
      }
      final double confidence = probabilities[best];
      final SleepSoundType type = confidence < unknownConfidenceThreshold
          ? SleepSoundType.unknown
          : _typeForIndex(best);
      final int start = starts[i];
      final int end = ends[i];
      if (segments.isNotEmpty &&
          segments.last.type == type &&
          start <= segments.last.endMs + 250) {
        final AudioSegment previous = segments.removeLast();
        final int total = previous.endMs - previous.startMs + end - start;
        final double weighted = total <= 0
            ? confidence
            : (previous.confidence * (previous.endMs - previous.startMs) +
                    confidence * (end - start)) /
                total;
        segments.add(AudioSegment(
          startMs: previous.startMs,
          endMs: end,
          type: type,
          confidence: weighted,
        ));
      } else {
        segments.add(AudioSegment(
          startMs: start,
          endMs: end,
          type: type,
          confidence: confidence,
        ));
      }
    }
    return segments;
  }

  // ------------------------------------------------------------- analysis

  static _Analysis? _analyze(Uint8List pcm, int sampleRate) {
    if (sampleRate <= 0) return null;
    final int sampleCount = pcm.length ~/ 2;
    if (sampleCount < 32) return null;

    final Int16List raw = Int16List(sampleCount);
    final ByteData bytes = ByteData.sublistView(pcm);
    var peak = 0.0;
    for (var i = 0; i < sampleCount; i++) {
      final int value = bytes.getInt16(i * 2, Endian.little);
      raw[i] = value;
      final double normalized = value / 32768.0;
      final double magnitude = normalized.abs();
      if (magnitude > peak) peak = magnitude;
    }
    final Float32List samples = Float32List(sampleCount);
    for (var i = 0; i < sampleCount; i++) {
      samples[i] = raw[i] / 32768.0;
    }

    final int durationMs = (sampleCount * 1000 / sampleRate).round();
    final int frameCount =
        sampleCount <= frameSize ? 1 : 1 + (sampleCount - frameSize) ~/ hopSize;

    final Float64List frameDb = Float64List(frameCount);
    final Float64List frameZcr = Float64List(frameCount);
    final Float64List frameCentroid = Float64List(frameCount);
    final Float64List frameRolloff = Float64List(frameCount);
    final Float64List frameSlope = Float64List(frameCount);
    final Float64List frameFlatness = Float64List(frameCount);
    final Float64List frameFlux = Float64List(frameCount);
    final Float64List frameVoicing = Float64List(frameCount);
    final Float64List frameF0 = Float64List(frameCount);
    final Float64List bandPower = Float64List(frameCount * 6);

    final double binHz = sampleRate / fftSize;
    final List<int> audible = <int>[];
    final List<List<int>> bands = List<List<int>>.generate(6, (_) => <int>[]);
    final List<int> flatBins = <int>[];
    final List<int> slopeBins = <int>[];
    final List<double> centroidWeights = <double>[];
    const List<double> edges = <double>[50, 150, 400, 1000, 2500, 5000, 8000];
    for (var bin = 0; bin <= fftSize ~/ 2; bin++) {
      final double hz = bin * binHz;
      if (hz >= 50 && hz < 8000) {
        audible.add(bin);
        centroidWeights.add(hz);
      }
      for (var band = 0; band < 6; band++) {
        if (hz >= edges[band] && hz < edges[band + 1]) {
          bands[band].add(bin);
          break;
        }
      }
      if (hz >= 100 && hz < 4000) flatBins.add(bin);
      if (hz >= 50 && hz < 4000) slopeBins.add(bin);
    }

    final Float64List re = Float64List(fftSize);
    final Float64List im = Float64List(fftSize);
    final Float64List power = Float64List(fftSize ~/ 2 + 1);
    final Float64List magnitude = Float64List(fftSize ~/ 2 + 1);
    final Float64List previousMagnitude = Float64List(fftSize ~/ 2 + 1);
    final Float64List normalizedMagnitude = Float64List(fftSize ~/ 2 + 1);
    final Float64List frame = Float64List(frameSize);

    for (var index = 0; index < frameCount; index++) {
      final int start = index * hopSize;
      for (var i = 0; i < frameSize; i++) {
        final int position = start + i;
        frame[i] = position < sampleCount ? samples[position] : 0.0;
      }

      double sumSquares = 0;
      for (var i = 0; i < frameSize; i++) {
        sumSquares += frame[i] * frame[i];
      }
      frameDb[index] = _linearToDb(math.sqrt(sumSquares / frameSize));
      frameZcr[index] = _zeroCrossingRate(frame);

      for (var i = 0; i < fftSize; i++) {
        re[i] = i < frameSize ? frame[i] * _hann400[i] : 0.0;
        im[i] = 0.0;
      }
      _fft(re, im, _bitReverse, _cosTable, _sinTable);
      for (var bin = 0; bin <= fftSize ~/ 2; bin++) {
        final double p = re[bin] * re[bin] + im[bin] * im[bin];
        power[bin] = p;
        magnitude[bin] = math.sqrt(p);
      }

      double total = 0;
      double weighted = 0;
      for (var i = 0; i < audible.length; i++) {
        total += power[audible[i]];
        weighted += centroidWeights[i] * power[audible[i]];
      }
      frameCentroid[index] = total > _eps ? weighted / total : 0;

      double cumulative = 0;
      double rolloff = 0;
      if (total > _eps) {
        for (final bin in audible) {
          cumulative += power[bin];
          if (cumulative >= 0.85 * total) {
            rolloff = bin * binHz;
            break;
          }
        }
      }
      frameRolloff[index] = rolloff;

      double logSum = 0;
      double arithmetic = 0;
      for (final bin in flatBins) {
        logSum += math.log(power[bin] + _eps);
        arithmetic += power[bin];
      }
      if (flatBins.isNotEmpty) {
        arithmetic /= flatBins.length;
        frameFlatness[index] = arithmetic > _eps
            ? (math.exp(logSum / flatBins.length) / arithmetic).clamp(0.0, 1.0)
            : 0.0;
      }

      double slope = 0;
      if (slopeBins.length >= 2) {
        double meanF = 0;
        double meanDb = 0;
        for (final bin in slopeBins) {
          meanF += bin * binHz / 1000.0;
          meanDb += 10 * math.log(power[bin] + _eps) / math.ln10;
        }
        meanF /= slopeBins.length;
        meanDb /= slopeBins.length;
        double covariance = 0;
        double variance = 0;
        for (final bin in slopeBins) {
          final double f = bin * binHz / 1000.0;
          final double db = 10 * math.log(power[bin] + _eps) / math.ln10;
          covariance += (f - meanF) * (db - meanDb);
          variance += (f - meanF) * (f - meanF);
        }
        slope = variance > _eps ? covariance / variance : 0;
      }
      frameSlope[index] = slope;

      double magnitudeSum = 0;
      for (final bin in audible) {
        magnitudeSum += magnitude[bin];
      }
      final double safeMagnitude = magnitudeSum + _eps;
      double diff = 0;
      for (var bin = 0; bin <= fftSize ~/ 2; bin++) {
        normalizedMagnitude[bin] = magnitude[bin] / safeMagnitude;
        if (index > 0) {
          diff += (normalizedMagnitude[bin] - previousMagnitude[bin]).abs();
        }
      }
      frameFlux[index] = index == 0 ? 0.0 : diff.clamp(0.0, 1.0);
      previousMagnitude.setAll(0, normalizedMagnitude);

      for (var band = 0; band < 6; band++) {
        double sum = 0;
        for (final bin in bands[band]) {
          sum += power[bin];
        }
        bandPower[index * 6 + band] = sum;
      }

      if (index % 2 == 0) {
        final _VoicingResult voicing = _voicing(samples, start);
        frameVoicing[index] = voicing.strength;
        frameF0[index] = voicing.f0;
      } else {
        frameVoicing[index] = frameVoicing[index - 1];
        frameF0[index] = frameF0[index - 1];
      }
    }

    // 5th percentile, not 10th: a maximum-length clip of continuous snoring
    // can contain less than 10% quiet audio, and a contaminated floor would
    // hide every active frame of the very event we are classifying.
    final double noiseFloor = _percentile(frameDb, 0.05);
    final double startThreshold = noiseFloor + 10.0;
    final double holdThreshold = noiseFloor + 6.0;
    final Uint8List mask = Uint8List(frameCount);
    for (var i = 0; i < frameCount; i++) {
      if (frameDb[i] > holdThreshold || frameDb[i] > startThreshold) {
        mask[i] = 1;
      }
    }
    var index = 0;
    while (index < frameCount) {
      if (mask[index] == 1) {
        index++;
        continue;
      }
      final int gapStart = index;
      while (index < frameCount && mask[index] == 0) {
        index++;
      }
      final int gap = index - gapStart;
      if (gap > 0 && gap <= 4 && gapStart > 0 && index < frameCount) {
        for (var i = gapStart; i < index; i++) {
          mask[i] = 1;
        }
      }
    }

    var firstActive = -1;
    var lastActive = -1;
    for (var i = 0; i < frameCount; i++) {
      if (mask[i] == 1) {
        if (firstActive < 0) firstActive = i;
        lastActive = i;
      }
    }

    return _Analysis(
      samples: samples,
      sampleRate: sampleRate,
      sampleCount: sampleCount,
      durationMs: durationMs,
      frameCount: frameCount,
      frameDb: frameDb,
      frameZcr: frameZcr,
      frameCentroid: frameCentroid,
      frameRolloff: frameRolloff,
      frameSlope: frameSlope,
      frameFlatness: frameFlatness,
      frameFlux: frameFlux,
      frameVoicing: frameVoicing,
      frameF0: frameF0,
      bandPower: bandPower,
      mask: mask,
      noiseFloorDb: noiseFloor,
      peakDb: _linearToDb(peak),
      firstActive: firstActive,
      lastActive: lastActive,
    );
  }

  static double _zeroCrossingRate(Float64List frame) {
    var crossings = 0;
    var previous = frame[0] >= 0;
    for (var i = 1; i < frame.length; i++) {
      final bool current = frame[i] >= 0;
      if (current != previous) crossings++;
      previous = current;
    }
    return crossings / (frame.length - 1);
  }

  static _VoicingResult _voicing(Float32List samples, int start) {
    final Float64List chunk = Float64List(_acfWindow);
    final int available = math.min(_acfWindow, samples.length - start);
    if (available <= 0) return const _VoicingResult(0, 0);
    for (var i = 0; i < available; i++) {
      chunk[i] = samples[start + i];
    }
    const int downLength = _acfWindow ~/ _acfDecimation;
    final Float64List down = Float64List(downLength);
    for (var i = 0; i < downLength; i++) {
      var sum = 0.0;
      for (var j = 0; j < _acfDecimation; j++) {
        sum += chunk[i * _acfDecimation + j];
      }
      down[i] = sum / _acfDecimation;
    }
    double mean = 0;
    for (final value in down) {
      mean += value;
    }
    mean /= down.length;
    for (var i = 0; i < down.length; i++) {
      down[i] -= mean;
    }
    double energy = 0;
    for (final value in down) {
      energy += value * value;
    }
    if (energy <= 1e-10) return const _VoicingResult(0, 0);

    var best = 0.0;
    var bestLag = 0;
    var crossedZero = false;
    final int maxLag = math.min(_acfMaxLag, down.length - 1);
    for (var lag = _acfMinLag; lag <= maxLag; lag++) {
      double numerator = 0;
      double energyA = 0;
      double energyB = 0;
      final int limit = down.length - lag;
      for (var i = 0; i < limit; i++) {
        final double a = down[i];
        final double b = down[i + lag];
        numerator += a * b;
        energyA += a * a;
        energyB += b * b;
      }
      final double denominator = math.sqrt(energyA * energyB + _eps);
      if (denominator <= 0) continue;
      var correlation = numerator / denominator;
      correlation /= math.max(_eps, (down.length - lag) / down.length);
      if (!crossedZero) {
        if (correlation < 0) crossedZero = true;
        continue;
      }
      if (correlation > best) {
        best = correlation;
        bestLag = lag;
      }
    }
    if (bestLag == 0 || best <= 0) return const _VoicingResult(0, 0);
    final double f0 = (16000 / _acfDecimation) / bestLag;
    return _VoicingResult(best.clamp(0.0, 1.0), f0);
  }

  static _Modulation _modulation(Float64List envelope, double frameRate) {
    if (envelope.length < 8) {
      return const _Modulation(0, 0, 0, false);
    }
    double mean = 0;
    for (final value in envelope) {
      mean += value;
    }
    mean /= envelope.length;
    double variance = 0;
    for (final value in envelope) {
      final double d = value - mean;
      variance += d * d;
    }
    // A perfectly steady envelope is a valid measurement, not a missing one:
    // it is exactly how a fan or a mains hum looks.  Only a span too short to
    // resolve the breathing band is reported as invalid.
    final bool breathValid = envelope.length / frameRate >= 3.0;
    if (variance <= _eps) {
      return _Modulation(0, 0, 0, breathValid);
    }

    final int nfft = _nextPowerOfTwo(math.max(64, envelope.length));
    final Float64List re = Float64List(nfft);
    final Float64List im = Float64List(nfft);
    final Float64List hann = _hann(envelope.length);
    for (var i = 0; i < envelope.length; i++) {
      re[i] = (envelope[i] - mean) * hann[i];
    }
    final List<int> reverse = _bitReverseTable(nfft);
    final Float64List cosTable = _cosTableFor(nfft);
    final Float64List sinTable = _sinTableFor(nfft);
    _fft(re, im, reverse, cosTable, sinTable);

    final double frameRateHz = frameRate;
    final double binHz = frameRateHz / nfft;
    double total = 0;
    double syllable = 0;
    double breath = 0;
    double peak = 0;
    double peakHz = 0;
    for (var bin = 0; bin <= nfft ~/ 2; bin++) {
      final double hz = bin * binHz;
      final double p = re[bin] * re[bin] + im[bin] * im[bin];
      if (hz >= 0.05 && hz < 20) total += p;
      if (hz >= 2 && hz < 8) syllable += p;
      if (hz >= 0.15 && hz < 0.7) {
        breath += p;
      }
      if (hz >= 0.15 && hz <= 8 && p > peak) {
        peak = p;
        peakHz = hz;
      }
    }
    if (total <= _eps) return const _Modulation(0, 0, 0, false);
    // Breathing-band modulation is only meaningful once the active span holds
    // at least two breath cycles; below ~3 s a 0.15 Hz component cannot be
    // resolved, so it is reported as invalid instead of as a noisy ratio.
    final bool valid = envelope.length / frameRateHz >= 3.0;
    // A band *ratio* is meaningless when the envelope barely varies: the step
    // at the start and end of a steady hum is a few frames out of hundreds,
    // yet it owns most of an almost-zero total power.  Require a real
    // modulation depth before reporting a breathing component.
    final double coefficientOfVariation =
        mean > _eps ? math.sqrt(variance / envelope.length) / mean : 0.0;
    final bool pulsing = coefficientOfVariation >= 0.08;
    return _Modulation(
      syllable / total,
      valid && pulsing ? breath / total : 0,
      peakHz,
      valid,
    );
  }

  // ------------------------------------------------------------- aggregation

  static AudioFeatures _emptyFor(_Analysis analysis, int durationMs) {
    return AudioFeatures(
      durationMs: durationMs,
      activeDurationMs: 0,
      activeRatio: 0,
      rmsDb: -100,
      peakDb: analysis.peakDb,
      noiseFloorDb: analysis.noiseFloorDb,
      snrDb: 0,
      zcr: 0,
      centroidHz: 0,
      centroidIqrHz: 0,
      rolloffHz: 0,
      spectralSlopeDbPerKhz: 0,
      flatness: 0,
      flatnessIqr: 0,
      flux: 0,
      bandRatios: const <double>[0, 0, 0, 0, 0, 0],
      voicing: 0,
      voicedFrameRatio: 0,
      f0Hz: 0,
      f0StdSemitones: 0,
      modulationSyllable: 0,
      modulationBreath: 0,
      modulationBreathValid: false,
      modulationPeakHz: 0,
      onsetRate: 0,
      segmentDurationMedianMs: 0,
      segmentDurationIqrMs: 0,
      gapCv: 0,
      crestFactor: 0,
      envelopeKurtosis: 0,
      shortBroadbandRatio: 0,
      activeStartMs: 0,
      activeEndMs: 0,
    );
  }

  static double _percentile(Float64List values, double q) {
    if (values.isEmpty) return 0;
    final Float64List sorted = Float64List.fromList(values)..sort();
    final int index =
        (q * (sorted.length - 1) + 0.5).floor().clamp(0, sorted.length - 1);
    return sorted[index];
  }

  static double _medianOf(
    Float64List values,
    List<int> indices,
  ) {
    if (indices.isEmpty) return 0;
    final Float64List picked = Float64List(indices.length);
    for (var i = 0; i < indices.length; i++) {
      picked[i] = values[indices[i]];
    }
    return _percentile(picked, 0.5);
  }

  static double _iqrOf(Float64List values, List<int> indices) {
    if (indices.isEmpty) return 0;
    final Float64List picked = Float64List(indices.length);
    for (var i = 0; i < indices.length; i++) {
      picked[i] = values[indices[i]];
    }
    return _percentile(picked, 0.75) - _percentile(picked, 0.25);
  }

  static AudioFeatures _aggregate(
    _Analysis analysis, {
    required int frameStart,
    required int frameEnd,
    required int sampleStart,
    required int sampleEnd,
    required int durationMs,
  }) {
    if (frameStart > frameEnd ||
        frameStart < 0 ||
        frameEnd >= analysis.frameCount) {
      return _emptyFor(analysis, durationMs);
    }
    final List<int> active = <int>[];
    for (var i = frameStart; i <= frameEnd; i++) {
      if (analysis.mask[i] == 1) active.add(i);
    }
    if (active.isEmpty) return _emptyFor(analysis, durationMs);

    final int frameCount = frameEnd - frameStart + 1;
    final double activeDurationS =
        active.length * hopSize / analysis.sampleRate;
    final double activeRatio = active.length / frameCount;

    final List<_Run> runs = <_Run>[];
    var index = frameStart;
    while (index <= frameEnd) {
      if (analysis.mask[index] == 0) {
        index++;
        continue;
      }
      final int start = index;
      while (index <= frameEnd && analysis.mask[index] == 1) {
        index++;
      }
      runs.add(_Run(start, index - 1));
    }
    final Float64List durations = Float64List(runs.length);
    for (var i = 0; i < runs.length; i++) {
      durations[i] =
          (runs[i].end - runs[i].start + 1) * hopSize / analysis.sampleRate;
    }
    final List<double> gaps = <double>[];
    for (var i = 1; i < runs.length; i++) {
      gaps.add(
        (runs[i].start - runs[i - 1].end - 1) * hopSize / analysis.sampleRate,
      );
    }
    double gapCv = 0;
    if (gaps.length >= 2) {
      double mean = 0;
      for (final gap in gaps) {
        mean += gap;
      }
      mean /= gaps.length;
      if (mean > _eps) {
        double variance = 0;
        for (final gap in gaps) {
          final double d = gap - mean;
          variance += d * d;
        }
        gapCv = math.sqrt(variance / gaps.length) / mean;
      }
    }

    final int firstActive = active.first;
    final int lastActive = active.last;
    final double medianActiveDb = _medianOf(analysis.frameDb, active);
    final double snrDb = medianActiveDb - analysis.noiseFloorDb;
    final Float64List activeRms = Float64List(active.length);
    for (var i = 0; i < active.length; i++) {
      activeRms[i] = math.pow(10, analysis.frameDb[active[i]] / 20).toDouble();
    }
    double rmsMean = 0;
    double rmsMax = 0;
    for (final value in activeRms) {
      rmsMean += value;
      if (value > rmsMax) rmsMax = value;
    }
    rmsMean /= activeRms.length;
    final double crest = rmsMean > _eps ? rmsMax / rmsMean : 0;
    double kurtosis = 0;
    if (activeRms.length > 1) {
      double variance = 0;
      for (final value in activeRms) {
        final double d = value - rmsMean;
        variance += d * d;
      }
      variance /= activeRms.length;
      final double std = math.sqrt(variance);
      if (std > _eps) {
        double moment = 0;
        for (final value in activeRms) {
          final double d = (value - rmsMean) / std;
          moment += d * d * d * d;
        }
        kurtosis = moment / activeRms.length;
      }
    }

    double shortBroadband = 0;
    for (final run in runs) {
      final double runDuration =
          (run.end - run.start + 1) * hopSize / analysis.sampleRate;
      if (runDuration >= 0.150) continue;
      double centroid = 0;
      double flatness = 0;
      for (var i = run.start; i <= run.end; i++) {
        centroid += analysis.frameCentroid[i];
        flatness += analysis.frameFlatness[i];
      }
      final int count = run.end - run.start + 1;
      if (centroid / count > 2000 && flatness / count > 0.30) {
        shortBroadband += runDuration;
      }
    }

    final Float64List meanBands = Float64List(6);
    for (final frame in active) {
      for (var band = 0; band < 6; band++) {
        meanBands[band] += analysis.bandPower[frame * 6 + band];
      }
    }
    double bandSum = _eps;
    for (var band = 0; band < 6; band++) {
      meanBands[band] /= active.length;
      bandSum += meanBands[band];
    }
    final List<double> bandRatios = <double>[
      for (var band = 0; band < 6; band++) meanBands[band] / bandSum,
    ];

    final List<int> voiced = <int>[];
    for (final frame in active) {
      if (analysis.frameVoicing[frame] > 0.30 && analysis.frameF0[frame] > 0) {
        voiced.add(frame);
      }
    }
    final double f0Median =
        voiced.isEmpty ? 0 : _medianOf(analysis.frameF0, voiced);
    double f0Std = 0;
    if (voiced.length >= 2 && f0Median > 0) {
      double sum = 0;
      for (final frame in voiced) {
        sum += math.log(analysis.frameF0[frame] / f0Median) / math.ln2 * 12;
      }
      final double mean = sum / voiced.length;
      double variance = 0;
      for (final frame in voiced) {
        final double value =
            math.log(analysis.frameF0[frame] / f0Median) / math.ln2 * 12;
        final double d = value - mean;
        variance += d * d;
      }
      f0Std = math.sqrt(variance / voiced.length);
    }

    final Float64List envelope = Float64List(lastActive - firstActive + 1);
    for (var i = firstActive; i <= lastActive; i++) {
      envelope[i - firstActive] =
          math.pow(10, analysis.frameDb[i] / 20).toDouble();
    }
    final _Modulation modulation =
        _modulation(envelope, analysis.sampleRate / hopSize);

    double peak = 0;
    for (var i = sampleStart; i < sampleEnd && i < analysis.sampleCount; i++) {
      final double value = analysis.samples[i].abs();
      if (value > peak) peak = value;
    }

    final int activeStartMs = math.max(
      0,
      ((firstActive * hopSize - sampleStart) * 1000 / analysis.sampleRate)
          .round(),
    );
    final int activeEndMs = math.min(
      durationMs,
      math.max(
        0,
        ((lastActive * hopSize + frameSize - sampleStart) *
                1000 /
                analysis.sampleRate)
            .round(),
      ),
    );

    return AudioFeatures(
      durationMs: durationMs,
      activeDurationMs: (activeDurationS * 1000).round(),
      activeRatio: activeRatio,
      rmsDb: _linearToDb(rmsMean),
      peakDb: _linearToDb(peak),
      noiseFloorDb: analysis.noiseFloorDb,
      snrDb: snrDb,
      zcr: _medianOf(analysis.frameZcr, active),
      centroidHz: _medianOf(analysis.frameCentroid, active),
      centroidIqrHz: _iqrOf(analysis.frameCentroid, active),
      rolloffHz: _medianOf(analysis.frameRolloff, active),
      spectralSlopeDbPerKhz: _medianOf(analysis.frameSlope, active),
      flatness: _medianOf(analysis.frameFlatness, active),
      flatnessIqr: _iqrOf(analysis.frameFlatness, active),
      flux: _medianOf(analysis.frameFlux, active),
      bandRatios: bandRatios,
      voicing: _medianOf(analysis.frameVoicing, active),
      voicedFrameRatio: voiced.length / active.length,
      f0Hz: f0Median,
      f0StdSemitones: f0Std,
      modulationSyllable: modulation.syllable,
      modulationBreath: modulation.breath,
      modulationBreathValid: modulation.breathValid,
      modulationPeakHz: modulation.peak,
      onsetRate: runs.length / math.max(_eps, activeDurationS),
      segmentDurationMedianMs: _percentile(durations, 0.5) * 1000,
      segmentDurationIqrMs:
          (_percentile(durations, 0.75) - _percentile(durations, 0.25)) * 1000,
      gapCv: gapCv,
      crestFactor: crest,
      envelopeKurtosis: kurtosis,
      shortBroadbandRatio: shortBroadband / math.max(_eps, activeDurationS),
      activeStartMs: activeStartMs,
      activeEndMs: activeEndMs,
    );
  }

  // ------------------------------------------------------------- FFT tables

  static Float64List _hann(int size) {
    final Float64List window = Float64List(size);
    for (var i = 0; i < size; i++) {
      window[i] = 0.5 * (1 - math.cos(2 * math.pi * i / math.max(1, size - 1)));
    }
    return window;
  }

  static Float64List _cosTableFor(int size) {
    final Float64List table = Float64List(size ~/ 2);
    for (var i = 0; i < table.length; i++) {
      table[i] = math.cos(2 * math.pi * i / size);
    }
    return table;
  }

  static Float64List _sinTableFor(int size) {
    final Float64List table = Float64List(size ~/ 2);
    for (var i = 0; i < table.length; i++) {
      table[i] = math.sin(2 * math.pi * i / size);
    }
    return table;
  }

  static List<int> _bitReverseTable(int size) {
    var bits = 0;
    while ((1 << bits) < size) {
      bits++;
    }
    final List<int> table = List<int>.filled(size, 0);
    for (var i = 0; i < size; i++) {
      var value = i;
      var reversed = 0;
      for (var bit = 0; bit < bits; bit++) {
        reversed = (reversed << 1) | (value & 1);
        value >>= 1;
      }
      table[i] = reversed;
    }
    return table;
  }

  static void _fft(
    Float64List re,
    Float64List im,
    List<int> reverse,
    Float64List cosTable,
    Float64List sinTable,
  ) {
    final int n = re.length;
    for (var i = 0; i < n; i++) {
      final int j = reverse[i];
      if (i < j) {
        final double tr = re[i];
        re[i] = re[j];
        re[j] = tr;
        final double ti = im[i];
        im[i] = im[j];
        im[j] = ti;
      }
    }
    for (var length = 2; length <= n; length <<= 1) {
      final int half = length >> 1;
      final int step = n ~/ length;
      for (var start = 0; start < n; start += length) {
        for (var k = 0; k < half; k++) {
          final int tableIndex = k * step;
          final double wRe = cosTable[tableIndex];
          final double wIm = -sinTable[tableIndex];
          final int a = start + k;
          final int b = a + half;
          final double uRe = re[a];
          final double uIm = im[a];
          final double vRe = re[b] * wRe - im[b] * wIm;
          final double vIm = re[b] * wIm + im[b] * wRe;
          re[a] = uRe + vRe;
          im[a] = uIm + vIm;
          re[b] = uRe - vRe;
          im[b] = uIm - vIm;
        }
      }
    }
  }

  static int _nextPowerOfTwo(int value) {
    var result = 1;
    while (result < value) {
      result <<= 1;
    }
    return result;
  }

  static double _linearToDb(double linear) {
    if (linear <= 0.0000001) return _minDb;
    return (20 * (math.log(linear) / math.ln10)).clamp(_minDb, 0.0);
  }
}

class _Analysis {
  final Float32List samples;
  final int sampleRate;
  final int sampleCount;
  final int durationMs;
  final int frameCount;
  final Float64List frameDb;
  final Float64List frameZcr;
  final Float64List frameCentroid;
  final Float64List frameRolloff;
  final Float64List frameSlope;
  final Float64List frameFlatness;
  final Float64List frameFlux;
  final Float64List frameVoicing;
  final Float64List frameF0;
  final Float64List bandPower;
  final Uint8List mask;
  final double noiseFloorDb;
  final double peakDb;
  final int firstActive;
  final int lastActive;

  const _Analysis({
    required this.samples,
    required this.sampleRate,
    required this.sampleCount,
    required this.durationMs,
    required this.frameCount,
    required this.frameDb,
    required this.frameZcr,
    required this.frameCentroid,
    required this.frameRolloff,
    required this.frameSlope,
    required this.frameFlatness,
    required this.frameFlux,
    required this.frameVoicing,
    required this.frameF0,
    required this.bandPower,
    required this.mask,
    required this.noiseFloorDb,
    required this.peakDb,
    required this.firstActive,
    required this.lastActive,
  });

  AudioFeatures aggregate({
    required int frameStart,
    required int frameEnd,
    required int sampleStart,
    required int sampleEnd,
    required int durationMs,
  }) {
    return AudioEventClassifier._aggregate(
      this,
      frameStart: frameStart,
      frameEnd: frameEnd,
      sampleStart: sampleStart,
      sampleEnd: sampleEnd,
      durationMs: durationMs,
    );
  }
}

class _Run {
  final int start;
  final int end;
  const _Run(this.start, this.end);
}

class _VoicingResult {
  final double strength;
  final double f0;
  const _VoicingResult(this.strength, this.f0);
}

class _Modulation {
  final double syllable;
  final double breath;
  final double peak;
  final bool breathValid;
  const _Modulation(this.syllable, this.breath, this.peak, this.breathValid);
}
