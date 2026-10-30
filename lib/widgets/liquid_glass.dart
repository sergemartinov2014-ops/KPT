import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'liquid_glass_modal.dart';
export 'liquid_glass_modal.dart';


/// Базовый мета-материал Liquid Glass (Apple HIG iOS 26 / Glassmorphism)
/// Обеспечивает физическую оптическую глубину, световую фаску, верхний блик и высокую производительность на Web и Mobile.
class LiquidGlass extends StatelessWidget {
  final Widget child;
  final double blur;
  final double radius;
  final Color? surfaceColor;
  final Gradient? borderGradient;
  final Color? borderColor;
  final double borderWidth;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final bool showShine;
  final Color? glowColor;
  final double glowRadius;

  const LiquidGlass({
    super.key,
    required this.child,
    this.blur = 18.0,
    this.radius = 24.0,
    this.surfaceColor,
    this.borderGradient,
    this.borderColor,
    this.borderWidth = 1.1,
    this.padding,
    this.margin,
    this.onTap,
    this.showShine = true,
    this.glowColor,
    this.glowRadius = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    // Оптимальный радиус размытия для Liquid Glass
    final effectiveBlur = blur;

    Widget glassCard = Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: borderGradient ??
            LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.28),
                Colors.white.withValues(alpha: 0.08),
                Colors.white.withValues(alpha: 0.02),
              ],
            ),
        boxShadow: [
          // Мягкая пространственная тень стекла
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 24,
            offset: const Offset(0, 10),
            spreadRadius: -2,
          ),
          // Опциональное мягкое внешнее свечение при активном статусе
          if (glowColor != null && glowRadius > 0)
            BoxShadow(
              color: glowColor!.withValues(alpha: 0.16),
              blurRadius: glowRadius,
              spreadRadius: 0,
            ),
        ],
      ),
      padding: EdgeInsets.all(borderWidth),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius - borderWidth),
        child: Stack(
          children: [
            // 1. Оптический блюр фонового контента
            if (effectiveBlur > 0)
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: effectiveBlur,
                    sigmaY: effectiveBlur,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),

            // 2. Полупрозрачный глубокий стеклянный градиент (Translucent Liquid Obsidian)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      (surfaceColor ?? const Color(0xFF101932))
                          .withValues(alpha: 0.58),
                      (surfaceColor ?? const Color(0xFF060A14))
                          .withValues(alpha: 0.42),
                    ],
                  ),
                ),
              ),
            ),

            // 3. Выразительный оптический скос стекла (Refractive Specular Sheen)
            if (showShine)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.16),
                          Colors.white.withValues(alpha: 0.03),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.40, 1.0],
                      ),
                    ),
                  ),
                ),
              ),

            // 4. Тонкая верхняя световая грань (Specular Top Rim Highlight)
            Positioned(
              top: 0,
              left: radius * 0.35,
              right: radius * 0.35,
              height: 1.0,
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.white.withValues(alpha: 0.32),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // 5. Контент внутри карточки
            Padding(
              padding: padding ?? EdgeInsets.zero,
              child: child,
            ),
          ],
        ),
      ),
    );

    if (onTap != null) {
      return LiquidGlassInteractive(
        onTap: onTap,
        child: glassCard,
      );
    }

    return glassCard;
  }
}

/// Компактная Liquid Glass таблетка (Pill) для тегов, чипов и бейджей
class LiquidGlassPill extends StatelessWidget {
  final Widget child;
  final Color? color;
  final Color? borderColor;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const LiquidGlassPill({
    super.key,
    required this.child,
    this.color,
    this.borderColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LiquidGlass(
      radius: 30,
      blur: 10,
      padding: padding,
      surfaceColor: color ?? AppTheme.glassSurfaceElevated,
      borderColor: borderColor ?? Colors.white.withValues(alpha: 0.25),
      borderWidth: 1.0,
      onTap: onTap,
      child: child,
    );
  }
}
