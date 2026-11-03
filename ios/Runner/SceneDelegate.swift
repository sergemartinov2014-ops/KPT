import Flutter
import UIKit

/// Скрывает содержимое приложения в системном переключателе задач и при
/// уходе в фон, чтобы интимные данные о сне не попадали в снапшот экрана.
class SceneDelegate: FlutterSceneDelegate {
  private var privacyOverlay: UIView?

  override func sceneWillResignActive(_ scene: UIScene) {
    super.sceneWillResignActive(scene)

    guard let windowScene = scene as? UIWindowScene else { return }
    guard let window = windowScene.windows.first(where: { $0.isKeyWindow })
      ?? windowScene.windows.first else { return }
    guard privacyOverlay == nil else { return }

    let overlay = UIView(frame: window.bounds)
    overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    overlay.backgroundColor = UIColor(red: 4.0 / 255.0, green: 6.0 / 255.0, blue: 12.0 / 255.0, alpha: 1.0)

    let title = UILabel()
    title.text = "Сомния"
    title.textColor = UIColor(red: 0.78, green: 0.72, blue: 1.0, alpha: 1.0)
    title.font = UIFont.systemFont(ofSize: 22, weight: .semibold)
    title.translatesAutoresizingMaskIntoConstraints = false

    let subtitle = UILabel()
    subtitle.text = "Данные сна защищены"
    subtitle.textColor = UIColor.white.withAlphaComponent(0.55)
    subtitle.font = UIFont.systemFont(ofSize: 13, weight: .regular)
    subtitle.translatesAutoresizingMaskIntoConstraints = false

    overlay.addSubview(title)
    overlay.addSubview(subtitle)
    NSLayoutConstraint.activate([
      title.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
      title.centerYAnchor.constraint(equalTo: overlay.centerYAnchor, constant: -10),
      subtitle.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
      subtitle.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 8),
    ])

    window.addSubview(overlay)
    privacyOverlay = overlay
  }

  override func sceneDidBecomeActive(_ scene: UIScene) {
    super.sceneDidBecomeActive(scene)
    privacyOverlay?.removeFromSuperview()
    privacyOverlay = nil
  }
}
