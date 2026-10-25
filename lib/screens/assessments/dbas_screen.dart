import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';

class DbasScreen extends StatefulWidget {
  const DbasScreen({super.key});

  @override
  State<DbasScreen> createState() => _DbasScreenState();
}

class _DbasScreenState extends State<DbasScreen> {
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final str = await rootBundle.loadString('assets/data/dbas_ru.json');
    if (mounted) {
      setState(() => _data = json.decode(str));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_data == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final items = _data!['items'] as List;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Когнитивная реструктуризация'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: AppTheme.bentoBox(
              gradient: const LinearGradient(
                colors: [Color(0xFF131A2E), Color(0xFF0C101B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ШКАЛА УБЕЖДЕНИЙ DBAS • КПТ-И', style: AppTheme.sectionLabel),
                const SizedBox(height: 8),
                Text(
                  _data!['description'],
                  style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ...items.map((item) => _buildCognitiveCard(item)),
        ],
      ),
    );
  }

  Widget _buildCognitiveCard(dynamic item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.bentoBox(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '0${item['id']}',
                style: AppTheme.monoFigures(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.warning),
              ),
              const SizedBox(width: 8),
              const Text(
                'КАТАСТРОФИЧЕСКАЯ МЫСЛЬ',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: AppTheme.warning),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            item['belief'],
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(12),
              border: const Border(
                left: BorderSide(color: AppTheme.success, width: 3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ДОКАЗАТЕЛЬНЫЙ ФАКТ СОМНОЛОГИИ',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.0, color: AppTheme.success),
                ),
                const SizedBox(height: 6),
                Text(
                  item['reframing'],
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
