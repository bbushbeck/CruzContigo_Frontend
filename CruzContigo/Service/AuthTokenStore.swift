import Foundation
import Security

struct AuthTokenStore {
    static let shared = AuthTokenStore()
    private let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "CruzContigo.auth",
        kSecAttrAccount as String: "token",
    ]

    func guardar(_ token: String) throws {
        let data = Data(token.utf8)
        if SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess {
            SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        } else {
            var item = query
            item[kSecValueData as String] = data
            item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            try check(SecItemAdd(item as CFDictionary, nil))
        }
    }

    func cargar() -> String? {
        var item = query
        item[kSecReturnData as String] = true
        item[kSecMatchLimit as String] = kSecMatchLimitOne
        var data: CFTypeRef?
        guard SecItemCopyMatching(item as CFDictionary, &data) == errSecSuccess,
              let data = data as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func eliminar() {
        SecItemDelete(query as CFDictionary)
    }

    private func check(_ status: OSStatus) throws {
        guard status == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
    }
}
