import Foundation
import SwiftUI

#if canImport(ManagedSettings)
import ManagedSettings
#endif

#if canImport(FamilyControls)
import FamilyControls
#endif

// MARK: - Focus Session State

/// Lightweight model the UI can use to render the current focus state
/// without needing to understand all of the Screen Time details.
struct FocusSessionState: Equatable {
    enum Phase: Equatable {
        case idle           // no session running
        case warmUp         // countdown before the real session starts
        case running        // active focus
        case completed      // finished normally
        case cancelled      // user ended early
    }

    var phase: Phase = .idle
    var label: String? = nil

    /// When the session actually started (after warm-up, if any).
    var startedAt: Date? = nil

    /// When the focus period will end.
    var endsAt: Date? = nil

    /// When a warm-up (if any) will end.
    var warmUpEndsAt: Date? = nil

    /// Convenience flag the UI uses everywhere.
    var isActive: Bool {
        switch phase {
        case .warmUp, .running:
            return true
        default:
            return false
        }
    }

    /// Best-effort remaining seconds until the *focus* period ends.
    var secondsRemaining: Int? {
        guard let endsAt, isActive else { return nil }
        let remaining = Int(endsAt.timeIntervalSinceNow.rounded())
        return max(remaining, 0)
    }

    static var idle: FocusSessionState { .init() }
}

// MARK: - ScreenTime Manager

@MainActor
final class ScreenTimeManager: ObservableObject {

    // MARK: High-level modes

    /// High-level mode the app is currently in. This is mostly for
    /// display / logic in the UI – `applyShield()` still ultimately
    /// decides what actually gets blocked.
    enum ActiveMode: Equatable {
        case idle
        case baseline                       // Always-on baseline block
        case focus                          // Focus session (Pomodoro / deep work)
        case panic                          // Short "panic button" block
        case essentialsOnly                 // "Everything but essentials" mode
    }

    // MARK: - Published UI State

    /// Whether the user has granted Screen Time (FamilyControls) authorization.
    @Published var isAuthorized: Bool = false

    /// Whether *any* shields are currently applied.
    @Published var isShieldActive: Bool = false

    /// High-level current mode (used mostly for UI / status).
    @Published var activeMode: ActiveMode = .idle

    /// Current focus session state (used in Home & Profile views).
    @Published var focusState: FocusSessionState = .idle

    /// Baseline "always-on" toggle. The UI is responsible for deciding
    /// when to call `enableBaseline()` / `disableBaseline()` based on
    /// schedules, switches, etc.
    @Published var isBaselineEnabled: Bool = false

    /// Timestamp for when the current panic block ends, if any.
    @Published private(set) var panicEndsAt: Date? = nil

    /// Timestamp for when the current "essentials only" block ends, if any.
    @Published private(set) var essentialsModeEndsAt: Date? = nil

    #if canImport(FamilyControls)
    /// Main selection for *blocked* content. This is what the FamilyActivityPicker
    /// in your UI is currently bound to and is used for:
    /// - Baseline blocking
    /// - Focus sessions
    /// - Panic button
    @Published var selection: FamilyActivitySelection = .init()

    /// Optional selection representing "allowed essentials" for the
    /// "everything but essentials" mode. For now we expose it so the UI
    /// can bind a second picker. In `applyShield()` we still block based
    /// on `selection` – actually computing "everything except these"
    /// will likely live in a dedicated helper later.
    @Published var essentialsSelection: FamilyActivitySelection = .init()
    #endif

    // MARK: - Private tasks & book-keeping

    /// Long-lived task ticking once per second to keep derived UI
    /// (e.g. timers) fresh.
    private var tickerTask: Task<Void, Never>?

    /// Task that manages a running focus session (handles warm-up and end).
    private var focusTask: Task<Void, Never>?

    /// Task for a panic-button short-term block.
    private var panicTask: Task<Void, Never>?

    /// Task for an "essentials only" block that should auto-end.
    private var essentialsTask: Task<Void, Never>?

    /// Task for temporary exceptions (buddy or self unlocks).
    private var exceptionTask: Task<Void, Never>?

    #if canImport(FamilyControls)
    /// Remember the last set of app tokens we applied shields to so we
    /// can create app-specific temporary exceptions.
    private var lastAppliedApplicationTokens: Set<ApplicationToken> = []
    #endif

    // MARK: - Init / deinit

    init() {
        startTicker()
        Task { [weak self] in
            await self?.refreshAuthorizationState()
        }
    }

    deinit {
        tickerTask?.cancel()
        focusTask?.cancel()
        panicTask?.cancel()
        essentialsTask?.cancel()
        exceptionTask?.cancel()
    }

    // MARK: - Authorization

    func requestAuthorization() async {
        #if canImport(FamilyControls)
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            await refreshAuthorizationState()
        } catch {
            print("ScreenTimeManager: Authorization error: \(error)")
            await refreshAuthorizationState()
        }
        #else
        // On platforms without FamilyControls this is a no-op so previews still work.
        isAuthorized = false
        #endif
    }

    func refreshAuthorizationState() async {
        #if canImport(FamilyControls)
        let status = await AuthorizationCenter.shared.authorizationStatus
        await MainActor.run {
            self.isAuthorized = (status == .approved)
        }
        #else
        isAuthorized = false
        #endif
    }

    // MARK: - Baseline block

    /// Enable the "always-on" baseline blocking using the current `selection`.
    func enableBaseline() {
        isBaselineEnabled = true
        // Only actually apply shields if we are not in a more specific
        // mode; if we *are*, the other mode will call `ap)`.
        if activeMode == .idle || activeMode == .baseline {
            activeMode = .baseline
            applyShield()
        }
    }

    /// Disable baseline blocking (does *not* cancel focus/panic/etc).
    func disableBaseline() {
        isBaselineEnabled = false
        if activeMode == .baseline {
            // We were only in baseline mode – clear shields entirely.
            clearShield()
            activeMode = .idle
        }
    }

    // MARK: - Focus sessions (Pomodoro)

    /// Starts a focus session of the given length (in minutes), with an
    /// optional warm-up period in seconds.
    func startFocusSession(minutes: Int, warmUpSeconds: Int) {
        // Cancel any existing focus or panic / essentials timers.
        focusTask?.cancel()

        let totalSeconds = max(minutes, 1) * 60
        let warmUp = max(warmUpSeconds, 0)

        let now = Date()
        let warmUpEndsAt = warmUp > 0 ? now.addingTimeInterval(TimeInterval(warmUp)) : nil
        let focusEndsAt = now.addingTimeInterval(TimeInterval(warmUp + totalSeconds))

        focusState = FocusSessionState(
            phase: warmUp > 0 ? .warmUp : .running,
            label: nil,
            startedAt: warmUp > 0 ? nil : now,
            endsAt: focusEndsAt,
            warmUpEndsAt: warmUpEndsAt
        )

        activeMode = .focus
        applyShield() // enforce blocking for focus

        focusTask = Task { [weak self] in
            guard let self else { return }

            // Warm-up phase
            if warmUp > 0 {
                try? await Task.sleep(nanoseconds: UInt64(warmUp) * 1_000_000_000)
                if Task.isCancelled { return }

                await MainActor.run {
                    self.focusState.startedAt = Date()
                    self.focusState.phase = .running
                }
            }

            // Focus phase
            let remainingFocusSeconds = totalSeconds
            try? await Task.sleep(nanoseconds: UInt64(remainingFocusSeconds) * 1_000_000_000)
            if Task.isCancelled { return }

            await self.endFocusSession(completed: true)
        }
    }

    /// Ends the current focus session, either because it completed or the
    /// user canceled it.
    func endFocusSession(completed: Bool) async {
        focusTask?.cancel()
        focusTask = nil

        await MainActor.run {
            focusState.phase = completed ? .completed : .cancelled
        }

        // After a focus session ends, we drop back to baseline if it is
        // enabled, otherwise to idle.
        if isBaselineEnabled {
            activeMode = .baseline
            applyShield()
        } else {
            activeMode = .idle
            clearShield()
        }
    }

    // MARK: - Panic button

    /// Quick "panic" block – immediately applies shields for a short
    /// period (default 15 minutes). This *overlays* on top of baseline.
    func startPanicBlock(minutes: Int = 15) {
        let clamped = max(1, minutes)
        panicTask?.cancel()

        let end = Date().addingTimeInterval(TimeInterval(clamped * 60))
        panicEndsAt = end
        activeMode = .panic
        applyShield()

        panicTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(clamped * 60) * 1_000_000_000)
            if Task.isCancelled { return }
            await self?.endPanicBlock()
        }
    }

    func endPanicBlock() async {
        panicTask?.cancel()
        panicTask = nil
        panicEndsAt = nil

        if focusState.isActive {
            activeMode = .focus
            applyShield()
        } else if isBaselineEnabled {
            activeMode = .baseline
            applyShield()
        } else {
            activeMode = .idle
            clearShield()
        }
    }

    // MARK: - "Everything but essentials" mode

    /// Activates an "everything but essentials" mode. For now this still
    /// applies shields based on `selection`; the intent is that the UI
    /// prepares `selection` so that it includes all non-essential
    /// content. We keep the manager logic simple and centralised.
    func startEssentialsOnlyMode(until endDate: Date? = nil) {
        essentialsTask?.cancel()

        essentialsModeEndsAt = endDate
        activeMode = .essentialsOnly
        applyShield()

        if let endDate {
            let seconds = max(1, Int(endDate.timeIntervalSinceNow))
            essentialsTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(seconds) * 1_000_000_000)
                if Task.isCancelled { return }
                await self?.endEssentialsOnlyMode()
            }
        }
    }

    func endEssentialsOnlyMode() async {
        essentialsTask?.cancel()
        essentialsTask = nil
        essentialsModeEndsAt = nil

        if focusState.isActive {
            activeMode = .focus
            applyShield()
        } else if panicEndsAt != nil {
            activeMode = .panic
            applyShield()
        } else if isBaselineEnabled {
            activeMode = .baseline
            applyShield()
        } else {
            activeMode = .idle
            clearShield()
        }
    }

    // MARK: - Shields

    /// Central place that decides *what* to shield based on the current
    /// mode. Right now the logic is intentionally simple:
    ///
    /// - In any blocking mode we shield the apps/categories/domains
    ///   captured in `selection`.
    /// - In the future you can expand this to treat panic / focus /
    ///   essentials differently.
    func applyShield() {
        #if canImport(ManagedSettings) && canImport(FamilyControls)
        let store = ManagedSettingsStore()

        // Apps (direct set; nil removes any app shields)
        if selection.applicationTokens.isEmpty {
            store.shield.applications = nil
            lastAppliedApplicationTokens = []
        } else {
            store.shield.applications = selection.applicationTokens
            lastAppliedApplicationTokens = selection.applicationTokens
        }

        // App/activity categories
        if selection.categoryTokens.isEmpty {
            store.shield.applicationCategories = nil
        } else {
            store.shield.applicationCategories = .specific(selection.categoryTokens)
        }

        // Web domains
        if selection.webDomainTokens.isEmpty {
            store.shield.webDomains = nil
        } else {
            store.shield.webDomains = selection.webDomainTokens
        }

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

    // MARK: - Temporary exceptions (buddy / self unlocks)

    /// Temporarily removes *all* shields for the given number of minutes,
    /// then reapplies them according to the current mode.
    func grantTemporaryException(minutes: Int) {
        let clamped = max(1, minutes)

        exceptionTask?.cancel()
        exceptionTask = Task { [weak self] in
            guard let self else { return }

            await MainActor.run {
                self.clearShield()
            }

            try? await Task.sleep(nanoseconds: UInt64(clamped * 60) * 1_000_000_000)
            if Task.isCancelled { return }

            await MainActor.run {
                // Re-evaluate which mode we should be in and re-apply.
                if self.activeMode != .idle {
                    self.applyShield()
                }
            }
        }
    }

    #if canImport(FamilyControls)
    /// Temporarily unblocks *specific* apps while keeping other shields
    /// in place as much as possible. For now we:
    /// - remember which app tokens were last shielded
    /// - create a new shield set with those minus the requested tokens
    /// - after `minutes`, restore the full shield set via `applyShield()`.
    func grantTemporaryException(forApps apps: Set<ApplicationToken>, minutes: Int) {
        let clamped = max(1, minutes)

        exceptionTask?.cancel()
        exceptionTask = Task { [weak self] in
            guard let self else { return }

            #if canImport(ManagedSettings)
            let store = ManagedSettingsStore()

            // Remove the requested apps from the currently shielded set.
            let remaining = self.lastAppliedApplicationTokens.subtracting(apps)
            await MainActor.run {
                store.shield.applications = remaining.isEmpty ? nil : remaining
            }
            #else
            await MainActor.run {
                self.clearShield()
            }
            #endif

            // Wait for the exception period to expire.
            try? await Task.sleep(nanoseconds: UInt64(clamped * 60) * 1_000_000_000)
            if Task.isCancelled { return }

            await MainActor.run {
                // Restore full shields according to the current mode.
                if self.activeMode != .idle {
                    self.applyShield()
                }
            }
        }
    }
    #endif

    // MARK: - Internal ticker

    /// Simple 1Hz ticker so that any computed time-remaining UI updates
    /// reasonably smoothly without every view having to manage its own
    /// timers.
    private func startTicker() {
        tickerTask?.cancel()
        tickerTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await MainActor.run {
                    // Touching the published state forces SwiftUI views that
                    // depend on `focusState.secondsRemaining` (and friends)
                    // to re-evaluate.
                    if self.focusState.isActive {
                        // Just reassign to trigger observers.
                        self.focusState = self.focusState
                    }
                }
            }
        }
    }
}

// MARK: - Helpers that other views already use

#if canImport(FamilyControls)
extension ScreenTimeManager {
    /// Very simple resolver used in `ApprovalsView` to show a name for each
    /// selected app token. Since the SDK doesn’t always give you a way to
    /// look up real app names, we fall back to generic names.
    func resolvedAppNames() -> [(token: ApplicationToken, name: String)] {
        let tokens = Array(selection.applicationTokens)
        return tokens.enumerated().map { (idx, t) in (t, "App \(idx + 1)") }
    }

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
    func resolvedAppNames() -> [(token: AnyHashable, name: String)] { [] }
    var selectionSummary: String { "" }
}
#endif
