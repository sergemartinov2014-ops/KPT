import 'package:flutter/material.dart';
import '../home/home_screen.dart';
import '../diary/diary_screen.dart';
import '../tools/tools_screen.dart';
import '../learn/learn_screen.dart';
import '../../theme/app_theme.dart';
import '../../widgets/liquid_glass.dart';

/// Главный навигационный экран с плавающей капсулой Liquid Glass (Apple HIG iOS 26)
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    DiaryScreen(),
    ToolsScreen(),
    LearnScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, // Позволяет контенту плавно прокручиваться под стеклом
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
          child: LiquidGlass(
            radius: 36,
            blur: 28,
            surfaceColor: AppTheme.glassUltraThin,
            borderGradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.28),
                Colors.white.withValues(alpha: 0.08),
                Colors.white.withValues(alpha: 0.02),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  0,
                  Icons.nights_stay_outlined,
                  Icons.nights_stay_rounded,
                  'Режим',
                ),
                _buildNavItem(
                  1,
                  Icons.insights_outlined,
                  Icons.insights_rounded,
                  'Дневник',
                ),
                _buildNavItem(
                  2,
                  Icons.blur_circular_outlined,
                  Icons.blur_circular_rounded,
                  'Практики',
                ),
                _buildNavItem(
                  3,
                  Icons.menu_book_outlined,
                  Icons.menu_book_rounded,
                  'Теория',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData icon,
    IconData activeIcon,
    String label,
  ) {
    final bool isSelected = _currentIndex == index;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _currentIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          height: 48, // 48pt tap target (Apple HIG requirement >= 44pt)
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.accent.withValues(alpha: 0.16)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected
                  ? AppTheme.accent.withValues(alpha: 0.35)
                  : Colors.transparent,
              width: 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isSelected ? activeIcon : icon,
                size: 20,
                color: isSelected ? AppTheme.accent : AppTheme.textMuted,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? AppTheme.textPrimary : AppTheme.textMuted,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
