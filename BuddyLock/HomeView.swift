import SwiftUI
#if canImport(FamilyControls)
import FamilyControls
#endif

struct HomeView: View {
    @EnvironmentObject var screenTime: ScreenTimeManager
    @ObservedObject var challengesService: ChallengeService

    @AppStorage("BuddyLock.displayName")
    private var displayName: String = ""

    @AppStorage("BuddyLock.didPromptForAuthorization")
    private var didPromptForAuthorization = false

    // UI state for focus controls
    @State private var showPicker = false
    @State private var focusMinutes: Int = 30
    @State private var scheduleEnabled: Bool = false
    @State private var scheduledStart: Date =
        Calendar.current.date(byAdding: .minute, value: 15, to: Date())
        ?? Date().addingTimeInterval(900)

    // Leaderboard UI state
    @State private var isLeaderboardExpanded = false

    // MARK: - Data models

    struct LeaderboardEntry: Identifiable {
        let id: UUID
        let displayName: String
        let scoreMinutes: Int
        let isCurrentUser: Bool

        init(
            id: UUID = UUID(),
            displayName: String,
            scoreMinutes: Int,
            isCurrentUser: Bool = false
        ) {
            self.id = id
            self.displayName = displayName
            self.scoreMinutes = scoreMinutes
            self.isCurrentUser = isCurrentUser
        }
    }

    struct SocialPost: Identifiable {
        let id: UUID
        let authorName: String
        let challengeTitle: String
        let caption: String
        let timestamp: Date

        init(
            id: UUID = UUID(),
            authorName: String,
            challengeTitle: String,
            caption: String,
            timestamp: Date
        ) {
            self.id = id
            self.authorName = authorName
            self.challengeTitle = challengeTitle
            self.caption = caption
            self.timestamp = timestamp
        }
    }

    struct Story: Identifiable {
        let id: UUID
        let authorName: String
        let isCurrentUser: Bool
        let hasUnseenContent: Bool

        init(
            id: UUID = UUID(),
            authorName: String,
            isCurrentUser: Bool = false,
            hasUnseenContent: Bool = true
        ) {
            self.id = id
            self.authorName = authorName
            self.isCurrentUser = isCurrentUser
            self.hasUnseenContent = hasUnseenContent
        }
    }

    // MARK: - Input data (plug real data in here later)

    private let leaderboardEntries: [LeaderboardEntry]
    private let socialPosts: [SocialPost]
    private let stories: [Story]

    /// Custom init so you can easily inject real data later.
    /// Existing call sites like `HomeView(challengesService: ...)` still work
    /// because the other parameters have defaults.
    init(
        challengesService: ChallengeService,
        leaderboardEntries: [LeaderboardEntry] = [],
        socialPosts: [SocialPost] = [],
        stories: [Story] = []
    ) {
        self.challengesService = challengesService
        self.leaderboardEntries = leaderboardEntries
        self.socialPosts = socialPosts
        self.stories = stories
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                storiesSection
                leaderboardSection
                socialFeedSection
                focusAndSetupSection
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .navigationTitle("Home")
        .navigationBarTitleDisplayMode(.large)
        .task {
            if !didPromptForAuthorization && !screenTime.isAuthorized {
                didPromptForAuthorization = true
                await screenTime.requestAuthorization()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .focusSessionCompleted)) { note in
            if let minutes = note.userInfo?["minutes"] as? Int {
                challengesService.recordLocalFocus(minutes: minutes)
            }
        }
    }
}

// MARK: - Sections

private extension HomeView {
    var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(greetingTitle)
                .font(.largeTitle.bold())
            Text("See how your focus stacks up with friends and what everyone’s been up to.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    var storiesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Stories")
                .font(.headline)

            StoryBubblesRowView(
                currentUserName: displayName.isEmpty ? "You" : displayName,
                stories: stories
            )

            if stories.isEmpty {
                Text("When you and your friends share challenge moments, they’ll appear here as stories.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    var leaderboardSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Friends leaderboard")
                    .font(.headline)
                Spacer()
                if leaderboardEntries.count > 4 {
                    Button {
                        withAnimation(.spring()) {
                            isLeaderboardExpanded.toggle()
                        }
                    } label: {
                        Text(isLeaderboardExpanded ? "Show less" : "Show all")
                            .font(.caption)
                    }
                }
            }

            if leaderboardEntries.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("No leaderboard yet")
                        .font(.subheadline.bold())
                    Text("Once you join challenges with friends, your weekly focus time will appear here.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                let rows = leaderboardRows(showAll: isLeaderboardExpanded)

                VStack(spacing: 8) {
                    ForEach(rows, id: \.id) { row in
                        if row.isEllipsis {
                            Button {
                                withAnimation(.spring()) {
                                    isLeaderboardExpanded = true
                                }
                            } label: {
                                HStack {
                                    Spacer()
                                    Text("⋯")
                                        .font(.title2)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                }
                                .padding(.vertical, 2)
                            }
                            .buttonStyle(.plain)
                        } else if let entry = row.entry {
                            LeaderboardRowView(
                                position: row.position,
                                entry: entry
                            )
                        }
                    }
                }
                .padding(12)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }

    var socialFeedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Challenge moments")
                    .font(.headline)
            }

            if socialPosts.isEmpty {
                Text("Share screenshots, photos, or notes from your challenges to keep each other motivated.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 12) {
                    ForEach(socialPosts) { post in
                        PostCardView(post: post)
                    }
                }
            }
        }
    }

    @ViewBuilder
    var focusAndSetupSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Focus & setup")
                .font(.headline)

            if !screenTime.isAuthorized {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Screen Time permission needed")
                        .font(.subheadline.bold())
                    Text("Grant permission so BuddyLock can shield distracting apps during challenges.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Button {
                        Task { await screenTime.requestAuthorization() }
                    } label: {
                        Label("Grant Screen Time Permission", systemImage: "lock.shield")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .padding(12)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("Quick focus session", systemImage: "bolt.fill")
                            .font(.subheadline.bold())
                        Spacer()
                        if screenTime.focusState.isActive,
                           let remaining = screenTime.focusState.secondsRemaining {
                            Text("Ends in \(formattedMinutes(from: remaining))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Not focusing")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Stepper("Focus length: \(focusMinutes) min",
                            value: $focusMinutes,
                            in: 5...180,
                            step: 5)
                        .font(.footnote)

                    HStack {
                        if screenTime.focusState.isActive {
                            Button(role: .destructive) {
                                screenTime.cancelFocusSession()
                            } label: {
                                Label("Stop Focus", systemImage: "stop.circle.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        } else {
                            Button {
                                screenTime.startFocusSession(
                                    minutes: focusMinutes,
                                    warmUpSeconds: 0
                                )
                            } label: {
                                Label("Start Focus", systemImage: "play.circle.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }

                    Toggle("Schedule for later", isOn: $scheduleEnabled.animation())
                        .font(.footnote)

                    if scheduleEnabled {
                        DatePicker(
                            "Start at",
                            selection: $scheduledStart,
                            displayedComponents: [.hourAndMinute, .date]
                        )
                        .font(.footnote)

                        HStack(spacing: 12) {
                            Button {
                                screenTime.scheduleFocusSession(
                                    start: scheduledStart,
                                    minutes: focusMinutes,
                                    warmUpSeconds: 0
                                )
                            } label: {
                                Label("Schedule", systemImage: "calendar.badge.clock")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)

                            if let s = screenTime.scheduledStart {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Scheduled for")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(s.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption)
                                }
                            }
                        }

                        if screenTime.scheduledStart != nil {
                            Button(role: .destructive) {
                                screenTime.cancelScheduledFocus()
                            } label: {
                                Text("Cancel scheduled focus")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .font(.footnote)
                        }
                    }

                    #if canImport(FamilyControls)
                    Divider().padding(.vertical, 4)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Apps & websites to shield")
                            .font(.footnote.bold())

                        Button {
                            showPicker = true
                        } label: {
                            Label("Choose apps & categories", systemImage: "slider.horizontal.3")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .sheet(isPresented: $showPicker) {
                            FamilyActivityPicker(selection: $screenTime.selection)
                        }

                        if !screenTime.selectionSummary.isEmpty {
                            Text(screenTime.selectionSummary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    #endif

                    Text("During a focus session, selected apps & domains are shielded while you earn progress in challenges.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }
}

// MARK: - Leaderboard layout helpers

private extension HomeView {
    struct LeaderboardRow: Identifiable {
        let id = UUID()
        let position: Int?
        let entry: LeaderboardEntry?
        let isEllipsis: Bool

        init(position: Int? = nil, entry: LeaderboardEntry? = nil, isEllipsis: Bool = false) {
            self.position = position
            self.entry = entry
            self.isEllipsis = isEllipsis
        }
    }

    func leaderboardRows(showAll: Bool) -> [LeaderboardRow] {
        var rows: [LeaderboardRow] = []

        // Sort by score descending
        let entries = leaderboardEntries.sorted { $0.scoreMinutes > $1.scoreMinutes }
        guard !entries.isEmpty else { return [] }

        // If showing everything OR small list, just show all
        if showAll || entries.count <= 4 {
            return entries.enumerated().map { index, entry in
                LeaderboardRow(position: index + 1, entry: entry)
            }
        }

        let top3 = Array(entries.prefix(3))
        guard let last = entries.last else { return [] }
        let myIndex = entries.firstIndex(where: { $0.isCurrentUser })

        // Always show top 3
        for (index, entry) in top3.enumerated() {
            rows.append(LeaderboardRow(position: index + 1, entry: entry))
        }

        // Helper to append a single ellipsis row
        func addEllipsis() {
            rows.append(LeaderboardRow(isEllipsis: true))
        }

        guard let myIndex = myIndex else {
            // No explicit current user: top 3 ... last
            addEllipsis()
            rows.append(LeaderboardRow(position: entries.count, entry: last))
            return rows
        }

        if myIndex < 3 {
            // You're already in top 3: top 3 ... last
            addEllipsis()
            rows.append(LeaderboardRow(position: entries.count, entry: last))
        } else if myIndex == entries.count - 1 {
            // You're last: top 3 ... you(last)
            addEllipsis()
            rows.append(LeaderboardRow(position: entries.count, entry: last))
        } else {
            // Typical case: top 3 ... your spot ... last
            addEllipsis()
            rows.append(LeaderboardRow(position: myIndex + 1, entry: entries[myIndex]))
            if entries[myIndex].id != last.id {
                addEllipsis()
                rows.append(LeaderboardRow(position: entries.count, entry: last))
            }
        }

        return rows
    }
}

// MARK: - Row / Card / Bubbles subviews

private struct LeaderboardRowView: View {
    let position: Int?
    let entry: HomeView.LeaderboardEntry

    var body: some View {
        HStack(spacing: 12) {
            if let position {
                Text("#\(position)")
                    .font(.subheadline.bold())
                    .frame(width: 32, alignment: .trailing)
            } else {
                Text("–")
                    .frame(width: 32, alignment: .trailing)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(entry.displayName)
                        .font(entry.isCurrentUser ? .subheadline.weight(.semibold) : .subheadline)
                    if entry.isCurrentUser {
                        Text("you")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
                Text("\(entry.scoreMinutes) min focused")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

private struct PostCardView: View {
    let post: HomeView.SocialPost

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .frame(width: 32, height: 32)
                        .opacity(0.15)
                    Text(String(post.authorName.prefix(1)))
                        .font(.subheadline.bold())
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(post.authorName)
                        .font(.subheadline.bold())
                    Text(post.challengeTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(relativeTime(from: post.timestamp))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text(post.caption)
                .font(.footnote)

        }
        .padding(12)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func relativeTime(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

private struct StoryBubblesRowView: View {
    let currentUserName: String
    let stories: [HomeView.Story]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                // "Your story" bubble
                StoryBubbleView(
                    label: "Your story",
                    initials: initials(from: currentUserName),
                    isCurrentUser: true,
                    hasUnseenContent: true
                )

                ForEach(stories) { story in
                    StoryBubbleView(
                        label: story.authorName,
                        initials: initials(from: story.authorName),
                        isCurrentUser: story.isCurrentUser,
                        hasUnseenContent: story.hasUnseenContent
                    )
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func initials(from name: String) -> String {
        let parts = name.split(separator: " ")
        if let first = parts.first, let last = parts.dropFirst().first {
            return "\(first.first ?? " ").\(last.first ?? " ")"
        } else if let first = name.first {
            return String(first)
        } else {
            return "?"
        }
    }
}

private struct StoryBubbleView: View {
    let label: String
    let initials: String
    let isCurrentUser: Bool
    let hasUnseenContent: Bool

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .strokeBorder(
                        hasUnseenContent ? Color.accentColor : Color.secondary.opacity(0.4),
                        lineWidth: hasUnseenContent ? 3 : 1
                    )
                    .frame(width: 56, height: 56)

                Text(initials)
                    .font(.subheadline.bold())
            }
            .overlay(alignment: .bottomTrailing) {
                if isCurrentUser {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.blue, .white)
                        .background(
                            Circle()
                                .fill(Color(.systemBackground))
                                .frame(width: 18, height: 18)
                        )
                        .offset(x: 4, y: 4)
                }
            }

            Text(label)
                .font(.caption2)
                .lineLimit(1)
        }
        .frame(width: 64)
    }
}

// MARK: - Helpers

private extension HomeView {
    var greetingTitle: String {
        let base = displayName.isEmpty ? "Welcome back" : "Hey, \(displayName)"
        return base
    }

    func formattedMinutes(from seconds: Int) -> String {
        let minutes = max(1, seconds / 60)
        return "\(minutes) min"
    }
}

// MARK: - Preview

#Preview {
    let challenges = ChallengeService()
    return NavigationStack {
        HomeView(
            challengesService: challenges,
            leaderboardEntries: [],
            socialPosts: [],
            stories: []
        )
    }
    .environmentObject(ScreenTimeManager())
}
