import SwiftUI
#if canImport(FamilyControls)
import FamilyControls
#endif

// MARK: - Lightweight models for the home screen

struct LeaderboardEntry: Identifiable, Hashable {
    let id = UUID()
    let rank: Int
    let displayName: String
    let totalMinutes: Int
    let isCurrentUser: Bool
}

struct Story: Identifiable, Hashable {
    let id = UUID()
    let userName: String
    let isCurrentUser: Bool
    let isNew: Bool
}

struct SocialPost: Identifiable, Hashable {
    let id = UUID()
    let userName: String
    let caption: String
    let createdAt: Date
}

// MARK: - Home View

struct HomeView: View {
    @EnvironmentObject var screenTime: ScreenTimeManager
    @ObservedObject var challengesService: ChallengeService

    // For now these are passed in from MainTabView so Home doesn’t invent fake data.
    var leaderboardEntries: [LeaderboardEntry]
    var socialPosts: [SocialPost]
    var stories: [Story]

    @AppStorage("BuddyLock.displayName")
    private var displayName: String = ""

    @AppStorage("BuddyLock.didPromptForAuthorization")
    private var didPromptForAuthorization = false

    // Local UI state
    @State private var showingBaselinePicker = false
    @State private var showingCustomFocusSheet = false
    @State private var customFocusMinutes: Double = 45

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                headerSection
                    .padding(.horizontal)

                focusControlsSection
                    .padding(.horizontal)

                appBlockingQuickControlsSection
                    .padding(.horizontal)

                leaderboardSection
                    .padding(.horizontal)

                storiesSection
                    .padding(.horizontal)

                socialFeedSection
                    .padding(.horizontal)
            }
            .padding(.vertical, 16)
        }
        .navigationTitle("Home")
        .navigationBarTitleDisplayMode(.large)
        .task {
            // First-launch: politely ask for Screen Time access once
            if !didPromptForAuthorization && !screenTime.isAuthorized {
                didPromptForAuthorization = true
                await screenTime.requestAuthorization()
            }
        }
        .sheet(isPresented: $showingBaselinePicker) {
            #if canImport(FamilyControls)
            NavigationStack {
                FamilyActivityPicker(selection: $screenTime.selection)
                    .navigationTitle("Choose blocked apps")
                    .navigationBarTitleDisplayMode(.inline)
            }
            #else
            Text("Screen Time APIs not available on this device.")
                .padding()
            #endif
        }
        .sheet(isPresented: $showingCustomFocusSheet) {
            customFocusSheet
        }
    }
}

// MARK: - Sections

private extension HomeView {

    // MARK: Header

    var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(greetingTitle)
                .font(.largeTitle.bold())

            Text("Protect your focus, check in with buddies, and share your best challenge moments.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if case .focus = screenTime.activeMode,
               let remaining = screenTime.focusState.secondsRemaining {
                Text("In focus: \(formatMinutes(remaining)) left")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else if screenTime.isBaselineEnabled {
                Text("Baseline blocking is on.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    var greetingTitle: String {
        let name = displayName.isEmpty ? "there" : displayName
        let hour = Calendar.current.component(.hour, from: Date())

        switch hour {
        case 5..<12:
            return "Good morning, \(name)"
        case 12..<17:
            return "Good afternoon, \(name)"
        default:
            return "Good evening, \(name)"
        }
    }

    // MARK: Focus controls

    var focusControlsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Focus sessions", systemImage: "timer")
                    .font(.headline)
                Spacer()
                currentModeBadge
            }

            if screenTime.focusState.isActive,
               let seconds = screenTime.focusState.secondsRemaining {
                // Active focus session card
                VStack(alignment: .leading, spacing: 12) {
                    Text("You’re in a focus session")
                        .font(.subheadline.weight(.semibold))

                    Text(formatTime(seconds))
                        .font(.system(size: 40, weight: .bold, design: .rounded))

                    Text("Stay off distractions until the timer hits zero. Your buddies can see your streaks.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    HStack {
                        Button(role: .destructive) {
                            Task {
                                await screenTime.endFocusSession(completed: false)
                            }
                        } label: {
                            Label("End early", systemImage: "xmark.circle")
                        }

                        Spacer()

                        Button {
                            // Panic block on top of current focus if needed
                            screenTime.startPanicBlock(minutes: 10)
                        } label: {
                            Label("I’m tempted", systemImage: "hand.raised.fill")
                        }
                    }
                    .font(.footnote)
                }
                .padding()
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                // Not in a focus session – offer presets
                VStack(alignment: .leading, spacing: 10) {
                    Text("Start a focus session to lock down distractions for a bit.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 12) {
                        Button {
                            screenTime.startFocusSession(minutes: 25, warmUpSeconds: 10)
                        } label: {
                            focusPresetLabel(title: "Quick focus", detail: "25 min")
                        }

                        Button {
                            screenTime.startFocusSession(minutes: 50, warmUpSeconds: 10)
                        } label: {
                            focusPresetLabel(title: "Deep focus", detail: "50 min")
                        }
                    }

                    Button {
                        showingCustomFocusSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "slider.horizontal.3")
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Custom session")
                                    .font(.subheadline.weight(.semibold))
                                Text("Choose your own focus length")
                                    .font(.caption)
                            }
                            Spacer()
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
            }
        }
    }

    func focusPresetLabel(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    var currentModeBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .frame(width: 8, height: 8)
                .foregroundStyle(screenTime.activeMode == .idle ? .gray.opacity(0.5) : .green)

            Text(modeTitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Color(.systemGray6))
        .clipShape(Capsule())
    }

    var modeTitle: String {
        switch screenTime.activeMode {
        case .idle:
            return "No active mode"
        case .baseline:
            return "Baseline blocking"
        case .focus:
            return "Focus session"
        case .panic:
            return "Panic block"
        case .essentialsOnly:
            return "Study Only mode"
        }
    }

    // MARK: App blocking quick controls (baseline / panic / essentials)

    var appBlockingQuickControlsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("App blocking", systemImage: "lock.app.fill")
                    .font(.headline)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 10) {
                // Baseline toggle (always-on blocking)
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
                        Text("Keep your most distracting apps blocked by default.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if !screenTime.selectionSummary.isEmpty {
                    Text(screenTime.selectionSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 2)
                }

                Button {
                    showingBaselinePicker = true
                } label: {
                    HStack {
                        Image(systemName: "square.stack.3d.up")
                        Text("Choose blocked apps & websites")
                        Spacer()
                    }
                    .font(.footnote)
                }

                Divider()
                    .padding(.vertical, 4)

                HStack(spacing: 12) {
                    Button {
                        screenTime.startPanicBlock(minutes: 15)
                    } label: {
                        HStack {
                            Image(systemName: "hand.raised.fill")
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Panic button")
                                    .font(.subheadline.weight(.semibold))
                                Text("Block distractions for 15 minutes.")
                                    .font(.caption)
                            }
                            Spacer()
                        }
                    }

                    Button {
                        let end = Calendar.current.date(byAdding: .hour, value: 2, to: Date())
                        screenTime.startEssentialsOnlyMode(until: end)
                    } label: {
                        HStack {
                            Image(systemName: "books.vertical.fill")
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Study Only")
                                    .font(.subheadline.weight(.semibold))
                                Text("Everything but essentials for 2h.")
                                    .font(.caption)
                            }
                            Spacer()
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    // MARK: Leaderboard

    var leaderboardSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Focus leaderboard")
                    .font(.headline)
                Spacer()
            }

            if leaderboardEntries.isEmpty {
                Text("Once you and your buddies start focusing, you’ll see a leaderboard here.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(leaderboardEntries.prefix(3)) { entry in
                        leaderboardRow(entry)
                    }

                    if let me = leaderboardEntries.first(where: { $0.isCurrentUser }),
                       let last = leaderboardEntries.sorted(by: { $0.rank < $1.rank }).last {

                        if me.rank > 3 && me.id != last.id {
                            HStack {
                                Text("…")
                                    .font(.headline)
                                Spacer()
                            }
                            .padding(.vertical, 2)

                            leaderboardRow(me)
                        }

                        if last.id != me.id && last.rank > 3 {
                            leaderboardRow(last)
                                .opacity(0.8)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }

    func leaderboardRow(_ entry: LeaderboardEntry) -> some View {
        HStack {
            Text("#\(entry.rank)")
                .font(.subheadline.weight(.semibold))
                .frame(width: 32, alignment: .leading)

            VStack(alignment: .leading) {
                Text(entry.displayName)
                    .font(entry.isCurrentUser ? .subheadline.weight(.semibold) : .subheadline)
                Text("\(entry.totalMinutes) min focused")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if entry.isCurrentUser {
                Text("You")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.15))
                    .clipShape(Capsule())
            }
        }
    }

    // MARK: Stories

    var storiesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Stories")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(stories) { story in
                        VStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .strokeBorder(story.isNew ? Color.accentColor : Color.gray.opacity(0.4), lineWidth: 3)
                                    .frame(width: 60, height: 60)

                                Text(String(story.userName.prefix(2)).uppercased())
                                    .font(.headline.weight(.semibold))
                            }
                            Text(story.isCurrentUser ? "You" : story.userName)
                                .font(.caption)
                        }
                    }

                    if stories.isEmpty {
                        Text("When buddies share story moments, they’ll show up here.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: 220, alignment: .leading)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: Social feed

    var socialFeedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Challenge moments")
                    .font(.headline)
                Spacer()
            }

            if socialPosts.isEmpty {
                Text("Post photos or clips from your challenges to share with buddies.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 12) {
                    ForEach(socialPosts) { post in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Circle()
                                    .frame(width: 28, height: 28)
                                    .foregroundStyle(Color.accentColor.opacity(0.2))
                                    .overlay(
                                        Text(String(post.userName.prefix(1)))
                                            .font(.caption.weight(.bold))
                                    )
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(post.userName)
                                        .font(.subheadline.weight(.semibold))
                                    Text(relativeDateString(from: post.createdAt))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }

                            Text(post.caption)
                                .font(.subheadline)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
            }
        }
    }

    // MARK: Custom focus sheet

    var customFocusSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("How long do you want to focus?")
                    .font(.headline)

                Slider(value: $customFocusMinutes, in: 10...120, step: 5) {
                    Text("Minutes")
                } minimumValueLabel: {
                    Text("10")
                } maximumValueLabel: {
                    Text("120")
                }

                Text("\(Int(customFocusMinutes)) minutes")
                    .font(.title2.weight(.semibold))

                Spacer()

                Button {
                    screenTime.startFocusSession(
                        minutes: Int(customFocusMinutes),
                        warmUpSeconds: 10
                    )
                    showingCustomFocusSheet = false
                } label: {
                    Text("Start focus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .navigationTitle("Custom focus")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingCustomFocusSheet = false
                    }
                }
            }
        }
    }

    // MARK: Helpers

    func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    func formatMinutes(_ seconds: Int) -> String {
        let minutes = max(1, seconds / 60)
        return "\(minutes) min"
    }

    func relativeDateString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Preview

#Preview {
    let challenges = ChallengeService()

    let demoLeaderboard: [LeaderboardEntry] = [
        .init(rank: 1, displayName: "Alex", totalMinutes: 250, isCurrentUser: false),
        .init(rank: 2, displayName: "You", totalMinutes: 210, isCurrentUser: true),
        .init(rank: 3, displayName: "Sam", totalMinutes: 180, isCurrentUser: false),
        .init(rank: 6, displayName: "Taylor", totalMinutes: 60, isCurrentUser: false)
    ]

    let demoStories: [Story] = [
        .init(userName: "You", isCurrentUser: true, isNew: true),
        .init(userName: "Alex", isCurrentUser: false, isNew: true),
        .init(userName: "Sam", isCurrentUser: false, isNew: false)
    ]

    let demoPosts: [SocialPost] = [
        .init(userName: "Alex", caption: "Finished my chem notes 💀", createdAt: Date().addingTimeInterval(-3600)),
        .init(userName: "You", caption: "2h deep work for SAT today 📚", createdAt: Date().addingTimeInterval(-7200))
    ]

    return NavigationStack {
        HomeView(
            challengesService: challenges,
            leaderboardEntries: demoLeaderboard,
            socialPosts: demoPosts,
            stories: demoStories
        )
    }
    .environmentObject(ScreenTimeManager())
}
