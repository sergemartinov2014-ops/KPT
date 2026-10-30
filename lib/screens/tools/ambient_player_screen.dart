import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/audio_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/aurora_canvas.dart';
import '../../widgets/liquid_glass.dart';

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
        title: const Text('Акустические среды'),
      ),
      body: AuroraCanvas(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Верхняя консоль активного канала и таймера сна
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: FadeSlideEntrance(
                delayMs: 0,
                child: LiquidGlass(
                  radius: 24,
                  blur: 20,
                  surfaceColor: AppTheme.glassSurface,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: isPlaying ? AppTheme.accent.withValues(alpha: 0.18) : AppTheme.glassSurfaceElevated,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isPlaying ? AppTheme.accent.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.15),
                              ),
                            ),
                            child: Icon(
                              currentSound != null ? _getIconForSound(currentSound.id) : Icons.headphones_rounded,
                              color: isPlaying ? AppTheme.accent : AppTheme.textMuted,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  currentSound?.name ?? 'Звук не выбран',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  remainingSecs > 0
                                      ? 'Fade-out через ${remainingSecs ~/ 60}:${(remainingSecs % 60).toString().padLeft(2, '0')}'
                                      : (isPlaying ? 'Бесшовный цикл активен' : 'Выберите сцену ниже'),
                                  style: AppTheme.monoFigures(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: remainingSecs > 0 ? AppTheme.warning : AppTheme.textSecondary,
                                    letterSpacing: 0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (currentSound != null)
                            IconButton.filled(
                              style: IconButton.styleFrom(
                                backgroundColor: isPlaying ? AppTheme.systemIndigo : AppTheme.glassSurfaceElevated,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              icon: Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: AppTheme.textPrimary),
                              onPressed: () => isPlaying ? audio.pause() : audio.resume(),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Таймер сна', style: AppTheme.sectionLabel),
                          Row(
                            children: [
                              _buildTimerChip(audio, 0, 'Выкл', remainingSecs == 0),
                              const SizedBox(width: 6),
                              _buildTimerChip(audio, 15, '15м', remainingSecs > 0 && remainingSecs <= 15 * 60),
                              const SizedBox(width: 6),
                              _buildTimerChip(audio, 30, '30м', remainingSecs > 15 * 60 && remainingSecs <= 30 * 60),
                              const SizedBox(width: 6),
                              _buildTimerChip(audio, 60, '60м', remainingSecs > 30 * 60),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text('Библиотека CBT-i Coach', style: AppTheme.sectionLabel),
            ),
            const SizedBox(height: 10),

            // Двуколоночная Bento-сетка звуков Liquid Glass
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(20, 2, 20, 28),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.45,
                ),
                itemCount: audio.sounds.length,
                itemBuilder: (context, i) {
                  final sound = audio.sounds[i];
                  final isThisPlaying = currentSound?.id == sound.id && isPlaying;

                  return FadeSlideEntrance(
                    delayMs: 30 * i,
                    child: LiquidGlassInteractive(
                      onTap: () => audio.toggleSound(sound),
                      child: LiquidGlass(
                        radius: 20,
                        blur: 14,
                        surfaceColor: isThisPlaying
                            ? AppTheme.accent.withValues(alpha: 0.18)
                            : AppTheme.glassSurface,
                        borderColor: isThisPlaying
                            ? AppTheme.accent
                            : Colors.white.withValues(alpha: 0.14),
                        borderWidth: isThisPlaying ? 1.4 : 1.0,
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Icon(
                                  _getIconForSound(sound.id),
                                  color: isThisPlaying ? AppTheme.accent : AppTheme.textSecondary,
                                  size: 22,
                                ),
                                Icon(
                                  isThisPlaying ? Icons.equalizer_rounded : Icons.play_circle_outline_rounded,
                                  color: isThisPlaying ? AppTheme.accent : AppTheme.textMuted,
                                  size: 18,
                                ),
                              ],
                            ),
                            Text(
                              sound.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: isThisPlaying ? FontWeight.w700 : FontWeight.w500,
                                color: isThisPlaying ? AppTheme.textPrimary : AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimerChip(AudioProvider audio, int minutes, String label, bool active) {
    return LiquidGlassInteractive(
      onTap: () => audio.setTimer(minutes),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? AppTheme.accent.withValues(alpha: 0.20) : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? AppTheme.accent : Colors.white.withValues(alpha: 0.14),
            width: 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? AppTheme.accent : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  IconData _getIconForSound(String id) {
    switch (id) {
      case 'rain':
        return Icons.water_drop_outlined;
      case 'forest':
        return Icons.park_outlined;
      case 'stream':
        return Icons.waves_rounded;
      case 'beach':
        return Icons.tsunami_rounded;
      case 'crickets':
        return Icons.nights_stay_outlined;
      case 'wind':
        return Icons.air_rounded;
      case 'white_noise':
        return Icons.blur_on_rounded;
      case 'long_bowl':
        return Icons.self_improvement_rounded;
      default:
        return Icons.music_note_outlined;
    }
  }
}
