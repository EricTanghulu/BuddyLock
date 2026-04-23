import SwiftUI
#if canImport(FamilyControls)
import FamilyControls
#endif

struct HomeView: View {
    @EnvironmentObject var screenTime: ScreenTimeManager
    @ObservedObject var buddyService: LocalBuddyService
    @ObservedObject var friendRequestService: FriendRequestService
    @ObservedObject var requestService: UnlockRequestService
    @ObservedObject var challengesService: ChallengeService

    var onOpenBuddies: () -> Void = {}
    var onOpenChallenges: () -> Void = {}
    var onCreateChallenge: () -> Void = {}

    @AppStorage("BuddyLock.displayName")
    private var displayName: String = ""

    @AppStorage("BuddyLock.quickFocusMinutes")
    private var quickFocusMinutes: Int = 15

    @AppStorage("BuddyLock.quickFocusLabel")
    private var quickFocusLabel: String = "Default"

    @AppStorage("BuddyLock.loseFocusMinutes")
    private var loseFocusMinutes: Int = 5

    @AppStorage("BuddyLock.savedRoutinePresets")
    private var savedRoutinePresetsData: String = ""

    @AppStorage("BuddyLock.selectedFocusPresetID")
    private var selectedFocusPresetID: String = HomeView.defaultFocusPresetID

    @State private var showingBaselinePicker = false
    @State private var showingPresetEditor = false
    @State private var showingFocusOptions = false
    @State private var savedPresets: [HomeRoutinePreset] = []
    @State private var didLoadPresets = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                todaySection
                    .padding(.horizontal)

                if isLiveFocusState {
                    liveFocusSection
                        .padding(.horizontal)
                }

                if shouldShowSetupRoadmap {
                    setupRoadmapSection
                        .padding(.horizontal)
                }

                if shouldShowChallengePulse {
                    challengePulseSection
                        .padding(.horizontal)
                }

                if shouldShowQuickStartSection {
                    focusQuickStartSection
                        .padding(.horizontal)
                }

                if shouldShowBlockedAppsSection {
                    blockedAppsSection
                        .padding(.horizontal)
                }

                if shouldShowShortcutsSection {
                    shortcutsSection
                        .padding(.horizontal)
                }

                if shouldShowChallengeActivitySection {
                    challengeActivitySection
                        .padding(.horizontal)
                }
            }
            .padding(.vertical, 16)
        }
        .navigationTitle("Home")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showingBaselinePicker) {
            #if canImport(FamilyControls)
            NavigationStack {
                FamilyActivityPicker(selection: $screenTime.selection)
                    .navigationTitle("Choose blocked apps")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                showingBaselinePicker = false
                            }
                        }
                    }
            }
            #else
            Text("Screen Time APIs not available on this device.")
                .padding()
            #endif
        }
        .sheet(isPresented: $showingPresetEditor) {
            NavigationStack {
                HomePresetEditorView(
                    quickFocusLabel: $quickFocusLabel,
                    quickFocusMinutes: $quickFocusMinutes,
                    loseFocusMinutes: $loseFocusMinutes,
                    savedPresets: $savedPresets
                )
            }
        }
        .sheet(isPresented: $showingFocusOptions) {
            NavigationStack {
                FocusPresetPickerView(
                    quickFocusLabel: normalizedLabel(quickFocusLabel, fallback: "Default"),
                    quickFocusMinutes: quickFocusMinutes,
                    savedPresets: focusPresets,
                    selectedPresetID: $selectedFocusPresetID,
                    onEditPresets: {
                        showingFocusOptions = false
                        showingPresetEditor = true
                    }
                )
            }
        }
        .task {
            loadSavedPresetsIfNeeded()
        }
        .onChange(of: savedPresets) { _, newValue in
            persistSavedPresets(newValue)
            ensureSelectedFocusPresetStillExists(in: newValue)
        }
    }
}

private extension HomeView {
    static let defaultFocusPresetID = "default-focus"

    var todaySection: some View {
        let hero = homeHero

        return VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(greetingTitle)
                    .font(.largeTitle.bold())

                Text(statusLine)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if isLiveFocusState {
                if !hero.badges.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(hero.badges) { badge in
                                statusChip(badge.title, tint: badge.tint)
                            }
                        }
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: hero.systemImage)
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(hero.tint)
                            .frame(width: 52, height: 52)
                            .background(hero.tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Today")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)

                            Text(hero.title)
                                .font(.title2.weight(.bold))

                            Text(hero.detail)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if !hero.badges.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(hero.badges) { badge in
                                    statusChip(badge.title, tint: badge.tint)
                                }
                            }
                        }
                    }

                    Button(action: hero.primaryAction) {
                        HStack {
                            Text(hero.primaryButtonTitle)
                            Spacer()
                        }
                        .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(hero.tint)

                    if let secondaryButtonTitle = hero.secondaryButtonTitle,
                       let secondaryAction = hero.secondaryAction {
                        Button(action: secondaryAction) {
                            HStack {
                                Text(secondaryButtonTitle)
                                Spacer()
                            }
                            .font(.subheadline.weight(.semibold))
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(20)
                .background(hero.tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            }
        }
    }

    var liveFocusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                "Live focus",
                subtitle: liveFocusSubtitle
            )

            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center, spacing: 18) {
                    focusProgressRing

                    VStack(alignment: .leading, spacing: 6) {
                        Text(liveFocusHeadline)
                            .font(.headline)

                        Text(liveFocusPrimaryMetric)
                            .font(.title.weight(.bold))

                        Text(liveFocusSecondaryMetric)
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        if let tertiaryMetric = liveFocusTertiaryMetric {
                            Text(tertiaryMetric)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()
                }

                if !liveFocusTags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(liveFocusTags) { tag in
                                statusChip(tag.title, tint: tag.tint)
                            }
                        }
                    }
                }

                if let message = liveFocusChallengeMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 10) {
                    Button(liveFocusPrimaryButtonTitle, action: liveFocusPrimaryAction)
                        .font(.subheadline.weight(.semibold))
                        .buttonStyle(.borderedProminent)
                        .tint(liveFocusTint)

                    if let secondaryTitle = liveFocusSecondaryButtonTitle,
                       let secondaryAction = liveFocusSecondaryAction {
                        Button(secondaryTitle, action: secondaryAction)
                            .font(.subheadline.weight(.semibold))
                            .buttonStyle(.bordered)
                    }
                }
            }
            .homeCardStyle()
        }
    }

    var setupRoadmapSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                "Setup roadmap",
                subtitle: setupRoadmapSubtitle
            )

            VStack(alignment: .leading, spacing: 14) {
                Text(setupRoadmapHeadline)
                    .font(.headline)

                VStack(spacing: 10) {
                    ForEach(setupSteps) { step in
                        setupStepRow(step)
                    }
                }

                HStack(spacing: 10) {
                    Button(setupPrimaryActionTitle, action: setupPrimaryAction)
                        .font(.subheadline.weight(.semibold))
                        .buttonStyle(.borderedProminent)

                    if let secondaryTitle = setupSecondaryActionTitle,
                       let secondaryAction = setupSecondaryAction {
                        Button(secondaryTitle, action: secondaryAction)
                            .font(.subheadline.weight(.semibold))
                            .buttonStyle(.bordered)
                    }
                }
            }
            .homeCardStyle()
        }
    }

    var challengePulseSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                "Challenge pulse",
                subtitle: challengePulseSubtitle
            )

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: challengePulseIcon)
                        .font(.headline)
                        .foregroundStyle(challengePulseTint)
                        .frame(width: 38, height: 38)
                        .background(challengePulseTint.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(challengePulseTitle)
                            .font(.headline)
                        Text(challengePulseDetail)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }

                if !challengePulseBadges.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(challengePulseBadges) { badge in
                            statusChip(badge.title, tint: badge.tint)
                        }
                    }
                }

                HStack(spacing: 10) {
                    Button(challengePulsePrimaryButtonTitle, action: challengePulsePrimaryAction)
                        .font(.subheadline.weight(.semibold))
                        .buttonStyle(.borderedProminent)
                        .tint(challengePulseTint)

                    if let secondaryTitle = challengePulseSecondaryButtonTitle,
                       let secondaryAction = challengePulseSecondaryAction {
                        Button(secondaryTitle, action: secondaryAction)
                            .font(.subheadline.weight(.semibold))
                            .buttonStyle(.bordered)
                    }
                }
            }
            .homeCardStyle()
        }
    }

    var focusQuickStartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                sectionHeader(
                    "Quick start",
                    subtitle: quickStartSubtitle
                )

                Spacer()

                Button("Focus presets") {
                    showingFocusOptions = true
                }
                .font(.footnote.weight(.semibold))
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(displayQuickStartOptions) { option in
                        Button {
                            launchQuickStart(option)
                        } label: {
                            quickStartCard(for: option)
                        }
                        .buttonStyle(.plain)
                        .disabled(!canLaunchNewFocusSession)
                    }
                }
            }

            Text(focusQuickStartHint)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
        }
    }

    var blockedAppsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                "Blocked apps",
                subtitle: blockedAppsSubtitle
            )

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(blockedAppsHeadline)
                            .font(.headline)
                        Text(blockedAppsDetail)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Toggle("", isOn: Binding(
                        get: { screenTime.isBaselineEnabled },
                        set: { newValue in
                            if newValue {
                                screenTime.enableBaseline()
                            } else {
                                screenTime.disableBaseline()
                            }
                        })
                    )
                    .labelsHidden()
                    .disabled(!screenTime.isAuthorized)
                }

                if shouldUseCompactBlockedAppsSection {
                    Text(compactBlockedAppsDetail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if hasBlockedSelection {
                    Text(screenTime.selectionSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if !shouldUseCompactBlockedAppsSection {
                    VStack(alignment: .leading, spacing: 8) {
                        miniInfoRow(
                            icon: "sun.max.fill",
                            tint: .green,
                            title: "Baseline",
                            detail: "All-day protection when you want a standing shield."
                        )

                        miniInfoRow(
                            icon: "timer",
                            tint: .accentColor,
                            title: "Focus",
                            detail: selectedPresetUsesOwnSelection
                                ? "Your current default preset uses its own blocked app set."
                                : "Your default preset uses this same blocked app set."
                        )
                    }
                }

                Button {
                    openBlockedAppsEditor()
                } label: {
                    HStack {
                        Image(systemName: screenTime.isAuthorized ? "square.stack.3d.up" : "hand.raised.app")
                        Text(screenTime.isAuthorized ? (hasBlockedSelection ? "Edit blocked apps" : "Choose blocked apps") : "Turn on Screen Time")
                        Spacer()
                    }
                    .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.bordered)
            }
            .homeCardStyle()
        }
    }

    var shortcutsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                "Shortcuts",
                subtitle: shortcutsSubtitle
            )

            if showsCompactShortcutLayout {
                VStack(spacing: 10) {
                    compactShortcutRow(buddyShortcut)
                    compactShortcutRow(challengeShortcut)
                }
                .homeCardStyle()
            } else {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ],
                    spacing: 12
                ) {
                    shortcutCard(buddyShortcut)
                    shortcutCard(challengeShortcut)
                }
            }
        }
    }

    var challengeActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                sectionHeader(
                    "Recent challenge activity",
                    subtitle: "A lighter read on what moved lately, without pulling focus away from your next action."
                )

                Spacer()

                Button("See all") {
                    onOpenChallenges()
                }
                .font(.footnote.weight(.semibold))
            }

            VStack(spacing: 10) {
                ForEach(displayedChallengeActivity) { item in
                    challengeActivityRow(for: item)
                }
            }
            .homeCardStyle()
        }
    }

    var greetingTitle: String {
        let firstName = displayName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ")
            .first
            .map(String.init)

        let hour = Calendar.current.component(.hour, from: Date())
        let prefix: String

        switch hour {
        case 5..<12:
            prefix = "Morning"
        case 12..<17:
            prefix = "Afternoon"
        default:
            prefix = "Evening"
        }

        if let firstName, !firstName.isEmpty {
            return "\(prefix), \(firstName)"
        }

        return prefix
    }

    var statusLine: String {
        if !screenTime.isAuthorized {
            return "BuddyLock still needs Screen Time access before it can actually block distractions."
        }

        if !hasBlockedSelection {
            return "Pick blocked apps once, then Home becomes your quick launchpad."
        }

        switch screenTime.focusState.phase {
        case .paused:
            return "Your focus session is paused, so your next action should be to resume or end it."
        case .warmUp:
            return "Warm-up is running and Home is now acting like your session dashboard."
        case .running:
            return "Focus is underway and the rest of Home steps back a bit."
        case .idle, .completed, .cancelled:
            break
        }

        switch screenTime.activeMode {
        case .baseline:
            return "Baseline blocking is on and ready in the background."
        case .panic:
            return "Panic block is running right now."
        case .essentialsOnly:
            return "Lock in mode is active."
        case .idle, .focus:
            if activeChallengesCount > 0 {
                return "You have \(activeChallengesCount) live challenge\(activeChallengesCount == 1 ? "" : "s") ready for more minutes."
            }
            return "Everything is set up for your next session."
        }
    }

    var pendingFriendRequestsCount: Int {
        friendRequestService.incomingRequests.count
    }

    var pendingApprovalsCount: Int {
        requestService.incoming.filter { requestService.canCurrentUserRespond(to: $0) }.count
    }

    var outgoingPendingCount: Int {
        requestService.outgoing.filter { $0.decision == .pending }.count
    }

    var activeChallenges: [Challenge] {
        challengesService.challenges.filter { $0.phase() == .active }
    }

    var upcomingChallenges: [Challenge] {
        challengesService.challenges.filter { $0.phase() == .upcoming }
    }

    var recentChallengeActivity: [ChallengeActivityItem] {
        Array(challengesService.activity.prefix(2))
    }

    var activeChallengesCount: Int {
        activeChallenges.count
    }

    var canLaunchNewFocusSession: Bool {
        switch screenTime.focusState.phase {
        case .idle, .completed, .cancelled:
            return true
        case .warmUp, .running, .paused:
            return false
        }
    }

    var hasBlockedSelection: Bool {
        !screenTime.selectionSummary.isEmpty
    }

    var focusPresets: [HomeRoutinePreset] { savedPresets }

    var selectedFocusPreset: HomeRoutinePreset? {
        guard selectedFocusPresetID != Self.defaultFocusPresetID else { return nil }
        return focusPresets.first { $0.id.uuidString == selectedFocusPresetID }
    }

    var selectedFocusTitle: String {
        if let selectedFocusPreset {
            return selectedFocusPreset.title
        }

        return normalizedLabel(quickFocusLabel, fallback: "Default")
    }

    var selectedFocusMinutes: Int {
        selectedFocusPreset?.minutes ?? quickFocusMinutes
    }

    var selectedFocusDetail: String {
        "\(selectedFocusTitle) • \(durationLabel(for: selectedFocusMinutes))"
    }

    var isLiveFocusState: Bool {
        switch screenTime.focusState.phase {
        case .warmUp, .running, .paused:
            return true
        case .idle, .completed, .cancelled:
            return false
        }
    }

    var shouldShowQuickStartSection: Bool {
        canLaunchNewFocusSession && screenTime.isAuthorized && hasBlockedSelection
    }

    var shouldShowBlockedAppsSection: Bool {
        !isLiveFocusState
    }

    var shouldShowShortcutsSection: Bool {
        !isLiveFocusState
    }

    var shouldShowChallengeActivitySection: Bool {
        !isLiveFocusState && !shouldShowSetupRoadmap && !recentChallengeActivity.isEmpty
    }

    var shouldShowSetupRoadmap: Bool {
        !isLiveFocusState && (!screenTime.isAuthorized || !hasBlockedSelection || buddyService.buddies.isEmpty)
    }

    var shouldShowChallengePulse: Bool {
        !isLiveFocusState && (activeChallengesCount > 0 || !upcomingChallenges.isEmpty || (!recentChallengeActivity.isEmpty && !shouldShowSetupRoadmap))
    }

    var hasUrgentBuddyShortcut: Bool {
        pendingApprovalsCount > 0 || pendingFriendRequestsCount > 0 || outgoingPendingCount > 0
    }

    var hasUrgentChallengeShortcut: Bool {
        activeChallengesCount > 0 || !upcomingChallenges.isEmpty
    }

    var hasUrgentShortcutContent: Bool {
        hasUrgentBuddyShortcut || hasUrgentChallengeShortcut
    }

    var showsCompactShortcutLayout: Bool {
        !hasUrgentShortcutContent
    }

    var quickStartOptions: [FocusQuickStartOption] {
        [
            FocusQuickStartOption(
                id: Self.defaultFocusPresetID,
                title: "\(normalizedLabel(quickFocusLabel, fallback: "Default"))",
                detail: durationLabel(for: quickFocusMinutes),
                isSelected: selectedFocusPresetID == Self.defaultFocusPresetID
            )
        ] + focusPresets.map { preset in
            FocusQuickStartOption(
                id: preset.id.uuidString,
                title: preset.title,
                detail: durationLabel(for: preset.minutes),
                isSelected: selectedFocusPresetID == preset.id.uuidString
            )
        }
    }

    var displayQuickStartOptions: [FocusQuickStartOption] {
        let preferredID = selectedFocusPresetID
        return quickStartOptions.sorted { lhs, rhs in
            switch (lhs.id == preferredID, rhs.id == preferredID) {
            case (true, false):
                return true
            case (false, true):
                return false
            default:
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
        }
    }

    var focusQuickStartHint: String {
        if !screenTime.isAuthorized {
            return "Turn on Screen Time before starting focus."
        }

        if !hasBlockedSelection {
            return "Pick blocked apps before your first session so focus mode has something to block."
        }

        switch screenTime.focusState.phase {
        case .paused:
            return "Resume or end your paused session before starting a new one."
        case .warmUp, .running:
            return "A focus session is already in progress."
        case .idle, .completed, .cancelled:
            return "Tap any card to start immediately. Set one as your default, then customize the row when your routine changes."
        }
    }

    var quickStartSubtitle: String {
        if shouldShowSetupRoadmap {
            return "These are your pinned one-tap focus launches. Once setup is done, this row becomes the fastest part of Home."
        }

        return "Tap any card to start immediately. Use Focus presets when you want to change the default or edit the list."
    }

    var blockedAppsHeadline: String {
        if !screenTime.isAuthorized {
            return "Screen Time is still off"
        }

        if !hasBlockedSelection {
            return "No blocked apps picked yet"
        }

        if screenTime.isBaselineEnabled {
            return "You're protected"
        }

        return compactSelectionSummary
    }

    var blockedAppsDetail: String {
        if !screenTime.isAuthorized {
            return "Enable access so BuddyLock can actually enforce your blocks."
        }

        if !hasBlockedSelection {
            return "Choose the apps, categories, and websites you want Home to protect by default."
        }

        return screenTime.isBaselineEnabled
            ? "Baseline blocking is on, so these stay protected even when no focus session is running."
            : "Baseline blocking is off right now. These still apply during focus sessions and locks."
    }

    var blockedAppsSubtitle: String {
        if !screenTime.isAuthorized {
            return "This section explains what gets blocked and when, so the difference between all-day protection and timed focus is easier to trust."
        }

        if shouldUseCompactBlockedAppsSection {
            return "This stays compact once setup is complete, so protection stays easy to verify without taking over the page."
        }

        return "This is your protection layer. Baseline keeps it on all day; focus turns it into a timed session."
    }

    var shouldUseCompactBlockedAppsSection: Bool {
        screenTime.isAuthorized && hasBlockedSelection && !shouldShowSetupRoadmap
    }

    var compactBlockedAppsDetail: String {
        let focusSource = selectedPresetUsesOwnSelection
            ? "Your default preset uses its own blocked apps."
            : "Your default preset uses this set."

        return screenTime.isBaselineEnabled
            ? "Baseline is on. \(focusSource)"
            : "Baseline is off. \(focusSource)"
    }

    var compactSelectionSummary: String {
        #if canImport(FamilyControls)
        let selection = screenTime.selection
        var parts: [String] = []

        if !selection.applicationTokens.isEmpty {
            parts.append("\(selection.applicationTokens.count) app\(selection.applicationTokens.count == 1 ? "" : "s")")
        }

        if !selection.categoryTokens.isEmpty {
            parts.append("\(selection.categoryTokens.count) categor\(selection.categoryTokens.count == 1 ? "y" : "ies")")
        }

        if !selection.webDomainTokens.isEmpty {
            parts.append("\(selection.webDomainTokens.count) site\(selection.webDomainTokens.count == 1 ? "" : "s")")
        }

        return parts.isEmpty ? "Blocked apps ready" : parts.joined(separator: " • ")
        #else
        return screenTime.selectionSummary
        #endif
    }

    var selectedPresetUsesOwnSelection: Bool {
        #if canImport(FamilyControls)
        return selectedFocusPreset?.selection.hasSelections ?? false
        #else
        return false
        #endif
    }

    var buddyShortcut: HomeShortcutInfo {
        if pendingApprovalsCount > 0 {
            return HomeShortcutInfo(
                title: "Review approvals",
                detail: "\(pendingApprovalsCount) unlock decision\(pendingApprovalsCount == 1 ? "" : "s") need your response.",
                buttonTitle: "Review approvals",
                systemImage: "checkmark.seal.fill",
                tint: .green,
                action: onOpenBuddies
            )
        }

        if pendingFriendRequestsCount > 0 {
            return HomeShortcutInfo(
                title: "Buddy requests waiting",
                detail: "\(pendingFriendRequestsCount) new request\(pendingFriendRequestsCount == 1 ? "" : "s") came in.",
                buttonTitle: "Accept requests",
                systemImage: "person.badge.plus",
                tint: .blue,
                action: onOpenBuddies
            )
        }

        if outgoingPendingCount > 0 {
            return HomeShortcutInfo(
                title: "Pending unlocks",
                detail: "\(outgoingPendingCount) request\(outgoingPendingCount == 1 ? "" : "s") still need a buddy response.",
                buttonTitle: "Check unlocks",
                systemImage: "hourglass",
                tint: .orange,
                action: onOpenBuddies
            )
        }

        if buddyService.buddies.isEmpty {
            return HomeShortcutInfo(
                title: "Add your first buddy",
                detail: "One real person makes the accountability side of BuddyLock much more useful.",
                buttonTitle: "Add buddy",
                systemImage: "person.2",
                tint: .purple,
                action: onOpenBuddies
            )
        }

        return HomeShortcutInfo(
            title: "Your buddy network",
            detail: "\(buddyService.buddies.count) buddy\(buddyService.buddies.count == 1 ? "" : "ies") are already in your corner.",
            buttonTitle: "Manage buddies",
            systemImage: "person.2.fill",
            tint: .purple,
            action: onOpenBuddies
        )
    }

    var challengeShortcut: HomeShortcutInfo {
        if activeChallengesCount > 0 {
            return HomeShortcutInfo(
                title: "Live challenges",
                detail: activeChallengesCount == 1
                    ? "One challenge is active right now."
                    : "\(activeChallengesCount) challenges are active right now.",
                buttonTitle: "View standings",
                systemImage: "flag.checkered",
                tint: .blue,
                action: onOpenChallenges
            )
        }

        if !upcomingChallenges.isEmpty {
            return HomeShortcutInfo(
                title: "Starting soon",
                detail: "\(upcomingChallenges.count) challenge\(upcomingChallenges.count == 1 ? "" : "s") will start soon.",
                buttonTitle: "See schedule",
                systemImage: "calendar",
                tint: .orange,
                action: onOpenChallenges
            )
        }

        if buddyService.buddies.isEmpty {
            return HomeShortcutInfo(
                title: "Challenges need people",
                detail: "Add a buddy first so a duel or group challenge actually has someone to involve.",
                buttonTitle: "Add buddies",
                systemImage: "person.3",
                tint: .secondary,
                action: onOpenBuddies
            )
        }

        return HomeShortcutInfo(
            title: "Start a challenge",
            detail: "A quick duel is the fastest way to add some friendly pressure to your next session.",
            buttonTitle: "Create duel",
            systemImage: "flag.2.crossed",
            tint: .orange,
            action: onCreateChallenge
        )
    }

    var shortcutsSubtitle: String {
        if showsCompactShortcutLayout {
            return "Nothing urgent is waiting, so these stay lighter and easier to skim."
        }

        if shouldShowSetupRoadmap {
            return "These shortcuts stay specific to what needs attention, instead of sending you to a generic tab."
        }

        return "These stay targeted, so Home routes you into the exact next task instead of just a generic destination."
    }

    var displayedChallengeActivity: [ChallengeActivityItem] {
        Array(recentChallengeActivity.prefix(hasUrgentChallengeShortcut ? 2 : 1))
    }

    var heroBadges: [HomeBadge] {
        var badges: [HomeBadge] = []

        if screenTime.isBaselineEnabled {
            badges.append(HomeBadge(title: "Baseline on", tint: .green))
        }

        if activeChallengesCount > 0 {
            badges.append(HomeBadge(title: "\(activeChallengesCount) live challenge\(activeChallengesCount == 1 ? "" : "s")", tint: .blue))
        }

        if buddyService.buddies.count > 0 {
            badges.append(HomeBadge(title: "\(buddyService.buddies.count) buddy\(buddyService.buddies.count == 1 ? "" : "ies")", tint: .purple))
        }

        return badges
    }

    var setupSteps: [HomeSetupStep] {
        [
            HomeSetupStep(
                title: "Turn on Screen Time",
                detail: "BuddyLock can only block apps after permission is enabled.",
                isComplete: screenTime.isAuthorized
            ),
            HomeSetupStep(
                title: "Choose blocked apps",
                detail: "Pick what focus mode should actually protect.",
                isComplete: hasBlockedSelection
            ),
            HomeSetupStep(
                title: "Add a buddy",
                detail: "Bring in one real person so accountability features feel useful.",
                isComplete: !buddyService.buddies.isEmpty
            )
        ]
    }

    var completedSetupSteps: Int {
        setupSteps.filter(\.isComplete).count
    }

    var setupRoadmapHeadline: String {
        if completedSetupSteps == setupSteps.count {
            return "Your setup is complete"
        }

        return "Setup progress: \(completedSetupSteps)/\(setupSteps.count)"
    }

    var setupRoadmapSubtitle: String {
        if screenTime.isAuthorized && hasBlockedSelection && buddyService.buddies.isEmpty {
            return "The solo focus side is ready. One buddy is the remaining step that makes Home feel more social and accountable."
        }

        return "Home changes quite a bit as setup fills in, so this keeps the remaining steps obvious instead of scattered."
    }

    var setupPrimaryActionTitle: String {
        if !screenTime.isAuthorized {
            return "Turn on Screen Time"
        }

        if !hasBlockedSelection {
            return "Choose blocked apps"
        }

        return "Open Buddies"
    }

    var setupPrimaryAction: () -> Void {
        if !screenTime.isAuthorized {
            return {
                Task {
                    await screenTime.requestAuthorization()
                }
            }
        }

        if !hasBlockedSelection {
            return openBlockedAppsEditor
        }

        return onOpenBuddies
    }

    var setupSecondaryActionTitle: String? {
        if !buddyService.buddies.isEmpty {
            return nil
        }

        if !screenTime.isAuthorized || !hasBlockedSelection {
            return "Open Buddies"
        }

        return nil
    }

    var setupSecondaryAction: (() -> Void)? {
        guard setupSecondaryActionTitle != nil else { return nil }
        return onOpenBuddies
    }

    var liveFocusTint: Color {
        switch screenTime.focusState.phase {
        case .paused:
            return .orange
        case .warmUp, .running:
            return .accentColor
        case .idle, .completed, .cancelled:
            return .secondary
        }
    }

    var liveFocusSubtitle: String {
        switch screenTime.focusState.phase {
        case .warmUp:
            return "This stays focused on the session itself while warm-up runs."
        case .running:
            return "This is the live state of your current session, without the rest of Home competing for attention."
        case .paused:
            return "Pause is treated like its own focused state, not just a warning banner."
        case .idle, .completed, .cancelled:
            return ""
        }
    }

    var liveFocusHeadline: String {
        switch screenTime.focusState.phase {
        case .warmUp:
            return "Warm-up in progress"
        case .running:
            return "Focus session active"
        case .paused:
            return "Focus paused"
        case .idle, .completed, .cancelled:
            return "Focus"
        }
    }

    var liveFocusPrimaryMetric: String {
        switch screenTime.focusState.phase {
        case .paused:
            return remainingText(until: screenTime.focusPauseEndsAt) ?? "Pause active"
        case .warmUp:
            return remainingText(until: screenTime.focusState.warmUpEndsAt) ?? "Starting"
        case .running:
            return remainingText(until: screenTime.focusState.endsAt) ?? "Running"
        case .idle, .completed, .cancelled:
            return selectedFocusDetail
        }
    }

    var liveFocusSecondaryMetric: String {
        switch screenTime.focusState.phase {
        case .paused:
            if let focusRemaining = screenTime.focusState.secondsRemaining {
                return "\(durationLabel(for: max(1, focusRemaining / 60))) remaining in session"
            }
            return "Resume when you're ready or end the session."
        case .warmUp:
            return "\(selectedFocusTitle) will start right after warm-up."
        case .running:
            return selectedPresetUsesOwnSelection
                ? "Using your preset’s custom blocked apps."
                : "Using your default blocked apps."
        case .idle, .completed, .cancelled:
            return "Ready"
        }
    }

    var liveFocusTertiaryMetric: String? {
        switch screenTime.focusState.phase {
        case .paused:
            if let focusPauseEndsAt = screenTime.focusPauseEndsAt {
                return "Pause ends \(focusPauseEndsAt.formatted(date: .omitted, time: .shortened))"
            }
            return nil
        case .warmUp, .running:
            return nil
        case .idle, .completed, .cancelled:
            return nil
        }
    }

    var liveFocusPrimaryButtonTitle: String {
        switch screenTime.focusState.phase {
        case .paused:
            return "Resume focus"
        case .warmUp, .running:
            return "Pause for \(loseFocusMinutes)m"
        case .idle, .completed, .cancelled:
            return "Start focus"
        }
    }

    var liveFocusPrimaryAction: () -> Void {
        switch screenTime.focusState.phase {
        case .paused:
            return {
                Task {
                    await screenTime.resumeFocusSession()
                }
            }
        case .warmUp, .running:
            return {
                screenTime.pauseFocusSession(for: loseFocusMinutes)
            }
        case .idle, .completed, .cancelled:
            return launchSelectedFocus
        }
    }

    var liveFocusSecondaryButtonTitle: String? {
        switch screenTime.focusState.phase {
        case .paused:
            return "End session"
        case .warmUp, .running:
            return activeChallengesCount > 0 ? "View standings" : "Edit blocked apps"
        case .idle, .completed, .cancelled:
            return nil
        }
    }

    var liveFocusSecondaryAction: (() -> Void)? {
        switch screenTime.focusState.phase {
        case .paused:
            return {
                Task {
                    await screenTime.endFocusSession(completed: false)
                }
            }
        case .warmUp, .running:
            return activeChallengesCount > 0 ? onOpenChallenges : openBlockedAppsEditor
        case .idle, .completed, .cancelled:
            return nil
        }
    }

    var liveFocusTags: [HomeBadge] {
        var tags: [HomeBadge] = []

        if selectedPresetUsesOwnSelection {
            tags.append(HomeBadge(title: "Preset-specific apps", tint: .accentColor))
        } else if hasBlockedSelection {
            tags.append(HomeBadge(title: compactSelectionSummary, tint: .green))
        }

        if activeChallengesCount > 0 {
            tags.append(HomeBadge(title: "\(activeChallengesCount) challenge\(activeChallengesCount == 1 ? "" : "s") affected", tint: .blue))
        }

        return tags
    }

    var liveFocusChallengeMessage: String? {
        guard activeChallengesCount > 0 else { return nil }

        if let insight = leadingChallengeInsight {
            if insight.deficit == 0 {
                return "You’re currently leading \(insight.challenge.resolvedTitle). Staying with this session helps protect that lead."
            }

            return "You’re \(insight.deficit)m behind in \(insight.challenge.resolvedTitle). Finishing this block can close the gap."
        }

        return "Any completed focus minutes can support your live challenges."
    }

    var liveFocusProgress: Double {
        switch screenTime.focusState.phase {
        case .running:
            guard let end = screenTime.focusState.endsAt,
                  let started = screenTime.focusState.startedAt else { return 0 }
            let total = max(end.timeIntervalSince(started), 1)
            let remaining = max(end.timeIntervalSinceNow, 0)
            return min(max(1 - (remaining / total), 0), 1)
        case .warmUp:
            guard let warmUpEndsAt = screenTime.focusState.warmUpEndsAt else { return 0.1 }
            let total = max(warmUpEndsAt.timeIntervalSince(Date()), 1)
            let remaining = max(warmUpEndsAt.timeIntervalSinceNow, 0)
            let progress = 1 - (remaining / total)
            return min(max(progress, 0.05), 1)
        case .paused:
            return 0.5
        case .idle, .completed, .cancelled:
            return 0
        }
    }

    var challengePulseSubtitle: String {
        if activeChallengesCount > 0 {
            return "This moves the challenge context higher so Home connects focus and accountability instead of treating them like separate tabs."
        }

        return "Even when nothing is live right now, Home should still tell you what is coming next."
    }

    var leadingChallengeInsight: ChallengeLeadInsight? {
        let insights = activeChallenges.compactMap { challenge -> ChallengeLeadInsight? in
            let yourMinutes = challenge.scores[challengesService.localUserID] ?? 0
            guard let leader = challenge.scores.max(by: { $0.value < $1.value }) else { return nil }
            let deficit = max(leader.value - yourMinutes, 0)
            let leaderName = leader.key == challengesService.localUserID ? "You" : buddyService.displayName(for: leader.key)

            return ChallengeLeadInsight(
                challenge: challenge,
                deficit: deficit,
                leaderName: leaderName,
                yourMinutes: yourMinutes,
                leaderMinutes: leader.value
            )
        }

        return insights.sorted { lhs, rhs in
            lhs.deficit < rhs.deficit
        }.first
    }

    var challengePulseTitle: String {
        if activeChallengesCount > 0, let insight = leadingChallengeInsight {
            if insight.deficit == 0 {
                return "You’re leading \(insight.challenge.resolvedTitle)"
            }

            return "\(insight.deficit)m would catch up in \(insight.challenge.resolvedTitle)"
        }

        if !upcomingChallenges.isEmpty {
            return upcomingChallenges.count == 1
                ? "\(upcomingChallenges[0].resolvedTitle) starts soon"
                : "\(upcomingChallenges.count) challenges start soon"
        }

        return "Challenge momentum is quiet"
    }

    var challengePulseDetail: String {
        if activeChallengesCount > 0, let insight = leadingChallengeInsight {
            if insight.deficit == 0 {
                return "You have \(insight.yourMinutes)m logged there already. A fresh session helps you keep the pace."
            }

            return "\(insight.leaderName) currently has \(insight.leaderMinutes)m. Your next focus block can narrow that gap."
        }

        if let next = upcomingChallenges.sorted(by: { $0.startDate < $1.startDate }).first {
            return "\(next.resolvedTitle) begins \(next.startDate.formatted(date: .abbreviated, time: .omitted))."
        }

        return "Creating one quick duel is still the fastest way to make Home feel more alive."
    }

    var challengePulseIcon: String {
        if activeChallengesCount > 0 {
            return leadingChallengeInsight?.deficit == 0 ? "crown.fill" : "chart.line.uptrend.xyaxis"
        }

        return !upcomingChallenges.isEmpty ? "calendar.badge.clock" : "flag"
    }

    var challengePulseTint: Color {
        if activeChallengesCount > 0 {
            return leadingChallengeInsight?.deficit == 0 ? .green : .orange
        }

        return !upcomingChallenges.isEmpty ? .blue : .secondary
    }

    var challengePulseBadges: [HomeBadge] {
        var badges: [HomeBadge] = []

        if activeChallengesCount > 0 {
            badges.append(HomeBadge(title: "\(activeChallengesCount) live", tint: .blue))
        }

        if !upcomingChallenges.isEmpty {
            badges.append(HomeBadge(title: "\(upcomingChallenges.count) upcoming", tint: .orange))
        }

        return badges
    }

    var challengePulsePrimaryButtonTitle: String {
        if activeChallengesCount > 0 {
            return "View standings"
        }

        if !upcomingChallenges.isEmpty {
            return "See challenge list"
        }

        return "Create challenge"
    }

    var challengePulsePrimaryAction: () -> Void {
        if activeChallengesCount > 0 || !upcomingChallenges.isEmpty {
            return onOpenChallenges
        }

        return onCreateChallenge
    }

    var challengePulseSecondaryButtonTitle: String? {
        if activeChallengesCount > 0 {
            return canLaunchNewFocusSession ? "Start focus" : nil
        }

        return buddyService.buddies.isEmpty ? "Add buddies" : nil
    }

    var challengePulseSecondaryAction: (() -> Void)? {
        if activeChallengesCount > 0 {
            return canLaunchNewFocusSession ? launchSelectedFocus : nil
        }

        return buddyService.buddies.isEmpty ? onOpenBuddies : nil
    }

    var homeHero: HomeHero {
        if !screenTime.isAuthorized {
            return HomeHero(
                title: "Turn on Screen Time first",
                detail: "BuddyLock cannot block apps, run focus sessions, or make unlock approvals meaningful until this permission is enabled.",
                systemImage: "hand.raised.app.fill",
                tint: .accentColor,
                primaryButtonTitle: "Turn on Screen Time",
                primaryAction: {
                    Task {
                        await screenTime.requestAuthorization()
                    }
                },
                secondaryButtonTitle: nil,
                secondaryAction: nil,
                badges: heroBadges
            )
        }

        if !hasBlockedSelection {
            return HomeHero(
                title: "Choose what to block",
                detail: "Pick your distractions once so every focus session from Home actually has something to protect.",
                systemImage: "square.stack.3d.up.fill",
                tint: .orange,
                primaryButtonTitle: "Choose blocked apps",
                primaryAction: openBlockedAppsEditor,
                secondaryButtonTitle: buddyService.buddies.isEmpty ? "Open Buddies" : nil,
                secondaryAction: buddyService.buddies.isEmpty ? onOpenBuddies : nil,
                badges: heroBadges
            )
        }

        switch screenTime.focusState.phase {
        case .paused:
            return HomeHero(
                title: "Resume your focus",
                detail: pausedFocusText ?? "Your session is paused and waiting for you.",
                systemImage: "pause.circle.fill",
                tint: .orange,
                primaryButtonTitle: "Resume focus",
                primaryAction: {
                    Task {
                        await screenTime.resumeFocusSession()
                    }
                },
                secondaryButtonTitle: "End session",
                secondaryAction: {
                    Task {
                        await screenTime.endFocusSession(completed: false)
                    }
                },
                badges: heroBadges
            )
        case .warmUp:
            return HomeHero(
                title: "Your focus session is starting",
                detail: focusRunningDetail,
                systemImage: "timer",
                tint: .accentColor,
                primaryButtonTitle: "Pause for \(loseFocusMinutes)m",
                primaryAction: {
                    screenTime.pauseFocusSession(for: loseFocusMinutes)
                },
                secondaryButtonTitle: activeChallengesCount > 0 ? "See challenges" : nil,
                secondaryAction: activeChallengesCount > 0 ? onOpenChallenges : nil,
                badges: heroBadges
            )
        case .running:
            return HomeHero(
                title: "Stay with this focus block",
                detail: focusRunningDetail,
                systemImage: "timer.circle.fill",
                tint: .accentColor,
                primaryButtonTitle: "Pause for \(loseFocusMinutes)m",
                primaryAction: {
                    screenTime.pauseFocusSession(for: loseFocusMinutes)
                },
                secondaryButtonTitle: activeChallengesCount > 0 ? "See challenges" : "Edit blocked apps",
                secondaryAction: activeChallengesCount > 0 ? onOpenChallenges : openBlockedAppsEditor,
                badges: heroBadges
            )
        case .idle, .completed, .cancelled:
            break
        }

        switch screenTime.activeMode {
        case .panic:
            return HomeHero(
                title: "Panic block is running",
                detail: remainingText(until: screenTime.panicEndsAt) ?? "Your emergency block is active right now.",
                systemImage: "exclamationmark.shield.fill",
                tint: .red,
                primaryButtonTitle: "End panic block",
                primaryAction: {
                    Task {
                        await screenTime.endPanicBlock()
                    }
                },
                secondaryButtonTitle: "Edit blocked apps",
                secondaryAction: openBlockedAppsEditor,
                badges: heroBadges
            )
        case .essentialsOnly:
            return HomeHero(
                title: "Lock in mode is active",
                detail: remainingText(until: screenTime.essentialsModeEndsAt) ?? "Only your essentials should be reachable right now.",
                systemImage: "lock.shield.fill",
                tint: .indigo,
                primaryButtonTitle: "End lock in mode",
                primaryAction: {
                    Task {
                        await screenTime.endEssentialsOnlyMode()
                    }
                },
                secondaryButtonTitle: nil,
                secondaryAction: nil,
                badges: heroBadges
            )
        case .idle, .baseline, .focus:
            break
        }

        if pendingApprovalsCount > 0 {
            return HomeHero(
                title: "Buddy decisions are waiting",
                detail: "\(pendingApprovalsCount) unlock decision\(pendingApprovalsCount == 1 ? "" : "s") need your response before someone can get back into a blocked app.",
                systemImage: "checkmark.seal.fill",
                tint: .green,
                primaryButtonTitle: "Review approvals",
                primaryAction: onOpenBuddies,
                secondaryButtonTitle: canLaunchNewFocusSession ? "Start focus" : nil,
                secondaryAction: canLaunchNewFocusSession ? launchSelectedFocus : nil,
                badges: heroBadges
            )
        }

        if pendingFriendRequestsCount > 0 {
            return HomeHero(
                title: "Your buddy inbox needs attention",
                detail: "\(pendingFriendRequestsCount) new request\(pendingFriendRequestsCount == 1 ? "" : "s") came in.",
                systemImage: "person.badge.plus",
                tint: .blue,
                primaryButtonTitle: "Review buddy requests",
                primaryAction: onOpenBuddies,
                secondaryButtonTitle: nil,
                secondaryAction: nil,
                badges: heroBadges
            )
        }

        if outgoingPendingCount > 0 {
            return HomeHero(
                title: "You’re waiting on your buddies",
                detail: "\(outgoingPendingCount) unlock request\(outgoingPendingCount == 1 ? "" : "s") are still pending right now.",
                systemImage: "hourglass",
                tint: .orange,
                primaryButtonTitle: "Check request status",
                primaryAction: onOpenBuddies,
                secondaryButtonTitle: nil,
                secondaryAction: nil,
                badges: heroBadges
            )
        }

        return HomeHero(
            title: "Your next focus block is ready",
            detail: activeChallengesCount > 0
                ? "\(selectedFocusDetail) is queued up, and your live challenges are waiting for more minutes."
                : "\(selectedFocusDetail) is set as your fastest path back into focus.",
            systemImage: "play.circle.fill",
            tint: .accentColor,
            primaryButtonTitle: "Start \(selectedFocusTitle)",
            primaryAction: launchSelectedFocus,
            secondaryButtonTitle: buddyService.buddies.isEmpty ? "Open Buddies" : "Create challenge",
            secondaryAction: buddyService.buddies.isEmpty ? onOpenBuddies : onCreateChallenge,
            badges: heroBadges
        )
    }

    func loadSavedPresetsIfNeeded() {
        guard !didLoadPresets else { return }
        didLoadPresets = true
        savedPresets = decodeSavedPresets(from: savedRoutinePresetsData)
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        ensureSelectedFocusPresetStillExists(in: savedPresets)
    }

    func persistSavedPresets(_ presets: [HomeRoutinePreset]) {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(presets),
           let string = String(data: data, encoding: .utf8) {
            savedRoutinePresetsData = string
        } else {
            savedRoutinePresetsData = ""
        }
    }

    func decodeSavedPresets(from string: String) -> [HomeRoutinePreset] {
        guard let data = string.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([HomeRoutinePreset].self, from: data)) ?? []
    }

    func remainingText(until endDate: Date?) -> String? {
        guard let endDate else { return nil }
        let seconds = max(Int(endDate.timeIntervalSinceNow.rounded()), 0)
        return "\(formatMinutes(seconds)) left"
    }

    var pausedFocusText: String? {
        if let pauseEnd = remainingText(until: screenTime.focusPauseEndsAt),
           let focusRemaining = screenTime.focusState.secondsRemaining {
            return "\(pauseEnd) pause • \(durationLabel(for: max(1, focusRemaining / 60))) remaining"
        }

        if let focusRemaining = screenTime.focusState.secondsRemaining {
            return "\(durationLabel(for: max(1, focusRemaining / 60))) remaining"
        }

        return nil
    }

    func durationLabel(for minutes: Int) -> String {
        if minutes % 60 == 0 {
            let hours = minutes / 60
            return hours == 1 ? "1 hour" : "\(hours) hours"
        }

        return "\(minutes) min"
    }

    var focusRunningDetail: String {
        switch screenTime.focusState.phase {
        case .warmUp:
            if let warmUpEndsAt = screenTime.focusState.warmUpEndsAt {
                return "\(remainingText(until: warmUpEndsAt) ?? "A moment left") until the real focus block starts."
            }
            return "Warm-up is running."
        case .running:
            if let secondsRemaining = screenTime.focusState.secondsRemaining {
                return "\(durationLabel(for: max(1, secondsRemaining / 60))) remaining in this session."
            }
            return "Your focus timer is active."
        case .paused, .idle, .completed, .cancelled:
            return selectedFocusDetail
        }
    }

    func runPreset(_ preset: HomeRoutinePreset) {
        #if canImport(FamilyControls)
        let overrideSelection = preset.selection.hasSelections ? preset.selection : nil
        screenTime.startFocusSession(minutes: preset.minutes, warmUpSeconds: 0, selectionOverride: overrideSelection)
        #else
        screenTime.startFocusSession(minutes: preset.minutes, warmUpSeconds: 0)
        #endif
    }

    func startSelectedFocus() {
        guard screenTime.isAuthorized, hasBlockedSelection, canLaunchNewFocusSession else { return }

        if let selectedFocusPreset {
            runPreset(selectedFocusPreset)
        } else {
            screenTime.startFocusSession(minutes: quickFocusMinutes, warmUpSeconds: 0)
        }
    }

    func launchSelectedFocus() {
        guard canLaunchNewFocusSession else { return }

        if !screenTime.isAuthorized {
            Task {
                await screenTime.requestAuthorization()
            }
            return
        }

        guard hasBlockedSelection else {
            showingBaselinePicker = true
            return
        }

        startSelectedFocus()
    }

    func launchQuickStart(_ option: FocusQuickStartOption) {
        guard canLaunchNewFocusSession else { return }

        selectedFocusPresetID = option.id

        if option.id == Self.defaultFocusPresetID {
            launchSelectedFocus()
            return
        }

        if !screenTime.isAuthorized {
            Task {
                await screenTime.requestAuthorization()
            }
            return
        }

        guard hasBlockedSelection else {
            showingBaselinePicker = true
            return
        }

        guard let preset = focusPresets.first(where: { $0.id.uuidString == option.id }) else { return }
        runPreset(preset)
    }

    func openBlockedAppsEditor() {
        if screenTime.isAuthorized {
            showingBaselinePicker = true
        } else {
            Task {
                await screenTime.requestAuthorization()
            }
        }
    }

    func ensureSelectedFocusPresetStillExists(in presets: [HomeRoutinePreset]) {
        guard selectedFocusPresetID != Self.defaultFocusPresetID else { return }

        let availableIDs = Set(presets.map { $0.id.uuidString })
        if !availableIDs.contains(selectedFocusPresetID) {
            selectedFocusPresetID = Self.defaultFocusPresetID
        }
    }

    func quickStartCard(for option: FocusQuickStartOption) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: option.isSelected ? "star.circle.fill" : "timer")
                    .font(.headline)
                    .foregroundStyle(option.isSelected ? Color.accentColor : Color.orange)
                    .frame(width: 38, height: 38)
                    .background((option.isSelected ? Color.accentColor : Color.orange).opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                Spacer()

                if option.isSelected {
                    statusChip("Default", tint: .accentColor)
                }
            }

            Text(option.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            Text(option.detail)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(option.isSelected ? "This is your default preset." : "Tap to start immediately.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(width: 180, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .opacity(canLaunchNewFocusSession ? 1 : 0.55)
    }

    func shortcutCard(_ info: HomeShortcutInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: info.systemImage)
                .font(.headline)
                .foregroundStyle(info.tint)
                .frame(width: 38, height: 38)
                .background(info.tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            Text(info.title)
                .font(.headline)
                .foregroundStyle(.primary)

            Text(info.detail)
                .font(.footnote)
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            Button(info.buttonTitle, action: info.action)
                .font(.subheadline.weight(.semibold))
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, minHeight: 180, alignment: .leading)
        .homeCardStyle()
    }

    func compactShortcutRow(_ info: HomeShortcutInfo) -> some View {
        Button(action: info.action) {
            HStack(spacing: 12) {
                Image(systemName: info.systemImage)
                    .font(.headline)
                    .foregroundStyle(info.tint)
                    .frame(width: 36, height: 36)
                    .background(info.tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(info.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(info.buttonTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }

    var focusProgressRing: some View {
        ZStack {
            Circle()
                .stroke(liveFocusTint.opacity(0.14), lineWidth: 10)

            Circle()
                .trim(from: 0, to: liveFocusProgress)
                .stroke(liveFocusTint, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))

            VStack(spacing: 2) {
                Text(progressRingLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(progressRingValue)
                    .font(.title3.weight(.bold))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
        }
        .frame(width: 110, height: 110)
    }

    var progressRingLabel: String {
        switch screenTime.focusState.phase {
        case .warmUp:
            return "Warm-up"
        case .running:
            return "Remaining"
        case .paused:
            return "Paused"
        case .idle, .completed, .cancelled:
            return "Ready"
        }
    }

    var progressRingValue: String {
        switch screenTime.focusState.phase {
        case .warmUp:
            return remainingText(until: screenTime.focusState.warmUpEndsAt) ?? "--"
        case .running:
            return remainingText(until: screenTime.focusState.endsAt) ?? "--"
        case .paused:
            return remainingText(until: screenTime.focusPauseEndsAt) ?? "--"
        case .idle, .completed, .cancelled:
            return selectedFocusDetail
        }
    }

    func setupStepRow(_ step: HomeSetupStep) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: step.isComplete ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(step.isComplete ? .green : .secondary)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
                Text(step.title)
                    .font(.subheadline.weight(.semibold))
                Text(step.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    func miniInfoRow(icon: String, tint: Color, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 24, height: 24)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    func challengeActivityRow(for item: ChallengeActivityItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: challengeActivityIcon(for: item))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(challengeActivityTint(for: item))
                .frame(width: 34, height: 34)
                .background(challengeActivityTint(for: item).opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(challengeActivityTitle(for: item))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(item.challengeTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(relativeDateString(from: item.createdAt))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    func challengeActivityTitle(for item: ChallengeActivityItem) -> String {
        let actor = displayName(for: item.participantID)

        switch item.kind {
        case .created:
            return "\(actor) started a challenge"
        case .rematchStarted:
            return "\(actor) kicked off a rematch"
        case .minutesLogged:
            let minutes = item.minutes ?? 0
            return "\(actor) logged \(minutes)m"
        }
    }

    func challengeActivityIcon(for item: ChallengeActivityItem) -> String {
        switch item.kind {
        case .created:
            return "flag.fill"
        case .rematchStarted:
            return "arrow.clockwise"
        case .minutesLogged:
            return "timer"
        }
    }

    func challengeActivityTint(for item: ChallengeActivityItem) -> Color {
        switch item.kind {
        case .created:
            return .orange
        case .rematchStarted:
            return .blue
        case .minutesLogged:
            return .green
        }
    }

    func displayName(for participantID: UUID?) -> String {
        guard let participantID else { return "Someone" }
        return participantID == challengesService.localUserID ? "You" : buddyService.displayName(for: participantID)
    }

    func relativeDateString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    func sectionHeader(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title3.weight(.bold))
            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    func normalizedLabel(_ value: String, fallback: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }

    func statusChip(_ title: String, tint: Color) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.14), in: Capsule())
    }

    func formatMinutes(_ seconds: Int) -> String {
        let minutes = max(1, Int(ceil(Double(seconds) / 60.0)))
        return "\(minutes) min"
    }
}

private struct HomeHero {
    let title: String
    let detail: String
    let systemImage: String
    let tint: Color
    let primaryButtonTitle: String
    let primaryAction: () -> Void
    let secondaryButtonTitle: String?
    let secondaryAction: (() -> Void)?
    let badges: [HomeBadge]
}

private struct HomeShortcutInfo {
    let title: String
    let detail: String
    let buttonTitle: String
    let systemImage: String
    let tint: Color
    let action: () -> Void
}

private struct HomeBadge: Identifiable {
    let title: String
    let tint: Color

    var id: String { title }
}

private struct FocusQuickStartOption: Identifiable {
    let id: String
    let title: String
    let detail: String
    let isSelected: Bool
}

private struct HomeSetupStep: Identifiable {
    let title: String
    let detail: String
    let isComplete: Bool

    var id: String { title }
}

private struct ChallengeLeadInsight {
    let challenge: Challenge
    let deficit: Int
    let leaderName: String
    let yourMinutes: Int
    let leaderMinutes: Int
}

private struct HomeRoutinePreset: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var minutes: Int
    #if canImport(FamilyControls)
    var selection: FamilyActivitySelection = .init()
    #endif

    init(id: UUID = UUID(), title: String, minutes: Int) {
        self.id = id
        self.title = title
        self.minutes = max(minutes, 1)
    }

    static func == (lhs: HomeRoutinePreset, rhs: HomeRoutinePreset) -> Bool {
        let baseMatch =
            lhs.id == rhs.id &&
            lhs.title == rhs.title &&
            lhs.minutes == rhs.minutes
        #if canImport(FamilyControls)
        return baseMatch && lhs.selection == rhs.selection
        #else
        return baseMatch
        #endif
    }
}

private struct HomePresetEditorView: View {
    @Binding var quickFocusLabel: String
    @Binding var quickFocusMinutes: Int
    @Binding var loseFocusMinutes: Int
    @Binding var savedPresets: [HomeRoutinePreset]

    @Environment(\.dismiss) private var dismiss

    @State private var showingAddPreset = false

    var body: some View {
        List {
            Section("Defaults") {
                EditableDefaultRow(title: $quickFocusLabel, fallback: "Default", value: $quickFocusMinutes, range: 1...180)
                NumericSettingRow(title: "Lose focus", value: $loseFocusMinutes, range: 1...30)
            }

            Section("Custom presets") {
                if savedPresets.isEmpty {
                    Text("Add custom presets.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach($savedPresets) { $preset in
                        EditablePresetRow(preset: $preset)
                    }
                    .onDelete { indexSet in
                        savedPresets.remove(atOffsets: indexSet)
                    }
                }

                Button {
                    showingAddPreset = true
                } label: {
                    Label("Add preset", systemImage: "plus")
                }
            }
        }
        .navigationTitle("Customize presets")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .sheet(isPresented: $showingAddPreset) {
            NavigationStack {
                AddHomePresetView { preset in
                    savedPresets.append(preset)
                    savedPresets.sort {
                        $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
                    }
                }
            }
        }
    }
}

private struct FocusPresetPickerView: View {
    let quickFocusLabel: String
    let quickFocusMinutes: Int
    let savedPresets: [HomeRoutinePreset]
    @Binding var selectedPresetID: String
    let onEditPresets: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Button {
                    selectedPresetID = HomeView.defaultFocusPresetID
                    dismiss()
                } label: {
                    optionCard(
                        title: quickFocusLabel,
                        detail: "\(quickFocusMinutes) min",
                        icon: "timer",
                        tint: .accentColor,
                        selected: selectedPresetID == HomeView.defaultFocusPresetID
                    )
                }
                .buttonStyle(.plain)

                ForEach(savedPresets) { preset in
                    Button {
                        selectedPresetID = preset.id.uuidString
                        dismiss()
                    } label: {
                        optionCard(
                            title: preset.title,
                            detail: durationLabel(for: preset.minutes),
                            icon: "timer",
                            tint: .accentColor,
                            selected: selectedPresetID == preset.id.uuidString
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .navigationTitle("Choose focus")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Edit") {
                    onEditPresets()
                }
            }
        }
    }

    private func durationLabel(for minutes: Int) -> String {
        if minutes % 60 == 0 {
            let hours = minutes / 60
            return hours == 1 ? "1 hour" : "\(hours) hours"
        }
        return "\(minutes) min"
    }

    private func optionCard(
        title: String,
        detail: String,
        icon: String,
        tint: Color,
        selected: Bool
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(tint)
                .frame(width: 40, height: 40)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if selected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(tint)
            }
        }
        .padding()
        .background(
            selected ? tint.opacity(0.12) : Color(.systemGray6),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
    }
}

private struct AddHomePresetView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var minutes = 20

    let onSave: (HomeRoutinePreset) -> Void

    var body: some View {
        Form {
            Section("Preset") {
                TextField("Name", text: $title)
                NumericSettingRow(title: "Minutes", value: $minutes, range: 1...360)
            }
        }
        .navigationTitle("New preset")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
                    onSave(HomeRoutinePreset(title: trimmed.isEmpty ? "Focus preset" : trimmed, minutes: minutes))
                    dismiss()
                }
            }
        }
    }
}

private struct EditableDefaultRow: View {
    @Binding var title: String
    let fallback: String
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField(fallback, text: $title)
                .textInputAutocapitalization(.words)

            NumericMinutesField(value: $value, range: range)
        }
        .padding(.vertical, 4)
    }
}

private struct NumericSettingRow: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
            NumericMinutesField(value: $value, range: range)
        }
    }
}

private struct NumericMinutesField: View {
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        TextField("Minutes", value: $value, format: .number)
            .keyboardType(.numberPad)
            .textFieldStyle(.roundedBorder)
            .onChange(of: value) { _, newValue in
                value = min(max(newValue, range.lowerBound), range.upperBound)
            }
    }
}

private struct EditablePresetRow: View {
    @Binding var preset: HomeRoutinePreset
    @State private var showingPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Name", text: $preset.title)
                .textInputAutocapitalization(.words)

            NumericMinutesField(value: $preset.minutes, range: 1...360)

            #if canImport(FamilyControls)
            VStack(alignment: .leading, spacing: 6) {
                Text(selectionSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button("Choose blocked apps") {
                    showingPicker = true
                }
                .buttonStyle(.bordered)
            }
            #endif
        }
        .padding(.vertical, 4)
        #if canImport(FamilyControls)
        .sheet(isPresented: $showingPicker) {
            NavigationStack {
                FamilyActivityPicker(selection: $preset.selection)
                    .navigationTitle("Preset apps")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                showingPicker = false
                            }
                        }
                    }
            }
        }
        #endif
    }

    #if canImport(FamilyControls)
    private var selectionSummary: String {
        let selection = preset.selection
        var parts: [String] = []
        if !selection.applicationTokens.isEmpty { parts.append("\(selection.applicationTokens.count) app(s)") }
        if !selection.categoryTokens.isEmpty { parts.append("\(selection.categoryTokens.count) category") }
        if !selection.webDomainTokens.isEmpty { parts.append("\(selection.webDomainTokens.count) website(s)") }
        return parts.isEmpty ? "Uses your default blocked apps." : "Blocks " + parts.joined(separator: ", ")
    }
    #endif
}

private extension View {
    func homeCardStyle() -> some View {
        self
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

#if canImport(FamilyControls)
private extension FamilyActivitySelection {
    var hasSelections: Bool {
        !applicationTokens.isEmpty || !categoryTokens.isEmpty || !webDomainTokens.isEmpty
    }
}
#endif

#Preview {
    let buddyService = LocalBuddyService()
    let friendRequests = FriendRequestService(buddyService: buddyService)
    let requestService = UnlockRequestService()
    let challengesService = ChallengeService()

    return NavigationStack {
        HomeView(
            buddyService: buddyService,
            friendRequestService: friendRequests,
            requestService: requestService,
            challengesService: challengesService
        )
    }
    .environmentObject(ScreenTimeManager())
}
