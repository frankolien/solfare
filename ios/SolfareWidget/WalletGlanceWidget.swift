import WidgetKit
import SwiftUI

struct WalletEntry: TimelineEntry {
  let date: Date
  let data: WalletWidgetData?
}

struct WalletProvider: TimelineProvider {
  func placeholder(in context: Context) -> WalletEntry {
    WalletEntry(date: Date(), data: .preview)
  }

  func getSnapshot(in context: Context, completion: @escaping (WalletEntry) -> Void) {
    completion(WalletEntry(date: Date(), data: WalletWidgetData.read() ?? .preview))
  }

  // Refresh every 15 minutes — the main app pushes fresh balance data on
  // every wallet update, so this is just a fallback heartbeat.
  func getTimeline(in context: Context, completion: @escaping (Timeline<WalletEntry>) -> Void) {
    let now = Date()
    let entry = WalletEntry(date: now, data: WalletWidgetData.read() ?? .preview)
    let next = Calendar.current.date(byAdding: .minute, value: 15, to: now)!
    completion(Timeline(entries: [entry], policy: .after(next)))
  }
}

// MARK: - Small (balance + 2 actions)

struct WalletGlanceSmallView: View {
  let entry: WalletEntry

  var body: some View {
    let data = entry.data ?? .preview
    ZStack {
      Brand.background.ignoresSafeArea()
      VStack(alignment: .leading, spacing: 6) {
        HStack {
          Text(data.walletName)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.white)
          Spacer()
          Image("AppIconRounded")
            .resizable()
            .frame(width: 16, height: 16)
            .cornerRadius(4)
        }
        Text(formatUsd(data.balanceUsd))
          .font(.system(size: 22, weight: .bold))
          .foregroundColor(.white)
          .minimumScaleFactor(0.6)
          .lineLimit(1)
        HStack(spacing: 3) {
          Image(systemName: data.percentChange24h >= 0 ? "arrow.up.right" : "arrow.down.right")
            .font(.system(size: 10, weight: .semibold))
          Text(String(format: "%.2f%%", abs(data.percentChange24h)))
            .font(.system(size: 12, weight: .semibold))
        }
        .foregroundColor(data.percentChange24h >= 0 ? Brand.positive : Brand.negative)
        Spacer(minLength: 0)
        HStack(spacing: 10) {
          ActionPill(systemImage: "arrow.left.arrow.right", url: "solfare://swap")
          ActionPill(systemImage: "paperplane.fill", url: "solfare://send")
        }
      }
      .padding(14)
    }
  }
}

// MARK: - Medium (balance + 4 actions, full wordmark)

struct WalletGlanceMediumView: View {
  let entry: WalletEntry

  var body: some View {
    let data = entry.data ?? .preview
    ZStack {
      Brand.background.ignoresSafeArea()
      VStack(alignment: .leading, spacing: 8) {
        HStack(alignment: .top) {
          VStack(alignment: .leading, spacing: 4) {
            Text(data.walletName)
              .font(.system(size: 14, weight: .semibold))
              .foregroundColor(.white)
            Text(formatUsd(data.balanceUsd))
              .font(.system(size: 26, weight: .bold))
              .foregroundColor(.white)
              .minimumScaleFactor(0.6)
              .lineLimit(1)
            HStack(spacing: 3) {
              Image(systemName: data.percentChange24h >= 0 ? "arrow.up.right" : "arrow.down.right")
                .font(.system(size: 10, weight: .semibold))
              Text(String(format: "%.2f%%", abs(data.percentChange24h)))
                .font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(data.percentChange24h >= 0 ? Brand.positive : Brand.negative)
          }
          Spacer()
          Text("Solflare")
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(Brand.accent)
        }
        Spacer(minLength: 0)
        HStack(spacing: 10) {
          ActionPill(systemImage: "arrow.down", url: "solfare://receive")
          ActionPill(systemImage: "arrow.left.arrow.right", url: "solfare://swap")
          ActionPill(systemImage: "banknote.fill", url: "solfare://stake")
          ActionPill(systemImage: "paperplane.fill", url: "solfare://send")
        }
      }
      .padding(14)
    }
  }
}

// Tappable circular action — uses Link so the OS deep-links the right
// route into the app instead of just opening the homepage.
struct ActionPill: View {
  let systemImage: String
  let url: String

  var body: some View {
    Link(destination: URL(string: url)!) {
      ZStack {
        Circle().fill(Color.white.opacity(0.08))
        Image(systemName: systemImage)
          .font(.system(size: 14, weight: .semibold))
          .foregroundColor(.white)
      }
      .frame(width: 40, height: 40)
    }
  }
}

struct WalletGlanceWidget: Widget {
  let kind = "WalletGlanceWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: WalletProvider()) { entry in
      WalletGlanceEntryView(entry: entry)
        .containerBackground(for: .widget) { Brand.background }
    }
    .configurationDisplayName("Wallet at a glance")
    .description("Monitor your balance and jump straight into wallet actions.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

struct WalletGlanceEntryView: View {
  @Environment(\.widgetFamily) var family
  let entry: WalletEntry

  var body: some View {
    switch family {
    case .systemMedium:
      WalletGlanceMediumView(entry: entry)
    default:
      WalletGlanceSmallView(entry: entry)
    }
  }
}

// MARK: - helpers

private func formatUsd(_ v: Double) -> String {
  let f = NumberFormatter()
  f.numberStyle = .currency
  f.currencyCode = "USD"
  f.maximumFractionDigits = 2
  return f.string(from: NSNumber(value: v)) ?? "$\(v)"
}

extension WalletWidgetData {
  static let preview = WalletWidgetData(
    walletName: "Main Wallet",
    balanceUsd: 21375.16,
    percentChange24h: 2.66,
    updatedAt: Date()
  )
}
