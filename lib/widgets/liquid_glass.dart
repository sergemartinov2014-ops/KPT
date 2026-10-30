import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'liquid_glass_modal.dart';
export 'liquid_glass_modal.dart';

/// Вариант материала Liquid Glass (iOS 26 Liquid Glass Design System)
enum LiquidGlassVariant {
  /// Стандартный глубокий обсидиановый материал
  regular,

  /// Акцентный материал с тинтом и деликатным свечением
  prominent,

  /// Ультратонкий материал для навигационных панелей и плавающих доков
  ultraThin,
}

/// Геометрическая форма стеклянного элемента
enum LiquidGlassShape {
  /// Закругленный прямоугольник (карточки, модалки, диалоги)
  roundedRect,

  /// Капсула / таблетка (Pill, бейджи, кнопки, навигационная панель)
  capsule,

  /// Идеальный круг (плавающие FAB, иконки)
  circle,
}

/// Стиль стеклянной кнопки (Apple HIG iOS 26 Button Styles)
enum LiquidGlassButtonStyle {
  /// Стандартная прозрачно-стеклянная кнопка
  glass,

  /// Акцентная кнопка с цветным стеклянным тинтом
  glassProminent,
}

/// Базовый мета-материал Liquid Glass (Apple HIG iOS 26 / ECC Liquid Glass Design System)
/// Динамический стеклянный материал с оптическим размытием фона, преломлением окружающего света,
/// световой фаской (Specular Edge) и тактильным откликом при нажатии.
class LiquidGlass extends StatelessWidget {
  final Widget child;
  final double blur;
  final double radius;
  final LiquidGlassVariant variant;
  final LiquidGlassShape shape;
  final Color? tint;
  final Color? surfaceColor;
  final Gradient? borderGradient;
  final Color? borderColor;
  final double borderWidth;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final bool isInteractive;
  final bool showShine;
  final Color? glowColor;
  final double glowRadius;

  const LiquidGlass({
    super.key,
    required this.child,
    this.blur = 20.0,
    this.radius = 24.0,
    this.variant = LiquidGlassVariant.regular,
    this.shape = LiquidGlassShape.roundedRect,
    this.tint,
    this.surfaceColor,
    this.borderGradient,
    this.borderColor,
    this.borderWidth = 1.0,
    this.padding,
    this.margin,
    this.onTap,
    this.isInteractive = false,
    this.showShine = true,
    this.glowColor,
    this.glowRadius = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBlur = blur;

    // Вычисление формы и скругления
    BorderRadius effectiveBorderRadius;
    BoxShape boxShape = BoxShape.rectangle;

    switch (shape) {
      case LiquidGlassShape.capsule:
        effectiveBorderRadius = BorderRadius.circular(100.0);
        break;
      case LiquidGlassShape.circle:
        boxShape = BoxShape.circle;
        effectiveBorderRadius = BorderRadius.zero;
        break;
      case LiquidGlassShape.roundedRect:
        effectiveBorderRadius = BorderRadius.circular(radius);
        break;
    }

    // Вычисление базовых цветов в зависимости от варианта и тинта
    Color topColor;
    Color bottomColor;

    switch (variant) {
      case LiquidGlassVariant.prominent:
        final activeTint = tint ?? glowColor ?? AppTheme.systemIndigo;
        topColor = Color.alphaBlend(
          activeTint.withValues(alpha: 0.22),
          surfaceColor ?? const Color(0xFF090D1C),
        ).withValues(alpha: 0.90);
        bottomColor = Color.alphaBlend(
          activeTint.withValues(alpha: 0.10),
          surfaceColor ?? const Color(0xFF04060E),
        ).withValues(alpha: 0.82);
        break;
      case LiquidGlassVariant.ultraThin:
        topColor = (surfaceColor ?? const Color(0xFF070B16)).withValues(alpha: 0.72);
        bottomColor = (surfaceColor ?? const Color(0xFF020409)).withValues(alpha: 0.62);
        break;
      case LiquidGlassVariant.regular:
        if (tint != null) {
          topColor = Color.alphaBlend(
            tint!.withValues(alpha: 0.12),
            surfaceColor ?? const Color(0xFF070B16),
          ).withValues(alpha: 0.88);
          bottomColor = Color.alphaBlend(
            tint!.withValues(alpha: 0.05),
            surfaceColor ?? const Color(0xFF020409),
          ).withValues(alpha: 0.78);
        } else {
          topColor = (surfaceColor ?? const Color(0xFF070B16)).withValues(alpha: 0.88);
          bottomColor = (surfaceColor ?? const Color(0xFF020409)).withValues(alpha: 0.78);
        }
        break;
    }

    // Тонкая оптическая световая грань (Specular Rim)
    final effectiveBorderGradient = borderGradient ??
        LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            tint != null
                ? tint!.withValues(alpha: 0.22)
                : Colors.white.withValues(alpha: 0.10),
            Colors.white.withValues(alpha: 0.03),
            Colors.white.withValues(alpha: 0.005),
          ],
        );

    final effectiveGlowColor = glowColor ?? (variant == LiquidGlassVariant.prominent ? tint : null);

    Widget glassCard = Container(
      margin: margin,
      decoration: BoxDecoration(
        shape: boxShape,
        borderRadius: boxShape == BoxShape.rectangle ? effectiveBorderRadius : null,
        gradient: borderColor == null ? effectiveBorderGradient : null,
        color: borderColor != null ? Colors.transparent : null,
        border: borderColor != null ? Border.all(color: borderColor!, width: borderWidth) : null,
        boxShadow: [
          // Глубокая пространственная тень стекла
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.60),
            blurRadius: 28,
            offset: const Offset(0, 10),
            spreadRadius: -2,
          ),
          // Опциональное мягкое внешнее свечение при активном статусе / prominent
          if (effectiveGlowColor != null && (glowRadius > 0 || variant == LiquidGlassVariant.prominent))
            BoxShadow(
              color: effectiveGlowColor.withValues(alpha: 0.16),
              blurRadius: glowRadius > 0 ? glowRadius : 20,
              spreadRadius: 0,
            ),
        ],
      ),
      padding: borderColor == null ? EdgeInsets.all(borderWidth) : EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: boxShape == BoxShape.rectangle
            ? (effectiveBorderRadius - BorderRadius.circular(borderWidth))
            : BorderRadius.zero,
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

            // 2. Полупрозрачный глубокий стеклянный градиент (Deep Dark Obsidian Glass)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [topColor, bottomColor],
                  ),
                ),
              ),
            ),

            // 3. Выразительный оптический скос стекла (Subtle Specular Sheen)
            if (showShine)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.035),
                          Colors.white.withValues(alpha: 0.008),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.35, 0.85],
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
                        (tint != null ? tint!.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.14)),
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

    if (onTap != null || isInteractive) {
      return LiquidGlassInteractive(
        onTap: onTap,
        child: glassCard,
      );
    }

    return glassCard;
  }
}

/// Контейнер для группы стеклянных элементов с согласованным интервалом (Apple HIG GlassEffectContainer)
/// Управляет пространственной группировкой стеклянных элементов без перегрузки визуального слоя.
class LiquidGlassContainer extends StatelessWidget {
  final Widget child;
  final double spacing;

  const LiquidGlassContainer({
    super.key,
    required this.child,
    this.spacing = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    return child;
  }
}

/// Кнопка в стиле Liquid Glass (Apple HIG iOS 26 Button Styles: .buttonStyle(.glass) / .glassProminent)
class LiquidGlassButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final LiquidGlassButtonStyle style;
  final Color? tint;
  final EdgeInsetsGeometry padding;
  final double radius;

  const LiquidGlassButton({
    super.key,
    required this.child,
    this.onPressed,
    this.style = LiquidGlassButtonStyle.glass,
    this.tint,
    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
    this.radius = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveTint = tint ?? (style == LiquidGlassButtonStyle.glassProminent ? AppTheme.systemIndigo : null);

    return LiquidGlass(
      shape: LiquidGlassShape.capsule,
      variant: style == LiquidGlassButtonStyle.glassProminent
          ? LiquidGlassVariant.prominent
          : LiquidGlassVariant.regular,
      tint: effectiveTint,
      radius: radius,
      padding: padding,
      onTap: onPressed,
      child: DefaultTextStyle(
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: style == LiquidGlassButtonStyle.glassProminent
              ? Colors.white
              : AppTheme.textPrimary,
          letterSpacing: -0.2,
        ),
        child: Center(child: child),
      ),
    );
  }
}

/// Компактная Liquid Glass таблетка (Pill) для тегов, чипов и бейджей (.glassEffect(.capsule))
class LiquidGlassPill extends StatelessWidget {
  final Widget child;
  final Color? color;
  final Color? tint;
  final Color? borderColor;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const LiquidGlassPill({
    super.key,
    required this.child,
    this.color,
    this.tint,
    this.borderColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LiquidGlass(
      shape: LiquidGlassShape.capsule,
      radius: 30,
      blur: 12,
      padding: padding,
      tint: tint,
      surfaceColor: color ?? AppTheme.glassSurface,
      borderColor: borderColor,
      borderWidth: 1.0,
      onTap: onTap,
      child: child,
    );
  }
}
