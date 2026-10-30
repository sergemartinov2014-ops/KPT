import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Холст с ночной хроматической авророй (Liquid Glass Ambient Canvas)
/// Создаёт мягкие глубокие световые пятна позади полупрозрачных стеклянных панелей.
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

        // 2. Верхнее ночное пятно свечения (Deep Indigo Aurora)
        if (showTopAurora)
          Positioned(
            top: -120,
            right: -80,
            child: IgnorePointer(
              child: Container(
                width: 380,
                height: 380,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      (primaryGlow ?? AppTheme.systemIndigo)
                          .withValues(alpha: 0.16),
                      (primaryGlow ?? AppTheme.systemIndigo)
                          .withValues(alpha: 0.04),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                ),
              ),
            ),
          ),

        // 3. Нижнее ночное пятно свечения (Calm Bio-Teal Aurora)
        if (showBottomAurora)
          Positioned(
            bottom: 60,
            left: -100,
            child: IgnorePointer(
              child: Container(
                width: 360,
                height: 360,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      (secondaryGlow ?? AppTheme.systemTeal)
                          .withValues(alpha: 0.12),
                      (secondaryGlow ?? AppTheme.systemTeal)
                          .withValues(alpha: 0.03),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                ),
              ),
            ),
          ),

        // 4. Контент страницы
        child,
      ],
    );
  }
}
