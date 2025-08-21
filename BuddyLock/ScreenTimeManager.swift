
import Foundation
import SwiftUI

#if canImport(ManagedSettings)
import ManagedSettings
#endif

#if canImport(FamilyControls)
import FamilyControls
#endif

extension Notification.Name {
    static let focusSessionCompleted = Notification.Name("BuddyLock.FocusSessionCompleted")
}

@MainActor
final class ScreenTimeManager: ObservableObject {
    // MARK: - Published UI State
    @Published var isAuthorized: Bool = false
    @Published var isShieldActive: Bool = false
    @Published var focusState: FocusSessionState = .idle
    @Published var scheduledStart: Date? = nil

    #if canImport(FamilyControls)
    @Published var selection: FamilyActivitySelection = .init()
    #endif

    // MARK: - Private
    private var focusTask: Task<Void, Never>?
    private var scheduleTask: Task<Void, Never>?

    var authorizationLabel: String { isAuthorized ? "Authorized" : "Not authorized" }

    init() {
        #if canImport(FamilyControls)
        Task { await refreshAuthorizationState() }
        #endif
    }

    // MARK: - Authorization

    #if canImport(FamilyControls)
    func refreshAuthorizationState() async {
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

    /// Applies shields for the current selection (apps, app categories, and web domains).
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

    /// Clears all shields.
    func clearShield() {
        #if canImport(ManagedSettings)
        let store = ManagedSettingsStore()
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
        #endif
        isShieldActive = false
    }

    // MARK: - Focus Sessions (warm-up + countdown)

    /// Represents a focus session with an optional warm-up delay before starting.
    /// During warm-up users can cancel to "resist the urge".
    func startFocusSession(minutes: Int, warmUpSeconds: Int = 0) {
        // Cancel any existing session first.
        cancelFocusSession()

        let totalRunSeconds = max(0, minutes) * 60
        let warmUp = max(0, warmUpSeconds)

        focusTask = Task { [weak self] in
            guard let self else { return }

            // 1) Apply shields immediately (so taps are blocked while warming up).
            self.applyShield()

            // 2) Optional warm-up countdown.
            if warmUp > 0 {
                await self.countDown(duration: warmUp, phase: .warmUp)
                if Task.isCancelled { return }
            }

            // 3) Run the focus countdown.
            await self.countDown(duration: totalRunSeconds, phase: .running)

            if Task.isCancelled { return }
            self.clearShield()
            self.focusState = .idle

            // Notify that a focus session completed, with minutes
            NotificationCenter.default.post(name: .focusSessionCompleted, object: nil, userInfo: ["minutes": totalRunSeconds / 60])
        }
    }

    /// Cancels any in-flight session and clears shields.
    func cancelFocusSession() {
        focusTask?.cancel()
        focusTask = nil
        clearShield()
        focusState = .idle
    }

    // MARK: - Scheduling

    /// Schedule a focus session to start at a future date/time.
    func scheduleFocusSession(start: Date, minutes: Int, warmUpSeconds: Int) {
        scheduleTask?.cancel()
        let delay = max(0, Int(start.timeIntervalSinceNow))
        scheduledStart = start

        scheduleTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: UInt64(delay) * 1_000_000_000)
            if Task.isCancelled { return }
            self.startFocusSession(minutes: minutes, warmUpSeconds: warmUpSeconds)
            await MainActor.run { self.scheduledStart = nil }
        }
    }

    func cancelScheduledFocus() {
        scheduleTask?.cancel()
        scheduleTask = nil
        scheduledStart = nil
    }

    // MARK: - Helpers

    private func countDown(duration: Int, phase: FocusSessionPhase) async {
        var remaining = duration
        await MainActor.run {
            switch phase {
            case .warmUp: self.focusState = .warmUp(secondsRemaining: remaining)
            case .running: self.focusState = .running(secondsRemaining: remaining)
            }
        }

        while remaining > 0 {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            if Task.isCancelled { return }
            remaining -= 1
            await MainActor.run {
                switch phase {
                case .warmUp: self.focusState = .warmUp(secondsRemaining: remaining)
                case .running: self.focusState = .running(secondsRemaining: remaining)
                }
            }
        }
    }
}

// MARK: - Focus Session State

enum FocusSessionState: Equatable {
    case idle
    case warmUp(secondsRemaining: Int)
    case running(secondsRemaining: Int)

    var isActive: Bool {
        if case .idle = self { return false } else { return true }
    }

    var secondsRemaining: Int? {
        switch self {
        case .warmUp(let s), .running(let s): return s
        case .idle: return nil
        }
    }

    var phase: FocusSessionPhase? {
        switch self {
        case .warmUp: return .warmUp
        case .running: return .running
        case .idle: return nil
        }
    }
}

enum FocusSessionPhase: Equatable {
    case warmUp
    case running
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
