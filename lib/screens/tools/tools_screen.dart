import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/liquid_glass.dart';
import '../../widgets/aurora_canvas.dart';
import 'stimulus_control_screen.dart';
import 'breathing_screen.dart';
import 'ambient_player_screen.dart';
import 'sleep_audio_screen.dart';
import 'smart_alarm_screen.dart';
import '../assessments/isi_screen.dart';
import '../assessments/dbas_screen.dart';

/// Экран практик и диагностики в стиле Apple Liquid Glass (iOS 26)
class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: const Text('Практики и диагностика'),
      ),
      body: AuroraCanvas(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
          children: [
            const Text('Ночные протоколы', style: AppTheme.sectionLabel),
            const SizedBox(height: 12),
            FadeSlideEntrance(
              delayMs: 0,
              child: _buildToolCard(
                context,
                icon: Icons.alarm_rounded,
                title: 'Умный будильник',
                subtitle:
                    'Пробуждение в фазе лёгкого сна без утренней разбитости с плавным нарастанием звука',
                tag: 'Будильник',
                tagColor: AppTheme.systemIndigo,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SmartAlarmScreen()),
                ),
              ),
            ),
            FadeSlideEntrance(
              delayMs: 40,
              child: _buildToolCard(
                context,
                icon: Icons.timelapse_rounded,
                title: 'Правило 20 минут',
                subtitle:
                    'Стимульный контроль при невозможности уснуть: мягкий фоновый таймер без взгляда на часы',
                tag: 'Стимулы',
                tagColor: AppTheme.accent,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const StimulusControlScreen()),
                ),
              ),
            ),
            FadeSlideEntrance(
              delayMs: 80,
              child: _buildToolCard(
                context,
                icon: Icons.waves_rounded,
                title: 'Дыхательный ритм 4–7–8',
                subtitle:
                    'Парасимпатическая разгрузка и снижение частоты сердечных сокращений перед сном',
                tag: 'Дыхание',
                tagColor: AppTheme.systemTeal,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BreathingScreen()),
                ),
              ),
            ),
            FadeSlideEntrance(
              delayMs: 120,
              child: _buildToolCard(
                context,
                icon: Icons.graphic_eq_rounded,
                title: 'Акустическое маскирование',
                subtitle:
                    '8 бесшовных звуковых сред из протокола CBT-i Coach с таймером плавного затухания',
                tag: '8 сцен',
                tagColor: AppTheme.primaryLight,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AmbientPlayerScreen()),
                ),
              ),
            ),
            FadeSlideEntrance(
              delayMs: 160,
              child: _buildToolCard(
                context,
                icon: Icons.mic_none_rounded,
                title: 'Аудиозапись сна',
                subtitle:
                    'Умная фиксация храпа, разговоров во сне и шорохов с автоотсечкой тишины',
                tag: 'Запись сна',
                tagColor: AppTheme.systemPurple,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SleepAudioScreen()),
                ),
              ),
            ),

            const SizedBox(height: 22),
            const Text('Клинические шкалы и диагностика', style: AppTheme.sectionLabel),
            const SizedBox(height: 12),
            FadeSlideEntrance(
              delayMs: 200,
              child: _buildToolCard(
                context,
                icon: Icons.analytics_outlined,
                title: 'Индекс тяжести инсомнии (ISI)',
                subtitle:
                    'Золотой стандарт клинической оценки симптомов бессонницы (7 вопросов, шкала 0–28)',
                tag: 'Шкала ISI',
                tagColor: AppTheme.systemAmber,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const IsiScreen()),
                ),
              ),
            ),
            FadeSlideEntrance(
              delayMs: 240,
              child: _buildToolCard(
                context,
                icon: Icons.psychology_outlined,
                title: 'Реструктуризация убеждений (DBAS)',
                subtitle:
                    'Разбор катастрофических мыслей о сне и снижение когнитивной гиперактивации',
                tag: 'Когниции',
                tagColor: AppTheme.accent,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DbasScreen()),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String tag,
    required Color tagColor,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: LiquidGlass(
        radius: 24,
        blur: 20,
        tint: tagColor,
        onTap: onTap,
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: tagColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: tagColor.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Icon(icon, color: tagColor, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: AppTheme.textPrimary,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3.5,
                        ),
                        decoration: BoxDecoration(
                          color: tagColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: tagColor.withValues(alpha: 0.28),
                          ),
                        ),
                        child: Text(
                          tag,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.1,
                            color: tagColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppTheme.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
