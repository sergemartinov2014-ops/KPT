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
    setState(() => _rulesData = json.decode(str));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('База знаний КПТ сна'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E283E), Color(0xFF151C2C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.surfaceBorder),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_stories, color: AppTheme.accent, size: 20),
                    SizedBox(width: 8),
                    Text('Научный фундамент сомнологии', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  'Когнитивно-поведенческая терапия (CBT-i) признана ВОЗ и Американской академией медицины сна '
                  'методом первого выбора при хронической бессоннице. Она эффективнее и безопаснее снотворных.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          const Text('Золотые правила стимульного контроля', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          if (_rulesData != null)
            ...(_rulesData!['rules'] as List).map((rule) => _buildRuleExpansionTile(rule)),

          const SizedBox(height: 20),
          const Text('Физиология сна', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          _buildArticleCard(
            'Двухпроцессная модель регуляции сна',
            'Сон регулируется двумя силами: «Давлением сна» (накоплением аденозина за день) и «Циркадным ритмом» (внутренними часами). Если вы поспите днем, давление сна сбрасывается.',
            Icons.sync,
          ),
          _buildArticleCard(
            'Миф об обязательных 8 часах',
            'Генетическая потребность во сне индивидуальна и колеблется от 6 до 9 часов. Попытки проводить в кровати 8 часов при потребности в 6.5 часах гарантированно приводят к ночным пробуждениям и бессоннице.',
            Icons.access_time,
          ),
          _buildArticleCard(
            'Температура спальни и мелатонин',
            'Чтобы заснуть, внутренняя температура тела должна снизиться на 1°C. Оптимальная температура в комнате — 18–20°C, а горячий душ за 1 час до сна расширяет сосуды и ускоряет охлаждение тела.',
            Icons.thermostat,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildRuleExpansionTile(dynamic rule) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppTheme.accent.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '${rule['id']}',
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.accent, fontSize: 13),
            ),
          ),
        ),
        title: Text(
          rule['title'],
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(
          rule['summary'],
          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Text(
            rule['content'],
            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildArticleCard(String title, String content, IconData icon) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: AppTheme.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(content, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4)),
          ],
        ),
      ),
    );
  }
}
