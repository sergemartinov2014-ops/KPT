import 'package:provider/provider.dart';
import '../../providers/sleep_provider.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme.dart';
import '../navigation/main_navigation_screen.dart';

class DisclaimerScreen extends StatefulWidget {
  const DisclaimerScreen({super.key});

  @override
  State<DisclaimerScreen> createState() => _DisclaimerScreenState();
}

class _DisclaimerScreenState extends State<DisclaimerScreen> {
  bool _acceptedTerms = false;
  bool _noContraindications = false;
  bool _enableSafeMode = false;

  bool get _canProceed => _acceptedTerms && _noContraindications;

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_accepted_disclaimer', true);
    if (mounted) {
      await context.read<SleepProvider>().toggleSafeModeSRT(_enableSafeMode);
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              const Center(
                child: Text(
                  'СОМНИЯ',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3.0,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              const Center(
                child: Text(
                  'Когнитивно-поведенческая терапия сна (CBT-i)',
                  style: TextStyle(fontSize: 12, color: AppTheme.accent),
                ),
              ),
              const SizedBox(height: 24),

              Expanded(
                child: ListView(
                  children: [
                    // Карточка клинического назначения
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
                              Icon(Icons.verified_user_outlined, color: AppTheme.accent, size: 20),
                              SizedBox(width: 8),
                              Text('Информационное соглашение', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            ],
                          ),
                          SizedBox(height: 10),
                          Text(
                            'Приложение «Сомния» является инструментом психообразования и поведенческой самопомощи при бессоннице. '
                            'Оно создано на основе открытых клинических протоколов CBT-i Стэнфордского университета и Департамента ветеранов США.\n\n'
                            'Приложение НЕ является медицинским изделием, НЕ ставит диагнозов и НЕ заменяет очную консультацию врача-сомнолога или психотерапевта.',
                            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.45),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Предупреждение о противопоказаниях (Стандарт CBT-i)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.warning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, color: AppTheme.warning, size: 20),
                              SizedBox(width: 8),
                              Text('Клинические противопоказания', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.warning)),
                            ],
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Методика ограничения сна (Sleep Restriction) требует особой осторожности. '
                            'Если у вас есть следующие состояния, проконсультируйтесь с врачом перед началом:\n'
                            '• Биполярное аффективное расстройство (риск индукции мании);\n'
                            '• Эпилепсия (депривация сна может спровоцировать приступ);\n'
                            '• Нелеченое обструктивное апноэ сна;\n'
                            '• Профессия, требующая предельной концентрации (водители, операторы машин).',
                            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Чекбоксы согласия
                    CheckboxListTile(
                      value: _acceptedTerms,
                      contentPadding: EdgeInsets.zero,
                      activeColor: AppTheme.accent,
                      title: const Text(
                        'Я понимаю, что приложение носит образовательный характер и не заменяет врача.',
                        style: TextStyle(fontSize: 13),
                      ),
                      onChanged: (v) => setState(() => _acceptedTerms = v ?? false),
                    ),
                    CheckboxListTile(
                      value: _noContraindications,
                      contentPadding: EdgeInsets.zero,
                      activeColor: AppTheme.accent,
                      title: const Text(
                        'У меня нет противопоказаний или я использую приложение под наблюдением специалиста.',
                        style: TextStyle(fontSize: 13),
                      ),
                      onChanged: (v) => setState(() => _noContraindications = v ?? false),
                    ),
                    CheckboxListTile(
                      value: _enableSafeMode,
                      contentPadding: EdgeInsets.zero,
                      activeColor: AppTheme.warning,
                      title: const Text(
                        'Включить щадящий режим (Safe-SRT): ограничение сна не менее 6.5 часов при наличии противопоказаний или дневной сонливости.',
                        style: TextStyle(fontSize: 13, color: AppTheme.warning),
                      ),
                      onChanged: (v) => setState(() => _enableSafeMode = v ?? false),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _canProceed ? _completeOnboarding : null,
                  child: const Text('Принять и начать'),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
