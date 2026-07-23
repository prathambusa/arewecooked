import SwiftUI
import WidgetKit

private let accentRed = Color(red: 1.0, green: 0.23, blue: 0.19)
private let dim = Color(white: 0.6)

private func usd(_ v: Double) -> String {
    String(format: "$%.2f", v)
}
private func relativeTime(_ date: Date) -> String {
    let diff = Date().timeIntervalSince(date)
    if diff < 60 { return "Just now" }
    if diff < 3600 { return "\(Int(diff / 60))m ago" }
    return "\(Int(diff / 3600))h ago"
}
private func shortTokens(_ n: Int) -> String {
    n >= 1_000_000 ? String(format: "%.1fM", Double(n)/1_000_000)
    : n >= 1_000   ? String(format: "%.1fK", Double(n)/1_000)
    : "\(n)"
}

struct AreWeCookedWidgetEntryView: View {
    let entry: UsageEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        ZStack {
            Color(red: 0.11, green: 0.11, blue: 0.12)
            content
        }
    }

    @ViewBuilder
    private var content: some View {
        if entry.summary.hasError {
            VStack(spacing: 6) {
                Image(systemName: "key.slash").font(.title2).foregroundStyle(dim)
                Text(entry.summary.errorMessage ?? "Add API key in app")
                    .font(.caption).foregroundStyle(dim).multilineTextAlignment(.center)
            }
            .padding(10)
        } else if family == .systemMedium {
            mediumView
        } else {
            smallView
        }
    }

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("TODAY").font(.system(size: 10, weight: .semibold)).foregroundStyle(dim).tracking(1.2)
            Spacer()
            Text(usd(entry.summary.todaySpendUSD))
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(accentRed).minimumScaleFactor(0.5).lineLimit(1)
            Text("API spend").font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.8))
            Spacer()
            Label(relativeTime(entry.summary.lastUpdated), systemImage: "clock")
                .font(.system(size: 9)).foregroundStyle(dim)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("ARE WE COOKED?").font(.system(size: 10, weight: .semibold)).foregroundStyle(dim).tracking(1.2)
                Spacer()
                Label(relativeTime(entry.summary.lastUpdated), systemImage: "clock").font(.system(size: 9)).foregroundStyle(dim)
            }
            Rectangle().fill(Color.white.opacity(0.12)).frame(height: 1)
            HStack(spacing: 0) {
                stat(usd(entry.summary.todaySpendUSD), "Today", accent: true)
                Rectangle().fill(Color.white.opacity(0.12)).frame(width: 1).padding(.vertical, 2)
                stat(usd(entry.summary.monthSpendUSD), "Month", accent: false)
                Rectangle().fill(Color.white.opacity(0.12)).frame(width: 1).padding(.vertical, 2)
                stat(shortTokens(entry.summary.totalTokens), "Tokens", accent: false)
            }
            .frame(maxHeight: .infinity)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func stat(_ value: String, _ label: String, accent: Bool) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value).font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(accent ? accentRed : .white).minimumScaleFactor(0.5).lineLimit(1)
            Text(label).font(.system(size: 10)).foregroundStyle(dim)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 8)
    }
}
