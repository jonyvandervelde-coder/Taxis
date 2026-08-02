import Foundation

struct AksturEntry: Codable, Identifiable {
    var id = UUID()
    var date: Date = Date()
    var from: String = ""
    var to: String = ""
    var km: Double = 0
    var purpose: String = ""
}

@MainActor
final class AkstursbokStore: ObservableObject {
    private static let key = "taxis.akstursbók"

    // 2025 Icelandic vehicle allowance rates (RSK guidelines)
    static let rateLow: Double  = 66.0  // ISK/km for first 5,000 km/year
    static let rateHigh: Double = 40.0  // ISK/km above 5,000 km/year
    static let tierBreak: Double = 5_000

    @Published private(set) var entries: [AksturEntry] = []

    init() { load() }

    var totalKm: Double { entries.reduce(0) { $0 + $1.km } }

    var estimatedDeductionISK: Double {
        let km = totalKm
        if km <= Self.tierBreak {
            return km * Self.rateLow
        }
        return Self.tierBreak * Self.rateLow + (km - Self.tierBreak) * Self.rateHigh
    }

    func add(_ entry: AksturEntry) {
        entries.append(entry)
        save()
    }

    func remove(_ entry: AksturEntry) {
        entries.removeAll { $0.id == entry.id }
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.key),
              let decoded = try? JSONDecoder().decode([AksturEntry].self, from: data)
        else { return }
        entries = decoded
    }

    private func save() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }
}
