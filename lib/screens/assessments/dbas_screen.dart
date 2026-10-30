import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import '../../widgets/aurora_canvas.dart';
import '../../widgets/liquid_glass.dart';

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
      body: AuroraCanvas(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
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
                    const Text('ШКАЛА УБЕЖДЕНИЙ DBAS • КПТ-И', style: AppTheme.sectionLabel),
                    const SizedBox(height: 8),
                    Text(
                      _data!['description'],
                      style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            ...List.generate(
              items.length,
              (index) => FadeSlideEntrance(
                delayMs: 40 * index,
                child: _buildCognitiveCard(items[index]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCognitiveCard(dynamic item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: LiquidGlass(
        radius: 22,
        blur: 16,
        surfaceColor: AppTheme.glassSurface,
        padding: const EdgeInsets.all(18),
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
                  'Катастрофическая мысль',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, letterSpacing: -0.1, color: AppTheme.warning),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              item['belief'],
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.success.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
                border: Border(
                  left: const BorderSide(color: AppTheme.success, width: 3.5),
                  top: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
                  right: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
                  bottom: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Факт доказательной сомнологии',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, letterSpacing: -0.1, color: AppTheme.success),
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
      ),
    );
  }
}
