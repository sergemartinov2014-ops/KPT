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
  int _solMinutes = 30; // Латентность засыпания (мин)
  int _awakeningsCount = 1;
  int _wasoMinutes = 20; // Пробуждения среди ночи (мин)
  TimeOfDay _wakeTime = const TimeOfDay(hour: 7, minute: 0);
  TimeOfDay _outOfBedTime = const TimeOfDay(hour: 7, minute: 15);
  int _qualityRating = 3; // 1 to 5
  int _napMinutes = 0;
  final TextEditingController _notesController = TextEditingController();

  // Вычисляемые параметры на лету
  int get _timeInBedMinutes {
    int bedTotal = _bedTime.hour * 60 + _bedTime.minute;
    int outTotal = _outOfBedTime.hour * 60 + _outOfBedTime.minute;
    if (outTotal < bedTotal) {
      return (24 * 60 - bedTotal) + outTotal;
    }
    return outTotal - bedTotal;
  }

  int get _morningAwakeMinutes {
    int wakeTotal = _wakeTime.hour * 60 + _wakeTime.minute;
    int outTotal = _outOfBedTime.hour * 60 + _outOfBedTime.minute;
    return outTotal >= wakeTotal ? (outTotal - wakeTotal) : 0;
  }

  int get _totalAwakeMinutes => _solMinutes + _wasoMinutes + _morningAwakeMinutes;

  bool get _isInputValid => _totalAwakeMinutes <= _timeInBedMinutes && _timeInBedMinutes > 0;

  int get _totalSleepMinutes {
    int tst = _timeInBedMinutes - _totalAwakeMinutes;
    return tst > 0 ? tst : 0;
  }

  double get _sleepEfficiency {
    if (_timeInBedMinutes <= 0) return 0.0;
    double se = (_totalSleepMinutes / _timeInBedMinutes) * 100.0;
    return se > 100.0 ? 100.0 : (se < 0 ? 0 : se);
  }

  @override
  Widget build(BuildContext context) {
    final se = _sleepEfficiency;
    Color seColor = se >= 85 ? AppTheme.success : (se >= 80 ? AppTheme.warning : AppTheme.error);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Запись в дневник сна'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (!_isInputValid) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.error.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.error.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: AppTheme.error, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Время бодрствования ($_totalAwakeMinutes мин) превышает время в кровати ($_timeInBedMinutes мин). Проверьте время отбоя или длительность засыпания.',
                            style: const TextStyle(fontSize: 12, color: AppTheme.error, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                _buildSectionHeader('1. Вечер и засыпание'),
                _buildTimePickerTile('Во сколько вы легли в кровать?', _bedTime, (t) => setState(() => _bedTime = t)),
                _buildTimePickerTile('Во сколько вы начали пытаться уснуть?', _trySleepTime, (t) => setState(() => _trySleepTime = t)),
                _buildNumberSlider('Сколько минут ушло на засыпание?', _solMinutes, 0, 180, 5, 'мин', (v) => setState(() => _solMinutes = v)),

                const SizedBox(height: 16),
                _buildSectionHeader('2. Ночные пробуждения'),
                _buildCounterTile('Сколько раз вы просыпались ночью?', _awakeningsCount, (c) => setState(() => _awakeningsCount = c)),
                _buildNumberSlider('Суммарно минут бодрствования ночью:', _wasoMinutes, 0, 240, 5, 'мин', (v) => setState(() => _wasoMinutes = v)),

                const SizedBox(height: 16),
                _buildSectionHeader('3. Утренний подъем'),
                _buildTimePickerTile('Во сколько вы окончательно проснулись?', _wakeTime, (t) => setState(() => _wakeTime = t)),
                _buildTimePickerTile('Во сколько встали с кровати?', _outOfBedTime, (t) => setState(() => _outOfBedTime = t)),

                const SizedBox(height: 16),
                _buildSectionHeader('4. Оценка и дневной сон'),
                _buildQualityRating(),
                _buildNumberSlider('Дневной сон вчера (если был):', _napMinutes, 0, 120, 15, 'мин', (v) => setState(() => _napMinutes = v)),
                const SizedBox(height: 16),
              ],
            ),
          ),

          // Живой расчет эффективности сна внизу
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              color: AppTheme.surfaceElevated,
              border: Border(top: BorderSide(color: AppTheme.surfaceBorder)),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Чистый сон: ${_totalSleepMinutes ~/ 60} ч ${_totalSleepMinutes % 60} мин',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                          Text(
                            'В кровати: ${_timeInBedMinutes ~/ 60} ч ${_timeInBedMinutes % 60} мин',
                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _isInputValid ? '${se.toStringAsFixed(1)}%' : '—',
                            style: TextStyle(
                              color: _isInputValid ? seColor : AppTheme.textMuted,
                              fontWeight: FontWeight.bold,
                              fontSize: 22,
                            ),
                          ),
                          const Text('Эффективность', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isInputValid ? _saveEntry : null,
                      child: const Text('Сохранить запись'),
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

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.accent)),
    );
  }

  Widget _buildTimePickerTile(String title, TimeOfDay time, Function(TimeOfDay) onChanged) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(title, style: const TextStyle(fontSize: 14)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.surfaceElevated,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.surfaceBorder),
          ),
          child: Text(
            '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
            style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
          ),
        ),
        onTap: () async {
          final t = await showTimePicker(context: context, initialTime: time);
          if (t != null) onChanged(t);
        },
      ),
    );
  }

  Widget _buildNumberSlider(String title, int value, int min, int max, int step, String unit, Function(int) onChanged) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(title, style: const TextStyle(fontSize: 14))),
                Text('$value $unit', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.accent)),
              ],
            ),
            Slider(
              value: value.toDouble(),
              min: min.toDouble(),
              max: max.toDouble(),
              divisions: (max - min) ~/ step,
              activeColor: AppTheme.accent,
              onChanged: (v) => onChanged(v.toInt()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCounterTile(String title, int count, Function(int) onChanged) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(title, style: const TextStyle(fontSize: 14)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, color: AppTheme.accent),
              onPressed: count > 0 ? () => onChanged(count - 1) : null,
            ),
            Text('$count', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            IconButton(
              icon: const Icon(Icons.add_circle_outline, color: AppTheme.accent),
              onPressed: () => onChanged(count + 1),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQualityRating() {
    final emojis = ['😫', '🙁', '😐', '🙂', '😊'];
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Как вы оцениваете качество сна?', style: TextStyle(fontSize: 14)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(5, (index) {
                final rating = index + 1;
                final isSelected = _qualityRating == rating;
                return InkWell(
                  onTap: () => setState(() => _qualityRating = rating),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.accent.withValues(alpha: 0.2) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isSelected ? AppTheme.accent : Colors.transparent),
                    ),
                    child: Text(emojis[index], style: const TextStyle(fontSize: 26)),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
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
        content: Text('Запись сохранена! Эффективность сна: ${_sleepEfficiency.toStringAsFixed(1)}%'),
        backgroundColor: AppTheme.surfaceElevated,
      ),
    );
  }
}
