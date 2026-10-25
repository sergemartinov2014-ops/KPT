import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

enum BreathPhase { inhale, hold, exhale }

class BreathingScreen extends StatefulWidget {
  const BreathingScreen({super.key});

  @override
  State<BreathingScreen> createState() => _BreathingScreenState();
}

class _BreathingScreenState extends State<BreathingScreen> with SingleTickerProviderStateMixin {
  BreathPhase _phase = BreathPhase.inhale;
  int _secondsLeft = 4;
  Timer? _timer;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    _startBreathingCycle();
  }

  void _startBreathingCycle() {
    _phase = BreathPhase.inhale;
    _secondsLeft = 4;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isActive) return;
      setState(() {
        if (_secondsLeft > 1) {
          _secondsLeft--;
        } else {
          // Смена фазы
          switch (_phase) {
            case BreathPhase.inhale:
              _phase = BreathPhase.hold;
              _secondsLeft = 7;
              break;
            case BreathPhase.hold:
              _phase = BreathPhase.exhale;
              _secondsLeft = 8;
              break;
            case BreathPhase.exhale:
              _phase = BreathPhase.inhale;
              _secondsLeft = 4;
              break;
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String phaseText;
    Color phaseColor;
    double scale;

    switch (_phase) {
      case BreathPhase.inhale:
        phaseText = 'Вдох через нос';
        phaseColor = AppTheme.accent;
        scale = 1.3 - (_secondsLeft / 4) * 0.3;
        break;
      case BreathPhase.hold:
        phaseText = 'Задержка дыхания';
        phaseColor = AppTheme.warning;
        scale = 1.3;
        break;
      case BreathPhase.exhale:
        phaseText = 'Медленный выдох через рот';
        phaseColor = AppTheme.primaryLight;
        scale = 1.0 + (_secondsLeft / 8) * 0.3;
        break;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Дыхание 4-7-8'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                phaseText,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: phaseColor),
              ),
              const SizedBox(height: 8),
              const Text('Методика доктора Эндрю Вейла для снятия ночной тревоги', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
              const SizedBox(height: 48),

              // Анимированный круг дыхания
              AnimatedContainer(
                duration: const Duration(seconds: 1),
                curve: Curves.easeInOut,
                width: 160 * scale,
                height: 160 * scale,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: phaseColor.withValues(alpha: 0.15),
                  border: Border.all(color: phaseColor, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: phaseColor.withValues(alpha: 0.3),
                      blurRadius: 30,
                      spreadRadius: 8,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    '$_secondsLeft',
                    style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: phaseColor),
                  ),
                ),
              ),
              const SizedBox(height: 60),

              // Кнопка паузы / продолжения
              IconButton.filledTonal(
                iconSize: 32,
                icon: Icon(_isActive ? Icons.pause : Icons.play_arrow),
                onPressed: () {
                  setState(() => _isActive = !_isActive);
                },
              ),
              const SizedBox(height: 24),
              const Text(
                'Сделайте 4 полных цикла (около 2 минут). Это активирует парасимпатическую нервную систему и замедляет пульс.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
