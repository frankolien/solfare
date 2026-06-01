import WidgetKit
import SwiftUI

struct PriceEntry: TimelineEntry {
  let date: Date
  let data: PriceWidgetData?
}

struct PriceProvider: TimelineProvider {
  func placeholder(in context: Context) -> PriceEntry {
    PriceEntry(date: Date(), data: .preview)
  }

  func getSnapshot(in context: Context, completion: @escaping (PriceEntry) -> Void) {
    completion(PriceEntry(date: Date(), data: PriceWidgetData.read() ?? .preview))
  }

  // Refresh every 15 minutes. The main app pushes fresh data whenever it
  // has it, so the widget will usually be more up-to-date than this — the
  // schedule is a floor, not a ceiling.
  func getTimeline(in context: Context, completion: @escaping (Timeline<PriceEntry>) -> Void) {
    let now = Date()
    let entry = PriceEntry(date: now, data: PriceWidgetData.read())
    let next = Calendar.current.date(byAdding: .minute, value: 15, to: now)!
    completion(Timeline(entries: [entry], policy: .after(next)))
  }
}

struct PriceTrackerWidgetView: View {
  let entry: PriceEntry

  var body: some View {
    let data = entry.data
    ZStack(alignment: .topLeading) {
      Brand.background.ignoresSafeArea()
      VStack(alignment: .leading, spacing: 6) {
        HStack {
          Text(data?.symbol ?? "SOL")
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.white)
          Spacer()
          Image("AppIconRounded")
            .resizable()
            .frame(width: 16, height: 16)
            .cornerRadius(4)
        }
        Spacer(minLength: 0)
        Sparkline(values: data?.sparkline ?? PriceWidgetData.preview.sparkline)
          .stroke(
            (data?.percentChange24h ?? 0) >= 0 ? Brand.positive : Brand.negative,
            style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round)
          )
          .frame(height: 36)
        VStack(alignment: .leading, spacing: 2) {
          Text(formatUsd(data?.priceUsd ?? 0))
            .font(.system(size: 22, weight: .bold))
            .foregroundColor(.white)
            .minimumScaleFactor(0.7)
            .lineLimit(1)
          HStack(spacing: 3) {
            Image(systemName: (data?.percentChange24h ?? 0) >= 0 ? "arrow.up.right" : "arrow.down.right")
              .font(.system(size: 10, weight: .semibold))
            Text(formatPercent(data?.percentChange24h ?? 0))
              .font(.system(size: 12, weight: .semibold))
          }
          .foregroundColor((data?.percentChange24h ?? 0) >= 0 ? Brand.positive : Brand.negative)
        }
      }
      .padding(14)
    }
    .widgetURL(URL(string: "solfare://market"))
  }
}

// Path drawn from a list of normalized [0, 1] price points.
struct Sparkline: Shape {
    
  let values: [Double]

  func path(in rect: CGRect) -> Path {
    guard values.count > 1 else { return Path() }
    let minV = values.min() ?? 0
    let maxV = values.max() ?? 1
    let range = max(maxV - minV, 0.0001)
    let stepX = rect.width / CGFloat(values.count - 1)
    var path = Path()
    for (i, v) in values.enumerated() {
      let x = CGFloat(i) * stepX
      let y = rect.height - CGFloat((v - minV) / range) * rect.height
      if i == 0 {
        path.move(to: CGPoint(x: x, y: y))
      } else {
        path.addLine(to: CGPoint(x: x, y: y))
      }
    }
    return path
  }
}

struct PriceTrackerWidget: Widget {
  let kind = "PriceTrackerWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: PriceProvider()) { entry in
      PriceTrackerWidgetView(entry: entry)
        .containerBackground(for: .widget) { Brand.background }
    }
    .configurationDisplayName("Price tracker")
    .description("Track current price and market data for SOL.")
    .supportedFamilies([.systemSmall])
  }
}

// MARK: - helpers

private func formatUsd(_ v: Double) -> String {
  let f = NumberFormatter()
  f.numberStyle = .currency
  f.currencyCode = "USD"
  f.maximumFractionDigits = v >= 1 ? 2 : 4
  return f.string(from: NSNumber(value: v)) ?? "$\(v)"
}

private func formatPercent(_ v: Double) -> String {
  let sign = v >= 0 ? "" : ""  // sign already encoded in arrow icon
  return "\(sign)\(String(format: "%.2f", abs(v)))%"
}

extension PriceWidgetData {
  static let preview = PriceWidgetData(
    symbol: "SOL",
    priceUsd: 85.37,
    percentChange24h: 2.93,
    sparkline: [80, 79.5, 81, 80.2, 82.4, 83.1, 82.8, 84.2, 84.9, 85.37],
    updatedAt: Date()
  )
}
