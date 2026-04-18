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
struct FocusSessionState: Equatable, Codable {
    enum Phase: Equatable, Codable {
        case idle           // no session running
        case warmUp         // countdown before the real session starts
        case running        // active focus
        case paused         // temporarily paused
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

    /// Frozen remaining time while paused.
    var pausedRemainingSeconds: Int? = nil

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
        switch phase {
        case .paused:
            return pausedRemainingSeconds
        case .warmUp, .running:
            guard let endsAt else { return nil }
            let remaining = Int(endsAt.timeIntervalSinceNow.rounded())
            return max(remaining, 0)
        case .idle, .completed, .cancelled:
            return nil
        }
    }

    static var idle: FocusSessionState { .init() }
}

// MARK: - ScreenTime Manager

@MainActor
final class ScreenTimeManager: ObservableObject {
    private struct PersistedSessionState: Codable {
        enum Mode: String, Codable {
            case none
            case focusRunning
            case focusPaused
        }

        var mode: Mode
        var focusState: FocusSessionState
        var focusPauseEndsAt: Date?
        #if canImport(FamilyControls)
        var focusSelectionOverride: FamilyActivitySelection?
        #endif
    }

    private static let persistedSessionKey = "BuddyLock.persistedSessionState"

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

    /// Whether we've completed at least one real authorization check this launch.
    @Published var hasResolvedAuthorizationStatus: Bool = false

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

    /// Timestamp for when a temporary exception ends, if any.
    @Published private(set) var exceptionEndsAt: Date? = nil

    /// Timestamp for when a paused focus window auto-ends, if any.
    @Published private(set) var focusPauseEndsAt: Date? = nil

    #if canImport(FamilyControls)
    /// Optional focus-specific selection used when a preset wants its own
    /// blocked apps instead of the shared default selection.
    @Published private(set) var focusSelectionOverride: FamilyActivitySelection? = nil
    #endif

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

    /// Task that manages an active focus pause.
    private var pausedFocusTask: Task<Void, Never>?

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
        restorePersistedSessionIfNeeded()
        Task { [weak self] in
            await self?.refreshAuthorizationState()
        }
    }

    deinit {
        tickerTask?.cancel()
        focusTask?.cancel()
        pausedFocusTask?.cancel()
        panicTask?.cancel()
        essentialsTask?.cancel()
        exceptionTask?.cancel()
    }

    // MARK: - Authorization

    func requestAuthorization() async {
        #if canImport(FamilyControls)
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            print("hello")
            await refreshAuthorizationState()
        } catch {
            print("ScreenTimeManager: Authorization error: \(error)")
            await refreshAuthorizationState()
        }
        #else
        // On platforms without FamilyControls this is a no-op so previews still work.
        isAuthorized = false
        hasResolvedAuthorizationStatus = true
        #endif
    }

    func refreshAuthorizationState() async {
        #if canImport(FamilyControls)
        print("can import family controls")
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            print("✅ requestAuthorization returned")

        } catch {
            print("❌ requestAuthorization threw:", error)
        }
        let after = AuthorizationCenter.shared.authorizationStatus
            print("🔍 Status AFTER request:", after)
        

        await MainActor.run {
            print("Status:", AuthorizationCenter.shared.authorizationStatus)
            let status = AuthorizationCenter.shared.authorizationStatus
            self.isAuthorized = (status == .approved)
            self.hasResolvedAuthorizationStatus = true
        }
        print("isAuthorized is (p2)...", isAuthorized)
        #else
        isAuthorized = false
        hasResolvedAuthorizationStatus = true
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
    func startFocusSession(minutes: Int, warmUpSeconds: Int, selectionOverride: FamilyActivitySelection? = nil) {
        // Cancel any existing focus or panic / essentials timers.
        focusTask?.cancel()
        pausedFocusTask?.cancel()
        pausedFocusTask = nil
        focusPauseEndsAt = nil

        let totalSeconds = max(minutes, 1) * 60
        let warmUp = max(warmUpSeconds, 0)

        let now = Date()
        let warmUpEndsAt = warmUp > 0 ? now.addingTimeInterval(TimeInterval(warmUp)) : nil
        let focusEndsAt = now.addingTimeInterval(TimeInterval(warmUp + totalSeconds))

        #if canImport(FamilyControls)
        focusSelectionOverride = selectionOverride
        #endif

        focusState = FocusSessionState(
            phase: warmUp > 0 ? .warmUp : .running,
            label: nil,
            startedAt: warmUp > 0 ? nil : now,
            endsAt: focusEndsAt,
            warmUpEndsAt: warmUpEndsAt,
            pausedRemainingSeconds: nil
        )

        activeMode = .focus
        applyShield() // enforce blocking for focus
        persistCurrentSession()

        focusTask = Task { [weak self] in
            guard let self else { return }

            // Warm-up phase
            if warmUp > 0 {
                try? await Task.sleep(nanoseconds: UInt64(warmUp) * 1_000_000_000)
                if Task.isCancelled { return }

                await MainActor.run {
                    self.focusState.startedAt = Date()
                    self.focusState.phase = .running
                    self.persistCurrentSession()
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
        pausedFocusTask?.cancel()
        pausedFocusTask = nil
        focusPauseEndsAt = nil
        #if canImport(FamilyControls)
        focusSelectionOverride = nil
        #endif

        await MainActor.run {
            focusState.phase = completed ? .completed : .cancelled
            focusState.pausedRemainingSeconds = nil
        }

        exceptionTask?.cancel()
        exceptionEndsAt = nil

        // After a focus session ends, we drop back to baseline if it is
        // enabled, otherwise to idle.
        if isBaselineEnabled {
            activeMode = .baseline
            applyShield()
        } else {
            activeMode = .idle
            clearShield()
        }
        clearPersistedSession()
    }

    func pauseFocusSession(for minutes: Int) {
        guard focusState.phase == .running || focusState.phase == .warmUp else { return }

        focusTask?.cancel()
        focusTask = nil

        let remaining = max(focusState.secondsRemaining ?? 0, 1)
        let pauseMinutes = max(minutes, 1)

        focusState.phase = .paused
        focusState.pausedRemainingSeconds = remaining
        focusState.endsAt = nil
        focusState.warmUpEndsAt = nil

        activeMode = .idle
        clearShield()

        focusPauseEndsAt = Date().addingTimeInterval(TimeInterval(pauseMinutes * 60))
        persistCurrentSession()

        pausedFocusTask?.cancel()
        pausedFocusTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(pauseMinutes * 60) * 1_000_000_000)
            if Task.isCancelled { return }
            await self?.resumeFocusSession()
        }
    }

    func resumeFocusSession() async {
        guard focusState.phase == .paused else { return }

        pausedFocusTask?.cancel()
        pausedFocusTask = nil
        focusPauseEndsAt = nil

        let remaining = max(focusState.pausedRemainingSeconds ?? 0, 1)
        let end = Date().addingTimeInterval(TimeInterval(remaining))

        focusState.phase = .running
        focusState.startedAt = Date()
        focusState.endsAt = end
        focusState.pausedRemainingSeconds = nil

        activeMode = .focus
        applyShield()
        persistCurrentSession()

        focusTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(remaining) * 1_000_000_000)
            if Task.isCancelled { return }
            await self?.endFocusSession(completed: true)
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
        let activeSelection = effectiveShieldSelection

        if activeSelection.applicationTokens.isEmpty {
            store.shield.applications = nil
            lastAppliedApplicationTokens = []
        } else {
            store.shield.applications = activeSelection.applicationTokens
            lastAppliedApplicationTokens = activeSelection.applicationTokens
        }

        // App/activity categories
        if activeSelection.categoryTokens.isEmpty {
            store.shield.applicationCategories = nil
        } else {
            store.shield.applicationCategories = .specific(activeSelection.categoryTokens)
        }

        // Web domains
        if activeSelection.webDomainTokens.isEmpty {
            store.shield.webDomains = nil
        } else {
            store.shield.webDomains = activeSelection.webDomainTokens
        }

        isShieldActive = true
        #else
        // No-ops so the demo UI still works without the frameworks/capabilities.
        isShieldActive = true
        #endif
    }

    #if canImport(FamilyControls)
    private var effectiveShieldSelection: FamilyActivitySelection {
        if activeMode == .focus, let focusSelectionOverride {
            return focusSelectionOverride
        }
        return selection
    }
    #endif

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
        exceptionEndsAt = Date().addingTimeInterval(TimeInterval(clamped * 60))
        exceptionTask = Task { [weak self] in
            guard let self else { return }

            await MainActor.run {
                self.clearShield()
            }

            try? await Task.sleep(nanoseconds: UInt64(clamped * 60) * 1_000_000_000)
            if Task.isCancelled { return }

            await MainActor.run {
                self.exceptionEndsAt = nil
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
        exceptionEndsAt = Date().addingTimeInterval(TimeInterval(clamped * 60))
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
                self.exceptionEndsAt = nil
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

                    if self.exceptionEndsAt != nil {
                        self.exceptionEndsAt = self.exceptionEndsAt
                    }

                    if self.focusPauseEndsAt != nil {
                        self.focusPauseEndsAt = self.focusPauseEndsAt
                    }
                }
            }
        }
    }

    private func restorePersistedSessionIfNeeded() {
        guard
            let data = UserDefaults.standard.data(forKey: Self.persistedSessionKey),
            let persisted = try? JSONDecoder().decode(PersistedSessionState.self, from: data)
        else {
            return
        }

        switch persisted.mode {
        case .none:
            clearPersistedSession()
        case .focusRunning:
            restoreRunningFocusSession(from: persisted)
        case .focusPaused:
            restorePausedFocusSession(from: persisted)
        }
    }

    private func restoreRunningFocusSession(from persisted: PersistedSessionState) {
        guard let end = persisted.focusState.endsAt else {
            clearPersistedSession()
            return
        }

        let remaining = Int(end.timeIntervalSinceNow.rounded())
        guard remaining > 0 else {
            clearPersistedSession()
            clearShield()
            activeMode = isBaselineEnabled ? .baseline : .idle
            return
        }

        focusState = persisted.focusState
        activeMode = .focus
        #if canImport(FamilyControls)
        focusSelectionOverride = persisted.focusSelectionOverride
        #endif
        applyShield()

        focusTask?.cancel()
        focusTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(remaining) * 1_000_000_000)
            if Task.isCancelled { return }
            await self?.endFocusSession(completed: true)
        }
    }

    private func restorePausedFocusSession(from persisted: PersistedSessionState) {
        guard let pauseEnd = persisted.focusPauseEndsAt,
              let remainingFocus = persisted.focusState.pausedRemainingSeconds
        else {
            clearPersistedSession()
            return
        }

        if pauseEnd <= Date() {
            focusState = persisted.focusState
            #if canImport(FamilyControls)
            focusSelectionOverride = persisted.focusSelectionOverride
            #endif
            Task { [weak self] in
                await self?.resumeFocusSession()
            }
            return
        }

        focusState = persisted.focusState
        focusState.pausedRemainingSeconds = remainingFocus
        activeMode = .idle
        #if canImport(FamilyControls)
        focusSelectionOverride = persisted.focusSelectionOverride
        #endif
        focusPauseEndsAt = pauseEnd
        clearShield()

        pausedFocusTask?.cancel()
        let pauseRemaining = max(Int(pauseEnd.timeIntervalSinceNow.rounded()), 1)
        pausedFocusTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(pauseRemaining) * 1_000_000_000)
            if Task.isCancelled { return }
            await self?.resumeFocusSession()
        }
    }

    private func persistCurrentSession() {
        let mode: PersistedSessionState.Mode
        switch focusState.phase {
        case .warmUp, .running:
            mode = .focusRunning
        case .paused:
            mode = .focusPaused
        case .idle, .completed, .cancelled:
            clearPersistedSession()
            return
        }

        #if canImport(FamilyControls)
        let persisted = PersistedSessionState(
            mode: mode,
            focusState: focusState,
            focusPauseEndsAt: focusPauseEndsAt,
            focusSelectionOverride: focusSelectionOverride
        )
        #else
        let persisted = PersistedSessionState(
            mode: mode,
            focusState: focusState,
            focusPauseEndsAt: focusPauseEndsAt
        )
        #endif

        guard let data = try? JSONEncoder().encode(persisted) else { return }
        UserDefaults.standard.set(data, forKey: Self.persistedSessionKey)
    }

    private func clearPersistedSession() {
        UserDefaults.standard.removeObject(forKey: Self.persistedSessionKey)
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
        selectionSummary(for: selection)
    }

    func selectionSummary(for selection: FamilyActivitySelection) -> String {
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
