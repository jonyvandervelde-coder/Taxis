//
//  KeychainHelper.swift
//  TaxÍs
//
//  Minimal, dependency-free Keychain wrapper. Used to store the API
//  credential ReceiptExtractionService needs to authenticate its
//  network calls (see the security note in ReceiptExtractionService.swift
//  about NOT shipping a raw third-party AI provider key in the client).
//

import Foundation
import Security

enum KeychainError: LocalizedError {
    case unexpectedStatus(OSStatus)
    case dataConversionFailed

    var errorDescription: String? {
        switch self {
        case .unexpectedStatus(let status):
            let message = SecCopyErrorMessageString(status, nil) as String? ?? "unknown"
            return "Keychain operation failed (OSStatus \(status): \(message))"
        case .dataConversionFailed:
            return "Failed to convert Keychain value to/from Data"
        }
    }
}

/// Thin wrapper around the Keychain Services API for storing a single
/// string secret under a given account key, scoped to this app only
/// (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` — never synced
/// to iCloud Keychain, never readable before the device's first unlock
/// after boot).
final class KeychainHelper {
    static let shared = KeychainHelper()

    private let service: String

    private init(service: String = Bundle.main.bundleIdentifier ?? "com.taxis.app") {
        self.service = service
    }

    func save(_ value: String, forAccount account: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.dataConversionFailed
        }

        // Remove any existing item first so this is a clean upsert.
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    func read(forAccount account: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard let data = result as? Data, let value = String(data: data, encoding: .utf8) else {
                throw KeychainError.dataConversionFailed
            }
            return value
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }

    func delete(forAccount account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
}
