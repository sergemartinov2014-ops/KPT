import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';

class LearnScreen extends StatefulWidget {
  const LearnScreen({super.key});

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> {
  Map<String, dynamic>? _rulesData;

  @override
  void initState() {
    super.initState();
    _loadRules();
  }

  Future<void> _loadRules() async {
    final str = await rootBundle.loadString('assets/data/sleep_rules_ru.json');
    if (mounted) {
      setState(() => _rulesData = json.decode(str));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: const Text('Теория КПТ-И'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: AppTheme.bentoBox(
              gradient: const LinearGradient(
                colors: [Color(0xFF131A2E), Color(0xFF0C101B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('КЛИНИЧЕСКИЙ СТАНДАРТ', style: AppTheme.sectionLabel),
                SizedBox(height: 8),
                Text(
                  'Доказательная терапия первой линии',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: AppTheme.textPrimary),
                ),
                SizedBox(height: 6),
                Text(
                  'Когнитивно-поведенческая терапия инсомнии (CBT-i) рекомендована Европейским обществом исследования сна (ESRS) и AASM как основной метод восстановления архитектуры сна без фармакотерапии.',
                  style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          const Text('ПРАВИЛА СТИМУЛЬНОГО КОНТРОЛЯ (БУТЗИН)', style: AppTheme.sectionLabel),
          const SizedBox(height: 12),

          if (_rulesData != null)
            ...(_rulesData!['rules'] as List).map((rule) => _buildRuleCard(rule)),

          const SizedBox(height: 20),
          const Text('НЕЙРОБИОЛОГИЯ СНА', style: AppTheme.sectionLabel),
          const SizedBox(height: 12),

          _buildArticleCard(
            '01',
            'Двухпроцессная модель Борбели',
            'Глубина сна определяется суммой двух векторов: гомеостатического давления сна (накопление аденозина с момента утреннего подъема — Процесс S) и суточного циркадного ритма (Процесс C). Любой дневной сон сбрасывает аденозиновое давление.',
          ),
          _buildArticleCard(
            '02',
            'Индивидуальная норма вместо 8 часов',
            'Попытка лежать в постели 8.5 часов при генетической потребности в 6.5 часах фрагментирует сон, снижает его эффективность (SE < 80%) и формирует условный рефлекс «постель = борьба со сном».',
          ),
          _buildArticleCard(
            '03',
            'Терморегуляция и мелатонин',
            'Для инициации сна температура ядра тела должна снизиться на 0.5–1.0 °C. Прохладная спальня (18–20 °C) и полное исключение белого/синего спектра экрана за час до отбоя ускоряют наступление фазы глубокого сна.',
          ),
        ],
      ),
    );
  }

  Widget _buildRuleCard(dynamic rule) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: AppTheme.bentoBox(radius: 16),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          iconColor: AppTheme.accent,
          collapsedIconColor: AppTheme.textMuted,
          leading: Container(
            width: 32,
            height: 32,
            decoration: AppTheme.bentoBox(color: AppTheme.surfaceElevated, radius: 9),
            child: Center(
              child: Text(
                '0${rule['id']}',
                style: AppTheme.monoFigures(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.accent),
              ),
            ),
          ),
          title: Text(
            rule['title'],
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.textPrimary),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              rule['summary'],
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ),
          children: [
            const Divider(),
            const SizedBox(height: 10),
            Text(
              rule['content'],
              style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArticleCard(String indexStr, String title, String content) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.bentoBox(radius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                indexStr,
                style: AppTheme.monoFigures(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5, color: AppTheme.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.5),
          ),
        ],
      ),
    );
  }
}
