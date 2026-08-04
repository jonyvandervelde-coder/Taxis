//
//  SupabaseConfig.swift
//  TaxÍs
//
//  Shared Supabase project configuration, read from the app's Info.plist
//  rather than hardcoded. The anon key is public-safe by design (RLS is
//  the real access boundary, per taxis_schema.sql) but both services that
//  need it (ReceiptExtractionService, SupabaseTransactionRepository)
//  should read it from one place.
//

import Foundation

enum SupabaseConfigError: LocalizedError {
    case missingInfoPlistKey(String)

    var errorDescription: String? {
        switch self {
        case .missingInfoPlistKey(let key):
            return "Missing required Info.plist key '\(key)'. Add it under your target's build settings/Info tab."
        }
    }
}

/// Reads Supabase connection details from Info.plist:
///   - `SUPABASE_URL`: e.g. "https://abcdefgh.supabase.co"
///   - `SUPABASE_ANON_KEY`: the project's public anon/publishable key
///   - `SUPABASE_FUNCTIONS_URL` (optional): overrides the derived Edge
///     Functions host if you're not using Supabase's default routing.
enum SupabaseConfig {
    static var projectURL: URL {
        get throws {
            guard
                let raw = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
                let url = URL(string: raw)
            else {
                throw SupabaseConfigError.missingInfoPlistKey("SUPABASE_URL")
            }
            return url
        }
    }

    static var anonKey: String {
        get throws {
            guard
                let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
                !key.isEmpty
            else {
                throw SupabaseConfigError.missingInfoPlistKey("SUPABASE_ANON_KEY")
            }
            return key
        }
    }

    /// Base URL for PostgREST, e.g. "https://abcdefgh.supabase.co/rest/v1".
    static var restURL: URL {
        get throws {
            try projectURL.appendingPathComponent("rest/v1")
        }
    }

    /// Base URL for Edge Functions, e.g. "https://abcdefgh.functions.supabase.co".
    static var functionsURL: URL {
        get throws {
            if
                let raw = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_FUNCTIONS_URL") as? String,
                let url = URL(string: raw)
            {
                return url
            }
            let projectHost = try projectURL.host
            guard let projectHost, let projectRef = projectHost.components(separatedBy: ".").first else {
                throw SupabaseConfigError.missingInfoPlistKey("SUPABASE_URL")
            }
            guard let url = URL(string: "https://\(projectRef).functions.supabase.co") else {
                throw SupabaseConfigError.missingInfoPlistKey("SUPABASE_URL")
            }
            return url
        }
    }
}
