import SwiftUI

#if canImport(FamilyControls)
import FamilyControls
#endif

private enum ChallengeFormat: String, CaseIterable, Identifiable {
    case duel
    case group

    var id: String { rawValue }

    var title: String {
        switch self {
        case .duel:
            return "Duel"
        case .group:
            return "Group"
        }
    }

    var subtitle: String {
        switch self {
        case .duel:
            return "One buddy, one scoreboard."
        case .group:
            return "A small circle, shared momentum."
        }
    }

    var defaultTitle: String {
        switch self {
        case .duel:
            return "Duel"
        case .group:
            return "Group challenge"
        }
    }
}

#if canImport(FamilyControls)
private typealias ChallengeTargetSelection = FamilyActivitySelection
#else
private struct ChallengeTargetSelection: Equatable {
    var hasSelections: Bool { false }
}
#endif

struct ChallengeCreateView: View {
    @ObservedObject var challenges: ChallengeService
    @ObservedObject var buddies: LocalBuddyService

    @Environment(\.dismiss) private var dismiss

    @State private var format: ChallengeFormat = .duel
    @State private var name: String = ""
    @State private var days: Int = 7
    @State private var targetSelection: ChallengeTargetSelection = .init()
    @State private var selectedBuddyID: UUID?
    @State private var selectedGroupBuddyIDs: Set<UUID> = []
    @State private var showingTargetPicker = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                introCard
                formatSection
                basicsSection
                participantsSection
                previewCard
            }
            .padding(.horizontal)
            .padding(.vertical, 16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("New Challenge")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                Button {
                    createChallenge()
                } label: {
                    Text(createButtonTitle)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isCreateDisabled)

                if isCreateDisabled {
                    Text(disabledMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .background(.ultraThinMaterial)
        }
        .sheet(isPresented: $showingTargetPicker) {
            #if canImport(FamilyControls)
            NavigationStack {
                FamilyActivityPicker(selection: $targetSelection)
                    .navigationTitle("Pick Apps & Categories")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                showingTargetPicker = false
                            }
                        }
                    }
            }
            #else
            Text("App selection isn’t available on this device.")
                .padding()
            #endif
        }
        .onAppear {
            preselectFirstBuddyIfNeeded()
        }
        .onChange(of: format) { _, newFormat in
            if newFormat == .duel {
                preselectFirstBuddyIfNeeded()
            }
        }
    }

    private var introCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Set the tone")
                .font(.title3.weight(.bold))
            Text("A good challenge is simple to understand at a glance: who’s in it, how long it lasts, and what everyone is trying to stay off or stay focused on.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .createCardBackground(tint: Color.orange.opacity(0.15))
    }

    private var formatSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Format")
                .font(.headline)

            HStack(spacing: 12) {
                ForEach(ChallengeFormat.allCases) { option in
                    Button {
                        format = option
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(option.title)
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                if format == option {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color.accentColor)
                                }
                            }

                            Text(option.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(
                            format == option ? Color.accentColor.opacity(0.12) : Color(.secondarySystemBackground),
                            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var basicsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Basics")
                .font(.headline)

            VStack(alignment: .leading, spacing: 10) {
                TextField("Challenge name (optional)", text: $name)
                    .textFieldStyle(.roundedBorder)

                Button {
                    showingTargetPicker = true
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Apps & categories")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text(targetSelectionSummary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Duration")
                        .font(.subheadline.weight(.semibold))

                    HStack(spacing: 10) {
                        ForEach([3, 7, 14, 30], id: \.self) { preset in
                            Button {
                                days = preset
                            } label: {
                                Text("\(preset)d")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(
                                        days == preset ? Color.accentColor.opacity(0.14) : Color(.secondarySystemBackground),
                                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Stepper("Length: \(days) day\(days == 1 ? "" : "s")", value: $days, in: 1...30)
                        .font(.footnote)
                }
            }
        }
        .createCardBackground()
    }

    @ViewBuilder
    private var participantsSection: some View {
        switch format {
        case .duel:
            duelSection
        case .group:
            groupSection
        }
    }

    private var duelSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pick Your Buddy")
                .font(.headline)

            if buddies.buddies.isEmpty {
                Text("You don’t have any buddies yet. Add someone first, then come back here to start a duel.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(buddies.buddies) { buddy in
                    Button {
                        selectedBuddyID = buddy.id
                    } label: {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(Color.orange.opacity(0.18))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Text(String(buddy.resolvedDisplayName.prefix(1)).uppercased())
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(.orange)
                                )

                            VStack(alignment: .leading, spacing: 4) {
                                Text(buddy.resolvedDisplayName)
                                    .font(.subheadline.weight(.semibold))
                                Text("One-on-one accountability")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: selectedBuddyID == buddy.id ? "largecircle.fill.circle" : "circle")
                                .foregroundStyle(selectedBuddyID == buddy.id ? Color.accentColor : .secondary)
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .createCardBackground()
    }

    private var groupSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pick the Group")
                .font(.headline)

            if buddies.buddies.isEmpty {
                Text("You don’t have any buddies yet. Add a few people first, then start a group challenge here.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(buddies.buddies) { buddy in
                    Toggle(
                        isOn: Binding(
                            get: { selectedGroupBuddyIDs.contains(buddy.id) },
                            set: { isSelected in
                                if isSelected {
                                    selectedGroupBuddyIDs.insert(buddy.id)
                                } else {
                                    selectedGroupBuddyIDs.remove(buddy.id)
                                }
                            }
                        )
                    ) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(buddy.resolvedDisplayName)
                                .font(.subheadline.weight(.semibold))
                            Text("Include them in the shared scoreboard")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .toggleStyle(.switch)
                }

                Text("You’re always included automatically, so you only need to pick the other people.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .createCardBackground()
    }

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Preview")
                .font(.headline)

            Text(resolvedTitle)
                .font(.title3.weight(.semibold))

            Text(previewSubtitle)
                .font(.footnote)
                .foregroundStyle(.secondary)

            if let target = targetDescription {
                Text(target)
                    .font(.subheadline)
            }
        }
        .createCardBackground(tint: Color.blue.opacity(0.12))
    }

    private var resolvedTitle: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? format.defaultTitle : trimmed
    }

    private var targetDescription: String? {
        targetSelectionHasSelections ? targetSelectionSummary : nil
    }

    private var previewSubtitle: String {
        let peopleText: String
        switch format {
        case .duel:
            if let selectedBuddyID,
               let buddy = buddies.buddy(for: selectedBuddyID) {
                peopleText = "You vs \(buddy.resolvedDisplayName)"
            } else {
                peopleText = "Pick one buddy"
            }
        case .group:
            if selectedGroupBuddyIDs.isEmpty {
                peopleText = "You plus a group"
            } else {
                peopleText = "You plus \(selectedGroupBuddyIDs.count) buddy\(selectedGroupBuddyIDs.count == 1 ? "" : "ies")"
            }
        }

        return "\(peopleText) • \(days) day\(days == 1 ? "" : "s")"
    }

    private var createButtonTitle: String {
        format == .duel ? "Create Duel" : "Create Group Challenge"
    }

    private var disabledMessage: String {
        if buddies.buddies.isEmpty {
            return "Add at least one buddy first."
        }

        switch format {
        case .duel:
            return "Choose the buddy you want to challenge."
        case .group:
            return "Pick at least one buddy for the group challenge."
        }
    }

    private var isCreateDisabled: Bool {
        switch format {
        case .duel:
            return selectedBuddyID == nil
        case .group:
            return selectedGroupBuddyIDs.isEmpty
        }
    }

    private func preselectFirstBuddyIfNeeded() {
        if selectedBuddyID == nil {
            selectedBuddyID = buddies.buddies.first?.id
        }
    }

    private func createChallenge() {
        switch format {
        case .duel:
            guard let selectedBuddyID,
                  let buddy = buddies.buddy(for: selectedBuddyID) else {
                return
            }

            challenges.createDuel(
                with: buddy,
                title: resolvedTitle,
                days: days,
                targetDescription: targetDescription
            )

        case .group:
            let groupBuddies = buddies.buddies.filter { selectedGroupBuddyIDs.contains($0.id) }
            guard !groupBuddies.isEmpty else { return }

            challenges.createGroup(
                with: groupBuddies,
                title: resolvedTitle,
                days: days,
                targetDescription: targetDescription
            )
        }

        dismiss()
    }

    private var targetSelectionSummary: String {
        #if canImport(FamilyControls)
        var parts: [String] = []
        if !targetSelection.applicationTokens.isEmpty {
            parts.append("\(targetSelection.applicationTokens.count) app\(targetSelection.applicationTokens.count == 1 ? "" : "s")")
        }
        if !targetSelection.categoryTokens.isEmpty {
            parts.append("\(targetSelection.categoryTokens.count) categor\(targetSelection.categoryTokens.count == 1 ? "y" : "ies")")
        }
        if !targetSelection.webDomainTokens.isEmpty {
            parts.append("\(targetSelection.webDomainTokens.count) website\(targetSelection.webDomainTokens.count == 1 ? "" : "s")")
        }
        return parts.isEmpty ? "Choose what this challenge is about" : parts.joined(separator: " • ")
        #else
        return "Choose what this challenge is about"
        #endif
    }

    private var targetSelectionHasSelections: Bool {
        #if canImport(FamilyControls)
        return !targetSelection.applicationTokens.isEmpty ||
            !targetSelection.categoryTokens.isEmpty ||
            !targetSelection.webDomainTokens.isEmpty
        #else
        return false
        #endif
    }
}

private extension View {
    func createCardBackground(tint: Color = Color(.secondarySystemBackground)) -> some View {
        padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tint, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

@MainActor
struct ChallengeCreateView_Previews: PreviewProvider {
    static var previewBuddyService: LocalBuddyService = {
        let service = LocalBuddyService()
        if service.buddies.isEmpty {
            service.addBuddy(LocalBuddy(buddyUserID: "sam", displayName: "Sam"))
            service.addBuddy(LocalBuddy(buddyUserID: "jules", displayName: "Jules"))
        }
        return service
    }()

    static var previewChallengeService: ChallengeService = {
        ChallengeService()
    }()

    static var previews: some View {
        NavigationStack {
            ChallengeCreateView(
                challenges: previewChallengeService,
                buddies: previewBuddyService
            )
        }
    }
}
