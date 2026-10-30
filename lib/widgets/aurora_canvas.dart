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

        // 2. Верхнее ночное пятно свечения (Calm Nocturnal Indigo Aurora)
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
                      (primaryGlow ?? const Color(0xFF4338CA))
                          .withValues(alpha: 0.18),
                      (primaryGlow ?? const Color(0xFF312E81))
                          .withValues(alpha: 0.06),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.50, 1.0],
                  ),
                ),
              ),
            ),
          ),

        // 3. Нижнее ночное пятно свечения (Deep Marine Teal Aurora)
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
                      (secondaryGlow ?? const Color(0xFF0369A1))
                          .withValues(alpha: 0.14),
                      (secondaryGlow ?? const Color(0xFF075985))
                          .withValues(alpha: 0.04),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.50, 1.0],
                  ),
                ),
              ),
            ),
          ),

        // 4. Тонкое акцентное пятно по центру (Deep Midnight Purple Mist)
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
                    const Color(0xFF581C87).withValues(alpha: 0.10),
                    const Color(0xFF3B0764).withValues(alpha: 0.03),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.50, 1.0],
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
