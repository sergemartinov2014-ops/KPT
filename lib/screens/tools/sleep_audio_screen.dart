import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/sleep_audio_clip.dart';
import '../../providers/sleep_audio_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/liquid_glass.dart';
import '../../widgets/aurora_canvas.dart';

class SleepAudioScreen extends StatefulWidget {
  const SleepAudioScreen({super.key});

  @override
  State<SleepAudioScreen> createState() => _SleepAudioScreenState();
}

class _SleepAudioScreenState extends State<SleepAudioScreen> {
  final DateFormat _timeFormat = DateFormat('HH:mm:ss');
  final DateFormat _dateFormat = DateFormat('d MMMM, yyyy', 'ru');

  @override
  Widget build(BuildContext context) {
    final audio = context.watch<SleepAudioProvider>();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Аудиозапись сна'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded, size: 20),
            tooltip: 'Параметры чувствительности',
            onPressed: () => _showSettingsDialog(context, audio),
          ),
          if (audio.clips.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined, size: 21),
              tooltip: 'Очистить историю записей',
              onPressed: () => _confirmClearAll(context, audio),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: AuroraCanvas(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
          children: [
            _buildHeroControlCard(context, audio),
            const SizedBox(height: 20),
            _buildQuickSettingsCard(context, audio),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Записи событий сна', style: AppTheme.sectionLabel),
                if (audio.clips.isNotEmpty)
                  Text(
                    '${audio.clips.length} ${audio.clips.length == 1 ? 'клип' : 'клипов'}',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (audio.clips.isEmpty)
              _buildEmptyState()
            else
              ...audio.clips.map((clip) => _buildClipCard(context, audio, clip)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroControlCard(BuildContext context, SleepAudioProvider audio) {
    final isRunning = audio.isMonitoring;
    final isWaiting = audio.isWaitingDelay;
    final isRec = audio.isRecordingClip;

    return LiquidGlass(
      radius: 28,
      blur: 24,
      surfaceColor: isRec
          ? AppTheme.error.withValues(alpha: 0.16)
          : (isRunning
              ? AppTheme.accent.withValues(alpha: 0.12)
              : AppTheme.glassSurfaceElevated),
      glowColor: isRec
          ? AppTheme.error
          : (isRunning ? AppTheme.accent : null),
      glowRadius: isRunning ? 22 : 0,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isRec
                      ? AppTheme.error.withValues(alpha: 0.2)
                      : (isRunning
                          ? AppTheme.accent.withValues(alpha: 0.15)
                          : AppTheme.surfaceElevated),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isRec
                        ? AppTheme.error.withValues(alpha: 0.4)
                        : (isRunning
                            ? AppTheme.accent.withValues(alpha: 0.3)
                            : AppTheme.surfaceBorder),
                  ),
                ),
                child: Icon(
                  isRec
                      ? Icons.fiber_manual_record
                      : (isRunning
                          ? Icons.graphic_eq_rounded
                          : Icons.mic_none_rounded),
                  color: isRec
                      ? AppTheme.error
                      : (isRunning ? AppTheme.accent : AppTheme.textSecondary),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isRec
                          ? 'Идет запись звука'
                          : (isWaiting
                              ? 'Ожидание засыпания'
                              : (isRunning
                                  ? 'Мониторинг активен'
                                  : 'Мониторинг выключен')),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.15,
                        color: isRec
                            ? AppTheme.error
                            : (isRunning
                                ? AppTheme.accent
                                : AppTheme.textMuted),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isRec
                          ? 'Фиксируем звуковой фрагмент...'
                          : (isWaiting
                              ? 'Запись включится через ${audio.delayMinutes} мин'
                              : (isRunning
                                  ? 'Слушаем микрофон на храп и разговоры'
                                  : 'Умная фиксация шумов и храпа')),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (isRunning) ...[
            const SizedBox(height: 20),
            _buildLiveSoundMeter(audio.currentDb, audio.startThresholdDb),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Записано за сессию: ${audio.sessionClipCount} / 50',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                if (isWaiting)
                  TextButton(
                    onPressed: () => audio.startMonitoring(bypassDelay: true),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(50, 24),
                    ),
                    child: const Text(
                      'Начать сейчас',
                      style: TextStyle(fontSize: 12, color: AppTheme.accent),
                    ),
                  ),
              ],
            ),
          ],

          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: isRunning
                    ? AppTheme.surfaceElevated
                    : AppTheme.accent,
                foregroundColor: isRunning
                    ? AppTheme.error
                    : const Color(0xFF06080F),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: isRunning
                      ? const BorderSide(color: AppTheme.surfaceBorder)
                      : BorderSide.none,
                ),
              ),
              icon: Icon(
                isRunning ? Icons.stop_rounded : Icons.play_arrow_rounded,
                size: 20,
              ),
              label: Text(
                isRunning ? 'Остановить мониторинг' : 'Включить на ночь',
                style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
              ),
              onPressed: () async {
                if (isRunning) {
                  await audio.stopMonitoring();
                } else {
                  final ok = await audio.startMonitoring();
                  if (!ok && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Предоставьте доступ к микрофону в настройках телефона'),
                      ),
                    );
                  }
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveSoundMeter(double currentDb, double thresholdDb) {
    // Нормализация децибел от -60 dB (тишина) до 0 dB (макс)
    final clamped = currentDb.clamp(-60.0, 0.0);
    final ratio = (clamped + 60.0) / 60.0;
    final isOverThreshold = currentDb >= thresholdDb;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Уровень громкости:',
              style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
            ),
            Text(
              '${currentDb.toStringAsFixed(1)} dB (порог: ${thresholdDb.toStringAsFixed(0)} dB)',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: isOverThreshold ? AppTheme.error : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Container(
            height: 8,
            color: AppTheme.surfaceElevated,
            child: Row(
              children: [
                Expanded(
                  flex: (ratio * 1000).toInt().clamp(1, 1000),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isOverThreshold
                          ? AppTheme.error
                          : (ratio > 0.6 ? AppTheme.warning : AppTheme.success),
                    ),
                  ),
                ),
                Expanded(
                  flex: ((1.0 - ratio) * 1000).toInt().clamp(0, 1000),
                  child: const SizedBox(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickSettingsCard(BuildContext context, SleepAudioProvider audio) {
    return LiquidGlass(
      radius: 24,
      blur: 20,
      surfaceColor: AppTheme.glassSurface,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.hourglass_top_rounded, color: AppTheme.accent, size: 18),
              SizedBox(width: 8),
              Text(
                'Задержка включения микрофона',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Не записывает звуки, пока вы укладываетесь в постель',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildDelayChip(audio, 0, 'Сразу'),
              const SizedBox(width: 8),
              _buildDelayChip(audio, 10, '10 мин'),
              const SizedBox(width: 8),
              _buildDelayChip(audio, 20, '20 мин'),
              const SizedBox(width: 8),
              _buildDelayChip(audio, 30, '30 мин'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDelayChip(SleepAudioProvider audio, int mins, String label) {
    final isSelected = audio.delayMinutes == mins;
    return Expanded(
      child: InkWell(
        onTap: () => audio.updateSettings(delay: mins),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.accent.withValues(alpha: 0.15) : AppTheme.surfaceElevated,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppTheme.accent : AppTheme.surfaceBorder,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? AppTheme.accent : AppTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const LiquidGlass(
      radius: 24,
      blur: 20,
      surfaceColor: AppTheme.glassSurface,
      padding: EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        children: [
          Icon(Icons.nights_stay_outlined, color: AppTheme.textMuted, size: 40),
          SizedBox(height: 12),
          Text(
            'Нет сохраненных фрагментов',
            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
          ),
          SizedBox(height: 6),
          Text(
            'Включите мониторинг перед сном. Приложение автоматически запишет моменты храпа, разговоров или резких шорохов.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.45),
          ),
        ],
      ),
    );
  }

  Widget _buildClipCard(BuildContext context, SleepAudioProvider audio, SleepAudioClip clip) {
    final isPlaying = audio.playingClipId == clip.id;

    IconData typeIcon;
    Color typeColor;
    switch (clip.soundType) {
      case SleepSoundType.snore:
        typeIcon = Icons.bedtime_rounded;
        typeColor = AppTheme.primaryLight;
        break;
      case SleepSoundType.talk:
        typeIcon = Icons.record_voice_over_rounded;
        typeColor = AppTheme.accent;
        break;
      case SleepSoundType.movement:
        typeIcon = Icons.waves_rounded;
        typeColor = AppTheme.success;
        break;
      case SleepSoundType.ambient:
        typeIcon = Icons.volume_up_rounded;
        typeColor = AppTheme.warning;
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: LiquidGlass(
        radius: 20,
        blur: 16,
        surfaceColor: isPlaying
            ? AppTheme.accent.withValues(alpha: 0.16)
            : AppTheme.glassSurface,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            InkWell(
              onTap: () => audio.playClip(clip),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isPlaying ? AppTheme.accent : typeColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isPlaying ? AppTheme.accent : typeColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: isPlaying ? const Color(0xFF06080F) : typeColor,
                  size: 24,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(typeIcon, size: 14, color: typeColor),
                      const SizedBox(width: 6),
                      Text(
                        clip.soundType.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: typeColor,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _timeFormat.format(clip.timestamp),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Text(
                        '${clip.durationSeconds} сек',
                        style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                      ),
                      const Text(
                        ' • ',
                        style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                      ),
                      Text(
                        'Пик ${clip.peakDecibels.toStringAsFixed(0)} dB',
                        style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                      ),
                      const Spacer(),
                      Text(
                        _dateFormat.format(clip.timestamp),
                        style: const TextStyle(fontSize: 10.5, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 19, color: AppTheme.textMuted),
              tooltip: 'Удалить фрагмент',
              onPressed: () => audio.deleteClip(clip.id),
            ),
          ],
        ),
      ),
    );
  }

  void _showSettingsDialog(BuildContext context, SleepAudioProvider audio) {
    double tempThreshold = audio.startThresholdDb;

    showLiquidGlassBottomSheet(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Порог чувствительности микрофона',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20, color: AppTheme.textSecondary),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Чем выше значение (ближе к 0 dB), тем громче должен быть храп или шум, чтобы началась запись.',
                  style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Порог активации:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                    Text(
                      '${tempThreshold.toStringAsFixed(0)} dB',
                      style: const TextStyle(
                        color: AppTheme.accent,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: tempThreshold,
                  min: -50.0,
                  max: -15.0,
                  divisions: 35,
                  activeColor: AppTheme.accent,
                  inactiveColor: AppTheme.surfaceElevated,
                  onChanged: (val) {
                    setModalState(() => tempThreshold = val);
                  },
                ),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Очень чуткий (-50 dB)', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                    Text('Только громкий (-15 dB)', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      foregroundColor: const Color(0xFF06080F),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Сохранить', style: TextStyle(fontWeight: FontWeight.w700)),
                    onPressed: () {
                      audio.updateSettings(threshold: tempThreshold);
                      Navigator.pop(ctx);
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmClearAll(BuildContext context, SleepAudioProvider audio) {
    showLiquidGlassDialog(
      context: context,
      builder: (ctx) => LiquidGlassDialog(
        icon: Icons.delete_outline_rounded,
        iconColor: AppTheme.error,
        title: const Text('Удалить все записи?'),
        content: const Text(
          'Все сохраненные аудиофрагменты сна будут удалены с устройства без возможности восстановления.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
              minimumSize: const Size(80, 44),
            ),
            child: const Text('Отмена', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
              minimumSize: const Size(100, 44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () {
              audio.clearAllClips();
              Navigator.pop(ctx);
            },
            child: const Text('Удалить', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
