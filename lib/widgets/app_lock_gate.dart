import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_lock_provider.dart';
import '../theme/app_theme.dart';

/// Экран-замок поверх приложения. Показывается, когда включена биометрия
/// и приложение вернулось из фона или было запущено заново.
class AppLockGate extends StatefulWidget {
  final Widget child;

  const AppLockGate({super.key, required this.child});

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> {
  bool _wasLocked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final lock = context.read<AppLockProvider>();
      if (lock.isLocked) lock.unlock();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppLockProvider>(
      builder: (context, lock, child) {
        if (lock.isLocked && !_wasLocked) {
          _wasLocked = true;
          // Замок живёт в home-маршруте, поэтому закрываем все экраны поверх.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            Navigator.of(context).popUntil((route) => route.isFirst);
          });
        } else if (!lock.isLocked) {
          _wasLocked = false;
        }

        if (!lock.isLocked) return child!;

        return Scaffold(
          backgroundColor: AppTheme.background,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.lock_outline_rounded,
                    color: AppTheme.accent,
                    size: 44,
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Сомния',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Данные сна защищены',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 28),
                  if (lock.isAuthenticating)
                    const CircularProgressIndicator()
                  else
                    ElevatedButton.icon(
                      icon: const Icon(Icons.face_rounded, size: 20),
                      label: const Text('Разблокировать'),
                      onPressed: lock.unlock,
                    ),
                ],
              ),
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}
