import Foundation

// Shared between the main app (which writes) and the widget extension
// (which reads). The Flutter side sends JSON over a MethodChannel; the
// Dart side writes the same JSON via FlutterUserDefaults into the same
// app group container.
//
// App Group identifier: keep this in sync with the entitlement on both
// the Runner target and the SolfareWidget target.
enum WidgetShared {
  static let appGroup = "group.com.example.solfare.widgets"
  static let walletKey = "wallet_widget_data"
  static let priceKey = "price_widget_data"

  static var defaults: UserDefaults? {
    UserDefaults(suiteName: appGroup)
  }
}

struct WalletWidgetData: Codable {
  let walletName: String
  let balanceUsd: Double
  let percentChange24h: Double
  let updatedAt: Date

  static func read() -> WalletWidgetData? {
    guard let defaults = WidgetShared.defaults else {
      NSLog("[WidgetRead] wallet: defaults nil — App Group missing on widget target")
      return nil
    }
    guard let raw = defaults.string(forKey: WidgetShared.walletKey) else {
      NSLog("[WidgetRead] wallet: key '\(WidgetShared.walletKey)' has no value yet")
      return nil
    }
    guard let data = raw.data(using: .utf8) else { return nil }
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .millisecondsSince1970
    do {
      let v = try decoder.decode(WalletWidgetData.self, from: data)
      NSLog("[WidgetRead] wallet: ok balance=\(v.balanceUsd)")
      return v
    } catch {
      NSLog("[WidgetRead] wallet: decode failed: \(error)")
      return nil
    }
  }
}

struct PriceWidgetData: Codable {
  let symbol: String
  let priceUsd: Double
  let percentChange24h: Double
  let sparkline: [Double]
  let updatedAt: Date

  static func read() -> PriceWidgetData? {
    guard let defaults = WidgetShared.defaults else {
      NSLog("[WidgetRead] price: defaults nil — App Group missing on widget target")
      return nil
    }
    guard let raw = defaults.string(forKey: WidgetShared.priceKey) else {
      NSLog("[WidgetRead] price: key '\(WidgetShared.priceKey)' has no value yet")
      return nil
    }
    guard let data = raw.data(using: .utf8) else { return nil }
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .millisecondsSince1970
    do {
      let v = try decoder.decode(PriceWidgetData.self, from: data)
      NSLog("[WidgetRead] price: ok price=\(v.priceUsd)")
      return v
    } catch {
      NSLog("[WidgetRead] price: decode failed: \(error)")
      return nil
    }
  }
}

// Brand colors lifted from the Flutter app for visual continuity.
import SwiftUI
enum Brand {
  static let accent = Color(red: 1.0, green: 0.84, blue: 0.0)
  static let background = Color.black
  static let positive = Color(red: 0.36, green: 0.84, blue: 0.45)
  static let negative = Color(red: 0.94, green: 0.36, blue: 0.36)
  static let muted = Color(white: 0.6)
}
