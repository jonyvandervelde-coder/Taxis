//
//  WorkerType.swift
//  TaxÍs
//
//  Icelandic tax filing splits into two worker profiles with different
//  income-reporting paths: launþegi (employee, reports via payslips) and
//  verktaki (self-employed contractor, reports income manually). A user
//  can be either, or both at once (e.g. a day job plus side contracting).
//

import Foundation

enum WorkerType: String, CaseIterable, Codable {
    case employee = "launthegi"
    case contractor = "verktaki"

    var displayName: String {
        switch self {
        case .employee: return "Launþegi"
        case .contractor: return "Verktaki"
        }
    }

    var subtitle: String {
        switch self {
        case .employee: return "I receive payslips from an employer"
        case .contractor: return "I invoice clients as self-employed"
        }
    }
}
