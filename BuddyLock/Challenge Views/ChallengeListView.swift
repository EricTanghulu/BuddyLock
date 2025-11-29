import SwiftUI

// MARK: - List scopes (Friends vs Global)

private enum ChallengeListScope: String, CaseIterable, Identifiable {
    case friends
    case global

    var id: String { rawValue }

    var title: String {
        switch self {
        case .friends: return "Friends"
        case .global:  return "Global"
        }
    }
}

// MARK: - Main list view

struct ChallengeListView: View {
    @ObservedObject var challenges: ChallengeService
    @ObservedObject var buddies: LocalBuddyService

    @State private var scope: ChallengeListScope = .friends

    private var friendChallenges: [Challenge] {
        challenges.challenges
    }

    var body: some View {
        VStack(spacing: 0) {
            // Segmented control
            Picker("Challenge scope", selection: $scope) {
                ForEach(ChallengeListScope.allCases) { scope in
                    Text(scope.title).tag(scope)
                }
            }
            .pickerStyle(.segmented)
            .padding([.horizontal, .top])

            List {
                switch scope {
                case .friends:
                    friendChallengesSection
                case .global:
                    globalChallengesSection
                }
            }
            .listStyle(.insetGrouped)
        }
        .navigationTitle("Challenges")
    }

    // MARK: - Sections

    private var friendChallengesSection: some View {
        Section {
            if friendChallenges.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No challenges yet")
                        .font(.headline)
                    Text("Once you create a challenge, it’ll show up here so you can track progress against your buddies.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            } else {
                ForEach(friendChallenges) { ch in
                    NavigationLink {
                        ChallengeDetailView(
                            challenge: ch,
                            challenges: challenges,
                            buddies: buddies
                        )
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(ch.title.isEmpty ? defaultTitle(for: ch) : ch.title)
                                .font(.headline)

                            Text(rowSubtitle(for: ch))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete { idx in
                    idx.map { friendChallenges[$0] }.forEach(challenges.removeChallenge)
                }
            }
        } header: {
            Text("Friend challenges")
        }
    }

    private var globalChallengesSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("App-wide challenges")
                    .font(.headline)

                Text("This is where global challenges will appear once they’re available. You’ll be able to join app-wide events and earn in-game rewards.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 6) {
                    Label("Featured challenge", systemImage: "sparkles")
                    Label("Joinable challenges", systemImage: "person.3.sequence")
                    Label("Your active global challenges", systemImage: "clock.arrow.circlepath")
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
            }
            .padding(.vertical, 4)
        } header: {
            Text("Global challenges")
        } footer: {
            Text("Hook this section up to your backend or mock data when you’re ready. The layout is designed to be easy to plug into real data later.")
                .font(.footnote)
        }
    }

    // MARK: - Helpers

    private func defaultTitle(for challenge: Challenge) -> String {
        switch challenge.type {
        case .duel:
            return "Duel"
        case .group:
            return "Group challenge"
        }
    }

    private func rowSubtitle(for challenge: Challenge) -> String {
        let typeText: String = {
            switch challenge.type {
            case .duel:  return "Duel"
            case .group: return "Group"
            }
        }()

        let endText = challenge.endDate.formatted(date: .abbreviated, time: .omitted)

        if let target = challenge.targetDescription,
           !target.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "\(typeText) • \(target) • Ends \(endText)"
        } else {
            return "\(typeText) • Ends \(endText)"
        }
    }
}

// MARK: - Preview

@MainActor
struct ChallengeListView_Previews: PreviewProvider {
    static var previewBuddyService: LocalBuddyService = {
        let s = LocalBuddyService()
        if s.buddies.isEmpty {
            s.addBuddy(name: "Alex")
            s.addBuddy(name: "Jordan")
            s.addBuddy(name: "Sam")
        }
        return s
    }()

    static var previewChallengeService: ChallengeService = {
        let s = ChallengeService()
        // Just for Xcode canvas; doesn’t affect real saved data.
        if s.challenges.isEmpty {
            let buddies = previewBuddyService.buddies
            if let first = buddies.first {
                s.createDuel(with: first, title: "Example duel", days: 7)
            }
            if buddies.count >= 2 {
                s.createGroup(
                    with: Array(buddies.prefix(2)),
                    title: "Example group",
                    days: 3
                )
            }
        }
        return s
    }()

    static var previews: some View {
        NavigationStack {
            ChallengeListView(
                challenges: previewChallengeService,
                buddies: previewBuddyService
            )
        }
    }
}
