import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/sleep_provider.dart';
import '../../services/clinical_report_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/aurora_canvas.dart';
import '../../widgets/liquid_glass.dart';

class DataManagementScreen extends StatefulWidget {
  const DataManagementScreen({super.key});

  @override
  State<DataManagementScreen> createState() => _DataManagementScreenState();
}

class _DataManagementScreenState extends State<DataManagementScreen> {
  int _selectedDays = 14;

  @override
  Widget build(BuildContext context) {
    final sleep = context.watch<SleepProvider>();
    final entries = sleep.entries;
    final window = sleep.currentWindow;
    final isiHistory = sleep.isiHistory;

    final reportText = ClinicalReportService.generateReport(
      entries: entries,
      currentWindow: window,
      isiHistory: isiHistory,
      days: _selectedDays,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Клинический отчет и данные'),
      ),
      body: AuroraCanvas(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
          children: [
            // 1. Выгрузка для сомнолога
            FadeSlideEntrance(
              delayMs: 0,
              child: LiquidGlass(
                radius: 24,
                blur: 18,
                surfaceColor: AppTheme.glassSurface,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('ВЫГРУЗКА ДЛЯ ВРАЧА-СОМНОЛОГА', style: AppTheme.sectionLabel),
                        Row(
                          children: [
                            _buildPeriodChip(14, '14 дн'),
                            const SizedBox(width: 6),
                            _buildPeriodChip(30, '30 дн'),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Сводный клинический протокол (предписанное окно, средние TIB, TST, SE %, SOL, WASO и динамика ISI).',
                      style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.45),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF060913).withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                      ),
                      height: 175,
                      width: double.infinity,
                      child: SingleChildScrollView(
                        child: Text(
                          reportText,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.copy_rounded, size: 17),
                        label: const Text('Скопировать клинический отчет'),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: reportText));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Отчет скопирован в буфер обмена'),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 2. Щадящий режим Safe-SRT
            FadeSlideEntrance(
              delayMs: 60,
              child: LiquidGlass(
                radius: 20,
                blur: 16,
                surfaceColor: AppTheme.glassSurface,
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('КЛИНИЧЕСКИЙ ПРЕДОХРАНИТЕЛЬ', style: AppTheme.sectionLabel),
                            SizedBox(height: 4),
                            Text(
                              'Щадящий режим (Safe-SRT)',
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppTheme.textPrimary),
                            ),
                          ],
                        ),
                        Switch(
                          value: sleep.isSafeModeSRT,
                          activeThumbColor: AppTheme.warning,
                          onChanged: (val) => sleep.toggleSafeModeSRT(val),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Удерживает минимальный порог окна сна на уровне 6.5 часов (390 минут) вместо стандартных 5.0 часов.',
                      style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.4),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 3. Метрики локального хранилища (Offline-First)
            FadeSlideEntrance(
              delayMs: 120,
              child: Row(
                children: [
                  Expanded(
                    child: LiquidGlass(
                      radius: 20,
                      blur: 16,
                      surfaceColor: AppTheme.glassSurface,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('ЗАПИСЕЙ НОЧЕЙ', style: AppTheme.sectionLabel),
                          const SizedBox(height: 8),
                          Text(
                            '${entries.length}',
                            style: AppTheme.monoFigures(fontSize: 24, fontWeight: FontWeight.w700, color: AppTheme.accent),
                          ),
                          const SizedBox(height: 2),
                          const Text('Локально на устройстве', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: LiquidGlass(
                      radius: 20,
                      blur: 16,
                      surfaceColor: AppTheme.glassSurface,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('ТЕСТОВ ISI', style: AppTheme.sectionLabel),
                          const SizedBox(height: 8),
                          Text(
                            '${isiHistory.length}',
                            style: AppTheme.monoFigures(fontSize: 24, fontWeight: FontWeight.w700, color: AppTheme.success),
                          ),
                          const SizedBox(height: 2),
                          const Text('100% Offline-First', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 4. Удаление данных
            FadeSlideEntrance(
              delayMs: 180,
              child: LiquidGlass(
                radius: 20,
                blur: 16,
                surfaceColor: AppTheme.error.withValues(alpha: 0.08),
                borderColor: AppTheme.error.withValues(alpha: 0.35),
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'УПРАВЛЕНИЕ ДАННЫМИ (152-ФЗ)',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: AppTheme.error),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Безвозвратное стирание локальной истории дневника сна, тестов ISI и сброс предписанного окна сна.',
                      style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.4),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.error,
                          side: BorderSide(color: AppTheme.error.withValues(alpha: 0.45)),
                        ),
                        onPressed: () => _confirmClearData(context, sleep),
                        child: const Text('Очистить все локальные данные'),
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

  Widget _buildPeriodChip(int days, String label) {
    final bool active = _selectedDays == days;
    return GestureDetector(
      onTap: () => setState(() => _selectedDays = days),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? AppTheme.accent.withValues(alpha: 0.16) : AppTheme.surfaceElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? AppTheme.accent : AppTheme.surfaceBorder),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: active ? FontWeight.w600 : FontWeight.w500,
            color: active ? AppTheme.accent : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  void _confirmClearData(BuildContext context, SleepProvider sleep) {
    showLiquidGlassDialog(
      context: context,
      builder: (ctx) => LiquidGlassDialog(
        icon: Icons.delete_forever_rounded,
        iconColor: AppTheme.error,
        title: const Text('Удалить все данные?'),
        content: const Text(
          'Все записи дневника сна и результаты клинических тестов будут стерты из памяти устройства без возможности восстановления.',
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
            onPressed: () async {
              Navigator.pop(ctx);
              await sleep.clearAllData();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Все локальные данные удалены'),
                  ),
                );
              }
            },
            child: const Text('Удалить', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
