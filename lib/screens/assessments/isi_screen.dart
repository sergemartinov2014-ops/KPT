import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/sleep_provider.dart';
import '../../theme/app_theme.dart';

class IsiScreen extends StatefulWidget {
  const IsiScreen({super.key});

  @override
  State<IsiScreen> createState() => _IsiScreenState();
}

class _IsiScreenState extends State<IsiScreen> {
  Map<String, dynamic>? _quizData;
  final Map<int, int> _answers = {}; // question index -> score (0..4)
  bool _isSubmitted = false;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    final str = await rootBundle.loadString('assets/data/isi_questions_ru.json');
    setState(() {
      _quizData = json.decode(str);
    });
  }

  int get _totalScore => _answers.values.fold(0, (sum, v) => sum + v);

  @override
  Widget build(BuildContext context) {
    if (_quizData == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final questions = _quizData!['questions'] as List;
    final isComplete = _answers.length == questions.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Тест выраженности бессонницы (ISI)'),
      ),
      body: _isSubmitted
          ? _buildResultView(questions.length)
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
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
                      Text(_quizData!['title'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.accent)),
                      const SizedBox(height: 6),
                      Text(_quizData!['description'], style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                ...List.generate(questions.length, (i) => _buildQuestionCard(i, questions[i])),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: isComplete
                      ? () {
                          final score = _totalScore;
                          final interpretations = _quizData!['interpretations'] as List;
                          final interp = interpretations.firstWhere(
                            (it) => score >= it['min'] && score <= it['max'],
                            orElse: () => interpretations.last,
                          );
                          context.read<SleepProvider>().saveIsiResult(score, interp['title']);
                          setState(() => _isSubmitted = true);
                        }
                      : null,
                  child: Text(isComplete ? 'Показать результат' : 'Ответьте на все 7 вопросов (${_answers.length}/7)'),
                ),
                const SizedBox(height: 40),
              ],
            ),
    );
  }

  Widget _buildQuestionCard(int index, dynamic q) {
    final options = q['options'] as List;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${index + 1}. ${q['text']}',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 12),
            ...options.map((opt) {
              final score = opt['score'] as int;
              final isSelected = _answers[index] == score;
              return InkWell(
                onTap: () => setState(() => _answers[index] = score),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.accent.withValues(alpha: 0.15) : AppTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? AppTheme.accent : AppTheme.surfaceBorder,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                        size: 18,
                        color: isSelected ? AppTheme.accent : AppTheme.textMuted,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          opt['text'],
                          style: TextStyle(
                            fontSize: 13,
                            color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildResultView(int totalQuestions) {
    final score = _totalScore;
    final interpretations = _quizData!['interpretations'] as List;
    final interp = interpretations.firstWhere(
      (it) => score >= it['min'] && score <= it['max'],
      orElse: () => interpretations.last,
    );

    Color scoreColor = score <= 7
        ? AppTheme.success
        : (score <= 14 ? AppTheme.warning : AppTheme.error);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 20),
        Center(
          child: Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scoreColor.withValues(alpha: 0.12),
              border: Border.all(color: scoreColor, width: 3),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$score',
                  style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: scoreColor),
                ),
                const Text('из 28 баллов', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: Text(
            interp['title'],
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: scoreColor),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.surfaceBorder),
          ),
          child: Text(
            interp['description'],
            style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary, height: 1.5),
          ),
        ),
        const SizedBox(height: 24),
        OutlinedButton(
          onPressed: () {
            setState(() {
              _answers.clear();
              _isSubmitted = false;
            });
          },
          child: const Text('Пройти тест заново'),
        ),
      ],
    );
  }
}
