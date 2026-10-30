import 'package:flutter/foundation.dart';
import '../models/sleep_audio_clip.dart';
import '../services/sleep_audio_recorder_service.dart';

class SleepAudioProvider extends ChangeNotifier {
  final SleepAudioRecorderService _service = SleepAudioRecorderService();

  SleepAudioRecorderService get service => _service;
  bool get isMonitoring => _service.isMonitoring;
  bool get isWaitingDelay => _service.isWaitingDelay;
  bool get isRecordingClip => _service.isRecordingClip;
  double get currentDb => _service.currentDb;
  int get sessionClipCount => _service.sessionClipCount;
  List<SleepAudioClip> get clips => _service.clips;
  String? get playingClipId => _service.playingClipId;
  int get delayMinutes => _service.delayMinutes;
  double get startThresholdDb => _service.startThresholdDb;

  SleepAudioProvider() {
    _service.onStateChanged = () => notifyListeners();
    _service.loadPersistedData();
  }

  Future<bool> startMonitoring({bool bypassDelay = false}) async {
    final result = await _service.startMonitoring(bypassDelay: bypassDelay);
    notifyListeners();
    return result;
  }

  Future<void> stopMonitoring() async {
    await _service.stopMonitoring();
    notifyListeners();
  }

  Future<void> playClip(SleepAudioClip clip) async {
    await _service.playClip(clip);
    notifyListeners();
  }

  Future<void> stopPlaying() async {
    await _service.stopPlaying();
    notifyListeners();
  }

  Future<void> deleteClip(String id) async {
    await _service.deleteClip(id);
    notifyListeners();
  }

  Future<void> clearAllClips() async {
    await _service.clearAllClips();
    notifyListeners();
  }

  Future<void> updateSettings({int? delay, double? threshold}) async {
    await _service.saveSettings(delay: delay, threshold: threshold);
    notifyListeners();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }
}
