import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../../theme/app_theme.dart';
import '../../widgets/aurora_canvas.dart';
import '../../widgets/liquid_glass.dart';
import 'breathing_screen.dart';
import 'ambient_player_screen.dart';

class StimulusControlScreen extends StatefulWidget {
  const StimulusControlScreen({super.key});

  @override
  State<StimulusControlScreen> createState() => _StimulusControlScreenState();
}

class _StimulusControlScreenState extends State<StimulusControlScreen> with SingleTickerProviderStateMixin {
  Timer? _timer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _timerFinished = false;
  final AudioPlayer _chimePlayer = AudioPlayer();
  late DateTime _endTime;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.94, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine),
    );

    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _endTime = DateTime.now().add(const Duration(minutes: 20));
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      final remaining = _endTime.difference(DateTime.now()).inSeconds;
      if (remaining <= 0) {
        timer.cancel();
        if (mounted) {
          setState(() => _timerFinished = true);
        }
        try {
          await _chimePlayer.setAsset('assets/audio/ambient/long_bowl.mp3');
          await _chimePlayer.setVolume(0.5);
          await _chimePlayer.play();
        } catch (_) {}
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    _chimePlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color orbColor = _timerFinished ? AppTheme.success : AppTheme.accent;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Правило 20 минут'),
      ),
      body: AuroraCanvas(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
          children: [
            const SizedBox(height: 20),
            // Многослойная концентрическая сфера Liquid Glass
            Center(
              child: ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: orbColor.withValues(alpha: 0.15), width: 1),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: LiquidGlass(
                    radius: 110,
                    blur: 20,
                    surfaceColor: const Color(0xFF141C2E),
                    borderColor: orbColor.withValues(alpha: 0.45),
                    borderWidth: 1.5,
                    glowColor: orbColor,
                    glowRadius: 32,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _timerFinished ? Icons.check_rounded : Icons.nights_stay_outlined,
                            size: 32,
                            color: orbColor,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _timerFinished ? 'Цикл завершен' : 'Вне постели',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: _timerFinished ? AppTheme.success : AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _timerFinished ? 'Вернитесь при сонливости' : 'Фоновый отсчет 20 мин',
                            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),

            const FadeSlideEntrance(
              delayMs: 0,
              child: LiquidGlass(
                radius: 20,
                blur: 16,
                surfaceColor: AppTheme.glassSurface,
                padding: EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ЗАЩИТА ОТ ЧАСОВОЙ ТРЕВОГИ', style: AppTheme.sectionLabel),
                    SizedBox(height: 8),
                    Text(
                      'Цифровой секундомер скрыт намеренно. Наблюдение за минутами ночью активирует кору головного мозга и усиливает бессонницу. По окончании 20 минут прозвучит мягкий сигнал тибетской чаши.',
                      style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            const Text('СПОКОЙНЫЕ ЗАНЯТИЯ В ДРУГОЙ КОМНАТЕ', style: AppTheme.sectionLabel),
            const SizedBox(height: 12),

            FadeSlideEntrance(
              delayMs: 60,
              child: _buildActionRow(
                Icons.waves_rounded,
                'Дыхание 4–7–8',
                'Снижение частоты пульса за 4 цикла',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BreathingScreen())),
              ),
            ),
            FadeSlideEntrance(
              delayMs: 120,
              child: _buildActionRow(
                Icons.graphic_eq_rounded,
                'Акустический фон',
                'Включить шум дождя или поющие чаши',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AmbientPlayerScreen())),
              ),
            ),
            FadeSlideEntrance(
              delayMs: 180,
              child: _buildActionRow(
                Icons.menu_book_outlined,
                'Чтение бумажной книги',
                'При теплом приглушенном свете без экранов',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionRow(IconData icon, String title, String subtitle, {VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: LiquidGlassInteractive(
        onTap: onTap,
        child: LiquidGlass(
          radius: 18,
          blur: 14,
          surfaceColor: AppTheme.glassSurfaceElevated,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
                ),
                child: Icon(icon, color: AppTheme.accent, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: AppTheme.textPrimary)),
                    const SizedBox(height: 3),
                    Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              if (onTap != null)
                const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
