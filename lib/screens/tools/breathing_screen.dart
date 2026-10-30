import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/aurora_canvas.dart';
import '../../widgets/liquid_glass.dart';

enum BreathPhase { inhale, hold, exhale }

class BreathingScreen extends StatefulWidget {
  const BreathingScreen({super.key});

  @override
  State<BreathingScreen> createState() => _BreathingScreenState();
}

class _BreathingScreenState extends State<BreathingScreen> {
  BreathPhase _phase = BreathPhase.inhale;
  int _secondsLeft = 4;
  int _completedCycles = 0;
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
              _completedCycles++;
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
    String phaseTitle;
    String phaseHint;
    Color phaseColor;
    double scale;

    switch (_phase) {
      case BreathPhase.inhale:
        phaseTitle = 'Вдох через нос';
        phaseHint = 'Спокойно наполняйте диафрагму';
        phaseColor = AppTheme.accent;
        scale = 1.0 + ((4 - _secondsLeft) / 4) * 0.28;
        break;
      case BreathPhase.hold:
        phaseTitle = 'Пауза';
        phaseHint = 'Мягкая задержка без напряжения';
        phaseColor = AppTheme.success;
        scale = 1.28;
        break;
      case BreathPhase.exhale:
        phaseTitle = 'Медленный выдох';
        phaseHint = 'Расслабьте плечи и челюсть';
        phaseColor = AppTheme.primaryLight;
        scale = 1.0 + (_secondsLeft / 8) * 0.28;
        break;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Дыхание 4–7–8'),
      ),
      body: AuroraCanvas(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              children: [
                // Индикатор пропорции 4 - 7 - 8
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildPhasePill('Вдох 4с', _phase == BreathPhase.inhale, AppTheme.accent),
                    const SizedBox(width: 8),
                    _buildPhasePill('Пауза 7с', _phase == BreathPhase.hold, AppTheme.success),
                    const SizedBox(width: 8),
                    _buildPhasePill('Выдох 8с', _phase == BreathPhase.exhale, AppTheme.systemIndigo),
                  ],
                ),
                const Spacer(),

                Text(
                  phaseTitle,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.0,
                    color: phaseColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  phaseHint,
                  style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 44),

                // Концентрический респираторный круг Liquid Glass
                SizedBox(
                  width: 260,
                  height: 260,
                  child: Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 950),
                      curve: Curves.easeInOutSine,
                      width: 175 * scale,
                      height: 175 * scale,
                      child: LiquidGlass(
                        radius: (175 * scale) / 2,
                        blur: 20,
                        surfaceColor: const Color(0xFF141C2E),
                        borderColor: phaseColor.withValues(alpha: 0.55),
                        borderWidth: 1.5,
                        glowColor: phaseColor,
                        glowRadius: 36,
                        child: Center(
                          child: Text(
                            '$_secondsLeft',
                            style: AppTheme.monoFigures(
                              fontSize: 54,
                              fontWeight: FontWeight.w300,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const Spacer(),

                Text(
                  'Завершено циклов: $_completedCycles из 4 рекомендуемых',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: Icon(_isActive ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 18),
                    label: Text(_isActive ? 'Приостановить практику' : 'Продолжить практику'),
                    onPressed: () => setState(() => _isActive = !_isActive),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhasePill(String text, bool active, Color color) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: active ? color.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: active ? color.withValues(alpha: 0.55) : Colors.white.withValues(alpha: 0.12),
          width: 1.1,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          color: active ? AppTheme.textPrimary : AppTheme.textMuted,
        ),
      ),
    );
  }
}
