//
//  KeychainService.swift
//  Municipal Elections Companion
//
//  Created by Alexander Fisher
//

import Foundation
import Security

protocol SessionStoreProtocol {
    func load() -> StoredSession?
    func save(_ session: StoredSession) throws
    func clear()
}

/// Stores the JWT session in the iOS Keychain, encrypted and never in UserDefaults.
final class KeychainService: SessionStoreProtocol {
    enum KeychainError: LocalizedError {
        case unhandled(OSStatus)

        var errorDescription: String? {
            "Couldn't save your login securely on this device (error \(statusCode))."
        }

        private var statusCode: OSStatus {
            switch self { case .unhandled(let status): return status }
        }
    }

    private let service = "ca.example.Municipal-Elections-Companion.session"
    private let account = "currentUser"

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    func load() -> StoredSession? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data
        else { return nil }
        return try? JSONDecoder().decode(StoredSession.self, from: data)
    }

    func save(_ session: StoredSession) throws {
        let data = try JSONEncoder().encode(session)
        clear()

        var query = baseQuery
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.unhandled(status) }
    }

    func clear() {
        SecItemDelete(baseQuery as CFDictionary)
    }
}
