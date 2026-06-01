import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  // Mirrors the Android FLAG_SECURE behaviour: when `secureScreenEnabled`
  // is true and the app loses focus, a privacy overlay covers the key
  // window so sensitive screens (recovery phrase, private key export,
  // passcode entry) never appear in the iOS app-switcher snapshot.
  private var secureScreenEnabled = false
  private var privacyOverlay: UIView?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleWillResignActive),
      name: UIApplication.willResignActiveNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleDidBecomeActive),
      name: UIApplication.didBecomeActiveNotification,
      object: nil
    )
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "SecureScreen")!
    let channel = FlutterMethodChannel(
      name: "solfare/secure_screen",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "enable":
        self?.secureScreenEnabled = true
        result(nil)
      case "disable":
        self?.secureScreenEnabled = false
        // If the user disables protection while the overlay is still up
        // (mid-transition back from background), drop it immediately.
        DispatchQueue.main.async { self?.hidePrivacyOverlay() }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  @objc private func handleWillResignActive() {
    guard secureScreenEnabled else { return }
    showPrivacyOverlay()
  }

  @objc private func handleDidBecomeActive() {
    hidePrivacyOverlay()
  }

  private func showPrivacyOverlay() {
    guard privacyOverlay == nil, let window = keyWindow() else { return }
    let overlay = UIView(frame: window.bounds)
    overlay.backgroundColor = .black
    overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]

    // Solfare yellow accent square as a discreet logo placeholder so the
    // snapshot looks intentional rather than crashed.
    let logo = UIView()
    logo.translatesAutoresizingMaskIntoConstraints = false
    logo.backgroundColor = UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0)
    logo.layer.cornerRadius = 12
    overlay.addSubview(logo)
    NSLayoutConstraint.activate([
      logo.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
      logo.centerYAnchor.constraint(equalTo: overlay.centerYAnchor),
      logo.widthAnchor.constraint(equalToConstant: 56),
      logo.heightAnchor.constraint(equalToConstant: 56),
    ])

    window.addSubview(overlay)
    privacyOverlay = overlay
  }

  private func hidePrivacyOverlay() {
    privacyOverlay?.removeFromSuperview()
    privacyOverlay = nil
  }

  // Scene-based apps don't expose UIApplication.shared.keyWindow anymore.
  // Walk the connected scenes for the foreground window.
  private func keyWindow() -> UIWindow? {
    return UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
      .first { $0.isKeyWindow }
  }
}
