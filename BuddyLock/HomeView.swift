import SwiftUI
#if canImport(FamilyControls)
import FamilyControls
#endif

struct HomeView: View {
    @EnvironmentObject var screenTime: ScreenTimeManager
    @ObservedObject var challengesService: ChallengeService

    // First-run permission prompt flag
    @AppStorage("BuddyLock.didPromptForAuthorization")
    private var didPromptForAuthorization = false

    // UI state
    @State private var showPicker = false
    @State private var focusMinutes: Int = 30
    @State private var scheduleEnabled: Bool = false
    @State private var scheduledStart: Date =
        Calendar.current.date(byAdding: .minute, value: 15, to: Date())
        ?? Date().addingTimeInterval(900)

    var body: some View {
        Form {
            // Permission only when NOT authorized
            if !screenTime.isAuthorized {
                Section {
                    Text("BuddyLock needs Screen Time permission to shield apps and websites.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Button("Grant Screen Time Permission") {
                        Task { await screenTime.requestAuthorization() }
                    }
                } header: {
                    Text("Permission Required")
                }
            }

            // Choose apps & categories to limit
            #if canImport(FamilyControls)
            Section("Choose apps & categories to limit") {
                Button("Open Family Activity Picker") { showPicker = true }
                    .sheet(isPresented: $showPicker) {
                        FamilyActivityPicker(selection: $screenTime.selection)
                    }
                if !screenTime.selectionSummary.isEmpty {
                    Text(screenTime.selectionSummary)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            #endif

            // Focus & Shield controls
            Section("Focus & Shield") {
                Toggle("Activate shield now", isOn: Binding(
                    get: { screenTime.isShieldActive },
                    set: { newValue in
                        if newValue { screenTime.applyShield() }
                        else { screenTime.clearShield() }
                    }
                ))

                Stepper("Focus length: \(focusMinutes) min",
                        value: $focusMinutes,
                        in: 5...180,
                        step: 5)

                HStack {
                    if screenTime.focusState.isActive {
                        Button(role: .destructive) {
                            screenTime.cancelFocusSession()
                        } label: {
                            Label("Stop Focus", systemImage: "stop.circle.fill")
                        }
                    } else {
                        if scheduleEnabled {
                            Button {
                                screenTime.scheduleFocusSession(
                                    start: scheduledStart,
                                    minutes: focusMinutes,
                                    warmUpSeconds: 0
                                )
                            } label: {
                                Label("Schedule Focus", systemImage: "calendar.badge.clock")
                            }
                        } else {
                            Button {
                                screenTime.startFocusSession(
                                    minutes: focusMinutes,
                                    warmUpSeconds: 0
                                )
                            } label: {
                                Label("Start Focus Now", systemImage: "play.circle.fill")
                            }
                        }
                    }

                    Spacer()

                    if let remaining = screenTime.focusState.secondsRemaining,
                       let phase = screenTime.focusState.phase {
                        FocusCountdownBadge(
                            secondsRemaining: remaining,
                            phase: phase
                        )
                    }
                }

                Toggle("Schedule for later", isOn: $scheduleEnabled.animation())
                if scheduleEnabled {
                    DatePicker(
                        "Start at",
                        selection: $scheduledStart,
                        displayedComponents: [.hourAndMinute, .date]
                    )

                    if let s = screenTime.scheduledStart {
                        Text("Scheduled for **\(s.formatted(date: .abbreviated, time: .shortened))**")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Button("Cancel Scheduled") {
                            screenTime.cancelScheduledFocus()
                        }
                        .tint(.red)
                    }
                }

                Text("During a focus session, selected apps & domains are shielded.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            // Info / next steps
            Section("Next steps") {
                Text("Use the **Friends** tab to send unlock requests and approve them, the **Challenges** tab to create and track competitions, and the **Profile** tab to manage your settings and display name.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("BuddyLock")
        // First-run auto-prompt for permission
        .task {
            if !didPromptForAuthorization && !screenTime.isAuthorized {
                didPromptForAuthorization = true
                await screenTime.requestAuthorization()
            }
        }
        // Auto-award focus session minutes to challenges
        .onReceive(NotificationCenter.default.publisher(for: .focusSessionCompleted)) { note in
            if let minutes = note.userInfo?["minutes"] as? Int {
                challengesService.recordLocalFocus(minutes: minutes)
            }
        }
    }
}

#Preview {
    let challenges = ChallengeService()
    return NavigationStack {
        HomeView(challengesService: challenges)
    }
    .environmentObject(ScreenTimeManager())
}
