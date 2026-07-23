import SwiftUI

private let cardBg = Color(red: 0.11, green: 0.11, blue: 0.12)
private let dim    = Color(white: 0.55)
private let barBg  = Color(white: 1.0, opacity: 0.08)

private func usd(_ v: Double) -> String { String(format: "$%.2f", v) }
private func shortTok(_ n: Int) -> String {
    n >= 1_000_000 ? String(format: "%.1fM", Double(n)/1_000_000)
    : n >= 1_000   ? String(format: "%.1fK", Double(n)/1_000) : "\(n)"
}
private func relTime(_ d: Date) -> String {
    let s = Date().timeIntervalSince(d)
    if s < 60   { return "Just now" }
    if s < 3600 { return "\(Int(s/60))m ago" }
    return "\(Int(s/3600))h ago"
}
private func shortModel(_ name: String) -> String {
    let l = name.lowercased()
    if l.contains("opus")   { return "Opus" }
    if l.contains("sonnet") { return "Sonnet" }
    if l.contains("haiku")  { return "Haiku" }
    if l.contains("gpt-4o") { return "GPT-4o" }
    if l.contains("gpt-4")  { return "GPT-4" }
    if l.contains("gpt-3")  { return "GPT-3.5" }
    if l.contains("o1")     { return "o1" }
    if l.contains("o3")     { return "o3" }
    return String(name.prefix(10))
}

private func dayLabels(count: Int) -> [String] {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!
    let today = cal.startOfDay(for: Date())
    let letters = ["S","M","T","W","T","F","S"]
    return (0..<count).map { i in
        let date = cal.date(byAdding: .day, value: -(count - i), to: today)!
        return letters[cal.component(.weekday, from: date) - 1]
    }
}

struct DesktopWidgetView: View {
    let summary: UsageSummary
    let isLoading: Bool
    let provider: Provider

    @AppStorage("show_yesterday") private var showYesterday = true
    @AppStorage("show_month")     private var showMonth     = true
    @AppStorage("show_tokens")    private var showTokens    = true
    @AppStorage("show_7day")      private var show7Day      = true
    @AppStorage("show_models")    private var showModels    = true

    private var accent: Color { provider.accentColor }
    private var prefs: WidgetPreferences { WidgetPreferences.current }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous).fill(cardBg)

            if isLoading {
                VStack(spacing: 8) {
                    ProgressView().scaleEffect(0.8)
                    Text("Fetching…").font(.caption).foregroundStyle(dim)
                }
            } else if summary.hasError {
                VStack(spacing: 8) {
                    Image(systemName: "key.slash").font(.title2).foregroundStyle(dim)
                    Text(summary.errorMessage ?? "Add API key")
                        .font(.caption).foregroundStyle(dim).multilineTextAlignment(.center)
                }
                .padding(16)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    headerRow
                    if prefs.hasMetrics {
                        divider
                        metricsRow
                    }
                    if show7Day {
                        divider
                        sparklineSection
                    }
                    if showModels {
                        divider
                        modelSection
                    }
                }
            }
        }
        .frame(width: 320, height: prefs.widgetHeight)
    }

    // MARK: - Sections

    private var headerRow: some View {
        HStack {
            Text("\(provider.displayName.uppercased()) USAGE")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(dim)
                .tracking(1.5)
            Spacer()
            Label(relTime(summary.lastUpdated), systemImage: "clock")
                .font(.system(size: 9))
                .foregroundStyle(dim)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var metricsRow: some View {
        let cols: [(String, String, Bool)] = [
            (usd(summary.todaySpendUSD),       "Yesterday", showYesterday),
            (usd(summary.monthSpendUSD),       "Month",     showMonth),
            (shortTok(summary.totalTokens),    "Tokens",    showTokens),
        ].filter { $0.2 }

        return HStack(spacing: 0) {
            ForEach(Array(cols.enumerated()), id: \.offset) { i, col in
                if i > 0 { Divider().overlay(Color.white.opacity(0.08)).padding(.vertical, 6) }
                metricCol(col.0, col.1, accent: i == 0)
            }
        }
        .padding(.horizontal, 6)
        .frame(height: 54)
    }

    private var sparklineSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("7-DAY SPEND")
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(dim)
                .tracking(1.2)
            if summary.sevenDayCents.isEmpty {
                Text("No data").font(.system(size: 9)).foregroundStyle(dim)
            } else {
                sparkline(summary.sevenDayCents)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var modelSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("MONTHLY BY MODEL")
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(dim)
                .tracking(1.2)
            if summary.modelCosts.isEmpty {
                Text("No data").font(.system(size: 9)).foregroundStyle(dim)
            } else {
                let top = Array(summary.modelCosts.prefix(3))
                let maxCents = top.first?.cents ?? 1
                ForEach(top, id: \.model) { modelRow($0, maxCents: maxCents) }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var divider: some View {
        Rectangle().fill(Color.white.opacity(0.07)).frame(height: 1)
    }

    // MARK: - Sub-views

    private func metricCol(_ value: String, _ label: String, accent: Bool) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(accent ? self.accent : .white)
                .minimumScaleFactor(0.5).lineLimit(1)
            Text(label).font(.system(size: 9, weight: .medium)).foregroundStyle(dim)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
    }

    private func sparkline(_ values: [Double]) -> some View {
        let maxVal = values.max() ?? 1
        let labels = dayLabels(count: values.count)
        return HStack(alignment: .bottom, spacing: 4) {
            ForEach(Array(values.enumerated()), id: \.offset) { i, v in
                let frac = maxVal > 0 ? v / maxVal : 0
                VStack(spacing: 3) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(i == values.count - 1 ? accent : accent.opacity(0.4))
                        .frame(height: max(CGFloat(frac) * 22, 3))
                    Text(labels[i])
                        .font(.system(size: 7, weight: .medium))
                        .foregroundStyle(dim)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 38)
    }

    private func modelRow(_ cost: ModelCost, maxCents: Double) -> some View {
        HStack(spacing: 8) {
            Text(shortModel(cost.model))
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(dim)
                .frame(width: 52, alignment: .leading)
            progressBar(maxCents > 0 ? cost.cents / maxCents : 0)
            Text(usd(cost.cents / 100))
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 42, alignment: .trailing)
        }
    }

    private func progressBar(_ fraction: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2).fill(barBg).frame(height: 4)
                RoundedRectangle(cornerRadius: 2)
                    .fill(accent)
                    .frame(width: max(geo.size.width * CGFloat(fraction), 0), height: 4)
            }
        }
        .frame(height: 4)
    }
}
