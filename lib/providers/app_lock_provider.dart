import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/native_bridge_service.dart';

/// Блокировка приложения по Face ID / Touch ID / системному паролю.
class AppLockProvider extends ChangeNotifier with WidgetsBindingObserver {
  static const String _prefsKey = 'somnia_app_lock_enabled';

  final SharedPreferences _prefs;
  bool _enabled;
  bool _unlocked;
  bool _authenticating = false;

  AppLockProvider(this._prefs)
      : _enabled = _prefs.getBool(_prefsKey) ?? false,
        _unlocked = !(_prefs.getBool(_prefsKey) ?? false) {
    WidgetsBinding.instance.addObserver(this);
  }

  bool get isEnabled => _enabled;
  bool get isLocked => _enabled && !_unlocked;
  bool get isAuthenticating => _authenticating;

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    await _prefs.setBool(_prefsKey, value);
    if (!value) {
      _unlocked = true;
    } else {
      _unlocked = false;
    }
    notifyListeners();
    if (value) {
      await unlock();
    }
  }

  Future<bool> unlock() async {
    if (!_enabled) {
      _unlocked = true;
      notifyListeners();
      return true;
    }
    if (_authenticating) return false;

    _authenticating = true;
    notifyListeners();

    final success = await NativeBridgeService.authenticate();
    _authenticating = false;
    if (success) _unlocked = true;
    notifyListeners();
    return success;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      if (_enabled && _unlocked) {
        _unlocked = false;
        notifyListeners();
      }
    }
    if (state == AppLifecycleState.resumed && isLocked && !_authenticating) {
      // Показываем системный запрос Face ID сразу при возврате в приложение.
      unlock();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
