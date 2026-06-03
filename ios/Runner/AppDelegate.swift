import Flutter
import UIKit
import WidgetKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  // Mirrors the Android FLAG_SECURE behaviour: when `secureScreenEnabled`
  // is true and the app loses focus, a privacy overlay covers the key
  // window so sensitive screens (recovery phrase, private key export,
  // passcode entry) never appear in the iOS app-switcher snapshot.
  private var secureScreenEnabled = false
  private var privacyOverlay: UIView?

  // Channels used by the deep-link handler. We keep references so a URL
  // arriving before the implicit engine has finished initialising can be
  // replayed once the deep-link channel is ready.
  private var deepLinkChannel: FlutterMethodChannel?
  private var pendingDeepLink: String?

  // App group identifier — must match SolfareWidget.entitlements and
  // Runner.entitlements. Shared UserDefaults under this suite is how the
  // widget extension reads the data the Flutter side pushes.
  private static let appGroup = "group.com.example.solfare.widgets"

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

  // Cold-launch path: iOS hands us the URL through launchOptions.
  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    handleIncomingUrl(url)
    return true
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let messenger = engineBridge.pluginRegistry
      .registrar(forPlugin: "SecureScreen")!.messenger()

    // Secure-screen channel (existing).
    let secureChannel = FlutterMethodChannel(
      name: "solfare/secure_screen",
      binaryMessenger: messenger
    )
    secureChannel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "enable":
        self?.secureScreenEnabled = true
        result(nil)
      case "disable":
        self?.secureScreenEnabled = false
        DispatchQueue.main.async { self?.hidePrivacyOverlay() }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    // Widget-data channel — the Flutter side writes JSON; we store it in
    // the shared UserDefaults the widget extension reads, then ask
    // WidgetKit to refresh the timeline so the lock-screen / home-screen
    // widget picks up the new value immediately.
    let widgetChannel = FlutterMethodChannel(
      name: "solfare/widget_data",
      binaryMessenger: messenger
    )
    widgetChannel.setMethodCallHandler { call, result in
      NSLog("[WidgetData] received call: \(call.method)")
      guard let args = call.arguments as? [String: Any],
            let key = args["key"] as? String,
            let json = args["json"] as? String else {
        NSLog("[WidgetData] bad_args")
        result(FlutterError(code: "bad_args", message: "expected {key, json}", details: nil))
        return
      }
      guard let defaults = UserDefaults(suiteName: AppDelegate.appGroup) else {
        NSLog("[WidgetData] UserDefaults(suiteName: \(AppDelegate.appGroup)) returned nil — App Group not registered for this target")
        result(FlutterError(code: "no_suite", message: "no app group", details: nil))
        return
      }
      defaults.set(json, forKey: key)
      // Cross-process App Group writes are not guaranteed to be visible to
      // the widget extension immediately. synchronize() is deprecated but
      // remains the only reliable way to force a flush across the process
      // boundary.
      defaults.synchronize()
      let verify = defaults.string(forKey: key) ?? ""
      NSLog("[WidgetData] wrote key=\(key) bytes=\(json.count) verified=\(verify.count)B")
      if #available(iOS 14.0, *) {
        WidgetCenter.shared.reloadAllTimelines()
        NSLog("[WidgetData] reloadAllTimelines fired")
      }
      result(nil)
    }

    // Deep-link channel — the native side pushes any solfare:// URL that
    // arrives here. The Dart side decides which route to navigate to.
    deepLinkChannel = FlutterMethodChannel(
      name: "solfare/deeplink",
      binaryMessenger: messenger
    )
    if let pending = pendingDeepLink {
      deepLinkChannel?.invokeMethod("open", arguments: pending)
      pendingDeepLink = nil
    }
  }

  // MARK: - secure-screen overlay (existing)

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

  private func keyWindow() -> UIWindow? {
    return UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
      .first { $0.isKeyWindow }
  }

  // MARK: - deep links

  private func handleIncomingUrl(_ url: URL) {
    let raw = url.absoluteString
    // If the engine and channel are up, deliver immediately; otherwise
    // remember it and let didInitializeImplicitFlutterEngine flush.
    if let channel = deepLinkChannel {
      channel.invokeMethod("open", arguments: raw)
    } else {
      pendingDeepLink = raw
    }
  }
}
