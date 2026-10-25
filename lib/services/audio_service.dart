import 'dart:async';
import 'package:just_audio/just_audio.dart';

class AmbientSound {
  final String id;
  final String name;
  final String assetPath;
  final String icon;

  const AmbientSound({
    required this.id,
    required this.name,
    required this.assetPath,
    required this.icon,
  });
}

class AudioService {
  final AudioPlayer _player = AudioPlayer();
  Timer? _sleepTimer;
  int _remainingTimerSeconds = 0;
  
  AmbientSound? _currentSound;
  bool _isPlaying = false;

  final List<AmbientSound> availableSounds = const [
    AmbientSound(
      id: 'rain',
      name: 'Мягкий дождь',
      assetPath: 'assets/audio/ambient/rain.mp3',
      icon: 'water_drop',
    ),
    AmbientSound(
      id: 'forest',
      name: 'Ночной лес',
      assetPath: 'assets/audio/ambient/forest.mp3',
      icon: 'forest',
    ),
    AmbientSound(
      id: 'stream',
      name: 'Лесной ручей',
      assetPath: 'assets/audio/ambient/stream.mp3',
      icon: 'waves',
    ),
    AmbientSound(
      id: 'beach',
      name: 'Морской прибой',
      assetPath: 'assets/audio/ambient/beach.mp3',
      icon: 'beach_access',
    ),
    AmbientSound(
      id: 'crickets',
      name: 'Сверчки в саду',
      assetPath: 'assets/audio/ambient/crickets.mp3',
      icon: 'nights_stay',
    ),
    AmbientSound(
      id: 'wind',
      name: 'Тихий ночной ветер',
      assetPath: 'assets/audio/ambient/wind.mp3',
      icon: 'air',
    ),
    AmbientSound(
      id: 'white_noise',
      name: 'Белый шум',
      assetPath: 'assets/audio/ambient/white_noise.mp3',
      icon: 'graphic_eq',
    ),
    AmbientSound(
      id: 'long_bowl',
      name: 'Поющие тибетские чаши',
      assetPath: 'assets/audio/ambient/long_bowl.mp3',
      icon: 'self_improvement',
    ),
  ];

  AudioPlayer get player => _player;
  AmbientSound? get currentSound => _currentSound;
  bool get isPlaying => _isPlaying;
  int get remainingTimerSeconds => _remainingTimerSeconds;

  Future<void> playSound(AmbientSound sound) async {
    try {
      if (_currentSound?.id == sound.id && _isPlaying) {
        await pause();
        return;
      }

      _currentSound = sound;
      await _player.setVolume(1.0); // Всегда сбрасываем громкость на полную
      await _player.setAsset(sound.assetPath);
      await _player.setLoopMode(LoopMode.one); // Бесшовное зацикливание
      await _player.play();
      _isPlaying = true;
    } catch (e) {
      _isPlaying = false;
    }
  }

  Future<void> pause() async {
    await _player.pause();
    _isPlaying = false;
  }

  Future<void> resume() async {
    if (_currentSound != null) {
      await _player.play();
      _isPlaying = true;
    }
  }

  Future<void> stop() async {
    await _player.stop();
    await _player.setVolume(1.0); // Восстанавливаем громкость после остановки
    _isPlaying = false;
    _sleepTimer?.cancel();
    _remainingTimerSeconds = 0;
  }

  /// Установка таймера сна с плавным угасанием (Fade-out) за 30 секунд до конца
  void setSleepTimer(int minutes, {Function()? onTimerFinished, Function(int)? onTick}) {
    _sleepTimer?.cancel();
    _player.setVolume(1.0);

    if (minutes <= 0) {
      _remainingTimerSeconds = 0;
      return;
    }

    _remainingTimerSeconds = minutes * 60;
    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_remainingTimerSeconds > 0) {
        _remainingTimerSeconds--;

        // Fade-out затухание в последние 30 секунд: от 1.0 до 0.0
        if (_remainingTimerSeconds <= 30) {
          final double vol = (_remainingTimerSeconds / 30.0).clamp(0.0, 1.0);
          await _player.setVolume(vol);
        }

        onTick?.call(_remainingTimerSeconds);
      } else {
        timer.cancel();
        await stop();
        onTimerFinished?.call();
      }
    });
  }

  void dispose() {
    _sleepTimer?.cancel();
    _player.dispose();
  }
}
