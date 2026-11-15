import Foundation
import LocalAuthentication
import Observation
import Security

@MainActor @Observable final class AppLock {
    private(set) var enabled = UserDefaults.standard.bool(forKey: "security.lockEnabled")
    private(set) var unlocked = !UserDefaults.standard.bool(forKey: "security.lockEnabled")
    private(set) var authenticating = false
    var message: String?
    private var generation = 0
    private var currentContext: LAContext?

    func lock() {
        generation += 1; currentContext?.invalidate(); currentContext = nil
        authenticating = false
        if enabled { unlocked = false }
    }
    func authenticate(enabling: Bool = false, disabling: Bool = false) async {
        guard !authenticating else { return }
        authenticating = true; message = nil
        let attempt = generation
        let context = LAContext(); currentContext = context
        defer { if attempt == generation { authenticating = false; currentContext = nil } }
        do {
            guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) else {
                message = "Configurez un code de déverrouillage sur l’iPhone pour activer la protection."
                return
            }
            let success = try await context.evaluatePolicy(.deviceOwnerAuthentication,
                localizedReason: "Accéder à vos données patrimoniales")
            guard success, attempt == generation else { return }
            unlocked = true
            if enabling || disabling {
                enabled = enabling
                UserDefaults.standard.set(enabled, forKey: "security.lockEnabled")
            }
        } catch {
            if attempt == generation { message = "Déverrouillage non effectué. Vous pouvez réessayer." }
        }
    }
}

/// Reserved for future read-only API credentials. Never store tokens in UserDefaults or logs.
enum KeychainStore {
    static func write(_ data: Data, account: String) throws {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "fr.patrimoine.personal", kSecAttrAccount as String: account]
        let attributes: [String: Any] = [kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
        let update = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        let status = update == errSecItemNotFound
            ? SecItemAdd(query.merging(attributes) { _, new in new } as CFDictionary, nil) : update
        guard status == errSecSuccess else { throw KeychainError.operationFailed(status) }
    }
    static func read(account: String) throws -> Data? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "fr.patrimoine.personal", kSecAttrAccount as String: account,
            kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw KeychainError.operationFailed(status) }
        return result as? Data
    }
    static func remove(account: String) throws {
        let status = SecItemDelete([kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "fr.patrimoine.personal", kSecAttrAccount as String: account] as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw KeychainError.operationFailed(status) }
    }
    enum KeychainError: Error { case operationFailed(OSStatus) }
}
