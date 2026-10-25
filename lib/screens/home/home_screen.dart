import '../settings/data_management_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/sleep_provider.dart';
import '../../providers/audio_provider.dart';
import '../../theme/app_theme.dart';
import '../diary/add_diary_entry_screen.dart';
import '../tools/stimulus_control_screen.dart';
import '../tools/ambient_player_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sleep = context.watch<SleepProvider>();
    final audio = context.watch<AudioProvider>();
    final window = sleep.currentWindow;
    final titration = sleep.latestTitration;

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          children: [
            Text('СОМНИЯ', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 2.0)),
            Text('КПТ терапия сна', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.assignment_outlined, size: 22),
            tooltip: 'Отчет для врача',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DataManagementScreen()),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // 1. Предписанное окно сна
          _buildSleepWindowCard(context, window, sleep),
          const SizedBox(height: 16),

          // 2. Дневник за сегодня
          _buildTodayDiaryCard(context, sleep),
          const SizedBox(height: 16),

          // 3. Быстрая помощь ночью: Стимульный контроль (Правило 20 минут)
          _buildStimulusControlBanner(context),
          const SizedBox(height: 16),

          // 4. Рекомендация титрации (если есть)
          if (titration != null && titration.daysCount >= 5)
            _buildTitrationCard(context, titration, sleep),

          // 5. Быстрый запуск звуков для сна
          _buildQuickAudioCard(context, audio),
          const SizedBox(height: 24),

          // 6. Дисклеймер
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'Приложение «Сомния» основано на клиническом протоколе CBT-i (когнитивно-поведенческая терапия инсомнии). '
              'Не является медицинским диагнозом и не заменяет очную консультацию врача-сомнолога.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: AppTheme.textMuted, height: 1.4),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSleepWindowCard(BuildContext context, dynamic window, SleepProvider sleep) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E283E), Color(0xFF151C2C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.surfaceBorder),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.bedtime_outlined, color: AppTheme.accent, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Предписанное окно сна',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20, color: AppTheme.textSecondary),
                onPressed: () => _showEditWindowDialog(context, sleep),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildTimeColumn('Отбой', window.formattedBedTime, Icons.nights_stay),
              Container(width: 1, height: 40, color: AppTheme.surfaceBorder),
              _buildTimeColumn('Подъем', window.formattedWakeTime, Icons.wb_sunny_outlined),
              Container(width: 1, height: 40, color: AppTheme.surfaceBorder),
              _buildTimeColumn('В кровати', window.formattedDuration, Icons.timer_outlined),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeColumn(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 18, color: AppTheme.accent),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
        Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
      ],
    );
  }

  Widget _buildTodayDiaryCard(BuildContext context, SleepProvider sleep) {
    final hasEntry = sleep.hasTodayEntry;
    final today = sleep.todayEntry;

    if (hasEntry && today != null) {
      final se = today.sleepEfficiency;
      Color seColor = se >= 85 ? AppTheme.success : (se >= 80 ? AppTheme.warning : AppTheme.error);

      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: seColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${se.toInt()}%',
                    style: TextStyle(color: seColor, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Дневник за сегодня заполнен', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    Text(
                      'Чистый сон: ${today.totalSleepTimeMinutes ~/ 60} ч ${today.totalSleepTimeMinutes % 60} мин • Эффективность: ${se.toStringAsFixed(1)}%',
                      style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.check_circle, color: AppTheme.success, size: 22),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.edit_note, color: AppTheme.primaryLight, size: 36),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Утренний дневник сна', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                SizedBox(height: 2),
                Text('Заполните данные о сегодняшней ночи для расчета эффективности', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AddDiaryEntryScreen()));
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              backgroundColor: AppTheme.primary,
            ),
            child: const Text('Заполнить', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildStimulusControlBanner(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const StimulusControlScreen()));
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceElevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.surfaceBorder),
        ),
        child: const Row(
          children: [
            Icon(Icons.hourglass_top_rounded, color: AppTheme.accent, size: 30),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Не можете уснуть? (Правило 20 минут)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppTheme.textPrimary)),
                  SizedBox(height: 2),
                  Text('Если не спится больше 20 минут — вставайте с кровати. Запустите ночной помощник.', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildTitrationCard(BuildContext context, dynamic titration, SleepProvider sleep) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.accent, width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: AppTheme.accent, size: 20),
                const SizedBox(width: 8),
                Text(titration.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.accent)),
              ],
            ),
            const SizedBox(height: 8),
            Text(titration.explanation, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => sleep.applyTitrationRecommendation(),
              child: const Text('Применить новое окно сна'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAudioCard(BuildContext context, AudioProvider audio) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.headphones, color: AppTheme.accent, size: 20),
                    SizedBox(width: 8),
                    Text('Звуки для сна', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  ],
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const AmbientPlayerScreen()));
                  },
                  child: const Text('Все звуки', style: TextStyle(fontSize: 13, color: AppTheme.accent)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: audio.sounds.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final sound = audio.sounds[i];
                  final isCurrent = audio.currentSound?.id == sound.id && audio.isPlaying;
                  return ActionChip(
                    backgroundColor: isCurrent ? AppTheme.accent.withValues(alpha: 0.2) : AppTheme.surfaceElevated,
                    side: BorderSide(color: isCurrent ? AppTheme.accent : AppTheme.surfaceBorder),
                    avatar: Icon(
                      isCurrent ? Icons.pause : Icons.play_arrow,
                      size: 16,
                      color: isCurrent ? AppTheme.accent : AppTheme.textPrimary,
                    ),
                    label: Text(
                      sound.name,
                      style: TextStyle(
                        fontSize: 13,
                        color: isCurrent ? AppTheme.accent : AppTheme.textPrimary,
                        fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    onPressed: () => audio.toggleSound(sound),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditWindowDialog(BuildContext context, SleepProvider sleep) {
    int bedHour = sleep.currentWindow.bedHour;
    int bedMinute = sleep.currentWindow.bedMinute;
    int wakeHour = sleep.currentWindow.wakeHour;
    int wakeMinute = sleep.currentWindow.wakeMinute;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Настройка окна сна', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Выберите привычное время отбоя и постоянного утреннего подъема.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                  const SizedBox(height: 20),
                  ListTile(
                    title: const Text('Время отбоя'),
                    trailing: Text(
                      '${bedHour.toString().padLeft(2, '0')}:${bedMinute.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.accent),
                    ),
                    onTap: () async {
                      final t = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay(hour: bedHour, minute: bedMinute),
                      );
                      if (t != null) {
                        setModalState(() {
                          bedHour = t.hour;
                          bedMinute = t.minute;
                        });
                      }
                    },
                  ),
                  ListTile(
                    title: const Text('Время утреннего подъема'),
                    trailing: Text(
                      '${wakeHour.toString().padLeft(2, '0')}:${wakeMinute.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.accent),
                    ),
                    onTap: () async {
                      final t = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay(hour: wakeHour, minute: wakeMinute),
                      );
                      if (t != null) {
                        setModalState(() {
                          wakeHour = t.hour;
                          wakeMinute = t.minute;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final success = await sleep.updateCustomWindow(bedHour, bedMinute, wakeHour, wakeMinute);
                        if (ctx.mounted) {
                          if (!success) {
                            final minHours = sleep.isSafeModeSRT ? '6.5' : '5';
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Окно сна не может быть меньше $minHours часов в целях клинической безопасности.'),
                                backgroundColor: AppTheme.error,
                              ),
                            );
                          } else {
                            Navigator.pop(ctx);
                          }
                        }
                      },
                      child: const Text('Сохранить'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
