import Foundation

let appGroupID = "group.com.prathambusa.AreWeCooked"
let keychainService = "com.prathambusa.AreWeCooked"
let keychainAPIKeyAccount = "anthropic-admin-api-key"
let sharedDefaultsKey = "usage_summary"

struct ModelCost: Codable {
    let model: String
    let cents: Double
}

struct UsageSummary: Codable {
    var todaySpendCents: Double
    var monthSpendCents: Double
    var todayInputTokens: Int
    var todayOutputTokens: Int
    var cacheReadTokens: Int
    var sevenDayCents: [Double]
    var modelCosts: [ModelCost]
    var lastUpdated: Date
    var hasError: Bool
    var errorMessage: String?

    var todaySpendUSD: Double { todaySpendCents / 100.0 }
    var monthSpendUSD: Double { monthSpendCents / 100.0 }
    var totalTokens: Int { todayInputTokens + todayOutputTokens }
    var cacheHitRate: Double {
        let total = Double(todayInputTokens) + Double(cacheReadTokens)
        guard total > 0 else { return 0 }
        return Double(cacheReadTokens) / total
    }

    // Custom decoder so old saved data without new fields still loads
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        todaySpendCents   = try c.decode(Double.self, forKey: .todaySpendCents)
        monthSpendCents   = try c.decode(Double.self, forKey: .monthSpendCents)
        todayInputTokens  = try c.decode(Int.self,    forKey: .todayInputTokens)
        todayOutputTokens = try c.decode(Int.self,    forKey: .todayOutputTokens)
        lastUpdated       = try c.decode(Date.self,   forKey: .lastUpdated)
        hasError          = try c.decode(Bool.self,   forKey: .hasError)
        errorMessage      = try? c.decode(String.self, forKey: .errorMessage)
        cacheReadTokens   = (try? c.decode(Int.self,      forKey: .cacheReadTokens))  ?? 0
        sevenDayCents     = (try? c.decode([Double].self,     forKey: .sevenDayCents))     ?? []
        modelCosts        = (try? c.decode([ModelCost].self,  forKey: .modelCosts))        ?? []
    }

    init(todaySpendCents: Double, monthSpendCents: Double,
         todayInputTokens: Int, todayOutputTokens: Int,
         cacheReadTokens: Int = 0, sevenDayCents: [Double] = [], modelCosts: [ModelCost] = [],
         lastUpdated: Date, hasError: Bool, errorMessage: String?) {
        self.todaySpendCents   = todaySpendCents
        self.monthSpendCents   = monthSpendCents
        self.todayInputTokens  = todayInputTokens
        self.todayOutputTokens = todayOutputTokens
        self.cacheReadTokens   = cacheReadTokens
        self.sevenDayCents     = sevenDayCents
        self.modelCosts        = modelCosts
        self.lastUpdated       = lastUpdated
        self.hasError          = hasError
        self.errorMessage      = errorMessage
    }

    static let placeholder = UsageSummary(
        todaySpendCents: 0, monthSpendCents: 0,
        todayInputTokens: 0, todayOutputTokens: 0,
        lastUpdated: Date(), hasError: false, errorMessage: nil
    )

    static let noKey = UsageSummary(
        todaySpendCents: 0, monthSpendCents: 0,
        todayInputTokens: 0, todayOutputTokens: 0,
        lastUpdated: Date(), hasError: true, errorMessage: "Add API key in app"
    )
}

extension UserDefaults {
    static var appGroup: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    func saveUsageSummary(_ summary: UsageSummary) {
        if let data = try? JSONEncoder().encode(summary) {
            set(data, forKey: sharedDefaultsKey)
        }
    }

    func loadUsageSummary() -> UsageSummary? {
        guard let data = data(forKey: sharedDefaultsKey) else { return nil }
        return try? JSONDecoder().decode(UsageSummary.self, from: data)
    }
}
