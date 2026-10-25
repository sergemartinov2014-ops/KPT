import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/sleep_diary_entry.dart';
import '../../providers/sleep_provider.dart';
import '../../theme/app_theme.dart';

class AddDiaryEntryScreen extends StatefulWidget {
  const AddDiaryEntryScreen({super.key});

  @override
  State<AddDiaryEntryScreen> createState() => _AddDiaryEntryScreenState();
}

class _AddDiaryEntryScreenState extends State<AddDiaryEntryScreen> {
  final DateTime _date = DateTime.now();

  TimeOfDay _bedTime = const TimeOfDay(hour: 23, minute: 30);
  TimeOfDay _trySleepTime = const TimeOfDay(hour: 23, minute: 45);
  int _solMinutes = 25;
  int _awakeningsCount = 1;
  int _wasoMinutes = 15;
  TimeOfDay _wakeTime = const TimeOfDay(hour: 7, minute: 0);
  TimeOfDay _outOfBedTime = const TimeOfDay(hour: 7, minute: 15);
  int _qualityRating = 3;
  int _napMinutes = 0;
  final TextEditingController _notesController = TextEditingController();

  int get _timeInBedMinutes {
    final int bedTotal = _bedTime.hour * 60 + _bedTime.minute;
    final int outTotal = _outOfBedTime.hour * 60 + _outOfBedTime.minute;
    if (outTotal < bedTotal) {
      return (24 * 60 - bedTotal) + outTotal;
    }
    return outTotal - bedTotal;
  }

  int get _morningAwakeMinutes {
    final int wakeTotal = _wakeTime.hour * 60 + _wakeTime.minute;
    final int outTotal = _outOfBedTime.hour * 60 + _outOfBedTime.minute;
    return outTotal >= wakeTotal ? (outTotal - wakeTotal) : 0;
  }

  int get _totalAwakeMinutes => _solMinutes + _wasoMinutes + _morningAwakeMinutes;

  bool get _isInputValid => _totalAwakeMinutes <= _timeInBedMinutes && _timeInBedMinutes > 0;

  int get _totalSleepMinutes {
    final int tst = _timeInBedMinutes - _totalAwakeMinutes;
    return tst > 0 ? tst : 0;
  }

  double get _sleepEfficiency {
    if (_timeInBedMinutes <= 0) return 0.0;
    final double se = (_totalSleepMinutes / _timeInBedMinutes) * 100.0;
    return se.clamp(0.0, 100.0);
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final se = _sleepEfficiency;
    final Color seColor = se >= 85 ? AppTheme.success : (se >= 80 ? AppTheme.warning : AppTheme.error);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Утренний отчет'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                if (!_isInputValid)
                  Container(
                    padding: const EdgeInsets.all(14),
                    margin: const EdgeInsets.only(bottom: 18),
                    decoration: AppTheme.bentoBox(
                      color: AppTheme.error.withValues(alpha: 0.08),
                      borderColor: AppTheme.error.withValues(alpha: 0.35),
                      radius: 14,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: AppTheme.error, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Суммарное бодрствование ($_totalAwakeMinutes мин) превышает время в постели ($_timeInBedMinutes мин). Проверьте время отбоя и подъема.',
                            style: const TextStyle(fontSize: 12, color: AppTheme.error, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),

                // СЕКЦИЯ 1: ВЕЧЕР
                const Text('1. ОТХОД КО СНУ', style: AppTheme.sectionLabel),
                const SizedBox(height: 10),
                Container(
                  decoration: AppTheme.bentoBox(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildCompactTimeBox(
                              'Легли в постель',
                              _bedTime,
                              (t) => setState(() => _bedTime = t),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildCompactTimeBox(
                              'Попытка уснуть',
                              _trySleepTime,
                              (t) => setState(() => _trySleepTime = t),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildInlineSlider(
                        label: 'Длительность засыпания (SOL)',
                        value: _solMinutes,
                        min: 0,
                        max: 180,
                        step: 5,
                        unit: 'мин',
                        onChanged: (v) => setState(() => _solMinutes = v),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 22),

                // СЕКЦИЯ 2: НОЧНЫЕ ПРОБУЖДЕНИЯ
                const Text('2. СЕРЕДИНА НОЧИ', style: AppTheme.sectionLabel),
                const SizedBox(height: 10),
                Container(
                  decoration: AppTheme.bentoBox(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Число ночных пробуждений', style: TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
                          Row(
                            children: [
                              _buildStepButton(
                                Icons.remove_rounded,
                                _awakeningsCount > 0 ? () => setState(() => _awakeningsCount--) : null,
                              ),
                              SizedBox(
                                width: 36,
                                child: Center(
                                  child: Text(
                                    '$_awakeningsCount',
                                    style: AppTheme.monoFigures(fontSize: 16, fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ),
                              _buildStepButton(
                                Icons.add_rounded,
                                () => setState(() => _awakeningsCount++),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Divider(),
                      ),
                      _buildInlineSlider(
                        label: 'Бодрствование ночью (WASO)',
                        value: _wasoMinutes,
                        min: 0,
                        max: 240,
                        step: 5,
                        unit: 'мин',
                        onChanged: (v) => setState(() => _wasoMinutes = v),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 22),

                // СЕКЦИЯ 3: УТРО
                const Text('3. УТРЕННИЙ ПОДЪЕМ', style: AppTheme.sectionLabel),
                const SizedBox(height: 10),
                Container(
                  decoration: AppTheme.bentoBox(),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildCompactTimeBox(
                          'Проснулись',
                          _wakeTime,
                          (t) => setState(() => _wakeTime = t),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildCompactTimeBox(
                          'Встали с постели',
                          _outOfBedTime,
                          (t) => setState(() => _outOfBedTime = t),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 22),

                // СЕКЦИЯ 4: СУБЪЕКТИВНЫЙ ТОНУС И ДНЕВНОЙ СОН
                const Text('4. КАЧЕСТВО СНА И ДНЕВНОЙ СОН', style: AppTheme.sectionLabel),
                const SizedBox(height: 10),
                Container(
                  decoration: AppTheme.bentoBox(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Субъективное качество ночи', style: TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
                      const SizedBox(height: 12),
                      _buildRatingSelector(),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Divider(),
                      ),
                      _buildInlineSlider(
                        label: 'Дневной сон накануне',
                        value: _napMinutes,
                        min: 0,
                        max: 120,
                        step: 15,
                        unit: 'мин',
                        onChanged: (v) => setState(() => _napMinutes = v),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Нижний телеметрический бар
          Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
            decoration: const BoxDecoration(
              color: AppTheme.surface,
              border: Border(top: BorderSide(color: AppTheme.surfaceBorder)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildTelemetryMetric(
                        'В ПОСТЕЛИ (TIB)',
                        '${_timeInBedMinutes ~/ 60}ч ${(_timeInBedMinutes % 60).toString().padLeft(2, '0')}м',
                        AppTheme.textSecondary,
                      ),
                      _buildTelemetryMetric(
                        'ЧИСТЫЙ СОН (TST)',
                        '${_totalSleepMinutes ~/ 60}ч ${(_totalSleepMinutes % 60).toString().padLeft(2, '0')}м',
                        AppTheme.textPrimary,
                      ),
                      _buildTelemetryMetric(
                        'ЭФФЕКТИВНОСТЬ',
                        _isInputValid ? '${se.toStringAsFixed(1)}%' : '—',
                        _isInputValid ? seColor : AppTheme.textMuted,
                        alignRight: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isInputValid ? _saveEntry : null,
                      child: const Text('Сохранить запись ночи'),
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

  Widget _buildCompactTimeBox(String label, TimeOfDay time, ValueChanged<TimeOfDay> onChanged) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () async {
        final t = await showTimePicker(context: context, initialTime: time);
        if (t != null) onChanged(t);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: AppTheme.bentoBox(color: AppTheme.surfaceElevated, radius: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                  style: AppTheme.monoFigures(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const Icon(Icons.schedule_rounded, size: 16, color: AppTheme.accent),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInlineSlider({
    required String label,
    required int value,
    required int min,
    required int max,
    required int step,
    required String unit,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
            Text(
              '$value $unit',
              style: AppTheme.monoFigures(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.accent),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Slider(
          value: value.toDouble(),
          min: min.toDouble(),
          max: max.toDouble(),
          divisions: (max - min) ~/ step,
          onChanged: (v) => onChanged(v.toInt()),
        ),
      ],
    );
  }

  Widget _buildStepButton(IconData icon, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 34,
        height: 34,
        decoration: AppTheme.bentoBox(color: AppTheme.surfaceElevated, radius: 10),
        child: Icon(icon, size: 18, color: onTap != null ? AppTheme.textPrimary : AppTheme.textMuted),
      ),
    );
  }

  Widget _buildRatingSelector() {
    final labels = ['Тяжело', 'Слабо', 'Средне', 'Хорошо', 'Глубоко'];
    return Row(
      children: List.generate(5, (index) {
        final rating = index + 1;
        final isSelected = _qualityRating == rating;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index < 4 ? 6 : 0),
            child: GestureDetector(
              onTap: () => setState(() => _qualityRating = rating),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primary.withValues(alpha: 0.22) : AppTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? AppTheme.accent : AppTheme.surfaceBorder,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      '$rating',
                      style: AppTheme.monoFigures(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? AppTheme.accent : AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      labels[index],
                      style: TextStyle(
                        fontSize: 9.5,
                        color: isSelected ? AppTheme.textPrimary : AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildTelemetryMetric(String label, String value, Color valueColor, {bool alignRight = false}) {
    return Column(
      crossAxisAlignment: alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.8, color: AppTheme.textMuted)),
        const SizedBox(height: 4),
        Text(value, style: AppTheme.monoFigures(fontSize: 18, fontWeight: FontWeight.w700, color: valueColor)),
      ],
    );
  }

  void _saveEntry() {
    final entry = SleepDiaryEntry(
      id: const Uuid().v4(),
      date: _date,
      bedHour: _bedTime.hour,
      bedMinute: _bedTime.minute,
      trySleepHour: _trySleepTime.hour,
      trySleepMinute: _trySleepTime.minute,
      solMinutes: _solMinutes,
      awakeningsCount: _awakeningsCount,
      wasoMinutes: _wasoMinutes,
      finalWakeHour: _wakeTime.hour,
      finalWakeMinute: _wakeTime.minute,
      outOfBedHour: _outOfBedTime.hour,
      outOfBedMinute: _outOfBedTime.minute,
      qualityRating: _qualityRating,
      napMinutes: _napMinutes,
      notes: _notesController.text,
    );

    context.read<SleepProvider>().addDiaryEntry(entry);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Запись сохранена • Эффективность: ${_sleepEfficiency.toStringAsFixed(1)}%'),
      ),
    );
  }
}
