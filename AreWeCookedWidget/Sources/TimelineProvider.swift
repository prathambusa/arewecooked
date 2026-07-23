import WidgetKit
import SwiftUI

struct UsageEntry: TimelineEntry {
    let date: Date
    let summary: UsageSummary
    let hasAPIKey: Bool
}

struct AreWeCookedTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> UsageEntry {
        UsageEntry(date: Date(), summary: .placeholder, hasAPIKey: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (UsageEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UsageEntry>) -> Void) {
        // Call completion synchronously — never block on network here.
        // The host app is responsible for pushing fresh data into UserDefaults.
        let entry = makeEntry()
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func makeEntry() -> UsageEntry {
        let key = UserDefaults.standard.string(forKey: "dev_admin_api_key") ?? ""
        if key.isEmpty {
            return UsageEntry(date: Date(), summary: .noKey, hasAPIKey: false)
        }
        if let saved = UserDefaults.standard.data(forKey: "usage_summary"),
           let summary = try? JSONDecoder().decode(UsageSummary.self, from: saved) {
            return UsageEntry(date: Date(), summary: summary, hasAPIKey: true)
        }
        // Key exists but no data yet — show a "loading" placeholder
        var loading = UsageSummary.placeholder
        loading.errorMessage = "Tap $ in menu bar → Refresh Now"
        loading.hasError = true
        return UsageEntry(date: Date(), summary: loading, hasAPIKey: true)
    }
}
