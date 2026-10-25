import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/audio_provider.dart';
import '../../theme/app_theme.dart';

class AmbientPlayerScreen extends StatelessWidget {
  const AmbientPlayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final audio = context.watch<AudioProvider>();
    final currentSound = audio.currentSound;
    final isPlaying = audio.isPlaying;
    final remainingSecs = audio.remainingTimerSeconds;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Звуки для сна'),
      ),
      body: Column(
        children: [
          // Активный плеер сверху
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: AppTheme.surface,
              border: Border(bottom: BorderSide(color: AppTheme.surfaceBorder)),
            ),
            child: Column(
              children: [
                Icon(
                  isPlaying ? Icons.graphic_eq : Icons.headphones,
                  size: 48,
                  color: isPlaying ? AppTheme.accent : AppTheme.textMuted,
                ),
                const SizedBox(height: 12),
                Text(
                  currentSound?.name ?? 'Выберите фоновый звук',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (remainingSecs > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Таймер сна: ${remainingSecs ~/ 60}:${(remainingSecs % 60).toString().padLeft(2, '0')}',
                    style: const TextStyle(fontSize: 12, color: AppTheme.warning),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Кнопка паузы / воспроизведения
                    IconButton.filled(
                      iconSize: 36,
                      style: IconButton.styleFrom(backgroundColor: AppTheme.primary),
                      icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                      onPressed: currentSound != null
                          ? () => isPlaying ? audio.pause() : audio.resume()
                          : null,
                    ),
                    const SizedBox(width: 16),
                    // Кнопка установки таймера сна
                    PopupMenuButton<int>(
                      icon: const Icon(Icons.timer_outlined, color: AppTheme.textPrimary),
                      tooltip: 'Таймер сна',
                      onSelected: (mins) => audio.setTimer(mins),
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 0, child: Text('Без таймера')),
                        const PopupMenuItem(value: 15, child: Text('15 минут')),
                        const PopupMenuItem(value: 30, child: Text('30 минут')),
                        const PopupMenuItem(value: 45, child: Text('45 минут')),
                        const PopupMenuItem(value: 60, child: Text('1 час')),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Сетка доступных 8 звуков
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: audio.sounds.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final sound = audio.sounds[i];
                final isThisPlaying = currentSound?.id == sound.id && isPlaying;

                return Card(
                  color: isThisPlaying ? AppTheme.surfaceElevated : AppTheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: isThisPlaying ? AppTheme.accent : AppTheme.surfaceBorder,
                      width: isThisPlaying ? 1.5 : 1.0,
                    ),
                  ),
                  child: ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isThisPlaying ? AppTheme.accent.withValues(alpha: 0.2) : AppTheme.surfaceBorder.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _getIconForSound(sound.id),
                        color: isThisPlaying ? AppTheme.accent : AppTheme.textPrimary,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      sound.name,
                      style: TextStyle(
                        fontWeight: isThisPlaying ? FontWeight.bold : FontWeight.w500,
                        color: isThisPlaying ? AppTheme.accent : AppTheme.textPrimary,
                      ),
                    ),
                    trailing: IconButton(
                      icon: Icon(isThisPlaying ? Icons.stop_circle : Icons.play_circle_outline),
                      color: isThisPlaying ? AppTheme.accent : AppTheme.textSecondary,
                      iconSize: 28,
                      onPressed: () => audio.toggleSound(sound),
                    ),
                    onTap: () => audio.toggleSound(sound),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconForSound(String id) {
    switch (id) {
      case 'rain':
        return Icons.water_drop;
      case 'forest':
        return Icons.forest;
      case 'stream':
        return Icons.waves;
      case 'beach':
        return Icons.beach_access;
      case 'crickets':
        return Icons.nights_stay;
      case 'wind':
        return Icons.air;
      case 'white_noise':
        return Icons.graphic_eq;
      case 'long_bowl':
        return Icons.self_improvement;
      default:
        return Icons.music_note;
    }
  }
}
