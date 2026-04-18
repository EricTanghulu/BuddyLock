import SwiftUI
#if canImport(FamilyControls)
import FamilyControls
#endif

struct HomeView: View {
    @EnvironmentObject var screenTime: ScreenTimeManager
    @ObservedObject var buddyService: LocalBuddyService
    @ObservedObject var friendRequestService: FriendRequestService
    @ObservedObject var requestService: UnlockRequestService

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
                headerSection
                    .padding(.horizontal)

                if hasHighlightedModeCard {
                    highlightedModeSection
                        .padding(.horizontal)
                }

                focusActionsSection
                    .padding(.horizontal)

                blockedAppsSection
                    .padding(.horizontal)

                accountabilitySection
                    .padding(.horizontal)
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

    var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(greetingTitle)
                .font(.largeTitle.bold())

            Text(statusLine)
                .font(.footnote)
                .foregroundStyle(.secondary)

            if screenTime.isBaselineEnabled && screenTime.activeMode == .idle {
                statusChip("Baseline blocking is on", tint: .green)
            }
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
            return "Turn on Screen Time to start blocking apps."
        }

        switch screenTime.activeMode {
        case .idle:
            if screenTime.focusState.phase == .paused {
                return "Focus paused."
            }
            return hasBlockedSelection ? "Ready." : "Ready without blocked apps."
        case .baseline:
            return "Baseline blocking is on."
        case .focus:
            return "Focus is on."
        case .panic:
            return "Panic block is running."
        case .essentialsOnly:
            return "Locked in."
        }
    }

    var hasHighlightedModeCard: Bool {
        switch screenTime.activeMode {
        case .panic, .essentialsOnly:
            return true
        case .idle, .baseline, .focus:
            return screenTime.focusState.phase == .paused
        }
    }

    @ViewBuilder
    var highlightedModeSection: some View {
        switch screenTime.activeMode {
        case .panic:
            modeStatusCard(
                title: "Panic block",
                timeText: remainingText(until: screenTime.panicEndsAt),
                tint: .red
            ) {
                Task {
                    await screenTime.endPanicBlock()
                }
            } actionLabel: {
                Text("End panic block")
            }
        case .essentialsOnly:
            modeStatusCard(
                title: "Lock in",
                timeText: remainingText(until: screenTime.essentialsModeEndsAt),
                tint: .indigo
            ) {
                Task {
                    await screenTime.endEssentialsOnlyMode()
                }
            } actionLabel: {
                Text("End lock")
            }
        case .idle, .baseline, .focus:
            if screenTime.focusState.phase == .paused {
                modeStatusCard(
                    title: "Focus paused",
                    timeText: pausedFocusText,
                    tint: .orange
                ) {
                    Task {
                        await screenTime.resumeFocusSession()
                    }
                } actionLabel: {
                    Text("Resume focus")
                }
            } else {
                EmptyView()
            }
        }
    }

    var focusActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Focus")

            VStack(alignment: .leading, spacing: 12) {
                Button {
                    startSelectedFocus()
                } label: {
                    primaryActionButton(
                        title: "Start Focus",
                        detail: selectedFocusDetail,
                        icon: "timer",
                        tint: .accentColor
                    )
                }
                .buttonStyle(.plain)
                .disabled(!screenTime.isAuthorized || screenTime.focusState.isActive)

                Button {
                    showingFocusOptions = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "square.grid.2x2")
                        Text("Choose focus")
                        Spacer()
                        Text(selectedFocusTitle)
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)

                if let setupPrompt {
                    compactSetupPrompt(setupPrompt)
                }
            }
        }
    }

    var blockedAppsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Blocked apps")

            VStack(alignment: .leading, spacing: 14) {
                Toggle(isOn: Binding(
                    get: { screenTime.isBaselineEnabled },
                    set: { newValue in
                        if newValue {
                            screenTime.enableBaseline()
                        } else {
                            screenTime.disableBaseline()
                        }
                    })
                ) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Baseline blocking")
                            .font(.subheadline.weight(.semibold))
                    }
                }
                .disabled(!screenTime.isAuthorized)

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text(hasBlockedSelection ? screenTime.selectionSummary : "No blocked apps or websites picked yet.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button {
                        if screenTime.isAuthorized {
                            showingBaselinePicker = true
                        } else {
                            Task {
                                await screenTime.requestAuthorization()
                            }
                        }
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
            }
            .homeCardStyle()
        }
    }

    var accountabilitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Buddy update")

            HStack(alignment: .top, spacing: 12) {
                Image(systemName: accountabilityInfo.systemImage)
                    .font(.headline)
                    .foregroundStyle(accountabilityInfo.tint)
                    .frame(width: 38, height: 38)
                    .background(accountabilityInfo.tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(accountabilityInfo.title)
                        .font(.headline)
                    Text(accountabilityInfo.detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .homeCardStyle()
        }
    }

    var accountabilityInfo: AccountabilityInfo {
        if pendingApprovalsCount > 0 {
            return AccountabilityInfo(
                title: "\(pendingApprovalsCount) approval\(pendingApprovalsCount == 1 ? "" : "s") waiting",
                detail: "Open Friends to respond.",
                systemImage: "checkmark.seal.fill",
                tint: .green
            )
        }

        if outgoingPendingCount > 0 {
            return AccountabilityInfo(
                title: "Waiting on a buddy",
                detail: "\(outgoingPendingCount) request\(outgoingPendingCount == 1 ? "" : "s") still open.",
                systemImage: "hourglass",
                tint: .orange
            )
        }

        if pendingFriendRequestsCount > 0 {
            return AccountabilityInfo(
                title: "\(pendingFriendRequestsCount) new buddy request\(pendingFriendRequestsCount == 1 ? "" : "s")",
                detail: "Open Friends to review.",
                systemImage: "person.badge.plus",
                tint: .blue
            )
        }

        if buddyService.buddies.isEmpty {
            return AccountabilityInfo(
                title: "No buddies yet",
                detail: "Add one from Friends.",
                systemImage: "person.2",
                tint: .secondary
            )
        }

        return AccountabilityInfo(
            title: "\(buddyService.buddies.count) buddy\(buddyService.buddies.count == 1 ? "" : "ies") in your circle",
            detail: "Friends has the details.",
            systemImage: "person.2.fill",
            tint: .purple
        )
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

    var setupPrompt: HomeSetupPrompt? {
        if !screenTime.isAuthorized {
            return HomeSetupPrompt(
                message: "Turn on Screen Time first.",
                buttonTitle: "Turn on Screen Time",
                action: {
                    Task {
                        await screenTime.requestAuthorization()
                    }
                }
            )
        }

        return nil
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

    func runPreset(_ preset: HomeRoutinePreset) {
        #if canImport(FamilyControls)
        let overrideSelection = preset.selection.hasSelections ? preset.selection : nil
        screenTime.startFocusSession(minutes: preset.minutes, warmUpSeconds: 0, selectionOverride: overrideSelection)
        #else
        screenTime.startFocusSession(minutes: preset.minutes, warmUpSeconds: 0)
        #endif
    }

    func startSelectedFocus() {
        guard screenTime.isAuthorized, !screenTime.focusState.isActive else { return }

        if let selectedFocusPreset {
            runPreset(selectedFocusPreset)
        } else {
            screenTime.startFocusSession(minutes: quickFocusMinutes, warmUpSeconds: 0)
        }
    }

    func ensureSelectedFocusPresetStillExists(in presets: [HomeRoutinePreset]) {
        guard selectedFocusPresetID != Self.defaultFocusPresetID else { return }

        let availableIDs = Set(presets.map { $0.id.uuidString })
        if !availableIDs.contains(selectedFocusPresetID) {
            selectedFocusPresetID = Self.defaultFocusPresetID
        }
    }

    func modeStatusCard<ActionLabel: View>(
        title: String,
        timeText: String?,
        tint: Color,
        action: @escaping () -> Void,
        @ViewBuilder actionLabel: () -> ActionLabel
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Text(title)
                    .font(.headline)

                Spacer()

                statusChip(title, tint: tint)
            }

            if let timeText {
                Text(timeText)
                    .font(.title3.weight(.semibold))
            }

            Button(action: action) {
                HStack {
                    actionLabel()
                    Spacer()
                }
                .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.bordered)
        }
        .homeCardStyle()
    }

    func compactSetupPrompt(_ prompt: HomeSetupPrompt) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(prompt.message)
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button(action: prompt.action) {
                Text(prompt.buttonTitle)
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    func primaryActionButton(title: String, detail: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
            }

            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(tint, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .foregroundStyle(.white)
        .opacity((!screenTime.isAuthorized || screenTime.focusState.isActive) ? 0.45 : 1)
    }

    func secondaryActionButton(title: String, detail: String, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(tint)
                .frame(width: 38, height: 38)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.title3.weight(.bold))
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

private struct HomeSetupPrompt {
    let message: String
    let buttonTitle: String
    let action: () -> Void
}

private struct AccountabilityInfo {
    let title: String
    let detail: String
    let systemImage: String
    let tint: Color
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

    return NavigationStack {
        HomeView(
            buddyService: buddyService,
            friendRequestService: friendRequests,
            requestService: requestService
        )
    }
    .environmentObject(ScreenTimeManager())
}
