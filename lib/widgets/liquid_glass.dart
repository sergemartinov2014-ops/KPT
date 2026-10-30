import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Базовый мета-материал Liquid Glass (Apple HIG iOS 26 / macOS Tahoe)
/// Обеспечивает физическую оптическую рефракцию, двойную световую фаску и гладкие скругления.
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
    this.blur = 20.0,
    this.radius = 24.0,
    this.surfaceColor,
    this.borderGradient,
    this.borderColor,
    this.borderWidth = 1.0,
    this.padding,
    this.margin,
    this.onTap,
    this.showShine = true,
    this.glowColor,
    this.glowRadius = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: surfaceColor ?? AppTheme.glassSurface,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Stack(
        children: [
          // Внутренний градиент естественного скольжения света (Specular Sheen)
          if (showShine)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radius),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.07),
                        Colors.white.withValues(alpha: 0.01),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.35, 1.0],
                    ),
                  ),
                ),
              ),
            ),
          child,
        ],
      ),
    );

    // Оптический блюр (BackdropFilter)
    content = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: content,
      ),
    );

    // Световая фаска (Border Gradient / Specular Rim)
    content = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: borderGradient ??
            LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.22),
                Colors.white.withValues(alpha: 0.08),
                Colors.white.withValues(alpha: 0.02),
              ],
              stops: const [0.0, 0.45, 1.0],
            ),
      ),
      padding: EdgeInsets.all(borderWidth),
      child: content,
    );

    // Внешнее свечение при активном статусе (Glow Aura)
    if (glowColor != null && glowRadius > 0) {
      content = Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            BoxShadow(
              color: glowColor!.withValues(alpha: 0.25),
              blurRadius: glowRadius,
              spreadRadius: 1,
            ),
          ],
        ),
        child: content,
      );
    }

    if (margin != null) {
      content = Padding(padding: margin!, child: content);
    }

    if (onTap != null) {
      content = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: content,
      );
    }

    return content;
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
      blur: 14,
      padding: padding,
      surfaceColor: color ?? AppTheme.glassSurfaceElevated,
      borderColor: borderColor,
      onTap: onTap,
      child: child,
    );
  }
}
