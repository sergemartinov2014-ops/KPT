import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:somnia/services/sleep_audio_model.dart';

void main() {
  final Map<String, dynamic> model = jsonDecode(
    File('assets/models/sleep_audio_v2.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  test('Dart-константы совпадают с JSON-ассетом', () {
    expect(kSleepAudioFeatureNames, model['feature_names']);
    expect(kSleepAudioModelClasses, model['classes']);
    expect(
      kSleepAudioModelTemperature,
      closeTo((model['temperature'] as num).toDouble(), 1e-12),
    );
    expect(
      kSleepAudioUnknownThreshold,
      closeTo((model['unknown_threshold'] as num).toDouble(), 1e-12),
    );
    expect(kSleepAudioModelMean, model['mean']);
    expect(kSleepAudioModelScale, model['scale']);
    expect(kSleepAudioModelIntercept, model['intercept']);
    expect(kSleepAudioModelCoefficients, model['coefficients']);
  });

  test('модель имеет 34 признака и 4 класса', () {
    expect(kSleepAudioFeatureNames, hasLength(34));
    expect(kSleepAudioModelClasses, hasLength(4));
    expect(kSleepAudioModelMean, hasLength(34));
    expect(kSleepAudioModelScale, hasLength(34));
    expect(kSleepAudioModelIntercept, hasLength(4));
    expect(kSleepAudioModelCoefficients, hasLength(4));
    for (final row in kSleepAudioModelCoefficients) {
      expect(row, hasLength(34));
    }
  });
}
