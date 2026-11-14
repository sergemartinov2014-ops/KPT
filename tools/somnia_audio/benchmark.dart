// Benchmark the shipping classifier on 15 s and 45 s clips.
//
//   dart run tools/somnia_audio/benchmark.dart
//
// The fixture is a committed synthetic snore WAV.  This measures the JIT VM
// on the development machine, not an AOT build on a phone.  Treat the numbers
// as an upper bound and re-measure on a device before making UI promises.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../lib/services/audio_event_classifier.dart';

const String _fixture = 'test/fixtures/sleep_audio/synth/snore.wav';
const int _sampleRate = 16000;
const int _warmup = 2;
const int _iterations = 5;

Uint8List _readPcm(String path) {
  final Uint8List bytes = File(path).readAsBytesSync();
  return Uint8List.sublistView(bytes, 44);
}

Uint8List _loopTo(Uint8List source, double seconds) {
  final int target = (seconds * _sampleRate).round() * 2;
  final Uint8List result = Uint8List(target);
  var offset = 0;
  while (offset < target) {
    final int count =
        (target - offset) < source.length ? target - offset : source.length;
    result.setRange(offset, offset + count, source);
    offset += count;
  }
  return result;
}

Map<String, dynamic> _run(Uint8List pcm, String label) {
  for (var i = 0; i < _warmup; i++) {
    AudioEventClassifier.classify(pcm);
  }
  final List<int> samples = <int>[];
  AudioClassification? last;
  final int rssBefore = ProcessInfo.currentRss;
  for (var i = 0; i < _iterations; i++) {
    final Stopwatch watch = Stopwatch()..start();
    last = AudioEventClassifier.classify(pcm);
    watch.stop();
    samples.add(watch.elapsedMicroseconds);
  }
  samples.sort();
  final int rssAfter = ProcessInfo.currentRss;
  final double mean =
      samples.reduce((a, b) => a + b) / samples.length / 1000.0;
  return <String, dynamic>{
    'label': label,
    'seconds': pcm.length / 2 / _sampleRate,
    'iterations': _iterations,
    'median_ms': samples[samples.length ~/ 2] / 1000.0,
    'min_ms': samples.first / 1000.0,
    'max_ms': samples.last / 1000.0,
    'mean_ms': mean,
    'rss_before_mb': rssBefore / (1024 * 1024),
    'rss_after_mb': rssAfter / (1024 * 1024),
    'predicted': last!.type.name,
    'confidence': last.confidence,
    'segments': last.segments.length,
  };
}

void main() {
  if (!File(_fixture).existsSync()) {
    stderr.writeln('Missing $_fixture. Run make_fixtures.py first.');
    exitCode = 2;
    return;
  }
  final Uint8List source = _readPcm(_fixture);
  final List<Map<String, dynamic>> rows = <Map<String, dynamic>>[];
  for (final double seconds in <double>[15, 45]) {
    final Map<String, dynamic> row = _run(_loopTo(source, seconds), '${seconds.toInt()}s');
    rows.add(row);
    print(jsonEncode(row));
  }

  final Map<String, dynamic> report = <String, dynamic>{
    'classifier': 'AudioEventClassifier v3 (DSP score fusion)',
    'fixture': _fixture,
    'fixture_source': 'synthetic (tools/somnia_audio/make_fixtures.py)',
    'runtime': 'dart JIT, development machine',
    'warning':
        'JIT on desktop. Not a phone measurement. Re-measure on an AOT device build.',
    'rows': rows,
  };
  final File output =
      File('tools/somnia_audio/data/benchmark_report.json');
  output.parent.createSync(recursive: true);
  output.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(report)}\n',
  );
  print('wrote ${output.path}');
}

