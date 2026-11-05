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
        w += math.exp(-math.pow((f - formant) / 350.0, 2).toDouble());
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
