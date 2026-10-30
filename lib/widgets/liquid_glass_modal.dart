import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import 'liquid_glass.dart';

/// Всплывающее модальное окно (Bottom Sheet) в дизайне Apple Liquid Glass (iOS 26 / HIG).
/// Обеспечивает оптическое преломление фонового экрана, световую фаску,
/// динамический граббер и адаптивное центрирование на широких экранах ПК.
class LiquidGlassSheet extends StatelessWidget {
  final Widget child;
  final double radius;
  final double blur;
  final bool showGrabber;
  final EdgeInsetsGeometry? padding;

  const LiquidGlassSheet({
    super.key,
    required this.child,
    this.radius = 32.0,
    this.blur = 20.0,
    this.showGrabber = true,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBlur = kIsWeb ? (blur > 8 ? 8.0 : blur) : blur;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 540;

    Widget sheetBody = Container(
      decoration: BoxDecoration(
        borderRadius: isDesktop
            ? BorderRadius.circular(radius)
            : BorderRadius.vertical(top: Radius.circular(radius)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 28,
            offset: const Offset(0, -6),
            spreadRadius: -2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: isDesktop
            ? BorderRadius.circular(radius)
            : BorderRadius.vertical(top: Radius.circular(radius)),
        child: Stack(
          children: [
            // 1. Оптический блюр фонового экрана
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

            // 2. Полупрозрачный глубокий стеклянный градиент для читаемости
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF161F30).withValues(alpha: 0.78),
                      const Color(0xFF0C1322).withValues(alpha: 0.88),
                    ],
                  ),
                ),
              ),
            ),

            // 3. Верхний световой скос (Specular Sheen)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.20),
                        Colors.white.withValues(alpha: 0.03),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.18, 1.0],
                    ),
                  ),
                ),
              ),
            ),

            // 4. Световая контурная грань (Specular Rim Border)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: isDesktop
                        ? BorderRadius.circular(radius)
                        : BorderRadius.vertical(top: Radius.circular(radius)),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.24),
                      width: 1.1,
                    ),
                  ),
                ),
              ),
            ),

            // 5. Контент шторки с граббером
            SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (showGrabber) ...[
                    Center(
                      child: Container(
                        width: 38,
                        height: 4.5,
                        margin: const EdgeInsets.only(top: 12, bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                  Flexible(
                    child: Padding(
                      padding: padding ?? const EdgeInsets.fromLTRB(22, 8, 22, 28),
                      child: child,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    // Центрирование шторки внутри фрейма на ПК (max 460px)
    if (isDesktop) {
      return Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 460),
          margin: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
          child: sheetBody,
        ),
      );
    }

    return sheetBody;
  }
}

/// Показывает модальное окно в стиле Apple Liquid Glass
Future<T?> showLiquidGlassBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  bool showGrabber = true,
  EdgeInsetsGeometry? padding,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.60),
    isScrollControlled: isScrollControlled,
    elevation: 0,
    builder: (ctx) => LiquidGlassSheet(
      showGrabber: showGrabber,
      padding: padding,
      child: builder(ctx),
    ),
  );
}

/// Всплывающее диалоговое окно в стиле Apple Liquid Glass (iOS 26)
class LiquidGlassDialog extends StatelessWidget {
  final Widget? title;
  final Widget? content;
  final List<Widget>? actions;
  final IconData? icon;
  final Color? iconColor;
  final double maxWidth;

  const LiquidGlassDialog({
    super.key,
    this.title,
    this.content,
    this.actions,
    this.icon,
    this.iconColor,
    this.maxWidth = 380,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        margin: const EdgeInsets.symmetric(horizontal: 24),
        child: LiquidGlass(
          radius: 28,
          blur: 24,
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          surfaceColor: const Color(0xFF141C2E),
          borderColor: Colors.white.withValues(alpha: 0.22),
          borderWidth: 1.2,
          child: Material(
            color: Colors.transparent,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (icon != null) ...[
                  Center(
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: (iconColor ?? AppTheme.systemIndigo).withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: (iconColor ?? AppTheme.systemIndigo).withValues(alpha: 0.35),
                        ),
                      ),
                      child: Icon(
                        icon,
                        color: iconColor ?? AppTheme.systemIndigo,
                        size: 26,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (title != null) ...[
                  DefaultTextStyle(
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.3,
                    ),
                    textAlign: icon != null ? TextAlign.center : TextAlign.start,
                    child: title!,
                  ),
                  const SizedBox(height: 10),
                ],
                if (content != null) ...[
                  DefaultTextStyle(
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: AppTheme.textSecondary,
                      height: 1.45,
                    ),
                    textAlign: icon != null ? TextAlign.center : TextAlign.start,
                    child: content!,
                  ),
                  const SizedBox(height: 24),
                ],
                if (actions != null && actions!.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: actions!,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Показывает Liquid Glass диалог с плавной анимацией масштабирования и затухания (Apple Spring Physics)
Future<T?> showLiquidGlassDialog<T>({
  required BuildContext context,
  required Widget Function(BuildContext) builder,
  bool barrierDismissible = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.black.withValues(alpha: 0.65),
    transitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (ctx, anim, secAnim) => builder(ctx),
    transitionBuilder: (ctx, anim, secAnim, child) {
      final curved = CurvedAnimation(
        parent: anim,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeInCubic,
      );
      return ScaleTransition(
        scale: Tween<double>(begin: 0.88, end: 1.0).animate(curved),
        child: FadeTransition(
          opacity: anim,
          child: child,
        ),
      );
    },
  );
}

/// Интерактивный виджет с тактильной отдачей и физической пружиной (Spring Scale Bounce)
class LiquidGlassInteractive extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;
  final HitTestBehavior behavior;

  const LiquidGlassInteractive({
    super.key,
    required this.child,
    this.onTap,
    this.pressedScale = 0.965,
    this.behavior = HitTestBehavior.opaque,
  });

  @override
  State<LiquidGlassInteractive> createState() => _LiquidGlassInteractiveState();
}

class _LiquidGlassInteractiveState extends State<LiquidGlassInteractive>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 110),
      reverseDuration: const Duration(milliseconds: 220),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.pressedScale,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeOutBack,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    if (widget.onTap != null) {
      _controller.forward();
    }
  }

  void _onTapUp(TapUpDetails _) {
    if (widget.onTap != null) {
      _controller.reverse();
    }
  }

  void _onTapCancel() {
    if (widget.onTap != null) {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onTap == null) {
      return widget.child;
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: widget.behavior,
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        onTap: () {
          HapticFeedback.lightImpact();
          widget.onTap?.call();
        },
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            final hoverScale = _isHovered && !_controller.isAnimating && _controller.value == 0
                ? 1.008
                : 1.0;
            return Transform.scale(
              scale: _scaleAnimation.value * hoverScale,
              child: child,
            );
          },
          child: widget.child,
        ),
      ),
    );
  }
}

/// Анимация появления карточек с мягким смещением вверх и затуханием (Staggered Fade-Slide)
class FadeSlideEntrance extends StatefulWidget {
  final Widget child;
  final int delayMs;
  final double offsetY;
  final Duration duration;

  const FadeSlideEntrance({
    super.key,
    required this.child,
    this.delayMs = 0,
    this.offsetY = 16.0,
    this.duration = const Duration(milliseconds: 360),
  });

  @override
  State<FadeSlideEntrance> createState() => _FadeSlideEntranceState();
}

class _FadeSlideEntranceState extends State<FadeSlideEntrance>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    final curved = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(curved);
    _slideAnim = Tween<Offset>(
      begin: Offset(0, widget.offsetY),
      end: Offset.zero,
    ).animate(curved);

    if (widget.delayMs > 0) {
      Future.delayed(Duration(milliseconds: widget.delayMs), () {
        if (mounted) _animController.forward();
      });
    } else {
      _animController.forward();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnim.value,
          child: Transform.translate(
            offset: _slideAnim.value,
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
