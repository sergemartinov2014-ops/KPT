// Minimal 16-bit PCM WAV reader shared by the offline evaluation scripts.
//
// The app records 16 kHz mono PCM, but external material is anything from 8 kHz
// mono to 44.1 kHz stereo, so the reader downmixes and linearly resamples to the
// canonical 16 kHz used by the classifier.
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

const int kCanonicalRate = 16000;

/// Mono float samples in [-1, 1] plus the source sample rate.
class WavAudio {
  final Float64List samples;
  final int sampleRate;
  const WavAudio(this.samples, this.sampleRate);
}

/// Reads a 16-bit PCM WAV file.  Returns null for unsupported input.
WavAudio? readWavFile(String path) {
  final bytes = File(path).readAsBytesSync();
  if (bytes.length < 44) return null;
  final data = ByteData.sublistView(bytes);
  if (String.fromCharCodes(bytes, 0, 4) != 'RIFF' ||
      String.fromCharCodes(bytes, 8, 12) != 'WAVE') {
    return null;
  }
  var offset = 12;
  var channels = 1;
  var bits = 16;
  var rate = 44100;
  int? dataOffset;
  int? dataLength;
  while (offset + 8 <= bytes.length) {
    final id = String.fromCharCodes(bytes, offset, offset + 4);
    final size = data.getUint32(offset + 4, Endian.little);
    final body = offset + 8;
    if (id == 'fmt ') {
      channels = data.getUint16(body + 2, Endian.little);
      rate = data.getUint32(body + 4, Endian.little);
      bits = data.getUint16(body + 14, Endian.little);
    } else if (id == 'data') {
      dataOffset = body;
      dataLength = size;
    }
    offset = body + size + (size.isOdd ? 1 : 0);
  }
  if (dataOffset == null || dataLength == null || bits != 16) return null;
  final frames = math.min(dataLength ~/ 2, (bytes.length - dataOffset) ~/ 2);
  if (frames <= 0) return null;
  final interleaved = Float64List(frames);
  for (var i = 0; i < frames; i++) {
    interleaved[i] = data.getInt16(dataOffset + i * 2, Endian.little) / 32768.0;
  }
  if (channels <= 1) return WavAudio(interleaved, rate);
  final monoFrames = frames ~/ channels;
  final mono = Float64List(monoFrames);
  for (var i = 0; i < monoFrames; i++) {
    var sum = 0.0;
    for (var c = 0; c < channels; c++) {
      sum += interleaved[i * channels + c];
    }
    mono[i] = sum / channels;
  }
  return WavAudio(mono, rate);
}

/// Linear-interpolation resampler, the same method `features.py` uses.
Float64List resampleTo16k(Float64List input, int fromRate) {
  if (fromRate == kCanonicalRate || input.isEmpty) return input;
  final target = (input.length / fromRate * kCanonicalRate).round();
  if (target <= 0) return Float64List(0);
  final output = Float64List(target);
  for (var i = 0; i < target; i++) {
    final position = i * fromRate / kCanonicalRate;
    final index = position.floor();
    final fraction = position - index;
    final a = input[index.clamp(0, input.length - 1)];
    final b = input[(index + 1).clamp(0, input.length - 1)];
    output[i] = a + (b - a) * fraction;
  }
  return output;
}

Uint8List toPcm16(Float64List samples) {
  final bytes = ByteData(samples.length * 2);
  for (var i = 0; i < samples.length; i++) {
    bytes.setInt16(
      i * 2,
      (samples[i].clamp(-1.0, 1.0) * 32767).round(),
      Endian.little,
    );
  }
  return bytes.buffer.asUint8List();
}

/// 16 kHz mono samples of a WAV file, or null when unreadable.
Float64List? loadWav16k(String path) {
  final wav = readWavFile(path);
  if (wav == null) return null;
  return resampleTo16k(wav.samples, wav.sampleRate);
}

double peakDb(Float64List samples) {
  var peak = 0.0;
  for (final value in samples) {
    final magnitude = value.abs();
    if (magnitude > peak) peak = magnitude;
  }
  return 20 * math.log(peak) / math.ln10;
}

double rmsDb(Float64List samples) {
  if (samples.isEmpty) return -100;
  var sum = 0.0;
  for (final value in samples) {
    sum += value * value;
  }
  return 20 * math.log(math.sqrt(sum / samples.length)) / math.ln10;
}
