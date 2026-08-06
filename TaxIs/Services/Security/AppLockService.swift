//
//  AppLockService.swift
//  TaxÍs
//
//  Manages biometric (Face ID / Touch ID) and 4-digit PIN app-lock.
//  The PIN is stored in the iOS Keychain with the
//  kSecAttrAccessibleWhenUnlockedThisDeviceOnly attribute — it never
//  leaves the device and is removed if the device is wiped.
//
//  Usage: observe `isLocked` in ContentView, call `lockApp()` from
//  `.onChange(of: scenePhase)` when the app backgrounds.
//

import Foundation
import LocalAuthentication
import SwiftUI

final class AppLockService: ObservableObject {

    static let shared = AppLockService()

    // MARK: - Published state

    @Published var isLocked = false

    // MARK: - Persisted preferences

    @AppStorage("taxis.lockEnabled")   var lockEnabled:  Bool   = false
    @AppStorage("taxis.lockMethod")    var lockMethod:   String = "biometric"  // "biometric" | "pin"

    // MARK: - Keychain key

    private let pinKeychainKey = "taxis.app.pin"

    // MARK: - Lifecycle

    /// Call when the app moves to the background.
    func lockApp() {
        guard lockEnabled else { return }
        isLocked = true
    }

    /// Call when the app returns to the foreground.  Biometric method
    /// auto-triggers immediately; PIN method keeps the lock screen visible
    /// until the user types their PIN.
    func handleForeground() {
        guard lockEnabled, isLocked, lockMethod == "biometric" else { return }
        Task { await unlockWithBiometric() }
    }

    // MARK: - Biometric unlock

    @discardableResult @MainActor
    func unlockWithBiometric() async -> Bool {
        let context = LAContext()
        var nsError: NSError?
        guard context.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics, error: &nsError
        ) else { return false }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Staðfestu auðkenningu til að opna TaxÍs"
            )
            if success { isLocked = false }
            return success
        } catch {
            return false
        }
    }

    // MARK: - PIN unlock

    func unlock(withPIN pin: String) -> Bool {
        guard let stored = loadPIN() else { return false }
        let success = (pin == stored)
        if success { isLocked = false }
        return success
    }

    // MARK: - Configuration

    func enableBiometric() {
        lockEnabled = true
        lockMethod  = "biometric"
    }

    func setPIN(_ pin: String) {
        savePIN(pin)
        lockEnabled = true
        lockMethod  = "pin"
    }

    func disableLock() {
        lockEnabled = false
        deletePIN()
    }

    // MARK: - Biometric availability

    func isBiometricAvailable() -> Bool {
        var error: NSError?
        return LAContext().canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics, error: &error
        )
    }

    var biometricLabel: String {
        let context = LAContext()
        var error: NSError?
        _ = context.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics, error: &error
        )
        switch context.biometryType {
        case .faceID:  return "Face ID"
        case .touchID: return "Touch ID"
        default:       return "Líffræðilegt auðkenni"
        }
    }

    var biometricIcon: String {
        let context = LAContext()
        var error: NSError?
        _ = context.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics, error: &error
        )
        return context.biometryType == .faceID ? "faceid" : "touchid"
    }

    // MARK: - Keychain helpers

    private func savePIN(_ pin: String) {
        guard let data = pin.data(using: .utf8) else { return }
        let attrs: [CFString: Any] = [
            kSecClass:            kSecClassGenericPassword,
            kSecAttrAccount:      pinKeychainKey,
            kSecValueData:        data,
            kSecAttrAccessible:   kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]
        SecItemDelete(attrs as CFDictionary)
        SecItemAdd(attrs as CFDictionary, nil)
    }

    private func loadPIN() -> String? {
        let query: [CFString: Any] = [
            kSecClass:        kSecClassGenericPassword,
            kSecAttrAccount:  pinKeychainKey,
            kSecReturnData:   true,
            kSecMatchLimit:   kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func deletePIN() {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrAccount: pinKeychainKey,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
