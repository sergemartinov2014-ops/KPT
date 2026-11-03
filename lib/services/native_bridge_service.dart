import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Мост к нативному iOS-слою (`ios/Runner/AppDelegate.swift`).
///
/// На других платформах вызовы безопасно превращаются в no-op, чтобы не
/// ломать Android/Web-сборки.
class NativeBridgeService {
  static const MethodChannel _channel = MethodChannel('somnia/native');

  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// Face ID / Touch ID / системный пароль.
  ///
  /// Возвращает `true`, если устройство не поддерживает биометрию: блокировка
  /// не должна запирать пользователя в приложении навсегда.
  static Future<bool> authenticate({
    String reason = 'Подтвердите личность, чтобы открыть «Сомнию»',
  }) async {
    if (!isSupported) return true;
    try {
      return await _channel.invokeMethod<bool>(
            'authenticate',
            {'reason': reason},
          ) ??
          false;
    } on MissingPluginException {
      // Нативный канал ещё не зарегистрирован — не разблокируем молча.
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// Включает FileProtection и исключает документы из iCloud-бэкапа.
  static Future<void> protectFileSystem() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('protectFileSystem');
    } catch (e) {
      debugPrint('[NativeBridge] protectFileSystem failed: $e');
    }
  }

  /// Планирует еженедельные локальные уведомления будильника.
  static Future<bool> scheduleAlarm({
    required bool enabled,
    required int hour,
    required int minute,
    required List<int> days,
  }) async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('scheduleAlarm', {
            'enabled': enabled,
            'hour': hour,
            'minute': minute,
            'days': days,
          }) ??
          false;
    } catch (e) {
      debugPrint('[NativeBridge] scheduleAlarm failed: $e');
      return false;
    }
  }

  static Future<void> cancelAlarm() async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('cancelAlarm');
    } catch (e) {
      debugPrint('[NativeBridge] cancelAlarm failed: $e');
    }
  }
}
