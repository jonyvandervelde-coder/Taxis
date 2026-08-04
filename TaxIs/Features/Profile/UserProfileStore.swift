//
//  UserProfileStore.swift
//  TaxÍs
//

import Foundation

@MainActor
final class UserProfileStore: ObservableObject {
    @Published var displayName: String {
        didSet { UserDefaults.standard.set(displayName, forKey: "taxis.profile.name") }
    }
    @Published var email: String {
        didSet { UserDefaults.standard.set(email, forKey: "taxis.profile.email") }
    }

    var initials: String {
        let words = displayName
            .trimmingCharacters(in: .whitespaces)
            .components(separatedBy: " ")
            .filter { !$0.isEmpty }
        if words.count >= 2 {
            return String(words[0].prefix(1) + words[1].prefix(1)).uppercased()
        } else if let first = words.first {
            return String(first.prefix(2)).uppercased()
        }
        return "?"
    }

    var displayEmail: String {
        email.isEmpty ? "" : email
    }

    init() {
        displayName = UserDefaults.standard.string(forKey: "taxis.profile.name") ?? ""
        email       = UserDefaults.standard.string(forKey: "taxis.profile.email") ?? ""
    }

    func clearOnSignOut() {
        email = ""
    }
}
