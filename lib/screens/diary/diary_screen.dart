import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/sleep_provider.dart';
import '../../theme/app_theme.dart';
import '../../models/sleep_diary_entry.dart';
import '../../widgets/liquid_glass.dart';
import '../../widgets/aurora_canvas.dart';
import '../settings/data_management_screen.dart';
import 'add_diary_entry_screen.dart';

/// Экран дневника и аналитики сна в стиле Apple Liquid Glass (iOS 26)
class DiaryScreen extends StatelessWidget {
  const DiaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sleep = context.watch<SleepProvider>();
    final entries = sleep.entries;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: const Text('Аналитика и дневник'),
        actions: [
          IconButton(
            icon: const Icon(Icons.description_outlined, size: 20),
            tooltip: 'Отчет для врача',
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
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 70), // Парит над плавающим таб-баром
        child: FloatingActionButton.extended(
          backgroundColor: AppTheme.systemIndigo,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
              color: Colors.white.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
          icon: const Icon(Icons.add_rounded, color: AppTheme.textPrimary, size: 20),
          label: const Text(
            'Записать ночь',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddDiaryEntryScreen()),
            );
          },
        ),
      ),
      body: AuroraCanvas(
        child: entries.isEmpty
            ? _buildEmptyState(context)
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
                children: [
                  _buildStatsSummary(sleep),
                  const SizedBox(height: 16),
                  _buildChartCard(entries),
                  const SizedBox(height: 24),
                  const Text('ЖУРНАЛ НОЧЕЙ', style: AppTheme.sectionLabel),
                  const SizedBox(height: 12),
                  ...entries.map((e) => _buildEntryTile(context, e, sleep)),
                ],
              ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: LiquidGlass(
          radius: 28,
          blur: 24,
          surfaceColor: AppTheme.glassSurfaceElevated,
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.accent.withValues(alpha: 0.3),
                  ),
                ),
                child: const Icon(
                  Icons.nights_stay_outlined,
                  size: 32,
                  color: AppTheme.accent,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Нет записей о сне',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Фиксируйте показатели каждое утро. После 5 ночей алгоритм рассчитает индивидуальную компрессию окна сна.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AddDiaryEntryScreen(),
                    ),
                  );
                },
                child: const Text('Добавить первую запись'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsSummary(SleepProvider sleep) {
    final avgSE = sleep.averageWeeklySE;
    final avgTST = sleep.averageWeeklyTSTMinutes;
    final Color seColor = avgSE >= 85
        ? AppTheme.success
        : (avgSE >= 80 ? AppTheme.warning : AppTheme.error);

    return Row(
      children: [
        Expanded(
          child: LiquidGlass(
            radius: 24,
            blur: 20,
            surfaceColor: AppTheme.glassSurface,
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ЭФФЕКТИВНОСТЬ (7 ДН)', style: AppTheme.sectionLabel),
                const SizedBox(height: 10),
                Text(
                  avgSE > 0 ? '${avgSE.toStringAsFixed(1)}%' : '—',
                  style: AppTheme.monoFigures(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: avgSE > 0 ? seColor : AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  avgSE >= 85 ? 'Консолидированный сон' : 'Целевой порог ≥ 85%',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: LiquidGlass(
            radius: 24,
            blur: 20,
            surfaceColor: AppTheme.glassSurface,
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ЧИСТЫЙ СОН (TST)', style: AppTheme.sectionLabel),
                const SizedBox(height: 10),
                Text(
                  avgTST > 0
                      ? '${avgTST ~/ 60}ч ${(avgTST % 60).toString().padLeft(2, '0')}м'
                      : '—',
                  style: AppTheme.monoFigures(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Среднее за неделю',
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChartCard(List<SleepDiaryEntry> entries) {
    final chartEntries = entries.take(7).toList().reversed.toList();

    if (chartEntries.length < 2) {
      return const LiquidGlass(
        radius: 24,
        blur: 20,
        surfaceColor: AppTheme.glassSurface,
        padding: EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(Icons.query_stats_rounded, color: AppTheme.accent, size: 22),
            SizedBox(width: 14),
            Expanded(
              child: Text(
                'Тренд эффективности сна появится после заполнения минимум 2 утренних записей.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return LiquidGlass(
      radius: 24,
      blur: 20,
      surfaceColor: AppTheme.glassSurface,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('ДИНАМИКА SLEEP EFFICIENCY', style: AppTheme.sectionLabel),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 2,
                    color: AppTheme.success,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Норма (85%)',
                    style: TextStyle(fontSize: 10.5, color: AppTheme.success),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 140,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 20,
                  getDrawingHorizontalLine: (val) {
                    if (val == 80) {
                      return FlLine(
                        color: AppTheme.success.withValues(alpha: 0.35),
                        strokeWidth: 1,
                        dashArray: [4, 4],
                      );
                    }
                    return FlLine(
                      color: Colors.white.withValues(alpha: 0.06),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      interval: 20,
                      getTitlesWidget: (v, _) => Text(
                        '${v.toInt()}%',
                        style: AppTheme.monoFigures(
                          fontSize: 9.5,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      getTitlesWidget: (v, _) {
                        final int index = v.toInt();
                        if (index >= 0 && index < chartEntries.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              DateFormat('dd.MM')
                                  .format(chartEntries[index].date),
                              style: AppTheme.monoFigures(
                                fontSize: 10,
                                color: AppTheme.textMuted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minY: 40,
                maxY: 100,
                lineBarsData: [
                  LineChartBarData(
                    spots: List.generate(chartEntries.length, (i) {
                      return FlSpot(
                        i.toDouble(),
                        chartEntries[i].sleepEfficiency.clamp(40.0, 100.0),
                      );
                    }),
                    isCurved: true,
                    curveSmoothness: 0.28,
                    color: AppTheme.accent,
                    barWidth: 2.5,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                        radius: 3.5,
                        color: AppTheme.background,
                        strokeWidth: 2,
                        strokeColor: spot.y >= 85
                            ? AppTheme.success
                            : AppTheme.accent,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.accent.withValues(alpha: 0.22),
                          AppTheme.accent.withValues(alpha: 0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
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

  Widget _buildEntryTile(
    BuildContext context,
    SleepDiaryEntry entry,
    SleepProvider sleep,
  ) {
    final se = entry.sleepEfficiency;
    final Color seColor = se >= 85
        ? AppTheme.success
        : (se >= 80 ? AppTheme.warning : AppTheme.error);

    return Dismissible(
      key: Key(entry.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppTheme.error.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.error.withValues(alpha: 0.4)),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline_rounded, color: AppTheme.error),
      ),
      onDismissed: (_) => sleep.deleteDiaryEntry(entry.id),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: LiquidGlass(
          radius: 20,
          blur: 16,
          surfaceColor: AppTheme.glassSurface,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: seColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: seColor.withValues(alpha: 0.35),
                  ),
                ),
                child: Center(
                  child: Text(
                    '${se.toInt()}%',
                    style: AppTheme.monoFigures(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: seColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('d MMMM, EEEE', 'ru').format(entry.date),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Сон ${entry.totalSleepTimeMinutes ~/ 60}ч ${entry.totalSleepTimeMinutes % 60}м • Постель ${entry.timeInBedMinutes ~/ 60}ч ${entry.timeInBedMinutes % 60}м • SOL ${entry.solMinutes}м',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
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
