import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/smart_alarm_config.dart';
import '../../providers/sleep_provider.dart';
import '../../providers/smart_alarm_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/liquid_glass.dart';
import '../../widgets/aurora_canvas.dart';
import 'alarm_ringing_screen.dart';

/// Экран управления умным будильником (Obsidian Sanctuary Smart Alarm)
class SmartAlarmScreen extends StatefulWidget {
  const SmartAlarmScreen({super.key});

  @override
  State<SmartAlarmScreen> createState() => _SmartAlarmScreenState();
}

class _SmartAlarmScreenState extends State<SmartAlarmScreen> {
  @override
  Widget build(BuildContext context) {
    final alarm = context.watch<SmartAlarmProvider>();
    final sleep = context.watch<SleepProvider>();

    // Если будильник зазвонил прямо сейчас — автоматически открываем экран звонка
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (alarm.isRinging && ModalRoute.of(context)?.isCurrent == true) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const AlarmRingingScreen(),
            fullscreenDialog: true,
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Умный будильник'),
        actions: [
          Transform.scale(
            scale: 0.85,
            child: Switch.adaptive(
              value: alarm.config.isEnabled,
              activeThumbColor: AppTheme.accent,
              onChanged: (val) => alarm.toggleEnabled(val),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: AuroraCanvas(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
          children: [
            // 1. Главная карточка времени и статуса
            _buildHeroTimeCard(context, alarm),

            const SizedBox(height: 16),

            // 2. Баннер синхронизации с CBT-i (Целевой подъём)
            _buildCbtiSyncBanner(context, alarm, sleep),

            const SizedBox(height: 24),

            // 3. Выбор окна лёгкого сна (Smart Wake Window)
            const Text('ОКНО ЛЁГКОГО СНА', style: AppTheme.sectionLabel),
            const SizedBox(height: 10),
            _buildSmartWindowCard(context, alarm),

            const SizedBox(height: 24),

            // 4. Выбор мелодии пробуждения
            const Text('Звук и мелодия', style: AppTheme.sectionLabel),
            const SizedBox(height: 10),
            _buildSoundPickerCard(context, alarm),

            const SizedBox(height: 24),

            // 5. Плавное нарастание и вибрация
            const Text('Мягкое пробуждение', style: AppTheme.sectionLabel),
            const SizedBox(height: 10),
            _buildGentleWakeCard(context, alarm),

            const SizedBox(height: 24),

            // 6. Дни повтора
            const Text('Дни повтора', style: AppTheme.sectionLabel),
            const SizedBox(height: 10),
            _buildRepeatDaysCard(context, alarm),

            const SizedBox(height: 28),

            // 7. Кнопка тестового запуска
            _buildTestAlarmButton(context, alarm),
          ],
        ),
      ),
    );
  }

  /// Карточка времени
  Widget _buildHeroTimeCard(BuildContext context, SmartAlarmProvider alarm) {
    final isEnabled = alarm.config.isEnabled;
    final isMonitoring = alarm.state == SmartAlarmState.monitoringLightSleep;

    return LiquidGlass(
      radius: 28,
      blur: 24,
      surfaceColor: AppTheme.glassSurfaceElevated,
      glowColor: isMonitoring ? AppTheme.accent : null,
      glowRadius: isMonitoring ? 20 : 0,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
      child: Column(
        children: [
          // Статус бейдж
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isMonitoring
                      ? AppTheme.accent.withValues(alpha: 0.15)
                      : isEnabled
                          ? AppTheme.surfaceElevated
                          : AppTheme.surfaceElevated.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isMonitoring
                        ? AppTheme.accent.withValues(alpha: 0.4)
                        : AppTheme.surfaceBorder,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isMonitoring
                            ? AppTheme.accent
                            : isEnabled
                                ? AppTheme.success
                                : AppTheme.textMuted,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isMonitoring
                          ? 'Отслеживание лёгкого сна...'
                          : isEnabled
                              ? alarm.formattedCountdown
                              : 'Будильник выключен',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isMonitoring
                            ? AppTheme.accent
                            : isEnabled
                                ? AppTheme.textPrimary
                                : AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: () => _showTimePicker(context, alarm),
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.all(4.0),
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 15, color: AppTheme.textMuted),
                      SizedBox(width: 4),
                      Text(
                        'Изменить',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Интерактивный кликабельный таймпикер
          GestureDetector(
            onTap: () => _showTimePicker(context, alarm),
            child: Text(
              alarm.config.formattedTime,
              style: AppTheme.monoFigures(
                fontSize: 68,
                fontWeight: FontWeight.w700,
                color: isEnabled ? AppTheme.textPrimary : AppTheme.textMuted,
                letterSpacing: -1.5,
              ),
            ),
          ),

          const SizedBox(height: 8),

          Text(
            alarm.config.smartWindowLabel,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  /// Баннер привязки к CBT-i
  Widget _buildCbtiSyncBanner(
    BuildContext context,
    SmartAlarmProvider alarm,
    SleepProvider sleep,
  ) {
    final window = sleep.currentWindow;
    final isSynced = alarm.config.wakeHour == window.wakeHour &&
        alarm.config.wakeMinute == window.wakeMinute;

    return LiquidGlass(
      radius: 18,
      blur: 16,
      surfaceColor: AppTheme.glassSurface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Icon(
            Icons.shield_outlined,
            size: 20,
            color: AppTheme.accent,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Терапевтическое окно CBT-i',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Назначенный подъём: ${window.formattedWakeTime}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (!isSynced)
            TextButton(
              onPressed: () {
                alarm.setWakeTime(window.wakeHour, window.wakeMinute);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Будильник установлен на ${window.formattedWakeTime} по предписанию CBT-i',
                    ),
                    backgroundColor: AppTheme.surfaceElevated,
                  ),
                );
              },
              child: const Text(
                'Привязать',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.accent,
                ),
              ),
            )
          else
            const Row(
              children: [
                Icon(Icons.check_circle_rounded, size: 16, color: AppTheme.success),
                SizedBox(width: 4),
                Text(
                  'Связано',
                  style: TextStyle(fontSize: 12, color: AppTheme.success),
                ),
              ],
            ),
        ],
      ),
    );
  }

  /// Карточка выбора окна умного пробуждения
  Widget _buildSmartWindowCard(
    BuildContext context,
    SmartAlarmProvider alarm,
  ) {
    const options = [0, 15, 20, 30, 45];

    return LiquidGlass(
      radius: 24,
      blur: 20,
      surfaceColor: AppTheme.glassSurface,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.waves_rounded, size: 18, color: AppTheme.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  alarm.config.smartWindowMinutes == 0
                      ? 'Точный будильник (без умного окна)'
                      : 'Окно поиска лёгкого сна: ${alarm.config.smartWindowMinutes} минут',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Если в этом окне датчик зафиксирует микродвижения или дыхательный всплеск, будильник сработает раньше целевого времени, избавив от утренней разбитости.',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((mins) {
              final isSelected = alarm.config.smartWindowMinutes == mins;
              final label = mins == 0 ? 'Точно' : '$mins мин';

              return ChoiceChip(
                label: Text(label),
                selected: isSelected,
                onSelected: (_) => alarm.setSmartWindow(mins),
                selectedColor: AppTheme.accent.withValues(alpha: 0.2),
                backgroundColor: AppTheme.surfaceElevated,
                side: BorderSide(
                  color: isSelected ? AppTheme.accent : AppTheme.surfaceBorder,
                ),
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? AppTheme.accent : AppTheme.textSecondary,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// Карточка выбора мелодии
  Widget _buildSoundPickerCard(
    BuildContext context,
    SmartAlarmProvider alarm,
  ) {
    final sound = alarm.config.soundOption;

    return LiquidGlass(
      radius: 24,
      blur: 20,
      surfaceColor: AppTheme.glassSurface,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.surfaceBorder),
            ),
            child: const Icon(
              Icons.music_note_rounded,
              size: 22,
              color: AppTheme.accent,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sound.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sound.subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: () => _showSoundPickerModal(context, alarm),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.accent,
              side: const BorderSide(color: AppTheme.surfaceBorder),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            child: const Text('Выбрать', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  /// Карточка мягкого пробуждения (нарастание и вибро)
  Widget _buildGentleWakeCard(
    BuildContext context,
    SmartAlarmProvider alarm,
  ) {
    const rampOptions = [0, 30, 60, 120];

    return LiquidGlass(
      radius: 24,
      blur: 20,
      surfaceColor: AppTheme.glassSurface,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Плавное нарастание громкости',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Старт с 5% громкости предотвращает выброс кортизола и скачок пульса при резком пробуждении.',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            children: rampOptions.map((sec) {
              final isSelected = alarm.config.rampUpDurationSeconds == sec;
              final label = sec == 0
                  ? 'Сразу 100%'
                  : sec < 60
                      ? '$sec сек'
                      : '${sec ~/ 60} мин';

              return ChoiceChip(
                label: Text(label),
                selected: isSelected,
                onSelected: (_) => alarm.setRampUpDuration(sec),
                selectedColor: AppTheme.accent.withValues(alpha: 0.2),
                backgroundColor: AppTheme.surfaceElevated,
                side: BorderSide(
                  color: isSelected ? AppTheme.accent : AppTheme.surfaceBorder,
                ),
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? AppTheme.accent : AppTheme.textSecondary,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          const Divider(color: AppTheme.surfaceBorder, height: 1),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.vibration_rounded, size: 20, color: AppTheme.textSecondary),
                  SizedBox(width: 10),
                  Text(
                    'Тактильная вибрация',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              Transform.scale(
                scale: 0.8,
                child: Switch.adaptive(
                  value: alarm.config.vibrate,
                  activeThumbColor: AppTheme.accent,
                  onChanged: (val) => alarm.toggleVibration(val),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Карточка дней повтора
  Widget _buildRepeatDaysCard(
    BuildContext context,
    SmartAlarmProvider alarm,
  ) {
    const days = [
      {'id': 1, 'name': 'Пн'},
      {'id': 2, 'name': 'Вт'},
      {'id': 3, 'name': 'Ср'},
      {'id': 4, 'name': 'Чт'},
      {'id': 5, 'name': 'Пт'},
      {'id': 6, 'name': 'Сб'},
      {'id': 7, 'name': 'Вс'},
    ];

    return LiquidGlass(
      radius: 24,
      blur: 20,
      surfaceColor: AppTheme.glassSurface,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                alarm.config.repeatDaysLabel,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              if (alarm.config.repeatDays.length != 7)
                TextButton(
                  onPressed: () => alarm.setRepeatDays([1, 2, 3, 4, 5, 6, 7]),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Каждый день (CBT-i)',
                    style: TextStyle(fontSize: 11, color: AppTheme.accent),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: days.map((day) {
              final int dayId = day['id'] as int;
              final String name = day['name'] as String;
              final isSelected = alarm.config.repeatDays.contains(dayId);

              return GestureDetector(
                onTap: () {
                  final list = List<int>.from(alarm.config.repeatDays);
                  if (isSelected) {
                    list.remove(dayId);
                  } else {
                    list.add(dayId);
                    list.sort();
                  }
                  alarm.setRepeatDays(list);
                },
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.accent
                        : AppTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.accent
                          : AppTheme.surfaceBorder,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    name,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? AppTheme.background
                          : AppTheme.textSecondary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// Кнопка проверки звука
  Widget _buildTestAlarmButton(
    BuildContext context,
    SmartAlarmProvider alarm,
  ) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: () async {
          await alarm.testAlarm();
          if (!context.mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AlarmRingingScreen(),
              fullscreenDialog: true,
            ),
          );
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.accent,
          side: const BorderSide(color: AppTheme.surfaceBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.play_circle_outline_rounded, size: 20),
            SizedBox(width: 8),
            Text(
              'Проверить сигнал и нарастание',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  /// Диалог выбора времени
  Future<void> _showTimePicker(
    BuildContext context,
    SmartAlarmProvider alarm,
  ) async {
    final initialTime = TimeOfDay(
      hour: alarm.config.wakeHour,
      minute: alarm.config.wakeMinute,
    );

    final selected = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: AppTheme.surface,
              hourMinuteColor: AppTheme.surfaceElevated,
              hourMinuteTextColor: AppTheme.textPrimary,
              dialBackgroundColor: AppTheme.surfaceElevated,
              dialHandColor: AppTheme.accent,
              dialTextColor: AppTheme.textPrimary,
              entryModeIconColor: AppTheme.accent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (selected != null) {
      await alarm.setWakeTime(selected.hour, selected.minute);
    }
  }

  /// Модальное окно выбора мелодий
  void _showSoundPickerModal(
    BuildContext context,
    SmartAlarmProvider alarm,
  ) {
    showLiquidGlassBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Consumer<SmartAlarmProvider>(
          builder: (context, alarmProv, _) {
            final previewingId = alarmProv.currentlyPreviewingSoundId;

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Мелодии пробуждения',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Гармоничные частоты, облегчающие переход в бодрствование.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: AlarmSoundOption.available.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = AlarmSoundOption.available[index];
                      final isSelected = alarmProv.config.soundId == item.id;
                      final isPlayingThis = previewingId == item.id;

                      return LiquidGlassInteractive(
                        onTap: () {
                          alarmProv.setSound(item.id);
                        },
                        child: LiquidGlass(
                          radius: 18,
                          blur: 10,
                          surfaceColor: isSelected
                              ? AppTheme.accent.withValues(alpha: 0.15)
                              : AppTheme.glassSurfaceElevated,
                          borderColor: isSelected
                              ? AppTheme.accent
                              : Colors.white.withValues(alpha: 0.14),
                          borderWidth: isSelected ? 1.4 : 1.0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                icon: Icon(
                                  isPlayingThis
                                      ? Icons.pause_circle_filled_rounded
                                      : Icons.play_circle_fill_rounded,
                                  color: isSelected
                                      ? AppTheme.accent
                                      : AppTheme.textSecondary,
                                  size: 30,
                                ),
                                onPressed: () {
                                  alarmProv.previewSound(item.id);
                                },
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.title,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: isSelected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      item.subtitle,
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                const Icon(
                                  Icons.check_circle_rounded,
                                  color: AppTheme.accent,
                                  size: 22,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      alarmProv.stopPreview();
                      Navigator.of(ctx).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      foregroundColor: AppTheme.background,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Выбрать',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
