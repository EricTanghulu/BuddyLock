import SwiftUI

struct CreateTabView: View {
    @ObservedObject var challenges: ChallengeService
    @ObservedObject var buddies: LocalBuddyService

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        ChallengeCreateView(challenges: challenges, buddies: buddies)
                    } label: {
                        Label("New Challenge", systemImage: "flag.2.crossed")
                    }
                }

                Section("Coming soon") {
                    Label("New Post", systemImage: "square.and.pencil")
                        .foregroundStyle(.secondary)
                    Label("New Story", systemImage: "camera.fill")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Create")
        }
    }
}
