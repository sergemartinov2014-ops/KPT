import Flutter
import LocalAuthentication
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private static let alarmIdentifiers: [String] = {
    var ids = (1...7).map { "somnia.alarm.weekday.\($0)" }
    ids.append("somnia.alarm.next")
    return ids
  }()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    registerNativeChannel(messenger: engineBridge.applicationRegistrar.messenger())
  }

  // MARK: - Native channel

  private func registerNativeChannel(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "somnia/native", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(FlutterError(code: "unavailable", message: "AppDelegate released", details: nil))
        return
      }

      switch call.method {
      case "authenticate":
        self.authenticate(call: call, result: result)
      case "protectFileSystem":
        self.protectFileSystem(result: result)
      case "scheduleAlarm":
        self.scheduleAlarm(call: call, result: result)
      case "cancelAlarm":
        self.cancelAlarm(result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  // MARK: - Biometric app lock

  private func authenticate(call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    let reason = args?["reason"] as? String ?? "Подтвердите личность, чтобы открыть «Сомнию»"

    let context = LAContext()
    context.localizedCancelTitle = "Отмена"
    var error: NSError?

    guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
      // Face ID/Touch ID/пароль не настроены. Блокировать навсегда нельзя —
      // иначе пользователь не сможет даже отключить замок в настройках.
      result(true)
      return
    }

    context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, _ in
      DispatchQueue.main.async {
        result(success)
      }
    }
  }

  // MARK: - Файловая защита и исключение из iCloud-бэкапа

  private func protectFileSystem(result: @escaping FlutterResult) {
    let fileManager = FileManager.default
    guard let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
      result(false)
      return
    }

    var directory = documents
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    try? directory.setResourceValues(values)

    // Записи сна создаются ночью, когда устройство может быть заблокировано,
    // поэтому используем completeUntilFirstUserAuthentication, а не complete.
    let protection = FileProtectionType.completeUntilFirstUserAuthentication
    let keys: [FileAttributeKey: Any] = [.protectionKey: protection]
    try? fileManager.setAttributes(keys, ofItemAtPath: documents.path)

    if let enumerator = fileManager.enumerator(
      at: documents,
      includingPropertiesForKeys: nil,
      options: [.skipsHiddenFiles]
    ) {
      for case let fileURL as URL in enumerator {
        try? fileManager.setAttributes(keys, ofItemAtPath: fileURL.path)
      }
    }

    result(true)
  }

  // MARK: - Локальные уведомления будильника

  private func scheduleAlarm(call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    let enabled = args["enabled"] as? Bool ?? false
    let center = UNUserNotificationCenter.current()

    center.removePendingNotificationRequests(withIdentifiers: AppDelegate.alarmIdentifiers)

    guard enabled else {
      DispatchQueue.main.async { result(true) }
      return
    }

    let hour = args["hour"] as? Int ?? 7
    let minute = args["minute"] as? Int ?? 0
    let days = args["days"] as? [Int] ?? [1, 2, 3, 4, 5, 6, 7]

    center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
      guard granted else {
        DispatchQueue.main.async { result(false) }
        return
      }

      let content = UNMutableNotificationContent()
      content.title = "Сомния"
      content.body = "Время просыпаться. Откройте приложение, чтобы завершить пробуждение."
      content.sound = .default

      if days.isEmpty {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        center.add(UNNotificationRequest(
          identifier: "somnia.alarm.next",
          content: content,
          trigger: trigger
        ))
      } else {
        for day in days {
          // Dart: 1 = понедельник … 7 = воскресенье.
          // UNCalendarNotificationTrigger: 1 = воскресенье … 7 = суббота.
          let weekday = day == 7 ? 1 : day + 1
          var components = DateComponents()
          components.weekday = weekday
          components.hour = hour
          components.minute = minute
          let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
          center.add(UNNotificationRequest(
            identifier: "somnia.alarm.weekday.\(day)",
            content: content,
            trigger: trigger
          ))
        }
      }

      DispatchQueue.main.async { result(true) }
    }
  }

  private func cancelAlarm(result: @escaping FlutterResult) {
    UNUserNotificationCenter.current()
      .removePendingNotificationRequests(withIdentifiers: AppDelegate.alarmIdentifiers)
    result(true)
  }
}
