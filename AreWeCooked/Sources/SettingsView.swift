import SwiftUI
import WidgetKit
import AppKit

struct SettingsView: View {
    @State private var selectedProvider: Provider = UserDefaults.standard.selectedProvider
    @State private var apiKey: String = ""
    @State private var showKey = false
    @State private var isRefreshing = false
    @State private var statusMessage: String? = nil
    @State private var isError = false
    @FocusState private var fieldFocused: Bool

    @AppStorage("show_yesterday") private var showYesterday = true
    @AppStorage("show_month")     private var showMonth     = true
    @AppStorage("show_tokens")    private var showTokens    = true
    @AppStorage("show_7day")      private var show7Day      = true
    @AppStorage("show_models")    private var showModels    = true

    var body: some View {
        Form {
            Section {
                Picker("Provider", selection: $selectedProvider) {
                    ForEach(Provider.allCases) { p in
                        Text(p.displayName).tag(p)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: selectedProvider) { _, newProvider in
                    UserDefaults.standard.selectedProvider = newProvider
                    apiKey = KeychainManager.load(for: newProvider) ?? ""
                    statusMessage = nil
                    DesktopWidgetController.shared.refresh()
                }
            } header: {
                Text("Provider")
            }

            Section {
                Toggle("Yesterday spend", isOn: $showYesterday).onChange(of: showYesterday) { _,_ in applyPrefs() }
                Toggle("Month spend",     isOn: $showMonth)    .onChange(of: showMonth)     { _,_ in applyPrefs() }
                Toggle("Token count",     isOn: $showTokens)   .onChange(of: showTokens)    { _,_ in applyPrefs() }
                Toggle("7-day trend",     isOn: $show7Day)     .onChange(of: show7Day)      { _,_ in applyPrefs() }
                Toggle("Model breakdown", isOn: $showModels)   .onChange(of: showModels)    { _,_ in applyPrefs() }
            } header: {
                Text("Display")
            }

            Section {
                HStack {
                    if showKey {
                        TextField(selectedProvider.apiPlaceholder, text: $apiKey)
                            .font(.system(.body, design: .monospaced))
                            .focused($fieldFocused)
                    } else {
                        SecureField(selectedProvider.apiPlaceholder, text: $apiKey)
                            .font(.system(.body, design: .monospaced))
                            .focused($fieldFocused)
                    }
                    Button(showKey ? "Hide" : "Show") { showKey.toggle() }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
                Text(keyHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("API Key")
            }

            Section {
                Button("Save & Refresh") { saveAndRefresh() }
                    .disabled(apiKey.trimmingCharacters(in: .whitespaces).isEmpty || isRefreshing)

                Button("Refresh Now") { refresh() }
                    .disabled(isRefreshing)

                if isRefreshing {
                    HStack {
                        ProgressView()
                        Text("Fetching usage data…").foregroundStyle(.secondary)
                    }
                }

                if let msg = statusMessage {
                    Text(msg)
                        .foregroundStyle(isError ? .red : .green)
                        .font(.caption)
                }
            } header: {
                Text("Actions")
            }

            Section {
                if let url = selectedProvider.consoleURL {
                    Link("Open \(selectedProvider.displayName) Console", destination: url)
                }
                if let url = selectedProvider.keysURL {
                    Link("Manage API Keys", destination: url)
                }
            } header: {
                Text("Links")
            }
        }
        .formStyle(.grouped)
        .onAppear {
            selectedProvider = UserDefaults.standard.selectedProvider
            apiKey = KeychainManager.load(for: selectedProvider) ?? ""
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { fieldFocused = true }
        }
    }

    private var keyHint: String {
        switch selectedProvider {
        case .anthropic: return "Requires an Admin API key from Anthropic Console (not a personal claude.ai key)."
        case .openai:    return "Requires a project or organization API key from platform.openai.com."
        case .grok:      return "Requires an API key from console.x.ai. Note: usage data may not be available."
        case .gemini:    return "Requires an API key from Google AI Studio. Note: billing data is not available via this API."
        }
    }

    private func applyPrefs() {
        DesktopWidgetController.shared.applyPreferences()
    }

    private func saveAndRefresh() {
        let trimmed = apiKey.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        _ = KeychainManager.save(key: trimmed, for: selectedProvider)
        refresh()
    }

    private func refresh() {
        isRefreshing = true
        statusMessage = nil
        let provider = selectedProvider
        Task {
            do {
                try await APIService.shared.fetchAndStore(provider: provider)
                await MainActor.run {
                    isRefreshing = false
                    isError = false
                    statusMessage = "Updated successfully"
                    DesktopWidgetController.shared.refresh()
                }
            } catch {
                await MainActor.run {
                    isRefreshing = false
                    isError = true
                    statusMessage = error.localizedDescription
                }
            }
        }
    }
}
