import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/sleep_provider.dart';
import '../../providers/audio_provider.dart';
import '../../providers/smart_alarm_provider.dart';
import '../../providers/sleep_audio_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/liquid_glass.dart';
import '../../widgets/aurora_canvas.dart';
import '../diary/add_diary_entry_screen.dart';
import '../settings/data_management_screen.dart';
import '../tools/stimulus_control_screen.dart';
import '../tools/ambient_player_screen.dart';
import '../tools/smart_alarm_screen.dart';
import '../tools/sleep_audio_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sleep = context.watch<SleepProvider>();
    final audio = context.watch<AudioProvider>();
    final smartAlarm = context.watch<SmartAlarmProvider>();
    final sleepAudio = context.watch<SleepAudioProvider>();
    final window = sleep.currentWindow;
    final titration = sleep.latestTitration;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.25),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: Image.asset(
                  'assets/icon/app_icon.png',
                  width: 28,
                  height: 28,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 11),
            const Text(
              'СОМНИЯ',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.2,
                color: AppTheme.textPrimary,
              ),
            ),
            if (sleep.isSafeModeSRT) ...[
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
                ),
                child: const Text(
                  'SAFE-SRT',
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: AppTheme.warning),
                ),
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.description_outlined, size: 20),
            tooltip: 'Отчет для врача и данные',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DataManagementScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: AuroraCanvas(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
          children: [
            // 1. Главный прибор: Предписанное окно сна
            _buildSleepWindowHero(context, window, sleep),
            const SizedBox(height: 16),

            // 2. Умный будильник (Smart Alarm из Moonap)
            _buildSmartAlarmCard(context, smartAlarm),
            const SizedBox(height: 16),

            // 3. Аудиозапись сна (Sleep Audio Tracker из Moonap)
            _buildSleepAudioCard(context, sleepAudio),
            const SizedBox(height: 16),

            // 4. Статус сегодняшнего дневника
            _buildTodayDiarySection(context, sleep),
            const SizedBox(height: 16),

            // 5. Еженедельная титрация (если накоплено >= 5 ночей)
            if (titration != null && titration.daysCount >= 5) ...[
              _buildTitrationCard(context, titration, sleep),
              const SizedBox(height: 16),
            ],

            // 6. Экстренный ночной протокол (Правило 20 минут)
            _buildStimulusControlTile(context),
            const SizedBox(height: 24),

            // 7. Акустический фон для сна
            _buildQuickAudioSection(context, audio),
            const SizedBox(height: 28),

            // 8. Ненавязчивый клинический футер
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                'Протокол КПТ-И (CBT-i) • Локальное хранение данных.\nИнструмент самопомощи, не заменяет консультацию врача.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: AppTheme.textMuted, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmartAlarmCard(BuildContext context, SmartAlarmProvider smartAlarm) {
    final config = smartAlarm.config;
    final isEnabled = config.isEnabled;

    return LiquidGlass(
      radius: 24,
      blur: 24,
      surfaceColor: const Color(0xFF090E1A),
      glowColor: null,
      glowRadius: 0,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppTheme.systemIndigo.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.alarm_rounded, color: AppTheme.systemIndigo, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'УМНЫЙ БУДИЛЬНИК',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: AppTheme.systemIndigo,
                        ),
                      ),
                      Text(
                        isEnabled ? smartAlarm.formattedCountdown : 'Будильник выключен',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
              Switch.adaptive(
                value: isEnabled,
                activeThumbColor: AppTheme.systemIndigo,
                onChanged: (val) {
                  HapticFeedback.lightImpact();
                  smartAlarm.toggleEnabled(val);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    config.formattedTime,
                    style: AppTheme.monoFigures(
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      color: isEnabled ? AppTheme.textPrimary : AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.systemIndigo.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppTheme.systemIndigo.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.auto_awesome, size: 11, color: AppTheme.systemIndigo),
                        const SizedBox(width: 4),
                        Text(
                          '±${config.smartWindowMinutes} мин лёгкий сон',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.systemIndigo,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              LiquidGlassInteractive(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SmartAlarmScreen()),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.tune_rounded, size: 14, color: AppTheme.textPrimary),
                      SizedBox(width: 6),
                      Text(
                        'Настроить',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.08),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.music_note_rounded, size: 14, color: AppTheme.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Мелодия: ${config.soundOption.title} • Плавное нарастание',
                  style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSleepAudioCard(BuildContext context, SleepAudioProvider sleepAudio) {
    final isMonitoring = sleepAudio.isMonitoring;
    final clipCount = sleepAudio.clips.length;

    return LiquidGlass(
      radius: 24,
      blur: 24,
      surfaceColor: const Color(0xFF090E1A),
      glowColor: null,
      glowRadius: 0,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppTheme.systemTeal.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isMonitoring ? Icons.mic_rounded : Icons.mic_none_rounded,
                      color: AppTheme.systemTeal,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'АУДИОЗАПИСЬ СНА',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: AppTheme.systemTeal,
                        ),
                      ),
                      Text(
                        isMonitoring
                            ? 'Идет анализ звуков (${sleepAudio.currentDb.toStringAsFixed(0)} дБ)'
                            : (clipCount > 0 ? 'Записано $clipCount событий' : 'Готов к ночному мониторингу'),
                        style: TextStyle(
                          fontSize: 12,
                          color: isMonitoring ? AppTheme.systemTeal : AppTheme.textSecondary,
                          fontWeight: isMonitoring ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Switch.adaptive(
                value: isMonitoring,
                activeThumbColor: AppTheme.systemTeal,
                onChanged: (val) {
                  HapticFeedback.lightImpact();
                  if (val) {
                    sleepAudio.startMonitoring();
                  } else {
                    sleepAudio.stopMonitoring();
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  isMonitoring
                      ? 'Фиксация храпа, разговоров и фаз ворочания в фоновом режиме'
                      : 'Автоматическая запись необычных звуков сна с порогом ${sleepAudio.startThresholdDb.toStringAsFixed(0)} дБ',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
                ),
              ),
              const SizedBox(width: 12),
              LiquidGlassInteractive(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SleepAudioScreen()),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.graphic_eq_rounded, size: 14, color: AppTheme.textPrimary),
                      SizedBox(width: 6),
                      Text(
                        'Записи',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSleepWindowHero(BuildContext context, dynamic window, SleepProvider sleep) {
    return LiquidGlass(
      radius: 26,
      blur: 24,
      surfaceColor: const Color(0xFF0A0F1D),
      glowColor: null,
      glowRadius: 0,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('ПРЕДПИСАННОЕ ОКНО СНА', style: AppTheme.sectionLabel),
              InkWell(
                onTap: () => _showEditWindowDialog(context, sleep),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.surfaceBorder),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.tune_rounded, size: 13, color: AppTheme.textSecondary),
                      SizedBox(width: 5),
                      Text('Изменить', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.south_west_rounded, size: 14, color: AppTheme.accent),
                        SizedBox(width: 4),
                        Text('Отбой', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      window.formattedBedTime,
                      style: AppTheme.monoFigures(fontSize: 32, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              // Минималистичный мост длительности
              Padding(
                padding: const EdgeInsets.only(bottom: 8, right: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.accent.withValues(alpha: 0.22)),
                  ),
                  child: Text(
                    window.formattedDuration,
                    style: AppTheme.monoFigures(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.accent, letterSpacing: 0),
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Icon(Icons.north_east_rounded, size: 14, color: AppTheme.success),
                        SizedBox(width: 4),
                        Text('Подъем', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      window.formattedWakeTime,
                      style: AppTheme.monoFigures(fontSize: 32, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            height: 1,
            color: AppTheme.surfaceBorder,
          ),
          const SizedBox(height: 12),
          const Row(
            children: [
              Icon(Icons.lock_clock_outlined, size: 14, color: AppTheme.textMuted),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Ложитесь не раньше времени отбоя и только при реальной сонливости',
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTodayDiarySection(BuildContext context, SleepProvider sleep) {
    final hasEntry = sleep.hasTodayEntry;
    final today = sleep.todayEntry;

    if (hasEntry && today != null) {
      final se = today.sleepEfficiency;
      final Color seColor = se >= 85 ? AppTheme.success : (se >= 80 ? AppTheme.warning : AppTheme.error);

      return LiquidGlass(
        radius: 22,
        blur: 20,
        surfaceColor: AppTheme.glassSurface,
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: seColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: seColor.withValues(alpha: 0.3)),
              ),
              child: Center(
                child: Text(
                  '${se.toInt()}%',
                  style: AppTheme.monoFigures(fontSize: 15, fontWeight: FontWeight.w700, color: seColor),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Ночь зафиксирована', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppTheme.textPrimary)),
                  const SizedBox(height: 4),
                  Text(
                    'Сон ${today.totalSleepTimeMinutes ~/ 60}ч ${today.totalSleepTimeMinutes % 60}м из ${today.timeInBedMinutes ~/ 60}ч ${today.timeInBedMinutes % 60}м в постели',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_note_rounded, color: AppTheme.textMuted),
              tooltip: 'Обновить запись',
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AddDiaryEntryScreen()));
              },
            ),
          ],
        ),
      );
    }

    return LiquidGlass(
      radius: 22,
      blur: 20,
      surfaceColor: AppTheme.glassSurfaceElevated,
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const AddDiaryEntryScreen()));
      },
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.wb_twilight_rounded, color: AppTheme.accent, size: 22),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Утренний дневник сна', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                SizedBox(height: 3),
                Text('Оцените прошедшую ночь за 1 минуту', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text('Заполнить', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
          ),
        ],
      ),
    );
  }

  Widget _buildStimulusControlTile(BuildContext context) {
    return LiquidGlass(
      radius: 22,
      blur: 20,
      surfaceColor: AppTheme.glassSurface,
      borderGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppTheme.warning.withValues(alpha: 0.16),
          Colors.white.withValues(alpha: 0.05),
          Colors.white.withValues(alpha: 0.01),
        ],
      ),
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const StimulusControlScreen()));
      },
      padding: const EdgeInsets.all(18),
      child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.surfaceElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.surfaceBorder),
              ),
              child: const Icon(Icons.timelapse_rounded, color: AppTheme.accent, size: 22),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Не спится более 20 минут?', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.textPrimary)),
                  SizedBox(height: 3),
                  Text('Стимульный контроль: фоновый ночной компаньон без часов', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.textMuted),
          ],
        ),
    );
  }

  Widget _buildTitrationCard(BuildContext context, dynamic titration, SleepProvider sleep) {
    return LiquidGlass(
      radius: 22,
      blur: 20,
      surfaceColor: const Color(0xFF0A0F1D),
      glowColor: null,
      glowRadius: 0,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_graph_rounded, color: AppTheme.accent, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  titration.title,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppTheme.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(titration.explanation, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.45)),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.accent),
                foregroundColor: AppTheme.accent,
              ),
              onPressed: () => sleep.applyTitrationRecommendation(),
              child: const Text('Применить скорректированный режим'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAudioSection(BuildContext context, AudioProvider audio) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('АКУСТИЧЕСКИЙ ФОН', style: AppTheme.sectionLabel),
            GestureDetector(
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AmbientPlayerScreen()));
              },
              child: const Text('Открыть плеер →', style: TextStyle(fontSize: 12, color: AppTheme.accent, fontWeight: FontWeight.w500)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: audio.sounds.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final sound = audio.sounds[i];
              final isCurrent = audio.currentSound?.id == sound.id && audio.isPlaying;
              return GestureDetector(
                onTap: () => audio.toggleSound(sound),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isCurrent ? AppTheme.primary.withValues(alpha: 0.2) : AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isCurrent ? AppTheme.accent : AppTheme.surfaceBorder,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isCurrent ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        size: 16,
                        color: isCurrent ? AppTheme.accent : AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        sound.name,
                        style: TextStyle(
                          fontSize: 12,
                          color: isCurrent ? AppTheme.textPrimary : AppTheme.textSecondary,
                          fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showEditWindowDialog(BuildContext context, SleepProvider sleep) {
    int bedHour = sleep.currentWindow.bedHour;
    int bedMinute = sleep.currentWindow.bedMinute;
    int wakeHour = sleep.currentWindow.wakeHour;
    int wakeMinute = sleep.currentWindow.wakeMinute;

    showLiquidGlassBottomSheet(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Калибровка окна сна', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                const SizedBox(height: 6),
                const Text(
                  'Время утреннего подъема служит главным якорем циркадного ритма.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 20),
                _buildModalTimeRow(
                  ctx: context,
                  label: 'Предписанный отбой',
                  hour: bedHour,
                  minute: bedMinute,
                  onPicked: (t) => setModalState(() {
                    bedHour = t.hour;
                    bedMinute = t.minute;
                  }),
                ),
                const SizedBox(height: 10),
                _buildModalTimeRow(
                  ctx: context,
                  label: 'Фиксированный подъем',
                  hour: wakeHour,
                  minute: wakeMinute,
                  onPicked: (t) => setModalState(() {
                    wakeHour = t.hour;
                    wakeMinute = t.minute;
                  }),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final success = await sleep.updateCustomWindow(bedHour, bedMinute, wakeHour, wakeMinute);
                      if (ctx.mounted) {
                        if (!success) {
                          final minHours = sleep.isSafeModeSRT ? '6.5' : '5.0';
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Минимальное безопасное окно сна — $minHours ч.'),
                            ),
                          );
                        } else {
                          Navigator.pop(ctx);
                        }
                      }
                    },
                    child: const Text('Сохранить расписание'),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildModalTimeRow({
    required BuildContext ctx,
    required String label,
    required int hour,
    required int minute,
    required ValueChanged<TimeOfDay> onPicked,
  }) {
    return LiquidGlassInteractive(
      onTap: () async {
        final t = await showTimePicker(
          context: ctx,
          initialTime: TimeOfDay(hour: hour, minute: minute),
        );
        if (t != null) onPicked(t);
      },
      child: LiquidGlass(
        radius: 16,
        blur: 10,
        surfaceColor: AppTheme.glassSurfaceElevated,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary, fontWeight: FontWeight.w500)),
            Text(
              '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
              style: AppTheme.monoFigures(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.accent),
            ),
          ],
        ),
      ),
    );
  }
}
