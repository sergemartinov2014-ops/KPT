import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/sleep_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/aurora_canvas.dart';
import '../../widgets/liquid_glass.dart';

class IsiScreen extends StatefulWidget {
  const IsiScreen({super.key});

  @override
  State<IsiScreen> createState() => _IsiScreenState();
}

class _IsiScreenState extends State<IsiScreen> {
  Map<String, dynamic>? _quizData;
  final Map<int, int> _answers = {};
  bool _isSubmitted = false;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    final str = await rootBundle.loadString('assets/data/isi_questions_ru.json');
    if (mounted) {
      setState(() {
        _quizData = json.decode(str);
      });
    }
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
        title: const Text('Шкала инсомнии (ISI)'),
        actions: [
          if (!_isSubmitted)
            Padding(
              padding: const EdgeInsets.only(right: 20),
              child: Center(
                child: Text(
                  '${_answers.length}/${questions.length}',
                  style: AppTheme.monoFigures(fontSize: 14, color: AppTheme.accent),
                ),
              ),
            ),
        ],
      ),
      body: AuroraCanvas(
        child: _isSubmitted
            ? _buildResultView()
            : Column(
                children: [
                  LinearProgressIndicator(
                    value: _answers.length / questions.length,
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    color: AppTheme.accent,
                    minHeight: 2.5,
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
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
                                const Text('КЛИНИЧЕСКИЙ СКРИНИНГ • 7 ВОПРОСОВ', style: AppTheme.sectionLabel),
                                const SizedBox(height: 8),
                                Text(
                                  _quizData!['description'],
                                  style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.45),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        ...List.generate(questions.length, (i) => _buildQuestionBento(i, questions[i])),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
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
                            child: Text(
                              isComplete
                                  ? 'Рассчитать клинический индекс'
                                  : 'Ответьте на все вопросы (${_answers.length} из ${questions.length})',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildQuestionBento(int index, dynamic q) {
    final options = q['options'] as List;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: FadeSlideEntrance(
        delayMs: 40 * index,
        child: LiquidGlass(
          radius: 22,
          blur: 16,
          surfaceColor: AppTheme.glassSurface,
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '0${index + 1}',
                    style: AppTheme.monoFigures(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.accent),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      q['text'],
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.textPrimary, height: 1.4),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ...options.map((opt) {
                final score = opt['score'] as int;
                final isSelected = _answers[index] == score;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: LiquidGlassInteractive(
                    onTap: () => setState(() => _answers[index] = score),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.accent.withValues(alpha: 0.16) : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected ? AppTheme.accent : Colors.white.withValues(alpha: 0.12),
                          width: isSelected ? 1.4 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: isSelected ? AppTheme.accent : Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Center(
                              child: Text(
                                '$score',
                                style: AppTheme.monoFigures(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected ? AppTheme.background : AppTheme.textMuted,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              opt['text'],
                              style: TextStyle(
                                fontSize: 13,
                                color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultView() {
    final score = _totalScore;
    final interpretations = _quizData!['interpretations'] as List;
    final interp = interpretations.firstWhere(
      (it) => score >= it['min'] && score <= it['max'],
      orElse: () => interpretations.last,
    );

    final Color scoreColor = score <= 7
        ? AppTheme.success
        : (score <= 14 ? AppTheme.warning : AppTheme.error);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 16),
        Center(
          child: LiquidGlass(
            radius: 82,
            blur: 24,
            surfaceColor: const Color(0xFF141C2E),
            borderColor: scoreColor.withValues(alpha: 0.55),
            borderWidth: 1.5,
            glowColor: scoreColor,
            glowRadius: 36,
            child: SizedBox(
              width: 164,
              height: 164,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Индекс ISI', style: AppTheme.sectionLabel),
                  const SizedBox(height: 4),
                  Text(
                    '$score',
                    style: AppTheme.monoFigures(fontSize: 52, fontWeight: FontWeight.w700, color: scoreColor),
                  ),
                  const Text('из 28 баллов', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 28),
        FadeSlideEntrance(
          delayMs: 60,
          child: LiquidGlass(
            radius: 22,
            blur: 16,
            surfaceColor: AppTheme.glassSurface,
            borderColor: scoreColor.withValues(alpha: 0.40),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Клиническая интерпретация', style: AppTheme.sectionLabel),
                const SizedBox(height: 8),
                Text(
                  interp['title'],
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: scoreColor),
                ),
                const SizedBox(height: 10),
                Text(
                  interp['description'],
                  style: const TextStyle(fontSize: 13.5, color: AppTheme.textSecondary, height: 1.5),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        OutlinedButton(
          onPressed: () {
            setState(() {
              _answers.clear();
              _isSubmitted = false;
            });
          },
          child: const Text('Пройти тестирование повторно'),
        ),
      ],
    );
  }
}
