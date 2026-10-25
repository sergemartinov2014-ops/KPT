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
        title: const Text('Практики и инструменты'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildToolCard(
            context,
            icon: Icons.hourglass_top_rounded,
            title: 'Правило 20 минут',
            subtitle: 'Помощник при бессоннице прямо сейчас: таймер выхода из кровати и инструкции',
            badge: 'Экстренно',
            badgeColor: AppTheme.accent,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StimulusControlScreen())),
          ),
          _buildToolCard(
            context,
            icon: Icons.air,
            title: 'Дыхание 4-7-8',
            subtitle: 'Ритмичная практика для быстрого снятия вегетативного напряжения и снижения пульса',
            badge: 'Релаксация',
            badgeColor: AppTheme.primaryLight,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BreathingScreen())),
          ),
          _buildToolCard(
            context,
            icon: Icons.headphones,
            title: 'Звуки природы для засыпания',
            subtitle: '8 бесшовных фоновых треков: дождь, ночной лес, ручей, морской прибой, поющие чаши',
            badge: '8 звуков',
            badgeColor: AppTheme.success,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AmbientPlayerScreen())),
          ),
          _buildToolCard(
            context,
            icon: Icons.quiz_outlined,
            title: 'Индекс тяжести инсомнии (ISI)',
            subtitle: 'Стандартизированный тест из 7 вопросов для точной оценки симптомов бессонницы',
            badge: 'Клинический тест',
            badgeColor: AppTheme.warning,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const IsiScreen())),
          ),
          _buildToolCard(
            context,
            icon: Icons.psychology_outlined,
            title: 'Работа с мыслями о сне',
            subtitle: 'Разбор 4 главных катастрофических убеждений и замена их на факты',
            badge: 'КПТ',
            badgeColor: AppTheme.primaryLight,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DbasScreen())),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildToolCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String badge,
    required Color badgeColor,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.surfaceBorder),
                ),
                child: Icon(icon, color: AppTheme.accent, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimary),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badge,
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: badgeColor),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
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
