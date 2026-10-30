import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/smart_alarm_provider.dart';
import '../../theme/app_theme.dart';
import '../diary/add_diary_entry_screen.dart';

/// Полноэкранный экран активного звонка умного будильника (Obsidian Sanctuary Wake Up)
class AlarmRingingScreen extends StatefulWidget {
  const AlarmRingingScreen({super.key});

  @override
  State<AlarmRingingScreen> createState() => _AlarmRingingScreenState();
}

class _AlarmRingingScreenState extends State<AlarmRingingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  String _formatCurrentTime() {
    final now = DateTime.now();
    final h = now.hour.toString().padLeft(2, '0');
    final m = now.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final alarm = context.watch<SmartAlarmProvider>();
    final isSmartWake = alarm.wakeUpReason == 'smart_window';
    final isTest = alarm.wakeUpReason == 'test';
    final volumePct = (alarm.currentVolume * 100).toInt();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          // Дышащая анимация утренней зари (Aurora Radial Glow)
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Center(
                child: Container(
                  width: 320 + (_pulseAnimation.value * 60),
                  height: 320 + (_pulseAnimation.value * 60),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        (isSmartWake
                                ? AppTheme.accent
                                : const Color(0xFFF59E0B))
                            .withValues(alpha: 0.20 + (_pulseAnimation.value * 0.15)),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 1.0],
                    ),
                  ),
                ),
              );
            },
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Верхний статус-бейдж
                  Padding(
                    padding: const EdgeInsets.only(top: 24.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceElevated,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isSmartWake
                              ? AppTheme.accent.withValues(alpha: 0.4)
                              : AppTheme.surfaceBorder,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isSmartWake
                                ? Icons.auto_awesome_rounded
                                : Icons.alarm_rounded,
                            size: 16,
                            color: isSmartWake
                                ? AppTheme.accent
                                : const Color(0xFFF59E0B),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isTest
                                ? 'Тестовое срабатывание'
                                : isSmartWake
                                    ? 'Окно лёгкого сна обнаружено'
                                    : 'Целевое время подъёма CBT-i',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Центральный блок времени и громкости
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatCurrentTime(),
                        style: AppTheme.monoFigures(
                          fontSize: 76,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -2.0,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        alarm.config.soundOption.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Индикатор нарастания громкости (Ramp-up bar)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        decoration: AppTheme.bentoBox(
                          color: AppTheme.surface.withValues(alpha: 0.8),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Плавное пробуждение',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                                Text(
                                  '$volumePct%',
                                  style: AppTheme.monoFigures(
                                    fontSize: 13,
                                    color: AppTheme.accent,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: alarm.currentVolume,
                                backgroundColor: AppTheme.surfaceBorder,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  AppTheme.accent,
                                ),
                                minHeight: 6,
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (isSmartWake) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.accent.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppTheme.accent.withValues(alpha: 0.2),
                            ),
                          ),
                          child: const Text(
                            'Акселерометр и аудиосенсор зафиксировали выход из глубокого сна. Пробуждение сейчас снижает утреннюю сонливость.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.4,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),

                  // Нижний блок кнопок управления
                  Padding(
                    padding: const EdgeInsets.only(bottom: 32.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Большая кнопка "Проснуться"
                        SizedBox(
                          width: double.infinity,
                          height: 60,
                          child: ElevatedButton(
                            onPressed: () => _handleDismiss(context, alarm),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.accent,
                              foregroundColor: AppTheme.background,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.wb_sunny_rounded, size: 22),
                                SizedBox(width: 10),
                                Text(
                                  'Проснуться',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Кнопка "Отложить" (с лимитом по протоколу CBT-i)
                        if (!isTest)
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: OutlinedButton(
                              onPressed: alarm.currentSnoozeCount <
                                      alarm.config.maxSnoozeCount
                                  ? () => _handleSnooze(context, alarm)
                                  : null,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.textPrimary,
                                side: const BorderSide(
                                  color: AppTheme.surfaceBorder,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Text(
                                alarm.currentSnoozeCount <
                                        alarm.config.maxSnoozeCount
                                    ? 'Отложить на ${alarm.config.snoozeDurationMinutes} мин (${alarm.currentSnoozeCount}/${alarm.config.maxSnoozeCount})'
                                    : 'Лимит откладываний исчерпан (CBT-i)',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: alarm.currentSnoozeCount <
                                          alarm.config.maxSnoozeCount
                                      ? AppTheme.textSecondary
                                      : AppTheme.textMuted,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleSnooze(BuildContext context, SmartAlarmProvider alarm) {
    alarm.snooze();
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Будильник отложен на ${alarm.config.snoozeDurationMinutes} мин',
        ),
        backgroundColor: AppTheme.surfaceElevated,
      ),
    );
  }

  Future<void> _handleDismiss(
    BuildContext context,
    SmartAlarmProvider alarm,
  ) async {
    final isTest = alarm.wakeUpReason == 'test';
    await alarm.dismiss();

    if (!context.mounted) return;
    Navigator.of(context).pop();

    if (!isTest) {
      _showMorningDiaryPrompt(context);
    }
  }

  void _showMorningDiaryPrompt(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.surfaceBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Icon(
              Icons.bedtime_outlined,
              size: 40,
              color: AppTheme.accent,
            ),
            const SizedBox(height: 12),
            const Text(
              'Доброе утро!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Зафиксируйте время сна и оценку ночи в дневнике CBT-i, пока воспоминания свежи.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AddDiaryEntryScreen(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: AppTheme.background,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Заполнить дневник сна',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text(
                'Заполнить позже',
                style: TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
