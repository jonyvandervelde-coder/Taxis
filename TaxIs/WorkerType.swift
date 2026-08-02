import Foundation

enum WorkerType: String, CaseIterable, Codable {
    case employee     = "launthegi"
    case contractor   = "verktaki"
    case heimagisting = "heimagisting"

    var displayName: String {
        switch self {
        case .employee:     return "Launþegi"
        case .contractor:   return "Verktaki"
        case .heimagisting: return "Heimagisting"
        }
    }

    var subtitle: String {
        switch self {
        case .employee:     return "Ég fæ launaseðla frá vinnuveitanda"
        case .contractor:   return "Ég geri reikninga sem sjálfstætt starfandi"
        case .heimagisting: return "Ég leigi út íbúð eða herbergi á Airbnb o.fl."
        }
    }

    var icon: String {
        switch self {
        case .employee:     return "doc.text.fill"
        case .contractor:   return "briefcase.fill"
        case .heimagisting: return "house.fill"
        }
    }
}
