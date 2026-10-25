import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../../theme/app_theme.dart';
import 'breathing_screen.dart';
import 'ambient_player_screen.dart';

class StimulusControlScreen extends StatefulWidget {
  const StimulusControlScreen({super.key});

  @override
  State<StimulusControlScreen> createState() => _StimulusControlScreenState();
}

class _StimulusControlScreenState extends State<StimulusControlScreen> with SingleTickerProviderStateMixin {
  Timer? _timer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _timerFinished = false;
  final AudioPlayer _chimePlayer = AudioPlayer();
  late DateTime _endTime;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _endTime = DateTime.now().add(const Duration(minutes: 20));
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      final remaining = _endTime.difference(DateTime.now()).inSeconds;
      if (remaining <= 0) {
        timer.cancel();
        setState(() {
          _timerFinished = true;
        });
        try {
          await _chimePlayer.setAsset('assets/audio/ambient/long_bowl.mp3');
          await _chimePlayer.setVolume(0.5);
          await _chimePlayer.play();
        } catch (_) {}
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    _chimePlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070A12), // Максимально мягкий ночной фон
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Стимульный контроль'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        children: [
          const SizedBox(height: 16),
          // Пульсирующая сфера без тикающих секунд (защита от Clock-Watching)
          Center(
            child: ScaleTransition(
              scale: _pulseAnimation,
              child: Container(
                width: 170,
                height: 170,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.surfaceElevated,
                  border: Border.all(
                    color: _timerFinished ? AppTheme.success : AppTheme.accent.withValues(alpha: 0.3),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (_timerFinished ? AppTheme.success : AppTheme.accent).withValues(alpha: 0.15),
                      blurRadius: 30,
                      spreadRadius: 6,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _timerFinished ? Icons.check_circle_outline : Icons.spa_outlined,
                      size: 36,
                      color: _timerFinished ? AppTheme.success : AppTheme.accent,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _timerFinished ? 'Пора вернуться' : 'Вне кровати',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _timerFinished ? AppTheme.success : AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _timerFinished ? 'Если появилась сонливость' : 'Таймер идет в фоне',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Пояснение: почему скрыт секундный таймер (Клинический стандарт)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.surfaceBorder),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.visibility_off_outlined, color: AppTheme.accent, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Не следите за часами (Clock-Watching)',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  'Мы намеренно не показываем тикающие секунды. Посекундный отсчет стимулирует тревогу и держит мозг в тонусе.\n\n'
                  'Вы не должны «высиживать» время: перейдите в другую комнату при слабом свете. Как только почувствуете тяжесть в веках или легкую дремоту — возвращайтесь в кровать.',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.45),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          const Text('Рекомендуемые спокойные занятия:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),

          _buildActivityTile(
            Icons.menu_book,
            'Почитать бумажную книгу',
            'При слабом желтом свете. Без ярких ламп и экранов гаджетов.',
          ),
          _buildActivityTile(
            Icons.air,
            'Дыхательная практика 4-7-8',
            'Замедляет сердцебиение и активирует парасимпатическую систему.',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BreathingScreen())),
          ),
          _buildActivityTile(
            Icons.headphones,
            'Звуки природы или дождя',
            'Включите шум дождя или поющие чаши для разгрузки мыслей.',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AmbientPlayerScreen())),
          ),
          _buildActivityTile(
            Icons.local_cafe_outlined,
            'Сделать глоток теплой воды',
            'Небольшое количество воды комнатной температуры или травяного сбора.',
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildActivityTile(IconData icon, String title, String subtitle, {VoidCallback? onTap}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: AppTheme.accent),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        trailing: onTap != null ? const Icon(Icons.chevron_right, size: 20, color: AppTheme.textMuted) : null,
        onTap: onTap,
      ),
    );
  }
}
