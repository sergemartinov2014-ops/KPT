// Baseline evaluation: exact v1 classifier snapshot on the synthetic test split.
//
//   python -m tools.somnia_audio.synth --out tools/somnia_audio/data/v1_test --per-class 40 --seed 900000
//   dart run tools/somnia_audio/baseline_eval.dart
//
// The snapshot imports the current enum (which adds `unknown`); v1 never emits
// it, so results match the code on main.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'baseline_v1_classifier.dart';

const List<String> _classes = <String>[
  'snore',
  'talk',
  'movement',
  'ambient',
];

void main(List<String> arguments) {
  var directory = Directory('tools/somnia_audio/data/v1_test');
  var output = File('tools/somnia_audio/data/baseline_v1_report.json');
  for (var i = 0; i < arguments.length - 1; i++) {
    if (arguments[i] == '--dir') directory = Directory(arguments[i + 1]);
    if (arguments[i] == '--out') output = File(arguments[i + 1]);
  }

  final File labels = File('${directory.path}/labels.csv');
  if (!labels.existsSync()) {
    stderr.writeln('Missing ${labels.path}. Run synth.py first.');
    exitCode = 2;
    return;
  }
  final List<String> lines = labels.readAsLinesSync();
  final List<String> header = lines.first.split(',');
  final int fileIndex = header.indexOf('file');
  final int labelIndex = header.indexOf('label');

  final List<String> truth = <String>[];
  final List<String> predicted = <String>[];
  final Stopwatch watch = Stopwatch()..start();
  for (final line in lines.skip(1)) {
    if (line.trim().isEmpty) continue;
    final List<String> cells = line.split(',');
    final String label = cells[labelIndex];
    final File wav = File('${directory.path}/${cells[fileIndex]}');
    final Uint8List bytes = wav.readAsBytesSync();
    final Uint8List pcm = Uint8List.sublistView(bytes, 44);
    final AudioClassification result = V1AudioEventClassifier.classify(pcm);
    final String kind = result.type.name;
    truth.add(label);
    predicted.add(kind);
    if (kind == 'unknown') {
      // v1 has no unknown class; count as a miss for every real class.
    }
  }
  watch.stop();

  final List<List<int>> confusion = List<List<int>>.generate(
    _classes.length,
    (_) => List<int>.filled(_classes.length, 0),
  );
  for (var i = 0; i < truth.length; i++) {
    final int row = _classes.indexOf(truth[i]);
    final int column = _classes.indexOf(predicted[i]);
    if (row >= 0 && column >= 0) confusion[row][column]++;
  }

  final Map<String, Map<String, double>> perClass =
      <String, Map<String, double>>{};
  var macroF1 = 0.0;
  for (var c = 0; c < _classes.length; c++) {
    var tp = 0;
    var fp = 0;
    var fn = 0;
    for (var row = 0; row < _classes.length; row++) {
      for (var column = 0; column < _classes.length; column++) {
        if (row == c && column == c) tp += confusion[row][column];
        if (row != c && column == c) fp += confusion[row][column];
        if (row == c && column != c) fn += confusion[row][column];
      }
    }
    final double precision = tp + fp == 0 ? 0 : tp / (tp + fp);
    final double recall = tp + fn == 0 ? 0 : tp / (tp + fn);
    final double f1 = precision + recall == 0
        ? 0
        : 2 * precision * recall / (precision + recall);
    macroF1 += f1;
    perClass[_classes[c]] = <String, double>{
      'precision': precision,
      'recall': recall,
      'f1': f1,
      'support': (tp + fn).toDouble(),
    };
  }
  macroF1 /= _classes.length;

  var talkToSnore = 0;
  var talkTotal = 0;
  for (var i = 0; i < truth.length; i++) {
    if (truth[i] == 'talk') {
      talkTotal++;
      if (predicted[i] == 'snore') talkToSnore++;
    }
  }

  final Map<String, dynamic> report = <String, dynamic>{
    'dataset': directory.path,
    'classifier': 'v1 snapshot from main',
    'warning':
        'Synthetic data only. These numbers do not estimate real-world accuracy.',
    'rows': truth.length,
    'accuracy': _accuracy(truth, predicted),
    'macro_f1': macroF1,
    'per_class': perClass,
    'confusion': confusion,
    'talk_to_snore_rate': talkTotal == 0 ? 0 : talkToSnore / talkTotal,
    'elapsed_ms': watch.elapsedMilliseconds,
  };
  output.parent.createSync(recursive: true);
  output.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(report)}\n',
  );
  print(jsonEncode(<String, dynamic>{
    'rows': truth.length,
    'accuracy': report['accuracy'],
    'macro_f1': report['macro_f1'],
    'talk_to_snore': report['talk_to_snore_rate'],
    'elapsed_ms': report['elapsed_ms'],
  }));
}

double _accuracy(List<String> truth, List<String> predicted) {
  if (truth.isEmpty) return 0;
  var correct = 0;
  for (var i = 0; i < truth.length; i++) {
    if (truth[i] == predicted[i]) correct++;
  }
  return correct / truth.length;
}
