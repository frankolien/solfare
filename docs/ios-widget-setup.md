# iOS Widget setup (one-time Xcode steps)

The Swift code, entitlements, and Flutter bridge are all checked in. The one thing this repo can't ship automatically is the Xcode target definition for the widget extension — Xcode owns `project.pbxproj` and editing it by hand is fragile. The steps below take ~5 minutes the first time, zero after that.

## 1. Open the iOS project in Xcode

```bash
open ios/Runner.xcworkspace
```

## 2. Add the Widget Extension target

1. In Xcode: **File → New → Target…**
2. Choose **Widget Extension** under iOS.
3. Set:
   - Product Name: `SolfareWidget`
   - Team: your dev team (any will do for local builds)
   - Bundle Identifier: leave Xcode's default (it'll be `com.example.solfare.SolfareWidget` matching the parent)
   - Language: **Swift**
   - **Uncheck** "Include Live Activity" and **uncheck** "Include Configuration App Intent" — we're shipping static widgets, not interactive ones.
4. Click **Finish**. When Xcode prompts to "Activate the scheme", click **Cancel** (Flutter manages the run scheme).

Xcode creates a `SolfareWidget/` folder under `ios/` with one auto-generated `SolfareWidget.swift` file. **Delete that auto-generated file** — we already have our own.

## 3. Wire the existing Swift files into the new target

In Xcode's project navigator, right-click the `SolfareWidget` group → **Add Files to "Runner"…**, navigate to `ios/SolfareWidget/`, and add:

- `SharedData.swift`
- `PriceTrackerWidget.swift`
- `WalletGlanceWidget.swift`
- `SolfareWidgetBundle.swift`

In the file inspector (right panel) make sure each one has **Target Membership** ticked for `SolfareWidget` and **unticked** for `Runner`. (The shared `SharedData.swift` is the exception — tick it for **both** if you want the main app to read what it just wrote.)

Also add the existing `SolfareWidget/Info.plist` and `SolfareWidget/SolfareWidget.entitlements` to the SolfareWidget target.

## 4. Configure the App Group

The widget reads data the main app writes through a shared App Group. Both targets need the same group identifier registered.

In Xcode, for **each** of `Runner` and `SolfareWidget`:

1. Select the target → **Signing & Capabilities** tab.
2. Click **+ Capability**, choose **App Groups**.
3. Click **+** under the App Groups list, add: `group.com.example.solfare.widgets`
4. Make sure the entitlements file path matches what's already on disk:
   - Runner: `Runner/Runner.entitlements`
   - SolfareWidget: `SolfareWidget/SolfareWidget.entitlements`

When you ship to App Store, change `com.example.solfare` to your real reverse-DNS team identifier across `WidgetShared.appGroup` in `SharedData.swift` and both entitlements files.

## 5. Build and run

```bash
flutter run
```

Once the app is on the device:

1. Open the app, sign in, let the price/balance refresh once. The widget data is now in shared `UserDefaults`.
2. Long-press the home screen → **+** (top-left) → search "Solfare" → pick a widget.
3. Add the Price tracker (small) and the Wallet at a glance (small or medium).

Tap any action button on the medium Wallet widget — iOS opens `solfare://send` (or `swap`, `receive`, `stake`), the main app catches it in `AppDelegate.application(_:open:options:)`, forwards it over the `solfare/deeplink` channel, and `DeepLinkBridge` navigates to the homepage and sets `DeepLinkBridge.intent`. From there the `HomepageScreen` can switch tabs / open sheets based on the intent — that's a follow-up edit on the Dart side.

## What's where

| Concern | File |
|---|---|
| Widget UI (SwiftUI) | `ios/SolfareWidget/PriceTrackerWidget.swift`, `WalletGlanceWidget.swift` |
| Widget bundle entry | `ios/SolfareWidget/SolfareWidgetBundle.swift` |
| Shared Codable data + UserDefaults suite | `ios/SolfareWidget/SharedData.swift` |
| Widget entitlements | `ios/SolfareWidget/SolfareWidget.entitlements` |
| Main app entitlements | `ios/Runner/Runner.entitlements` |
| Native channel handlers (widget data write, deep-link forward) | `ios/Runner/AppDelegate.swift` |
| URL scheme registration | `ios/Runner/Info.plist` (`CFBundleURLTypes`) |
| Dart write path | `lib/core/widgets/widget_bridge.dart`, used from `lib/features/wallet/presentation/bloc/wallet_bloc.dart` |
| Dart deep-link receive path | `lib/core/deeplink/deep_link_bridge.dart`, initialised in `lib/main.dart` |

## Known follow-ups

- Sparkline payload is currently empty — the widget renders the price + percent fine but no chart line. Hook in a 24h `market_chart` fetch from CoinGecko (or reuse what `MarketBloc` already has) and pass the array of closes to `WidgetBridge.pushPrice`.
- `HomepageScreen` doesn't yet consume `DeepLinkBridge.intent`. Add a `ValueListenableBuilder` (or just a `.addListener` in `initState`) that switches tabs / opens sheets when the intent arrives.
- App Group identifier hardcoded as `group.com.example.solfare.widgets` — swap to your real team prefix before App Store.
- NFT spotlight widget design exists in the screenshots but isn't built. Would need an additional shared payload (image URL + name) and another widget kind.
