import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/sleep_provider.dart';
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
    if (!mounted) return;
    await context.read<SleepProvider>().toggleSafeModeSRT(_enableSafeMode);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppTheme.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'СОМНИЯ • ПРОТОКОЛ CBT-I',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.0,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Клиническая безопасность и информированное согласие',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.4,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 20),

              Expanded(
                child: ListView(
                  children: [
                    // 1. Назначение протокола
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: AppTheme.bentoBox(),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('НАУЧНАЯ БАЗА И СТАТУС', style: AppTheme.sectionLabel),
                          SizedBox(height: 8),
                          Text(
                            'Приложение реализует поведенческий протокол терапии инсомнии (CBT-i Coach, Stanford / VA). Все алгоритмы работают полностью автономно на вашем устройстве.\n\n'
                            'Приложение не является медицинским изделием, не устанавливает диагнозов и не заменяет очную консультацию врача-сомнолога.',
                            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.5),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 2. Ограничения для компрессии сна
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: AppTheme.bentoBox(
                        color: AppTheme.warning.withValues(alpha: 0.05),
                        borderColor: AppTheme.warning.withValues(alpha: 0.28),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.shield_moon_outlined, color: AppTheme.warning, size: 16),
                              SizedBox(width: 6),
                              Text(
                                'ОГРАНИЧЕНИЯ МЕТОДА СЖАТИЯ СНА (SRT)',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.1,
                                  color: AppTheme.warning,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Интенсивное сокращение времени в постели противопоказано без врачебного контроля при следующих состояниях:\n'
                            '• Эпилепсия и судорожная готовность;\n'
                            '• Биполярное аффективное расстройство;\n'
                            '• Нелеченое обструктивное апноэ сна;\n'
                            '• Работа, связанная с вождением транспорта.',
                            style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.5),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    const Text('ПОДТВЕРЖДЕНИЕ ПАРАМЕТРОВ', style: AppTheme.sectionLabel),
                    const SizedBox(height: 10),

                    _buildConsentTile(
                      value: _acceptedTerms,
                      title: 'Образовательный статус',
                      subtitle: 'Я понимаю, что приложение является дневником самопомощи и не заменяет врача.',
                      activeColor: AppTheme.accent,
                      onTap: () => setState(() => _acceptedTerms = !_acceptedTerms),
                    ),
                    const SizedBox(height: 10),
                    _buildConsentTile(
                      value: _noContraindications,
                      title: 'Скрининг противопоказаний',
                      subtitle: 'У меня нет перечисленных выше состояний или я работаю со специалистом.',
                      activeColor: AppTheme.accent,
                      onTap: () => setState(() => _noContraindications = !_noContraindications),
                    ),
                    const SizedBox(height: 10),
                    _buildConsentTile(
                      value: _enableSafeMode,
                      title: 'Щадящий режим титрации (Safe-SRT)',
                      subtitle: 'Не сокращать окно сна менее 6.5 часов (рекомендуется при высокой дневной сонливости).',
                      activeColor: AppTheme.warning,
                      isOptionalBadge: true,
                      onTap: () => setState(() => _enableSafeMode = !_enableSafeMode),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _canProceed ? _completeOnboarding : null,
                  child: const Text('Активировать протокол сна'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConsentTile({
    required bool value,
    required String title,
    required String subtitle,
    required Color activeColor,
    required VoidCallback onTap,
    bool isOptionalBadge = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: AppTheme.bentoBox(
          color: value ? AppTheme.surfaceElevated : AppTheme.surface,
          borderColor: value ? activeColor.withValues(alpha: 0.5) : AppTheme.surfaceBorder,
          radius: 16,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 22,
              height: 22,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                color: value ? activeColor : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: value ? activeColor : AppTheme.textMuted,
                  width: 1.5,
                ),
              ),
              child: value
                  ? const Icon(Icons.check_rounded, size: 15, color: AppTheme.background)
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      if (isOptionalBadge)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.warning.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'ОПЦИЯ',
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppTheme.warning),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.35),
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
