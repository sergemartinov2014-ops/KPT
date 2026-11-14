// Field-style evaluation of the whole night-sound chain on a real recording.
//
// Unlike `classifier_eval.dart` (which scores isolated windows), this script
// feeds a continuous stream through the *shipping* detector and classifier, the
// way the app does at night.  The source is mixed into a fixed room-noise floor
// at several target peak levels, which simulates the phone being closer to or
// further from the sleeper:
//
//   dart run tools/somnia_audio/session_eval.dart \
//       --source reports/audio/snoring_apnoea_16k.wav \
//       --levels -12,-22,-32,-42,-52 \
//       --snore-ranges 0-7.2,39.8-46.9 \
//       --out tools/somnia_audio/data/session_real_snore.json
//
// `--snore-ranges` is the ground truth in seconds relative to the source file
// (before the lead-in).  Clips overlapping those ranges are the true detection
// target; clips outside them are false positives.
// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:somnia/services/audio_event_classifier.dart';
import 'package:somnia/services/night_sound_detector.dart';

import 'wav_io.dart';

const int _chunkSamples = 336; // ~21 ms, the iOS plugin stream chunk

class _ClipReport {
  final double startSeconds;
  final double durationSeconds;
  final double activeSeconds;
  final String type;
  final double confidence;
  final double peakDb;
  const _ClipReport({
    required this.startSeconds,
    required this.durationSeconds,
    required this.activeSeconds,
    required this.type,
    required this.confidence,
    required this.peakDb,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'start_s': double.parse(startSeconds.toStringAsFixed(2)),
        'duration_s': double.parse(durationSeconds.toStringAsFixed(2)),
        'active_s': double.parse(activeSeconds.toStringAsFixed(2)),
        'type': type,
        'confidence': double.parse(confidence.toStringAsFixed(3)),
        'peak_db': double.parse(peakDb.toStringAsFixed(1)),
      };
}

class _Scenario {
  final double targetPeakDb;
  final double sourcePeakDb;
  final double sourceRmsDb;
  final List<_ClipReport> clips;
  final double coverage;
  final int falseClips;
  final int snoreClips;
  const _Scenario({
    required this.targetPeakDb,
    required this.sourcePeakDb,
    required this.sourceRmsDb,
    required this.clips,
    required this.coverage,
    required this.falseClips,
    required this.snoreClips,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'target_peak_db': targetPeakDb,
        'source_peak_db': double.parse(sourcePeakDb.toStringAsFixed(1)),
        'source_rms_db': double.parse(sourceRmsDb.toStringAsFixed(1)),
        'clips': clips.map((c) => c.toJson()).toList(),
        'snore_time_covered': double.parse(coverage.toStringAsFixed(3)),
        'snore_clips': snoreClips,
        'false_clips': falseClips,
      };
}

List<(double, double)> _parseRanges(String value) {
  return value
      .split(',')
      .map((part) => part.trim())
      .where((part) => part.contains('-'))
      .map((part) {
    final pieces = part.split('-');
    return (double.parse(pieces[0]), double.parse(pieces[1]));
  }).toList();
}

Float64List _roomNoise(int samples, double rmsDb, int seed) {
  final random = math.Random(seed);
  final rms = math.pow(10, rmsDb / 20).toDouble();
  final output = Float64List(samples);
  for (var i = 0; i < samples; i += 2) {
    // Box–Muller, mean 0, standard deviation 1.
    final u1 = random.nextDouble().clamp(1e-9, 1.0);
    final u2 = random.nextDouble();
    final g1 = math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2);
    final g2 = math.sqrt(-2 * math.log(u1)) * math.sin(2 * math.pi * u2);
    output[i] = g1 * rms;
    if (i + 1 < samples) output[i + 1] = g2 * rms;
  }
  return output;
}

_Scenario _runScenario({
  required Float64List source,
  required List<(double, double)> snoreRanges,
  required double targetPeakDb,
  required double roomDb,
  required double leadInSeconds,
  required int seed,
}) {
  final int leadIn = (leadInSeconds * kCanonicalRate).round();
  // Long enough for the detector to see its 3 s silence tail and close the
  // last clip, as the recorder would when the user stops monitoring.
  final int tail = (5.0 * kCanonicalRate).round();
  final int total = leadIn + source.length + tail;
  final mixed = Float64List(total);
  final room = _roomNoise(total, roomDb, seed);
  final sourcePeak = _peak(source);
  final double gain = sourcePeak > 0
      ? math
          .pow(10, (targetPeakDb - 20 * math.log(sourcePeak) / math.ln10) / 20)
          .toDouble()
      : 1.0;
  for (var i = 0; i < total; i++) {
    final sourceIndex = i - leadIn;
    final double voice = sourceIndex >= 0 && sourceIndex < source.length
        ? source[sourceIndex] * gain
        : 0.0;
    mixed[i] = (voice + room[i]).clamp(-1.0, 1.0);
  }

  final detector = NightSoundDetector(
    sampleRate: kCanonicalRate,
    // Match the app: 20 s cap, 3 s silence tail, default sensitivity.
    maxDurationSeconds: 20,
    silenceTimeoutSeconds: 3,
  )..enabled = true;
  final clips = <_ClipReport>[];
  final start = DateTime(2026, 1, 1);
  var samplePosition = 0;
  for (var offset = 0;
      offset + 2 <= mixed.length;
      offset += _chunkSamples * 2) {
    final end = math.min(mixed.length, offset + _chunkSamples * 2);
    final chunk = toPcm16(Float64List.sublistView(mixed, offset, end));
    final detected = detector.addChunk(
      chunk,
      now: start
          .add(Duration(milliseconds: samplePosition * 1000 ~/ kCanonicalRate)),
    );
    if (detected != null) {
      final classification = AudioEventClassifier.classify(detected.pcm);
      final startSeconds =
          detected.startTime.difference(start).inMilliseconds / 1000.0;
      clips.add(_ClipReport(
        startSeconds: startSeconds,
        durationSeconds: detected.pcm.length / 2 / kCanonicalRate,
        activeSeconds: detected.activeSamples / kCanonicalRate,
        type: classification.type.name,
        confidence: classification.confidence,
        peakDb: detected.peakDb,
      ));
    }
    samplePosition += end - offset;
  }

  // Ground truth is relative to the source, shifted by the lead-in.
  final truth = snoreRanges
      .map((range) => (
            range.$1 + leadIn / kCanonicalRate,
            range.$2 + leadIn / kCanonicalRate
          ))
      .toList();
  var totalTruth = 0.0;
  var covered = 0.0;
  for (final range in truth) {
    totalTruth += range.$2 - range.$1;
    var cursor = range.$1;
    final relevant = clips
        .where((clip) =>
            clip.startSeconds < range.$2 &&
            clip.startSeconds + clip.durationSeconds > range.$1)
        .toList()
      ..sort((a, b) => a.startSeconds.compareTo(b.startSeconds));
    for (final clip in relevant) {
      final from = math.max(cursor, clip.startSeconds);
      final to = math.min(range.$2, clip.startSeconds + clip.durationSeconds);
      if (to > from) {
        covered += to - from;
        cursor = to;
      }
    }
  }

  bool overlapsTruth(_ClipReport clip) => truth.any((range) =>
      clip.startSeconds < range.$2 &&
      clip.startSeconds + clip.durationSeconds > range.$1);

  final snoreClips =
      clips.where((clip) => overlapsTruth(clip) && clip.type == 'snore').length;
  final falseClips = clips.where((clip) => !overlapsTruth(clip)).length;

  return _Scenario(
    targetPeakDb: targetPeakDb,
    sourcePeakDb: 20 * math.log(sourcePeak) / math.ln10,
    sourceRmsDb: 20 * math.log(_rms(source)) / math.ln10,
    clips: clips,
    coverage: totalTruth == 0 ? 0 : covered / totalTruth,
    falseClips: falseClips,
    snoreClips: snoreClips,
  );
}

double _peak(Float64List values) {
  var peak = 0.0;
  for (final value in values) {
    if (value.abs() > peak) peak = value.abs();
  }
  return peak;
}

double _rms(Float64List values) {
  var sum = 0.0;
  for (final value in values) {
    sum += value * value;
  }
  return values.isEmpty ? 0 : math.sqrt(sum / values.length);
}

void main(List<String> arguments) {
  String? sourcePath;
  var levels = <double>[-12, -22, -32, -42, -52];
  var roomDb = -65.0;
  var leadIn = 5.0;
  String? rangesValue;
  String? output;
  for (var i = 0; i < arguments.length; i++) {
    final arg = arguments[i];
    switch (arg) {
      case '--source':
        sourcePath = arguments[++i];
      case '--levels':
        levels = arguments[++i]
            .split(',')
            .map((value) => double.parse(value.trim()))
            .toList();
      case '--room-db':
        roomDb = double.parse(arguments[++i]);
      case '--lead-in':
        leadIn = double.parse(arguments[++i]);
      case '--snore-ranges':
        rangesValue = arguments[++i];
      case '--out':
        output = arguments[++i];
      default:
        stderr.writeln('Unknown option $arg');
        exitCode = 2;
        return;
    }
  }
  if (sourcePath == null) {
    stderr.writeln('Pass --source path/to/recording.wav');
    exitCode = 2;
    return;
  }
  final source = loadWav16k(sourcePath);
  if (source == null) {
    stderr.writeln('Cannot read $sourcePath as 16-bit PCM WAV');
    exitCode = 2;
    return;
  }
  final ranges = _parseRanges(rangesValue ?? '');

  final scenarios = <_Scenario>[];
  for (final level in levels) {
    final scenario = _runScenario(
      source: source,
      snoreRanges: ranges,
      targetPeakDb: level,
      roomDb: roomDb,
      leadInSeconds: leadIn,
      seed: 4242,
    );
    scenarios.add(scenario);
    stdout.writeln(
      'peak ${level.toStringAsFixed(0)} dBFS: '
      '${scenario.clips.length} clips, '
      '${scenario.snoreClips} snore, ${scenario.falseClips} false, '
      'coverage ${(scenario.coverage * 100).toStringAsFixed(0)}%',
    );
    for (final clip in scenario.clips) {
      stdout.writeln(
        '   ${clip.startSeconds.toStringAsFixed(1)}s '
        '${clip.durationSeconds.toStringAsFixed(1)}s '
        '${clip.type.padRight(9)} '
        'conf ${clip.confidence.toStringAsFixed(2)} '
        'peak ${clip.peakDb.toStringAsFixed(1)}',
      );
    }
  }

  if (output != null) {
    final report = <String, dynamic>{
      'source': sourcePath,
      'source_peak_db': scenarios.first.sourcePeakDb,
      'source_rms_db': scenarios.first.sourceRmsDb,
      'room_rms_db': roomDb,
      'lead_in_s': leadIn,
      'snore_ranges_s': ranges.map((r) => [r.$1, r.$2]).toList(),
      'detector': 'NightSoundDetector(sensitivityDb: 7)',
      'classifier':
          'DSP score fusion (lib/services/audio_event_classifier.dart)',
      'scenarios': scenarios.map((s) => s.toJson()).toList(),
    };
    final file = File(output);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(report)}\n',
    );
    stdout.writeln('wrote $output');
  }
}
