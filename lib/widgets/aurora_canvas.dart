import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Холст с ночной хроматической авророй (Liquid Glass Ambient Canvas)
/// Создаёт глубокие световые пятна позади полупрозрачных стеклянных панелей,
/// благодаря которым эффект Liquid Glass виден отчетливо и физично.
class AuroraCanvas extends StatelessWidget {
  final Widget child;
  final bool showTopAurora;
  final bool showBottomAurora;
  final Color? primaryGlow;
  final Color? secondaryGlow;

  const AuroraCanvas({
    super.key,
    required this.child,
    this.showTopAurora = true,
    this.showBottomAurora = true,
    this.primaryGlow,
    this.secondaryGlow,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 1. Глубокий ночной фон
        Positioned.fill(
          child: Container(
            color: AppTheme.background,
          ),
        ),

        // 2. Верхнее ночное пятно свечения (Vibrant Indigo-Violet Aurora)
        if (showTopAurora)
          Positioned(
            top: -120,
            right: -80,
            child: IgnorePointer(
              child: Container(
                width: 480,
                height: 480,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      (primaryGlow ?? const Color(0xFF6366F1))
                          .withValues(alpha: 0.48),
                      (primaryGlow ?? const Color(0xFF4338CA))
                          .withValues(alpha: 0.22),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.45, 1.0],
                  ),
                ),
              ),
            ),
          ),

        // 3. Нижнее ночное пятно свечения (Calm Bio-Teal / Cyan Aurora)
        if (showBottomAurora)
          Positioned(
            bottom: 20,
            left: -100,
            child: IgnorePointer(
              child: Container(
                width: 440,
                height: 440,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      (secondaryGlow ?? const Color(0xFF0EA5E9))
                          .withValues(alpha: 0.38),
                      (secondaryGlow ?? const Color(0xFF0D9488))
                          .withValues(alpha: 0.16),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.50, 1.0],
                  ),
                ),
              ),
            ),
          ),

        // 4. Тонкое акцентное пятно по центру (Moonlight Mist / Purple Glow)
        Positioned(
          top: 320,
          right: -100,
          child: IgnorePointer(
            child: Container(
              width: 380,
              height: 380,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFA855F7).withValues(alpha: 0.30),
                    const Color(0xFF818CF8).withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),
        ),

        // 5. Контент страницы
        child,
      ],
    );
  }
}
