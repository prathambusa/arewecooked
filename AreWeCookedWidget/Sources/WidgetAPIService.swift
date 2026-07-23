import Foundation

private let widgetAPIKeyDefaultsKey = "dev_admin_api_key"
private let widgetSummaryDefaultsKey = "usage_summary"

enum WidgetAPIService {
    static func savedAPIKey() -> String? {
        UserDefaults.standard.string(forKey: widgetAPIKeyDefaultsKey)
    }

    static func saveAPIKey(_ key: String) {
        UserDefaults.standard.set(key, forKey: widgetAPIKeyDefaultsKey)
    }

    static func cachedSummary() -> UsageSummary? {
        guard let data = UserDefaults.standard.data(forKey: widgetSummaryDefaultsKey) else { return nil }
        return try? JSONDecoder().decode(UsageSummary.self, from: data)
    }

    static func cacheSummary(_ summary: UsageSummary) {
        if let data = try? JSONEncoder().encode(summary) {
            UserDefaults.standard.set(data, forKey: widgetSummaryDefaultsKey)
        }
    }

    static func fetchSummary(apiKey: String) async throws -> UsageSummary {
        let base = "https://api.anthropic.com/v1/organizations"
        let now = Date()
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: now)
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!

        async let todayCost = fetchCost(base: base, apiKey: apiKey, from: todayStart, to: now)
        async let monthCost = fetchCost(base: base, apiKey: apiKey, from: monthStart, to: now)
        async let todayUsage = fetchUsage(base: base, apiKey: apiKey, from: todayStart, to: now)

        let (td, md, tu) = try await (todayCost, monthCost, todayUsage)
        return UsageSummary(
            todaySpendCents: td,
            monthSpendCents: md,
            todayInputTokens: tu.input,
            todayOutputTokens: tu.output,
            lastUpdated: now,
            hasError: false,
            errorMessage: nil
        )
    }

    private static func fetchCost(base: String, apiKey: String, from: Date, to: Date) async throws -> Double {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime]
        var comps = URLComponents(string: "\(base)/cost_report")!
        comps.queryItems = [
            URLQueryItem(name: "starting_at", value: fmt.string(from: from)),
            URLQueryItem(name: "ending_at", value: fmt.string(from: to)),
            URLQueryItem(name: "bucket_width", value: "1d")
        ]
        let json = try await get(url: comps.url!, apiKey: apiKey)
        var total = 0.0
        if let buckets = json["data"] as? [[String: Any]] {
            for bucket in buckets {
                if let results = bucket["results"] as? [[String: Any]] {
                    for r in results {
                        total += Double(r["amount"] as? String ?? "0") ?? 0
                    }
                }
            }
        }
        return total
    }

    private static func fetchUsage(base: String, apiKey: String, from: Date, to: Date) async throws -> (input: Int, output: Int) {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime]
        var comps = URLComponents(string: "\(base)/usage_report/messages")!
        comps.queryItems = [
            URLQueryItem(name: "starting_at", value: fmt.string(from: from)),
            URLQueryItem(name: "ending_at", value: fmt.string(from: to)),
            URLQueryItem(name: "bucket_width", value: "1d")
        ]
        let json = try await get(url: comps.url!, apiKey: apiKey)
        var input = 0, output = 0
        if let buckets = json["data"] as? [[String: Any]] {
            for bucket in buckets {
                if let results = bucket["results"] as? [[String: Any]] {
                    for r in results {
                        input += (r["input_tokens"] as? Int ?? 0) + (r["cache_read_input_tokens"] as? Int ?? 0)
                        output += r["output_tokens"] as? Int ?? 0
                    }
                }
            }
        }
        return (input, output)
    }

    private static func get(url: URL, apiKey: String) async throws -> [String: Any] {
        var req = URLRequest(url: url)
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        let (data, _) = try await URLSession.shared.data(for: req)
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }
}
