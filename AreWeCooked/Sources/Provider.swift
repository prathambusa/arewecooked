import SwiftUI

enum Provider: String, CaseIterable, Identifiable {
    case anthropic
    case openai
    case grok
    case gemini

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .anthropic: return "Anthropic"
        case .openai:    return "OpenAI"
        case .grok:      return "Grok"
        case .gemini:    return "Gemini"
        }
    }

    var accentColor: Color {
        switch self {
        case .anthropic: return Color(red: 1.0,  green: 0.23, blue: 0.19)
        case .openai:    return Color(red: 0.07, green: 0.73, blue: 0.49)
        case .grok:      return Color(white: 0.88)
        case .gemini:    return Color(red: 0.27, green: 0.51, blue: 0.96)
        }
    }

    var apiPlaceholder: String {
        switch self {
        case .anthropic: return "sk-ant-admin01-..."
        case .openai:    return "sk-proj-..."
        case .grok:      return "xai-..."
        case .gemini:    return "AIza..."
        }
    }

    var consoleURL: URL? {
        switch self {
        case .anthropic: return URL(string: "https://console.anthropic.com/settings/usage")
        case .openai:    return URL(string: "https://platform.openai.com/usage")
        case .grok:      return URL(string: "https://console.x.ai")
        case .gemini:    return URL(string: "https://aistudio.google.com")
        }
    }

    var keysURL: URL? {
        switch self {
        case .anthropic: return URL(string: "https://console.anthropic.com/settings/admin-keys")
        case .openai:    return URL(string: "https://platform.openai.com/api-keys")
        case .grok:      return URL(string: "https://console.x.ai/team/default/api-keys")
        case .gemini:    return URL(string: "https://aistudio.google.com/app/apikey")
        }
    }
}

// MARK: - Widget section preferences

struct WidgetPreferences {
    var showYesterday: Bool
    var showMonth: Bool
    var showTokens: Bool
    var show7Day: Bool
    var showModels: Bool

    static var current: WidgetPreferences {
        let d = UserDefaults.standard
        return WidgetPreferences(
            showYesterday: d.object(forKey: "show_yesterday") as? Bool ?? true,
            showMonth:     d.object(forKey: "show_month")     as? Bool ?? true,
            showTokens:    d.object(forKey: "show_tokens")    as? Bool ?? true,
            show7Day:      d.object(forKey: "show_7day")      as? Bool ?? true,
            showModels:    d.object(forKey: "show_models")    as? Bool ?? true
        )
    }

    var hasMetrics: Bool { showYesterday || showMonth || showTokens }

    var widgetHeight: CGFloat {
        var h: CGFloat = 36          // header always
        if hasMetrics  { h += 55 }  // divider + metrics row
        if show7Day    { h += 72 }  // divider + sparkline + labels
        if showModels  { h += 92 }  // divider + model rows
        return h
    }
}

private let selectedProviderKey = "selected_provider"

extension UserDefaults {
    var selectedProvider: Provider {
        get { Provider(rawValue: string(forKey: selectedProviderKey) ?? "") ?? .anthropic }
        set { set(newValue.rawValue, forKey: selectedProviderKey) }
    }
}
