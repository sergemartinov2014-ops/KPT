import 'package:flutter/foundation.dart';
import '../models/sleep_audio_clip.dart';
import '../models/sleep_audio_event.dart';
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
  List<SleepAudioEvent> get events => _service.events;
  double get noiseFloorDb => _service.noiseFloorDb;
  double get triggerThresholdDb => _service.triggerThresholdDb;
  String? get playingClipId => _service.playingClipId;
  String? get startingClipId => _service.startingClipId;
  int get delayMinutes => _service.delayMinutes;
  double get sensitivityDb => _service.sensitivityDb;
  double get lowBandFloorDb => _service.lowBandFloorDb;
  int get maxClipsPerSession => _service.maxClipsPerSessionLimit;
  String? get lastError => _service.lastError;

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

  /// Возвращает `null` при успехе либо текст ошибки для UI.
  Future<String?> playClip(SleepAudioClip clip) async {
    final result = await _service.playClip(clip);
    notifyListeners();
    return result;
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

  Future<void> updateSettings({int? delay, double? sensitivity}) async {
    await _service.saveSettings(delay: delay, sensitivity: sensitivity);
    notifyListeners();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }
}
