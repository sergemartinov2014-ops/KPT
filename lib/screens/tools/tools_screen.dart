import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'stimulus_control_screen.dart';
import 'breathing_screen.dart';
import 'ambient_player_screen.dart';
import '../assessments/isi_screen.dart';
import '../assessments/dbas_screen.dart';

class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: const Text('Практики и диагностика'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          const Text('НОЧНЫЕ ПРОТОКОЛЫ', style: AppTheme.sectionLabel),
          const SizedBox(height: 12),
          _buildToolCard(
            context,
            icon: Icons.timelapse_rounded,
            title: 'Правило 20 минут',
            subtitle: 'Стимульный контроль при невозможности уснуть: мягкий фоновый таймер без взгляда на часы',
            tag: 'SCT',
            tagColor: AppTheme.accent,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StimulusControlScreen())),
          ),
          _buildToolCard(
            context,
            icon: Icons.waves_rounded,
            title: 'Дыхательный ритм 4–7–8',
            subtitle: 'Парасимпатическая разгрузка и снижение частоты сердечных сокращений перед сном',
            tag: 'ВЕГЕТАТИКА',
            tagColor: AppTheme.success,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BreathingScreen())),
          ),
          _buildToolCard(
            context,
            icon: Icons.graphic_eq_rounded,
            title: 'Акустическое маскирование',
            subtitle: '8 бесшовных звуковых сред из протокола CBT-i Coach с таймером плавного затухания',
            tag: '8 СЦЕН',
            tagColor: AppTheme.primaryLight,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AmbientPlayerScreen())),
          ),

          const SizedBox(height: 20),
          const Text('КЛИНИЧЕСКИЕ ШКАЛЫ И КОГНИЦИИ', style: AppTheme.sectionLabel),
          const SizedBox(height: 12),
          _buildToolCard(
            context,
            icon: Icons.analytics_outlined,
            title: 'Индекс тяжести инсомнии (ISI)',
            subtitle: 'Золотой стандарт клинической оценки симптомов бессонницы (7 вопросов, шкала 0–28)',
            tag: 'ШКАЛА ISI',
            tagColor: AppTheme.warning,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const IsiScreen())),
          ),
          _buildToolCard(
            context,
            icon: Icons.psychology_outlined,
            title: 'Реструктуризация убеждений (DBAS)',
            subtitle: 'Разбор катастрофических мыслей о сне и снижение когнитивной гиперактивации',
            tag: 'КПТ-И',
            tagColor: AppTheme.accent,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DbasScreen())),
          ),
        ],
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
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: AppTheme.bentoBox(),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: AppTheme.bentoBox(color: AppTheme.surfaceElevated, radius: 12),
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
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppTheme.textPrimary),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: tagColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: tagColor.withValues(alpha: 0.25)),
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: tagColor),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
