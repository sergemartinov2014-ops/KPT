import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/psqi_result.dart';
import '../../providers/sleep_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/aurora_canvas.dart';
import '../../widgets/liquid_glass.dart';

/// Питтсбургский индекс качества сна (PSQI) — месячный опросник.
class PsqiScreen extends StatefulWidget {
  const PsqiScreen({super.key});

  @override
  State<PsqiScreen> createState() => _PsqiScreenState();
}

class _PsqiScreenState extends State<PsqiScreen> {
  static const List<String> _frequencyShort = [
    'Ни разу',
    'Реже 1×/нед',
    '1–2×/нед',
    '3+×/нед',
  ];

  Map<String, dynamic>? _data;

  final Map<String, int> _frequencies = {};
  final Map<String, int> _choices = {};

  TimeOfDay _bedTime = const TimeOfDay(hour: 23, minute: 0);
  TimeOfDay _wakeTime = const TimeOfDay(hour: 7, minute: 0);
  double _latencyMinutes = 20;
  double _hoursSlept = 7;

  PsqiResult? _result;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final str = await rootBundle.loadString('assets/data/psqi_questions_ru.json');
    if (!mounted) return;
    setState(() => _data = json.decode(str) as Map<String, dynamic>);
  }

  List<dynamic> get _sleepProblems =>
      (_data?['sleepProblems'] as List<dynamic>?) ?? const [];

  List<dynamic> get _singleChoice =>
      (_data?['singleChoice'] as List<dynamic>?) ?? const [];

  bool get _isComplete =>
      _frequencies.length == _sleepProblems.length &&
      _choices.length == _singleChoice.length;

  @override
  Widget build(BuildContext context) {
    if (_data == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Индекс PSQI (месяц)'),
      ),
      body: AuroraCanvas(
        child: _result != null ? _buildResultView(_result!) : _buildFormView(),
      ),
    );
  }

  Widget _buildFormView() {
    final answered = _frequencies.length + _choices.length;
    final totalQuestions = _sleepProblems.length + _singleChoice.length;

    return Column(
      children: [
        LinearProgressIndicator(
          value: totalQuestions == 0 ? 0 : answered / totalQuestions,
          backgroundColor: Colors.white.withValues(alpha: 0.08),
          color: AppTheme.systemPurple,
          minHeight: 2.5,
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
            children: [
              FadeSlideEntrance(
                delayMs: 0,
                child: LiquidGlass(
                  radius: 22,
                  blur: 16,
                  surfaceColor: AppTheme.glassSurface,
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'МЕСЯЧНЫЙ СКРИНИНГ • 30 ДНЕЙ',
                        style: AppTheme.sectionLabel,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _data!['description'] as String,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              _buildTimingCard(),
              const SizedBox(height: 18),
              const Text(
                'Как часто за последний месяц у вас возникали проблемы со сном?',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 10),
              ...List.generate(_sleepProblems.length, (i) {
                final problem = _sleepProblems[i] as Map<String, dynamic>;
                return _buildFrequencyQuestion(i, problem);
              }),
              const SizedBox(height: 8),
              ...List.generate(_singleChoice.length, (i) {
                final item = _singleChoice[i] as Map<String, dynamic>;
                return _buildSingleChoice(i, item);
              }),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isComplete ? _submit : null,
                  child: Text(
                    _isComplete
                        ? 'Рассчитать индекс PSQI'
                        : 'Ответьте на все вопросы ($answered из $totalQuestions)',
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimingCard() {
    return FadeSlideEntrance(
      delayMs: 40,
      child: LiquidGlass(
        radius: 22,
        blur: 16,
        surfaceColor: AppTheme.glassSurface,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Параметры сна за последний месяц', style: AppTheme.sectionLabel),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildTimeButton(
                    label: 'Обычно ложились',
                    time: _bedTime,
                    onChanged: (t) => setState(() => _bedTime = t),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTimeButton(
                    label: 'Обычно вставали',
                    time: _wakeTime,
                    onChanged: (t) => setState(() => _wakeTime = t),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _buildSliderRow(
              label: 'Сколько минут засыпали',
              valueLabel: '${_latencyMinutes.round()} мин',
              value: _latencyMinutes,
              min: 0,
              max: 180,
              divisions: 36,
              onChanged: (v) => setState(() => _latencyMinutes = v),
            ),
            const SizedBox(height: 12),
            _buildSliderRow(
              label: 'Сколько часов реально спали',
              valueLabel: '${_hoursSlept.toStringAsFixed(1)} ч',
              value: _hoursSlept,
              min: 0,
              max: 12,
              divisions: 24,
              onChanged: (v) => setState(() => _hoursSlept = v),
            ),
            const SizedBox(height: 8),
            const Text(
              'Реальное время сна должно быть меньше времени, проведённого в постели.',
              style: TextStyle(fontSize: 11, color: AppTheme.textMuted, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeButton({
    required String label,
    required TimeOfDay time,
    required ValueChanged<TimeOfDay> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 6),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: time,
              builder: (context, child) {
                return MediaQuery(
                  data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
                  child: child!,
                );
              },
            );
            if (picked != null) onChanged(picked);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            ),
            child: Row(
              children: [
                const Icon(Icons.schedule_rounded, size: 16, color: AppTheme.systemPurple),
                const SizedBox(width: 8),
                Text(
                  '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                  style: AppTheme.monoFigures(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSliderRow({
    required String label,
    required String valueLabel,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary)),
            Text(
              valueLabel,
              style: AppTheme.monoFigures(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.systemPurple,
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          activeColor: AppTheme.systemPurple,
          inactiveColor: AppTheme.surfaceElevated,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildFrequencyQuestion(int index, Map<String, dynamic> problem) {
    final id = problem['id'] as String;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: LiquidGlass(
        radius: 18,
        blur: 14,
        surfaceColor: AppTheme.glassSurface,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '5${String.fromCharCode(97 + index)}',
                  style: AppTheme.monoFigures(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.systemPurple,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    problem['text'] as String,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: List.generate(4, (score) {
                final selected = _frequencies[id] == score;
                return _buildChip(
                  label: _frequencyShort[score],
                  selected: selected,
                  onTap: () => setState(() => _frequencies[id] = score),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSingleChoice(int index, Map<String, dynamic> item) {
    final id = item['id'] as String;
    final options = item['options'] as List<dynamic>;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: LiquidGlass(
        radius: 18,
        blur: 14,
        surfaceColor: AppTheme.glassSurface,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item['text'] as String,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: options.map((option) {
                final opt = option as Map<String, dynamic>;
                final score = (opt['score'] as num).toInt();
                final selected = _choices[id] == score;
                return _buildChip(
                  label: opt['text'] as String,
                  selected: selected,
                  onTap: () => setState(() => _choices[id] = score),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.systemPurple.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? AppTheme.systemPurple
                : Colors.white.withValues(alpha: 0.12),
            width: selected ? 1.3 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? AppTheme.systemPurple : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  void _submit() {
    final bed = DateTime(2000, 1, 1, _bedTime.hour, _bedTime.minute);
    final wake = DateTime(2000, 1, 1, _wakeTime.hour, _wakeTime.minute);

    // Q5b–Q5j участвуют в C5; Q5a учитывается в C2.
    var disturbanceSum = 0;
    for (var i = 1; i < _sleepProblems.length; i++) {
      final id = (_sleepProblems[i] as Map<String, dynamic>)['id'] as String;
      disturbanceSum += _frequencies[id] ?? 0;
    }

    final result = PsqiResult.calculate(
      date: DateTime.now(),
      subjectiveQuality: _choices['q6'] ?? 0,
      latencyMinutes: _latencyMinutes.round(),
      sleepLatencyFrequency: _frequencies['q5a'] ?? 0,
      hoursSlept: _hoursSlept,
      bedTime: bed,
      wakeTime: wake,
      sleepDisturbanceSum: disturbanceSum,
      medicationFrequency: _choices['q7'] ?? 0,
      daytimeSleepinessFrequency: _choices['q8'] ?? 0,
      enthusiasmDifficulty: _choices['q9'] ?? 0,
    );

    context.read<SleepProvider>().savePsqiResult(result);
    setState(() => _result = result);
  }

  Widget _buildResultView(PsqiResult result) {
    final color = result.total <= 5
        ? AppTheme.success
        : (result.total <= 10 ? AppTheme.warning : AppTheme.error);
    final dateFormat = DateFormat('d MMMM yyyy', 'ru');

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 8),
        Center(
          child: LiquidGlass(
            radius: 82,
            blur: 24,
            surfaceColor: const Color(0xFF141C2E),
            borderColor: color.withValues(alpha: 0.55),
            borderWidth: 1.5,
            glowColor: color,
            glowRadius: 36,
            child: SizedBox(
              width: 164,
              height: 164,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Индекс PSQI', style: AppTheme.sectionLabel),
                  const SizedBox(height: 4),
                  Text(
                    '${result.total}',
                    style: AppTheme.monoFigures(
                      fontSize: 52,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                  const Text('из 21 балла', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        FadeSlideEntrance(
          delayMs: 60,
          child: LiquidGlass(
            radius: 22,
            blur: 16,
            surfaceColor: AppTheme.glassSurface,
            borderColor: color.withValues(alpha: 0.4),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Клиническая интерпретация', style: AppTheme.sectionLabel),
                const SizedBox(height: 8),
                Text(
                  result.title,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: color),
                ),
                const SizedBox(height: 10),
                Text(
                  result.description,
                  style: const TextStyle(fontSize: 13.5, color: AppTheme.textSecondary, height: 1.5),
                ),
                const SizedBox(height: 12),
                Text(
                  'Сон ${result.hoursSlept.toStringAsFixed(1)} ч · Эффективность ${result.sleepEfficiency.toStringAsFixed(1)}% · Засыпание ${result.latencyMinutes} мин',
                  style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted, height: 1.4),
                ),
                const SizedBox(height: 4),
                Text(
                  'Дата: ${dateFormat.format(result.date)} · порог > 5 баллов',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        FadeSlideEntrance(
          delayMs: 120,
          child: LiquidGlass(
            radius: 20,
            blur: 16,
            surfaceColor: AppTheme.glassSurface,
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Компоненты PSQI', style: AppTheme.sectionLabel),
                const SizedBox(height: 12),
                ...result.components.map((component) {
                  final score = component['score'] as int;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            component['label'] as String,
                            style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
                          ),
                        ),
                        ...List.generate(4, (i) {
                          final filled = i < score;
                          return Container(
                            width: 18,
                            height: 6,
                            margin: const EdgeInsets.only(left: 3),
                            decoration: BoxDecoration(
                              color: filled ? color : Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          );
                        }),
                        const SizedBox(width: 8),
                        Text(
                          '$score',
                          style: AppTheme.monoFigures(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        OutlinedButton(
          onPressed: () {
            setState(() {
              _result = null;
              _frequencies.clear();
              _choices.clear();
            });
          },
          child: const Text('Пройти тестирование повторно'),
        ),
      ],
    );
  }
}
