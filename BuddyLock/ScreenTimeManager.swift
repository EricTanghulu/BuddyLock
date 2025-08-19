import Foundation
import SwiftUI

#if canImport(ManagedSettings)
import ManagedSettings
#endif

#if canImport(FamilyControls)
import FamilyControls
#endif

@MainActor
final class ScreenTimeManager: ObservableObject {
    // Public UI state
    @Published var isAuthorized: Bool = false
    @Published var isShieldActive: Bool = false

    #if canImport(FamilyControls)
    @Published var selection: FamilyActivitySelection = .init()
    #endif

    var authorizationLabel: String { isAuthorized ? "Authorized" : "Not authorized" }

    init() {
        #if canImport(FamilyControls)
        Task { await refreshAuthorizationState() }
        #endif
    }

    // MARK: - Authorization

    #if canImport(FamilyControls)
    func refreshAuthorizationState() async {
        // authorizationStatus is async, non-throwing.
        let status = await AuthorizationCenter.shared.authorizationStatus
        isAuthorized = (status == .approved)
    }
    #endif

    func requestAuthorization() async {
        #if canImport(FamilyControls)
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            await refreshAuthorizationState()
        } catch {
            print("Authorization error: \(error)")
            await refreshAuthorizationState()
        }
        #else
        print("FamilyControls not available on this platform/SDK.")
        #endif
    }

    // MARK: - Shields

    /// Apply immediate shields for the current selection (apps, app categories, and web domains).
    func applyShield() {
        #if canImport(ManagedSettings) && canImport(FamilyControls)
        let store = ManagedSettingsStore()

        // Apps (direct set; nil removes any app shields)
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens

        // App/activity categories (uses ShieldSettings)
        store.shield.applicationCategories = .specific(selection.categoryTokens)

        // Web domains (direct set; NOT .specific)
        store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens

        isShieldActive = true
        #else
        // No-ops so the demo UI still works without the frameworks/capabilities.
        isShieldActive = true
        #endif
    }

    /// Clear all shields that we may have applied.
    func clearShield() {
        #if canImport(ManagedSettings)
        let store = ManagedSettingsStore()
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
        #endif
        isShieldActive = false
    }

    // MARK: - Focus Session

    /// Simple timeboxed focus session: shield now, unshield after `minutes`.
    func startFocusSession(minutes: Int) async {
        applyShield()
        let seconds = max(0, minutes) * 60
        // Sleep is cancellable; if the task is cancelled we won't unshield.
        try? await Task.sleep(nanoseconds: UInt64(seconds) * 1_000_000_000)
        if Task.isCancelled { return }
        clearShield()
    }

    func stopFocusSession() {
        clearShield()
    }
}

#if canImport(FamilyControls)
extension ScreenTimeManager {
    var selectionSummary: String {
        var parts: [String] = []
        if !selection.applicationTokens.isEmpty { parts.append("\(selection.applicationTokens.count) app(s)") }
        if !selection.categoryTokens.isEmpty { parts.append("\(selection.categoryTokens.count) category token(s)") }
        if !selection.webDomainTokens.isEmpty { parts.append("\(selection.webDomainTokens.count) web domain(s)") }
        return parts.isEmpty ? "" : "Selected: " + parts.joined(separator: ", ")
    }
}
#else
extension ScreenTimeManager {
    var selectionSummary: String { "" }
}
#endif
