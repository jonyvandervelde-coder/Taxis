//
//  OnboardingStore.swift
//  TaxÍs
//
//  Tracks the user's worker-type selection (launþegi/verktaki/both) and
//  whether they've completed the one-time onboarding flow. Persisted to
//  UserDefaults — this is a local preference, not account data, so it
//  doesn't need Supabase.
//

import Foundation

@MainActor
final class OnboardingStore: ObservableObject {
    @Published var workerTypes: Set<WorkerType>
    @Published var hasCompletedOnboarding: Bool
    @Published var termsAccepted: Bool

    private let workerTypesKey = "taxis.onboarding.workerTypes"
    private let completedKey   = "taxis.onboarding.completed"
    private let termsKey       = "taxis.onboarding.termsAccepted"

    init() {
        let defaults = UserDefaults.standard
        let storedRaw = defaults.stringArray(forKey: workerTypesKey) ?? []
        workerTypes = Set(storedRaw.compactMap(WorkerType.init(rawValue:)))
        hasCompletedOnboarding = defaults.bool(forKey: completedKey)
        termsAccepted = defaults.bool(forKey: termsKey)
    }

    func toggle(_ type: WorkerType) {
        if workerTypes.contains(type) {
            workerTypes.remove(type)
        } else {
            workerTypes.insert(type)
        }
    }

    /// Persists a profile-type change made after onboarding (e.g. via the
    /// in-app profile switcher on HomeView).
    func setWorkerTypes(_ types: Set<WorkerType>) {
        workerTypes = types
        UserDefaults.standard.set(types.map(\.rawValue), forKey: workerTypesKey)
    }

    func acceptTerms() {
        termsAccepted = true
        UserDefaults.standard.set(true, forKey: termsKey)
    }

    func completeOnboarding() {
        let defaults = UserDefaults.standard
        defaults.set(workerTypes.map(\.rawValue), forKey: workerTypesKey)
        defaults.set(true, forKey: completedKey)
        hasCompletedOnboarding = true
    }

    /// Lets a signed-in user redo the worker-type setup (exposed from Settings).
    func reset() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: workerTypesKey)
        defaults.removeObject(forKey: completedKey)
        defaults.removeObject(forKey: termsKey)
        workerTypes = []
        hasCompletedOnboarding = false
        termsAccepted = false
    }
}
