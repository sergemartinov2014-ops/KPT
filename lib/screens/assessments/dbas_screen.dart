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
    setState(() => _data = json.decode(str));
  }

  @override
  Widget build(BuildContext context) {
    if (_data == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final items = _data!['items'] as List;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Работа с мыслями о сне'),
      ),
      body: ListView(
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
                const Row(
                  children: [
                    Icon(Icons.psychology_outlined, color: AppTheme.accent, size: 22),
                    SizedBox(width: 8),
                    Text('Когнитивная терапия сна', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _data!['description'],
                  style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ...items.map((item) => _buildCard(item)),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildCard(dynamic item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.cancel_outlined, color: AppTheme.error, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item['belief'],
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(color: AppTheme.surfaceBorder, height: 1),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check_circle_outline, color: AppTheme.success, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Рациональный контраргумент:',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.success),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item['reframing'],
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
