import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

const String kAudioFixtureDirectory = 'test/fixtures/sleep_audio';
const String kAudioFixtureManifest = '$kAudioFixtureDirectory/features.json';

Map<String, dynamic> loadAudioFixtureManifest() {
  return jsonDecode(File(kAudioFixtureManifest).readAsStringSync())
      as Map<String, dynamic>;
}

/// Reads a canonical 44-byte PCM16 WAV and returns its raw PCM payload.
Uint8List readWavPcm(String path) {
  final Uint8List bytes = File(path).readAsBytesSync();
  if (bytes.length <= 44) {
    throw StateError('WAV too short: $path');
  }
  return Uint8List.sublistView(bytes, 44);
}
