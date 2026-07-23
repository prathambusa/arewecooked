import Foundation
import WidgetKit

// MARK: - Anthropic response types

struct CostReport: Codable {
    struct Bucket: Codable {
        let startingAt: String
        let endingAt: String
        let results: [CostResult]
        enum CodingKeys: String, CodingKey {
            case startingAt = "starting_at"; case endingAt = "ending_at"; case results
        }
    }
    struct CostResult: Codable {
        let amount: String
        let currency: String
        let costType: String?
        let model: String?
        let workspace: String?
        enum CodingKeys: String, CodingKey {
            case amount, currency, model, workspace; case costType = "cost_type"
        }
    }
    let data: [Bucket]
    let hasMore: Bool?
    enum CodingKeys: String, CodingKey { case data; case hasMore = "has_more" }
}

struct UsageReport: Codable {
    struct Bucket: Codable {
        let results: [UsageResult]
    }
    struct UsageResult: Codable {
        let uncachedInputTokens: Int
        let outputTokens: Int
        let cacheReadInputTokens: Int
        let cacheCreation: CacheCreation?
        struct CacheCreation: Codable {
            let ephemeral1hInputTokens: Int
            let ephemeral5mInputTokens: Int
            enum CodingKeys: String, CodingKey {
                case ephemeral1hInputTokens = "ephemeral_1h_input_tokens"
                case ephemeral5mInputTokens = "ephemeral_5m_input_tokens"
            }
        }
        var totalInputTokens: Int {
            uncachedInputTokens + (cacheCreation?.ephemeral1hInputTokens ?? 0) + (cacheCreation?.ephemeral5mInputTokens ?? 0)
        }
        enum CodingKeys: String, CodingKey {
            case uncachedInputTokens  = "uncached_input_tokens"
            case outputTokens         = "output_tokens"
            case cacheReadInputTokens = "cache_read_input_tokens"
            case cacheCreation        = "cache_creation"
        }
    }
    let data: [Bucket]
    let hasMore: Bool?
    enum CodingKeys: String, CodingKey { case data; case hasMore = "has_more" }
}

// MARK: - OpenAI response types

struct OpenAICostReport: Codable {
    struct Bucket: Codable {
        let startTime: Int
        let endTime: Int
        let results: [CostResult]
        enum CodingKeys: String, CodingKey {
            case startTime = "start_time"; case endTime = "end_time"; case results
        }
    }
    struct CostResult: Codable {
        struct Amount: Codable { let value: Double; let currency: String }
        let amount: Amount
        let model: String?
        let lineItem: String?
        enum CodingKeys: String, CodingKey { case amount, model; case lineItem = "line_item" }
    }
    let data: [Bucket]
}

struct OpenAIUsageReport: Codable {
    struct Bucket: Codable {
        let results: [UsageResult]
    }
    struct UsageResult: Codable {
        let inputTokens: Int
        let outputTokens: Int
        let inputCachedTokens: Int?
        enum CodingKeys: String, CodingKey {
            case inputTokens = "input_tokens"
            case outputTokens = "output_tokens"
            case inputCachedTokens = "input_cached_tokens"
        }
    }
    let data: [Bucket]
}

// MARK: - Errors

enum APIError: LocalizedError {
    case noAPIKey
    case httpError(Int, String)
    case decodingError(String)
    case unsupported(String)

    var errorDescription: String? {
        switch self {
        case .noAPIKey:             return "No API key configured"
        case .httpError(let c, let m): return "HTTP \(c): \(m)"
        case .decodingError(let m): return "Decode error: \(m)"
        case .unsupported(let m):   return m
        }
    }
}

// MARK: - Service

class APIService {
    static let shared = APIService()
    private let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 30
        return URLSession(configuration: cfg)
    }()

    func fetchAndStore(provider: Provider) async throws {
        guard let apiKey = KeychainManager.load(for: provider), !apiKey.isEmpty else {
            throw APIError.noAPIKey
        }
        switch provider {
        case .anthropic: try await fetchAnthropic(apiKey: apiKey)
        case .openai:    try await fetchOpenAI(apiKey: apiKey)
        case .grok:      throw APIError.unsupported("Grok usage API is not publicly available")
        case .gemini:    throw APIError.unsupported("Gemini billing API requires Google Cloud — not supported")
        }
    }

    // MARK: - Anthropic

    private func fetchAnthropic(apiKey: String) async throws {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let now = Date()
        let todayMidnight     = cal.startOfDay(for: now)
        let yesterdayMidnight = cal.date(byAdding: .day, value: -1, to: todayMidnight)!
        let sevenDaysAgo      = cal.date(byAdding: .day, value: -7, to: todayMidnight)!
        let monthStart        = cal.date(from: cal.dateComponents([.year, .month], from: now))!

        async let yesterdayCost  = anthropicCost(apiKey: apiKey, from: yesterdayMidnight, to: todayMidnight)
        async let monthCost      = anthropicCost(apiKey: apiKey, from: monthStart, to: now)
        async let usage          = anthropicUsage(apiKey: apiKey, from: yesterdayMidnight, to: todayMidnight)
        async let sevenDay       = anthropicSevenDay(apiKey: apiKey, from: sevenDaysAgo, to: todayMidnight)
        async let models         = anthropicModels(apiKey: apiKey, from: monthStart, to: now)

        let (td, md, tu) = try await (yesterdayCost, monthCost, usage)
        let sd = await sevenDay
        let mc = await models

        save(UsageSummary(todaySpendCents: td, monthSpendCents: md,
                          todayInputTokens: tu.input, todayOutputTokens: tu.output,
                          cacheReadTokens: tu.cacheRead, sevenDayCents: sd, modelCosts: mc,
                          lastUpdated: now, hasError: false, errorMessage: nil))
    }

    private func anthropicCost(apiKey: String, from: Date, to: Date) async throws -> Double {
        let buckets = try await anthropicCostBuckets(apiKey: apiKey, from: from, to: to)
        return buckets.flatMap(\.results).reduce(0) { $0 + (Double($1.amount) ?? 0) }
    }

    private func anthropicCostBuckets(apiKey: String, from: Date, to: Date, extraItems: [URLQueryItem] = []) async throws -> [CostReport.Bucket] {
        let fmt = isoFormatter()
        var all: [CostReport.Bucket] = []
        var currentFrom = from
        repeat {
            var c = URLComponents(string: "https://api.anthropic.com/v1/organizations/cost_report")!
            c.queryItems = [item("starting_at", fmt.string(from: currentFrom)),
                            item("ending_at",   fmt.string(from: to)),
                            item("bucket_width","1d"),
                            item("limit",       "100")] + extraItems
            let r: CostReport = try await anthropicFetch(url: c.url!, apiKey: apiKey)
            all.append(contentsOf: r.data)
            guard r.hasMore == true,
                  let lastEnd = r.data.last.flatMap({ fmt.date(from: $0.endingAt) }) else { break }
            currentFrom = lastEnd
        } while true
        return all
    }

    private func anthropicUsage(apiKey: String, from: Date, to: Date) async throws -> (input: Int, output: Int, cacheRead: Int) {
        let fmt = isoFormatter()
        var c = URLComponents(string: "https://api.anthropic.com/v1/organizations/usage_report/messages")!
        c.queryItems = [item("starting_at", fmt.string(from: from)),
                        item("ending_at",   fmt.string(from: to)),
                        item("bucket_width","1d")]
        let r: UsageReport = try await anthropicFetch(url: c.url!, apiKey: apiKey)
        var inp = 0, out = 0, cr = 0
        for b in r.data { for u in b.results { inp += u.totalInputTokens; out += u.outputTokens; cr += u.cacheReadInputTokens } }
        return (inp, out, cr)
    }

    private func anthropicSevenDay(apiKey: String, from: Date, to: Date) async -> [Double] {
        guard let r = try? await _anthropicSevenDay(apiKey: apiKey, from: from, to: to) else { return [] }
        return r
    }
    private func _anthropicSevenDay(apiKey: String, from: Date, to: Date) async throws -> [Double] {
        let buckets = try await anthropicCostBuckets(apiKey: apiKey, from: from, to: to)
        return buckets.map { $0.results.reduce(0) { $0 + (Double($1.amount) ?? 0) } }
    }

    private func anthropicModels(apiKey: String, from: Date, to: Date) async -> [ModelCost] {
        guard let r = try? await _anthropicModels(apiKey: apiKey, from: from, to: to) else { return [] }
        return r
    }
    private func _anthropicModels(apiKey: String, from: Date, to: Date) async throws -> [ModelCost] {
        let buckets = try await anthropicCostBuckets(apiKey: apiKey, from: from, to: to, extraItems: [item("group_by[]", "description")])
        var totals: [String: Double] = [:]
        for b in buckets { for res in b.results { totals[res.model ?? "unknown", default: 0] += Double(res.amount) ?? 0 } }
        return totals.map { ModelCost(model: $0.key, cents: $0.value) }.filter { $0.cents > 0 }.sorted { $0.cents > $1.cents }
    }

    private func anthropicFetch<T: Decodable>(url: URL, apiKey: String) async throws -> T {
        var req = URLRequest(url: url)
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        return try await performFetch(req: req)
    }

    // MARK: - OpenAI

    private func fetchOpenAI(apiKey: String) async throws {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let now = Date()
        let todayMidnight     = cal.startOfDay(for: now)
        let yesterdayMidnight = cal.date(byAdding: .day, value: -1, to: todayMidnight)!
        let sevenDaysAgo      = cal.date(byAdding: .day, value: -7, to: todayMidnight)!
        let monthStart        = cal.date(from: cal.dateComponents([.year, .month], from: now))!

        async let yesterdayCost = openaiCost(apiKey: apiKey, from: yesterdayMidnight, to: todayMidnight)
        async let monthCost     = openaiCost(apiKey: apiKey, from: monthStart, to: now)
        async let usage         = openaiUsage(apiKey: apiKey, from: yesterdayMidnight, to: todayMidnight)
        async let sevenDay      = openaiSevenDay(apiKey: apiKey, from: sevenDaysAgo, to: todayMidnight)
        async let models        = openaiModels(apiKey: apiKey, from: monthStart, to: now)

        let (td, md, tu) = try await (yesterdayCost, monthCost, usage)
        let sd = await sevenDay
        let mc = await models

        // OpenAI amounts are in USD dollars — multiply by 100 for cents
        save(UsageSummary(todaySpendCents: td * 100, monthSpendCents: md * 100,
                          todayInputTokens: tu.input, todayOutputTokens: tu.output,
                          cacheReadTokens: tu.cacheRead,
                          sevenDayCents: sd.map { $0 * 100 }, modelCosts: mc,
                          lastUpdated: now, hasError: false, errorMessage: nil))
    }

    private func openaiCost(apiKey: String, from: Date, to: Date) async throws -> Double {
        var c = URLComponents(string: "https://api.openai.com/v1/organization/costs")!
        c.queryItems = [item("start_time", "\(Int(from.timeIntervalSince1970))"),
                        item("end_time",   "\(Int(to.timeIntervalSince1970))"),
                        item("bucket_width","1d")]
        let r: OpenAICostReport = try await openaiFetch(url: c.url!, apiKey: apiKey)
        return r.data.flatMap(\.results).reduce(0) { $0 + $1.amount.value }
    }

    private func openaiUsage(apiKey: String, from: Date, to: Date) async throws -> (input: Int, output: Int, cacheRead: Int) {
        var c = URLComponents(string: "https://api.openai.com/v1/organization/usage/completions")!
        c.queryItems = [item("start_time", "\(Int(from.timeIntervalSince1970))"),
                        item("end_time",   "\(Int(to.timeIntervalSince1970))"),
                        item("bucket_width","1d")]
        let r: OpenAIUsageReport = try await openaiFetch(url: c.url!, apiKey: apiKey)
        var inp = 0, out = 0, cr = 0
        for b in r.data { for u in b.results { inp += u.inputTokens; out += u.outputTokens; cr += u.inputCachedTokens ?? 0 } }
        return (inp, out, cr)
    }

    private func openaiSevenDay(apiKey: String, from: Date, to: Date) async -> [Double] {
        guard let r = try? await _openaiSevenDay(apiKey: apiKey, from: from, to: to) else { return [] }
        return r
    }
    private func _openaiSevenDay(apiKey: String, from: Date, to: Date) async throws -> [Double] {
        var c = URLComponents(string: "https://api.openai.com/v1/organization/costs")!
        c.queryItems = [item("start_time", "\(Int(from.timeIntervalSince1970))"),
                        item("end_time",   "\(Int(to.timeIntervalSince1970))"),
                        item("bucket_width","1d")]
        let r: OpenAICostReport = try await openaiFetch(url: c.url!, apiKey: apiKey)
        return r.data.map { $0.results.reduce(0) { $0 + $1.amount.value } }
    }

    private func openaiModels(apiKey: String, from: Date, to: Date) async -> [ModelCost] {
        guard let r = try? await _openaiModels(apiKey: apiKey, from: from, to: to) else { return [] }
        return r
    }
    private func _openaiModels(apiKey: String, from: Date, to: Date) async throws -> [ModelCost] {
        var c = URLComponents(string: "https://api.openai.com/v1/organization/costs")!
        c.queryItems = [item("start_time", "\(Int(from.timeIntervalSince1970))"),
                        item("end_time",   "\(Int(to.timeIntervalSince1970))"),
                        item("bucket_width","1d"),
                        item("group_by[]", "model")]
        let r: OpenAICostReport = try await openaiFetch(url: c.url!, apiKey: apiKey)
        var totals: [String: Double] = [:]
        for b in r.data { for res in b.results { totals[res.model ?? res.lineItem ?? "unknown", default: 0] += res.amount.value }  }
        return totals.map { ModelCost(model: $0.key, cents: $0.value * 100) }.filter { $0.cents > 0 }.sorted { $0.cents > $1.cents }
    }

    private func openaiFetch<T: Decodable>(url: URL, apiKey: String) async throws -> T {
        var req = URLRequest(url: url)
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        return try await performFetch(req: req)
    }

    // MARK: - Shared helpers

    private func save(_ summary: UsageSummary) {
        UserDefaults.appGroup.saveUsageSummary(summary)
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func isoFormatter() -> ISO8601DateFormatter {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        f.timeZone = TimeZone(identifier: "UTC")!
        return f
    }

    private func item(_ name: String, _ value: String) -> URLQueryItem {
        URLQueryItem(name: name, value: value)
    }

    private func performFetch<T: Decodable>(req: URLRequest) async throws -> T {
        var r = req
        r.setValue("AreWeCooked/1.0", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: r)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw APIError.httpError(http.statusCode, body)
        }
        do { return try JSONDecoder().decode(T.self, from: data) }
        catch let e as DecodingError {
            switch e {
            case .keyNotFound(let key, let ctx):
                throw APIError.decodingError("Missing key '\(key.stringValue)' at \(ctx.codingPath.map(\.stringValue).joined(separator: "."))")
            case .typeMismatch(_, let ctx):
                throw APIError.decodingError("Type mismatch at \(ctx.codingPath.map(\.stringValue).joined(separator: ".")): \(ctx.debugDescription)")
            default:
                throw APIError.decodingError(e.localizedDescription)
            }
        }
    }
}
