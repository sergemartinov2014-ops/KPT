// End-to-end evaluation of the on-device DSP classifier on labelled WAV files.
//
// This runs the *shipping* Dart classifier (`AudioEventClassifier`), not a
// Python re-implementation, so the numbers describe what the app will do.
//
// Usage:
//   dart run tools/somnia_audio/classifier_eval.dart \
//       tools/somnia_audio/data/external/esc50 --recursive \
//       --window 1.0 --hop 0.5 --min-active 0.3 \
//       --out tools/somnia_audio/data/classifier_real_windows.json
//
// The directory name is the label.  A label that is not one of the four model
// classes (e.g. `breathing`) is reported separately as a false-positive probe:
// it is not a class the app shows, but classifying a quiet breathing pattern as
// a snore is the most damaging mistake a sleep app can make.
// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'wav_io.dart';

import 'package:somnia/services/audio_event_classifier.dart';

const int kSampleRate = kCanonicalRate;
const List<String> kClasses = <String>['snore', 'talk', 'movement', 'ambient'];

class _Row {
  final String label;
  final String predicted;
  final double confidence;
  final double activeSeconds;
  final String file;
  _Row(this.label, this.predicted, this.confidence, this.activeSeconds,
      this.file);
}

List<File> collect(String path, bool recursive) {
  final entity = FileSystemEntity.typeSync(path);
  if (entity == FileSystemEntityType.file) return [File(path)];
  final dir = Directory(path);
  if (!dir.existsSync()) return [];
  final files = <File>[];
  for (final entry in dir.listSync(recursive: recursive)) {
    if (entry is File && entry.path.toLowerCase().endsWith('.wav')) {
      files.add(entry);
    }
  }
  files.sort((a, b) => a.path.compareTo(b.path));
  return files;
}

String labelFor(File file) {
  final parts = file.uri.pathSegments;
  return parts.length >= 2 ? parts[parts.length - 2] : 'unknown';
}

void main(List<String> arguments) {
  final paths = <String>[];
  double? window;
  double hop = 0.5;
  double minActive = 0.0;
  var recursive = true;
  String? output;
  String? manifest;
  for (var i = 0; i < arguments.length; i++) {
    final arg = arguments[i];
    if (arg == '--window' && i + 1 < arguments.length) {
      window = double.parse(arguments[++i]);
    } else if (arg == '--hop' && i + 1 < arguments.length) {
      hop = double.parse(arguments[++i]);
    } else if (arg == '--min-active' && i + 1 < arguments.length) {
      minActive = double.parse(arguments[++i]);
    } else if (arg == '--out' && i + 1 < arguments.length) {
      output = arguments[++i];
    } else if (arg == '--manifest' && i + 1 < arguments.length) {
      manifest = arguments[++i];
    } else if (arg == '--no-recursive') {
      recursive = false;
    } else if (arg == '--recursive') {
      recursive = true;
    } else if (arg.startsWith('--')) {
      stderr.writeln('Unknown option $arg');
      exitCode = 2;
      return;
    } else {
      paths.add(arg);
    }
  }

  // (file, label) pairs from either a directory tree or a CSV manifest.
  final entries = <MapEntry<File, String>>[];
  if (manifest != null) {
    final file = File(manifest);
    if (!file.existsSync()) {
      stderr.writeln('Missing manifest $manifest');
      exitCode = 2;
      return;
    }
    final lines = file.readAsLinesSync();
    if (lines.isEmpty) {
      stderr.writeln('Empty manifest');
      exitCode = 2;
      return;
    }
    final header = lines.first.split(',');
    final fileIndex = header.indexOf('file');
    final labelIndex = header.indexOf('label');
    if (fileIndex < 0 || labelIndex < 0) {
      stderr.writeln('Manifest needs "file" and "label" columns');
      exitCode = 2;
      return;
    }
    final parent = file.parent.path;
    for (final line in lines.skip(1)) {
      if (line.trim().isEmpty) continue;
      final cells = line.split(',');
      if (cells.length <= labelIndex || cells.length <= fileIndex) continue;
      final path = cells[fileIndex].startsWith('file://')
          ? Uri.parse(cells[fileIndex]).toFilePath()
          : '$parent/${cells[fileIndex]}';
      entries.add(MapEntry(File(path), cells[labelIndex]));
    }
  } else {
    for (final path in paths) {
      for (final file in collect(path, recursive)) {
        entries.add(MapEntry(file, labelFor(file)));
      }
    }
  }
  if (entries.isEmpty) {
    stderr.writeln('Pass a directory of labelled WAV files or --manifest.');
    exitCode = 2;
    return;
  }

  final rows = <_Row>[];
  for (final entry in entries) {
    final file = entry.key;
    final label = entry.value;
    final samples = loadWav16k(file.path);
    if (samples == null) {
      stderr.writeln('Skipping ${file.path}: not 16-bit PCM WAV');
      continue;
    }
    final int windowSamples =
        window == null ? samples.length : (window * kSampleRate).round();
    final int hopSamples =
        window == null ? samples.length : (hop * kSampleRate).round();
    if (samples.isEmpty || windowSamples <= 0) continue;
    for (var start = 0;
        start + windowSamples <= samples.length;
        start += hopSamples) {
      final chunk =
          Float64List.sublistView(samples, start, start + windowSamples);
      final pcm = toPcm16(chunk);
      final result =
          AudioEventClassifier.classify(pcm, sampleRate: kSampleRate);
      final activeSeconds = result.features.activeDurationMs / 1000.0;
      if (activeSeconds < minActive) continue;
      rows.add(_Row(label, result.type.name, result.confidence, activeSeconds,
          file.path));
    }
  }

  if (rows.isEmpty) {
    stderr.writeln('No rows evaluated (check --min-active).');
    exitCode = 1;
    return;
  }

  final counts = <String, Map<String, int>>{};
  for (final row in rows) {
    counts.putIfAbsent(row.label, () => <String, int>{});
    counts[row.label]![row.predicted] =
        (counts[row.label]![row.predicted] ?? 0) + 1;
  }

  final supervised = rows.where((row) => kClasses.contains(row.label)).toList();
  final metrics = <String, dynamic>{};
  if (supervised.isNotEmpty) {
    final matrix = List<List<int>>.generate(
        kClasses.length + 1, (_) => List<int>.filled(kClasses.length + 1, 0));
    for (final row in supervised) {
      final truth = kClasses.indexOf(row.label);
      final predicted = kClasses.contains(row.predicted)
          ? kClasses.indexOf(row.predicted)
          : kClasses.length;
      matrix[truth][predicted]++;
    }
    final perClass = <String, Map<String, double>>{};
    final f1s = <double>[];
    for (var i = 0; i < kClasses.length; i++) {
      final truePositive = matrix[i][i].toDouble();
      final support = matrix[i].fold<int>(0, (a, b) => a + b).toDouble();
      var predictedPositive = 0.0;
      for (var r = 0; r < matrix.length; r++) {
        predictedPositive += matrix[r][i];
      }
      final precision =
          predictedPositive == 0 ? 0.0 : truePositive / predictedPositive;
      final recall = support == 0 ? 0.0 : truePositive / support;
      final f1 = precision + recall == 0
          ? 0.0
          : 2 * precision * recall / (precision + recall);
      f1s.add(f1);
      perClass[kClasses[i]] = <String, double>{
        'precision': precision,
        'recall': recall,
        'f1': f1,
        'support': support,
      };
    }
    metrics['rows'] = supervised.length;
    metrics['macro_f1'] = f1s.reduce((a, b) => a + b) / f1s.length;
    metrics['snore_recall'] = perClass['snore']!['recall'];
    metrics['snore_precision'] = perClass['snore']!['precision'];
    metrics['mean_confidence'] =
        supervised.map((row) => row.confidence).reduce((a, b) => a + b) /
            supervised.length;
    metrics['per_class'] = perClass;
    metrics['confusion'] = <String, dynamic>{
      'labels': [...kClasses, 'unknown'],
      'matrix': matrix,
    };
    print('rows=${metrics['rows']} '
        'macro-F1=${(metrics['macro_f1'] as double).toStringAsFixed(3)} '
        'snore P/R=${(metrics['snore_precision'] as double).toStringAsFixed(3)}/'
        '${(metrics['snore_recall'] as double).toStringAsFixed(3)} '
        'mean-confidence=${(metrics['mean_confidence'] as double).toStringAsFixed(3)}');
    print('confusion (rows=true, cols=pred):');
    final labels = <String>[...kClasses, 'unknown'];
    print('        ${labels.map((e) => e.padLeft(9)).join()}');
    for (var i = 0; i < matrix.length; i++) {
      print(
          '${labels[i].padLeft(8)} ${matrix[i].map((e) => e.toString().padLeft(9)).join()}');
    }
  }

  print('\npredictions by label:');
  final sorted = counts.keys.toList()..sort();
  for (final label in sorted) {
    final summary = counts[label]!
        .entries
        .map((e) => '${e.key}=${e.value}')
        .toList()
      ..sort();
    print('  ${label.padLeft(12)}: ${summary.join(', ')}');
  }

  final report = <String, dynamic>{
    'classifier': 'DSP score fusion (lib/services/audio_event_classifier.dart)',
    'sample_rate': kSampleRate,
    'window_s': window,
    'hop_s': window == null ? null : hop,
    'min_active_s': minActive,
    'rows': rows.length,
    'metrics': metrics.isEmpty ? null : metrics,
    'prediction_counts': counts,
    'warning':
        'External clips only. Not labelled sleep recordings and not a benchmark. '
            'Numbers do not estimate real-world accuracy.',
  };
  if (output != null) {
    File(output)
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(
          '${const JsonEncoder.withIndent('  ').convert(report)}\n');
    print('wrote $output');
  }
  final snore = counts['snore'];
  if (snore != null && snore.isNotEmpty) {
    final total = snore.values.reduce((a, b) => a + b);
    final recall = (snore['snore'] ?? 0) / total;
    print('snore recall: ${recall.toStringAsFixed(3)} ($total rows)');
  }
  final breathing = counts['breathing'];
  if (breathing != null && breathing.isNotEmpty) {
    final total = breathing.values.reduce((a, b) => a + b);
    print('breathing -> snore: '
        '${((breathing['snore'] ?? 0) / math.max(1, total)).toStringAsFixed(3)}');
  }
}
