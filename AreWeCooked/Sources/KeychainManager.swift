import Foundation

private func defaultsKey(_ provider: Provider) -> String { "api_key_\(provider.rawValue)" }

enum KeychainManager {
    static func save(key: String, for provider: Provider) -> Bool {
        UserDefaults.standard.set(key, forKey: defaultsKey(provider))
        return true
    }

    static func load(for provider: Provider) -> String? {
        if let k = UserDefaults.standard.string(forKey: defaultsKey(provider)), !k.isEmpty { return k }
        // Migrate old Anthropic key stored under legacy key
        if provider == .anthropic {
            return UserDefaults.standard.string(forKey: "dev_admin_api_key")
        }
        return nil
    }

    static func delete(for provider: Provider) {
        UserDefaults.standard.removeObject(forKey: defaultsKey(provider))
    }
}
