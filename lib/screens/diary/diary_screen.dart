import '../settings/data_management_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/sleep_provider.dart';
import '../../theme/app_theme.dart';
import '../../models/sleep_diary_entry.dart';
import 'add_diary_entry_screen.dart';

class DiaryScreen extends StatelessWidget {
  const DiaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sleep = context.watch<SleepProvider>();
    final entries = sleep.entries;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Дневник сна'),
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
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Добавить ночь', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const AddDiaryEntryScreen()));
        },
      ),
      body: entries.isEmpty
          ? _buildEmptyState(context)
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                _buildStatsSummary(sleep),
                const SizedBox(height: 16),
                _buildChartCard(entries),
                const SizedBox(height: 16),
                const Text('История записей', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...entries.map((e) => _buildEntryTile(context, e, sleep)),
                const SizedBox(height: 80),
              ],
            ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.menu_book_outlined, size: 64, color: AppTheme.textMuted),
            const SizedBox(height: 16),
            const Text('Дневник пока пуст', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              'Заполняйте дневник каждое утро после пробуждения. Через 5 дней приложение рассчитает ваше персональное окно сна.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Записать первую ночь'),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AddDiaryEntryScreen()));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSummary(SleepProvider sleep) {
    final avgSE = sleep.averageWeeklySE;
    final avgTST = sleep.averageWeeklyTSTMinutes;

    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.surfaceBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Ср. эффективность', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                const SizedBox(height: 4),
                Text(
                  avgSE > 0 ? '${avgSE.toStringAsFixed(1)}%' : '—',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: avgSE >= 85 ? AppTheme.success : (avgSE >= 80 ? AppTheme.warning : AppTheme.error),
                  ),
                ),
                Text(avgSE >= 85 ? 'Отличный уровень' : 'Цель: выше 85%', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.surfaceBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Ср. чистое время', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                const SizedBox(height: 4),
                Text(
                  avgTST > 0 ? '${avgTST ~/ 60} ч ${avgTST % 60} м' : '—',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.accent),
                ),
                const Text('За последние 7 дней', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChartCard(List<SleepDiaryEntry> entries) {
    final chartEntries = entries.take(7).toList().reversed.toList();

    // Если записей меньше 2 — показываем мягкое информационное состояние
    if (chartEntries.length < 2) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.show_chart, color: AppTheme.accent, size: 22),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('График эффективности сна', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    SizedBox(height: 4),
                    Text(
                      'Для отображения динамики требуется минимум 2 записи в дневнике. Заполняйте данные каждое утро.',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.35),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Динамика эффективности сна (SE %)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('Цель CBT-i: 85%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.success)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 170,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 20,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: AppTheme.surfaceBorder.withValues(alpha: 0.5),
                      strokeWidth: 1,
                    ),
                  ),
                  extraLinesData: ExtraLinesData(
                    horizontalLines: [
                      // Пунктирная клиническая целевая линия 85%
                      HorizontalLine(
                        y: 85,
                        color: AppTheme.success.withValues(alpha: 0.7),
                        strokeWidth: 1.5,
                        dashArray: [6, 4],
                      ),
                    ],
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        getTitlesWidget: (v, _) => Text('${v.toInt()}%', style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, _) {
                          int index = v.toInt();
                          if (index >= 0 && index < chartEntries.length) {
                            return Text(DateFormat('dd.MM').format(chartEntries[index].date), style: const TextStyle(fontSize: 10, color: AppTheme.textMuted));
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  minY: 40,
                  maxY: 100,
                  lineBarsData: [
                    LineChartBarData(
                      spots: List.generate(chartEntries.length, (i) {
                        return FlSpot(i.toDouble(), chartEntries[i].sleepEfficiency);
                      }),
                      isCurved: true,
                      color: AppTheme.accent,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppTheme.accent.withValues(alpha: 0.12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntryTile(BuildContext context, SleepDiaryEntry entry, SleepProvider sleep) {
    final se = entry.sleepEfficiency;
    Color seColor = se >= 85 ? AppTheme.success : (se >= 80 ? AppTheme.warning : AppTheme.error);

    return Dismissible(
      key: Key(entry.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: AppTheme.error.withValues(alpha: 0.8),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => sleep.deleteDiaryEntry(entry.id),
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: seColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${se.toInt()}%',
                style: TextStyle(color: seColor, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
          title: Text(
            DateFormat('EEEE, d MMMM', 'ru').format(entry.date),
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          subtitle: Text(
            'Чистый сон: ${entry.totalSleepTimeMinutes ~/ 60} ч ${entry.totalSleepTimeMinutes % 60} м • В кровати: ${entry.timeInBedMinutes ~/ 60} ч ${entry.timeInBedMinutes % 60} м',
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
        ),
      ),
    );
  }
}
