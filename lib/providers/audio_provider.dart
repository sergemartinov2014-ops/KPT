import 'package:flutter/foundation.dart';
import '../services/audio_service.dart';

class AudioProvider extends ChangeNotifier {
  final AudioService _service = AudioService();

  AudioService get service => _service;
  AmbientSound? get currentSound => _service.currentSound;
  bool get isPlaying => _service.isPlaying;
  int get remainingTimerSeconds => _service.remainingTimerSeconds;
  List<AmbientSound> get sounds => _service.availableSounds;

  Future<void> toggleSound(AmbientSound sound) async {
    await _service.playSound(sound);
    notifyListeners();
  }

  Future<void> pause() async {
    await _service.pause();
    notifyListeners();
  }

  Future<void> resume() async {
    await _service.resume();
    notifyListeners();
  }

  Future<void> stop() async {
    await _service.stop();
    notifyListeners();
  }

  void setTimer(int minutes) {
    _service.setSleepTimer(
      minutes,
      onTick: (_) => notifyListeners(),
      onTimerFinished: () => notifyListeners(),
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }
}
