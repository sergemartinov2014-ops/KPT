import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/sleep_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/liquid_glass.dart';
import '../../widgets/aurora_canvas.dart';
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
      body: AuroraCanvas(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Image.asset(
                      'assets/icon/app_icon.png',
                      width: 20,
                      height: 20,
                      errorBuilder: (_, __, ___) => Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppTheme.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
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
                const SizedBox(height: 14),
                const Text(
                  'Клиническая безопасность и протокол сна',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.4,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 16),

                Expanded(
                  child: ListView(
                    children: [
                      // 1. Назначение протокола
                      const LiquidGlass(
                        radius: 20,
                        blur: 20,
                        padding: EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Научная база и статус', style: AppTheme.sectionLabel),
                            SizedBox(height: 8),
                            Text(
                              'Приложение реализует поведенческий протокол терапии инсомнии (CBT-i Coach, Stanford / VA) и функции трекинга сна из Moonap. Все алгоритмы работают полностью автономно на вашем устройстве.\n\n'
                              'Приложение не является медицинским изделием, не устанавливает диагнозов и не заменяет очную консультацию врача-сомнолога.',
                              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.5),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 2. Ограничения для компрессии сна
                      LiquidGlass(
                        radius: 20,
                        blur: 20,
                        surfaceColor: AppTheme.warning.withValues(alpha: 0.12),
                        glowColor: AppTheme.warning,
                        glowRadius: 10,
                        padding: const EdgeInsets.all(18),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.shield_moon_outlined, color: AppTheme.warning, size: 16),
                                SizedBox(width: 6),
                                Text(
                                  'Ограничения метода сжатия сна (SRT)',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -0.15,
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
                      const SizedBox(height: 18),

                      const Text('Подтверждение параметров', style: AppTheme.sectionLabel),
                      const SizedBox(height: 10),

                      _buildConsentTile(
                        value: _acceptedTerms,
                        title: 'Образовательный статус',
                        subtitle: 'Я понимаю, что приложение является дневником самопомощи и не заменяет врача.',
                        activeColor: AppTheme.systemIndigo,
                        onTap: () => setState(() => _acceptedTerms = !_acceptedTerms),
                      ),
                      const SizedBox(height: 10),
                      _buildConsentTile(
                        value: _noContraindications,
                        title: 'Скрининг противопоказаний',
                        subtitle: 'У меня нет перечисленных выше состояний или я работаю со специалистом.',
                        activeColor: AppTheme.systemIndigo,
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
                LiquidGlassInteractive(
                  onTap: _canProceed ? _completeOnboarding : () {},
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      gradient: _canProceed
                          ? const LinearGradient(
                              colors: [AppTheme.systemIndigo, Color(0xFF4F46E5)],
                            )
                          : null,
                      color: _canProceed ? null : Colors.white.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: _canProceed
                          ? [
                              BoxShadow(
                                color: AppTheme.systemIndigo.withValues(alpha: 0.40),
                                blurRadius: 20,
                                offset: const Offset(0, 6),
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        'Активировать протокол сна',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: _canProceed ? Colors.white : AppTheme.textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
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
    return LiquidGlassInteractive(
      onTap: onTap,
      child: LiquidGlass(
        radius: 18,
        blur: 16,
        surfaceColor: value ? activeColor.withValues(alpha: 0.15) : AppTheme.glassSurface,
        glowColor: value ? activeColor : null,
        glowRadius: value ? 8 : 0,
        padding: const EdgeInsets.all(14),
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
                  ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
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
