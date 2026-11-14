import 'dart:math' as math;
import 'dart:typed_data';

/// Result of feeding one PCM chunk to [NightSoundDetector].
///
/// A non-null result means the detector has just closed an event window and
/// handed back the complete PCM buffer, ready for WAV writing and
/// classification.
class DetectedClip {
  /// Raw PCM16LE mono bytes: pre-roll + event + silence tail.
  final Uint8List pcm;

  /// Start of the clip including the pre-roll, wall-clock time.
  final DateTime startTime;

  /// End of the clip, wall-clock time.
  final DateTime endTime;

  /// Peak broadband level inside the clip, dBFS.
  final double peakDb;

  /// Number of samples that were above the hold threshold.  This is the
  /// "active" part of the event and is what the recorder uses to drop
  /// sub-second clicks.
  final int activeSamples;

  const DetectedClip({
    required this.pcm,
    required this.startTime,
    required this.endTime,
    required this.peakDb,
    required this.activeSamples,
  });
}

/// Pure-Dart adaptive event detector for night-sound monitoring.
///
/// The detector owns the whole record decision: pre-roll, trigger, hysteresis,
/// silence tail and the maximum clip length.  Keeping it independent of the
/// audio plugin makes the state machine testable with synthetic PCM streams –
/// the audio plugin can only be exercised on a device.
///
/// Detection is **relative to a local noise floor** rather than to an absolute
/// dBFS slider.  Two levels are tracked per chunk:
///
/// * broadband RMS (everything the microphone hears);
/// * band-limited RMS in the 60–1200 Hz band, where snoring and most bedroom
///   rumble live.
///
/// A chunk triggers when either level rises far enough above its own floor.
/// A steady fan, an air conditioner or a fridge hum raises the floor too, so it
/// does not trigger; a snore that is 20 dB below a loud hiss but stands out in
/// the low band still does.  The floors are adaptive and frozen while a clip is
/// being recorded, so a long snore cannot lift its own threshold and cut itself
/// off.
class NightSoundDetector {
  /// PCM sample rate, Hz.
  final int sampleRate;

  /// Seconds of audio kept before the trigger so a clip does not start in the
  /// middle of a snore.
  final int preRollSeconds;

  /// Close the clip after this many seconds without a level above the hold
  /// threshold.
  final int silenceTimeoutSeconds;

  /// Hard cap for one clip.
  final int maxDurationSeconds;

  /// How far above the local noise floor an event must rise, dB.
  ///
  /// Higher = less sensitive.  This is the user-facing "sensitivity" setting.
  double sensitivityDb;

  /// Never trigger below this absolute level, dBFS.  Prevents the detector
  /// from amplifying the noise of an utterly silent room.
  final double absoluteFloorDb;

  set sensitivity(double value) => sensitivityDb = value;

  static const int _bucketMs = 100;
  static const int _floorWindowSeconds = 60;
  static const double _floorPercentile = 0.10;
  static const int _floorUpdateMs = 500;
  static const int _warmupBuckets = 15; // 1.5 s of audio before detecting

  final _BandFilter _bandFilter;

  bool _enabled = false;
  bool _isRecording = false;

  double _broadbandDb = -100.0;
  double _bandDb = -100.0;
  double _floorDb = -100.0;
  double _bandFloorDb = -100.0;
  bool _floorPrimed = false;

  final List<_LevelBucket> _history = <_LevelBucket>[];
  int _bucketElapsedMs = 0;
  double _bucketBroadEnergy = 0.0;
  double _bucketBandEnergy = 0.0;
  int _bucketSamples = 0;
  int _msSinceFloorUpdate = 0;
  int _lastChunkMs = 0;

  final List<Uint8List> _preRoll = <Uint8List>[];
  int _preRollBytes = 0;

  BytesBuilder? _clipBuffer;
  int _clipSamples = 0;
  int _silenceSamples = 0;
  int _activeSamples = 0;
  double _clipPeakDb = -100.0;
  DateTime? _clipStart;

  int _aboveTriggerStreak = 0;

  NightSoundDetector({
    this.sampleRate = 16000,
    this.preRollSeconds = 2,
    this.silenceTimeoutSeconds = 3,
    this.maxDurationSeconds = 45,
    this.sensitivityDb = 7.0,
    this.absoluteFloorDb = -72.0,
  }) : _bandFilter = _BandFilter(sampleRate);

  bool get isRecording => _isRecording;
  double get currentDb => _broadbandDb;
  double get lowBandDb => _bandDb;
  double get noiseFloorDb => _floorDb;
  double get lowBandFloorDb => _bandFloorDb;

  /// Effective trigger level shown in the UI.
  double get triggerThresholdDb =>
      math.min(-5.0, math.max(absoluteFloorDb, _floorDb + sensitivityDb));

  /// Seconds currently buffered for the open clip.
  double get clipDurationSeconds => _clipSamples / sampleRate;

  double get _holdAboveFloorDb => math.max(3.0, sensitivityDb - 4.0);

  /// Enable/disable recording while the detector keeps learning the noise
  /// floor.  Used for the "wait N minutes before listening" delay: the audio
  /// session must stay alive so iOS does not suspend the app.
  set enabled(bool value) {
    _enabled = value;
    if (!value && _isRecording) {
      _discardClip();
    }
  }

  /// Forget the learned floor.  Call when monitoring starts.
  ///
  /// [keepFloor] is used by the interruption watchdog: the room has not
  /// changed while the audio engine was restarting, so re-learning the floor
  /// would only create a blind window.
  void reset({bool keepFloor = false}) {
    _enabled = false;
    _discardClip();
    if (!keepFloor) {
      _history.clear();
      _preRoll.clear();
      _preRollBytes = 0;
      _bucketElapsedMs = 0;
      _bucketBroadEnergy = 0.0;
      _bucketBandEnergy = 0.0;
      _bucketSamples = 0;
      _broadbandDb = -100.0;
      _bandDb = -100.0;
      _floorDb = -100.0;
      _bandFloorDb = -100.0;
      _floorPrimed = false;
      _msSinceFloorUpdate = 0;
      _bandFilter.reset();
    }
    _aboveTriggerStreak = 0;
  }

  /// Feed one PCM16LE mono chunk.
  ///
  /// Returns a [DetectedClip] when this chunk closed an event, otherwise null.
  DetectedClip? addChunk(Uint8List chunk, {DateTime? now}) {
    if (chunk.length < 2) return null;
    final int sampleCount = chunk.length ~/ 2;
    if (sampleCount == 0) return null;
    final DateTime time = now ?? DateTime.now();

    final data = ByteData.sublistView(chunk);
    double broadSum = 0.0;
    double bandSum = 0.0;
    for (var i = 0; i < sampleCount; i++) {
      final double sample = data.getInt16(i * 2, Endian.little) / 32768.0;
      broadSum += sample * sample;
      final double filtered = _bandFilter.process(sample);
      bandSum += filtered * filtered;
    }
    _broadbandDb = _toDb(math.sqrt(broadSum / sampleCount));
    _bandDb = _toDb(math.sqrt(bandSum / sampleCount));
    _lastChunkMs = (sampleCount * 1000 / sampleRate).round();

    _accumulateHistory(sampleCount, broadSum, bandSum);

    final bool aboveHold =
        _floorPrimed && _bandDb - _bandFloorDb >= _holdAboveFloorDb;
    final bool aboveBroadHold =
        _floorPrimed && _broadbandDb - _floorDb >= _holdAboveFloorDb + 1.5;

    // The floor is learned from idle audio only.  Event audio must never enter
    // the statistics: a continuous snore would otherwise raise its own floor
    // and cut itself off after a few seconds.
    if (!_isRecording) {
      _maybeUpdateFloor();
    }

    if (_isRecording) {
      _append(chunk, sampleCount, aboveHold || aboveBroadHold);
      if (aboveHold || aboveBroadHold) {
        _silenceSamples = 0;
      } else {
        _silenceSamples += sampleCount;
      }
      final bool silenceDone =
          _silenceSamples >= silenceTimeoutSeconds * sampleRate;
      final bool tooLong = _clipSamples >= maxDurationSeconds * sampleRate;
      if (silenceDone || tooLong) {
        return _finish(time);
      }
      return null;
    }

    // Idle: keep a rolling pre-roll.
    _addToPreRoll(chunk);

    if (!_enabled) {
      _aboveTriggerStreak = 0;
      return null;
    }
    if (_history.length < _warmupBuckets) return null;

    final bool trigger = _isTrigger();
    if (!trigger) {
      _aboveTriggerStreak = 0;
      return null;
    }
    _aboveTriggerStreak++;
    // Two ~20 ms chunks make a ~40 ms event; a single very strong chunk is
    // enough on its own.
    final double bandSnr = _bandDb - _bandFloorDb;
    final double broadSnr = _broadbandDb - _floorDb;
    if (_aboveTriggerStreak < 2 &&
        bandSnr < sensitivityDb + 6.0 &&
        broadSnr < sensitivityDb + 8.0) {
      return null;
    }
    _startClip(chunk, sampleCount, time);
    return null;
  }

  bool _isTrigger() {
    if (_broadbandDb < absoluteFloorDb && _bandDb < absoluteFloorDb) {
      return false;
    }
    final double bandSnr = _bandDb - _bandFloorDb;
    final double broadSnr = _broadbandDb - _floorDb;
    // The low band is the snore channel: a smaller rise is already meaningful.
    // Broadband needs a bigger rise so taps, hiss and desk bumps stay out.
    return bandSnr >= sensitivityDb || broadSnr >= sensitivityDb + 3.0;
  }

  void _startClip(Uint8List chunk, int sampleCount, DateTime time) {
    _isRecording = true;
    _clipBuffer = BytesBuilder(copy: false);
    _clipSamples = 0;
    _silenceSamples = 0;
    _activeSamples = 0;
    _clipPeakDb = _broadbandDb;

    final int preRollSamples = _preRollBytes ~/ 2;
    _clipStart = time.subtract(
      Duration(milliseconds: (preRollSamples * 1000 / sampleRate).round()),
    );

    for (final buffered in _preRoll) {
      _clipBuffer!.add(buffered);
      _clipSamples += buffered.length ~/ 2;
    }
    _preRoll.clear();
    _preRollBytes = 0;

    _clipBuffer!.add(chunk);
    _clipSamples += sampleCount;
    _activeSamples += sampleCount;
  }

  void _append(Uint8List chunk, int sampleCount, bool active) {
    if (_clipBuffer == null) return;
    _clipBuffer!.add(chunk);
    _clipSamples += sampleCount;
    if (active) _activeSamples += sampleCount;
    if (_broadbandDb > _clipPeakDb) _clipPeakDb = _broadbandDb;
  }

  DetectedClip? _finish(DateTime time) {
    final buffer = _clipBuffer;
    final start = _clipStart;
    final peak = _clipPeakDb;
    final active = _activeSamples;
    _discardClip();
    if (buffer == null) return null;
    final pcm = buffer.takeBytes();
    if (pcm.isEmpty) return null;
    return DetectedClip(
      pcm: pcm,
      startTime: start ?? time,
      endTime: time,
      peakDb: peak,
      activeSamples: active,
    );
  }

  void _discardClip() {
    _isRecording = false;
    _clipBuffer = null;
    _clipSamples = 0;
    _silenceSamples = 0;
    _activeSamples = 0;
    _clipPeakDb = -100.0;
    _clipStart = null;
  }

  void _addToPreRoll(Uint8List chunk) {
    _preRoll.add(chunk);
    _preRollBytes += chunk.length;
    final int maxBytes = preRollSeconds * sampleRate * 2;
    while (_preRollBytes > maxBytes && _preRoll.isNotEmpty) {
      _preRollBytes -= _preRoll.removeAt(0).length;
    }
  }

  void _accumulateHistory(int sampleCount, double broadSum, double bandSum) {
    if (_isRecording) return;
    _bucketBroadEnergy += broadSum;
    _bucketBandEnergy += bandSum;
    _bucketSamples += sampleCount;
    _bucketElapsedMs += (sampleCount * 1000 / sampleRate).round();
    if (_bucketElapsedMs < _bucketMs) return;
    _history.add(_LevelBucket(
      broadbandDb: _toDb(math.sqrt(_bucketBroadEnergy / _bucketSamples)),
      bandDb: _toDb(math.sqrt(_bucketBandEnergy / _bucketSamples)),
    ));
    _bucketBroadEnergy = 0.0;
    _bucketBandEnergy = 0.0;
    _bucketSamples = 0;
    _bucketElapsedMs = 0;
    const int maxBuckets = _floorWindowSeconds * 1000 ~/ _bucketMs;
    while (_history.length > maxBuckets) {
      _history.removeAt(0);
    }
  }

  void _maybeUpdateFloor() {
    if (_history.length < 4) return;
    _msSinceFloorUpdate += _lastChunkMs;
    if (_msSinceFloorUpdate < _floorUpdateMs) return;
    _msSinceFloorUpdate = 0;

    final int n = _history.length;
    final List<double> broad =
        List<double>.generate(n, (i) => _history[i].broadbandDb)..sort();
    final List<double> band =
        List<double>.generate(n, (i) => _history[i].bandDb)..sort();
    final int index = (_floorPercentile * (n - 1)).round().clamp(0, n - 1);
    final double broadP = broad[index];
    final double bandP = band[index];

    if (!_floorPrimed) {
      _floorDb = broadP;
      _bandFloorDb = bandP;
      _floorPrimed = true;
      return;
    }
    // Down fast, up slowly: a snore must not drag the floor up and mask the
    // rest of the night, but a room that got quieter should be tracked.
    _floorDb = (broadP < _floorDb
            ? _floorDb * 0.5 + broadP * 0.5
            : _floorDb * 0.9 + broadP * 0.1)
        .clamp(-100.0, -15.0);
    _bandFloorDb = (bandP < _bandFloorDb
            ? _bandFloorDb * 0.5 + bandP * 0.5
            : _bandFloorDb * 0.9 + bandP * 0.1)
        .clamp(-100.0, -15.0);
  }

  static double _toDb(double linear) {
    if (linear <= 1e-7) return -100.0;
    return (20.0 * math.log(linear) / math.ln10).clamp(-100.0, 0.0);
  }
}

class _LevelBucket {
  final double broadbandDb;
  final double bandDb;
  const _LevelBucket({required this.broadbandDb, required this.bandDb});
}

/// Second-order Butterworth band-pass built from an RBJ high-pass at 60 Hz
/// followed by an RBJ low-pass at 1200 Hz.  Only the level matters, so the
/// absolute gain of the cascade is irrelevant.
class _BandFilter {
  final double _hpA1;
  final double _hpA2;
  final double _hpB0;
  final double _hpB1;
  final double _hpB2;
  final double _lpA1;
  final double _lpA2;
  final double _lpB0;
  final double _lpB1;
  final double _lpB2;

  double _hpX1 = 0.0;
  double _hpX2 = 0.0;
  double _hpY1 = 0.0;
  double _hpY2 = 0.0;
  double _lpX1 = 0.0;
  double _lpX2 = 0.0;
  double _lpY1 = 0.0;
  double _lpY2 = 0.0;

  factory _BandFilter(int sampleRate) {
    const double q = 0.7071067811865476;
    double alpha(double w0) => math.sin(w0) / (2 * q);
    double a0(double w0) => 1 + alpha(w0);

    final double wHigh = 2 * math.pi * 60 / sampleRate;
    final double cosHigh = math.cos(wHigh);
    final double highA0 = a0(wHigh);
    final double highB0 = (1 + cosHigh) / 2 / highA0;
    final double highB1 = -(1 + cosHigh) / highA0;
    final double highB2 = (1 + cosHigh) / 2 / highA0;
    final double highA1 = -2 * cosHigh / highA0;
    final double highA2 = (1 - alpha(wHigh)) / highA0;

    final double wLow = 2 * math.pi * 1200 / sampleRate;
    final double cosLow = math.cos(wLow);
    final double lowA0 = a0(wLow);
    final double lowB0 = (1 - cosLow) / 2 / lowA0;
    final double lowB1 = (1 - cosLow) / lowA0;
    final double lowB2 = (1 - cosLow) / 2 / lowA0;
    final double lowA1 = -2 * cosLow / lowA0;
    final double lowA2 = (1 - alpha(wLow)) / lowA0;
    return _BandFilter._internal(
      hpB0: highB0,
      hpB1: highB1,
      hpB2: highB2,
      hpA1: highA1,
      hpA2: highA2,
      lpB0: lowB0,
      lpB1: lowB1,
      lpB2: lowB2,
      lpA1: lowA1,
      lpA2: lowA2,
    );
  }

  _BandFilter._internal({
    required double hpB0,
    required double hpB1,
    required double hpB2,
    required double hpA1,
    required double hpA2,
    required double lpB0,
    required double lpB1,
    required double lpB2,
    required double lpA1,
    required double lpA2,
  })  : _hpB0 = hpB0,
        _hpB1 = hpB1,
        _hpB2 = hpB2,
        _hpA1 = hpA1,
        _hpA2 = hpA2,
        _lpB0 = lpB0,
        _lpB1 = lpB1,
        _lpB2 = lpB2,
        _lpA1 = lpA1,
        _lpA2 = lpA2;

  double process(double input) {
    final double high = _hpB0 * input +
        _hpB1 * _hpX1 +
        _hpB2 * _hpX2 -
        _hpA1 * _hpY1 -
        _hpA2 * _hpY2;
    _hpX2 = _hpX1;
    _hpX1 = input;
    _hpY2 = _hpY1;
    _hpY1 = high;

    final double low = _lpB0 * high +
        _lpB1 * _lpX1 +
        _lpB2 * _lpX2 -
        _lpA1 * _lpY1 -
        _lpA2 * _lpY2;
    _lpX2 = _lpX1;
    _lpX1 = high;
    _lpY2 = _lpY1;
    _lpY1 = low;
    return low;
  }

  void reset() {
    _hpX1 = _hpX2 = _hpY1 = _hpY2 = 0.0;
    _lpX1 = _lpX2 = _lpY1 = _lpY2 = 0.0;
  }
}
