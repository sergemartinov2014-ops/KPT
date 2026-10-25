import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/sleep_provider.dart';
import '../../services/clinical_report_service.dart';
import '../../theme/app_theme.dart';

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
        title: const Text('Отчет для врача и данные'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Секция отчета для врача
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.surfaceBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.assignment_outlined, color: AppTheme.accent, size: 22),
                    SizedBox(width: 8),
                    Text('Отчет для врача-сомнолога', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Сводная клиническая выгрузка с расчетом TIB, TST, средней эффективности сна и динамики тестов ISI. '
                  'Вы можете скопировать ее для отправки специалисту.',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('Период выгрузки:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 12),
                    ChoiceChip(
                      label: const Text('14 дней'),
                      selected: _selectedDays == 14,
                      selectedColor: AppTheme.accent.withValues(alpha: 0.2),
                      side: BorderSide(color: _selectedDays == 14 ? AppTheme.accent : AppTheme.surfaceBorder),
                      onSelected: (sel) => setState(() => _selectedDays = 14),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('30 дней'),
                      selected: _selectedDays == 30,
                      selectedColor: AppTheme.accent.withValues(alpha: 0.2),
                      side: BorderSide(color: _selectedDays == 30 ? AppTheme.accent : AppTheme.surfaceBorder),
                      onSelected: (sel) => setState(() => _selectedDays = 30),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Превью отчета в стилизованном блоке
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.surfaceBorder),
                  ),
                  height: 180,
                  child: SingleChildScrollView(
                    child: Text(
                      reportText,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Скопировать отчет для врача'),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: reportText));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Отчет скопирован в буфер обмена! Вы можете отправить его врачу или сохранить.'),
                          backgroundColor: AppTheme.surfaceElevated,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 2. Секция щадящего режима титрации (Safe-SRT)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.surfaceBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.health_and_safety_outlined, color: AppTheme.warning, size: 22),
                        SizedBox(width: 8),
                        Text('Щадящий режим (Safe-SRT)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                    Switch(
                      value: sleep.isSafeModeSRT,
                      activeThumbColor: AppTheme.warning,
                      onChanged: (val) => sleep.toggleSafeModeSRT(val),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Устанавливает минимальное окно сна не менее 6.5 часов (390 минут) вместо стандартных 5.0 часов. '
                  'Рекомендуется при наличии противопоказаний (эпилепсия, БАР, апноэ или работа водителем).',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 3. Секция локальной приватности
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.surfaceBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.shield_outlined, color: AppTheme.success, size: 22),
                    SizedBox(width: 8),
                    Text('Приватность и хранение', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Все ваши медицинские записи хранятся исключительно на этом устройстве (Offline-First). '
                  'Приложение не собирает личные данные и не имеет серверов слежения.\n\n'
                  '• Сохранено ночей в дневнике: ${entries.length}\n'
                  '• Пройдено тестов ISI: ${isiHistory.length}',
                  style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 3. Красная зона: Полное удаление данных
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.delete_forever, color: AppTheme.error, size: 22),
                    SizedBox(width: 8),
                    Text('Удаление всех данных', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.error)),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Безвозвратное удаление всей истории дневника сна, результатов опросников и сброс окна сна к заводским настройкам.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.error,
                    side: const BorderSide(color: AppTheme.error),
                  ),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Очистить все данные'),
                  onPressed: () => _confirmClearData(context, sleep),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _confirmClearData(BuildContext context, SleepProvider sleep) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceElevated,
        title: const Text('Удалить все данные?'),
        content: const Text(
          'Вы уверены, что хотите стереть все записи дневника и результаты тестов? '
          'Это действие нельзя отменить.',
          style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () async {
              Navigator.pop(ctx);
              await sleep.clearAllData();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Все локальные данные были успешно удалены.'),
                    backgroundColor: AppTheme.surface,
                  ),
                );
              }
            },
            child: const Text('Удалить всё'),
          ),
        ],
      ),
    );
  }
}
