import SwiftUI

#if canImport(FamilyControls)
import FamilyControls
#endif

struct ContentView: View {
    @EnvironmentObject var screenTime: ScreenTimeManager
    @StateObject private var buddies = BuddyService()
    @StateObject private var challenges = ChallengeService()
    @AppStorage("BuddyLock.didPromptForAuthorization") private var didPromptForAuthorization = false

    @State private var showPicker = false
    @State private var focusMinutes: Int = 30
    @State private var warmUpSeconds: Int = 0
    @State private var scheduleEnabled: Bool = false
    @State private var scheduledStart: Date = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)

    var body: some View {
        NavigationStack {
            Form {
                // Authorization section: only when NOT authorized
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

                // Selection
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

                // Focus & Shield
                Section("Focus & Shield") {
                    Toggle("Activate shield now", isOn: Binding(
                        get: { screenTime.isShieldActive },
                        set: { newValue in
                            if newValue { screenTime.applyShield() } else { screenTime.clearShield() }
                        }
                    ))
                    Stepper("Focus length: \(focusMinutes) min", value: $focusMinutes, in: 5...180, step: 5)
                    Stepper("Warm-up: \(warmUpSeconds) sec", value: $warmUpSeconds, in: 0...60, step: 5)

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
                                    screenTime.scheduleFocusSession(start: scheduledStart, minutes: focusMinutes, warmUpSeconds: warmUpSeconds)
                                } label: {
                                    Label("Schedule Focus", systemImage: "calendar.badge.clock")
                                }
                            } else {
                                Button {
                                    screenTime.startFocusSession(minutes: focusMinutes, warmUpSeconds: warmUpSeconds)
                                } label: {
                                    Label("Start Focus Now", systemImage: "play.circle.fill")
                                }
                            }
                        }

                        Spacer()

                        if let remaining = screenTime.focusState.secondsRemaining,
                           let phase = screenTime.focusState.phase {
                            FocusCountdownBadge(secondsRemaining: remaining, phase: phase)
                        }
                    }

                    Toggle("Schedule for later", isOn: $scheduleEnabled.animation())
                    if scheduleEnabled {
                        DatePicker("Start at", selection: $scheduledStart, displayedComponents: [.hourAndMinute, .date])
                        if let s = screenTime.scheduledStart {
                            Text("Scheduled for **\(s.formatted(date: .abbreviated, time: .shortened))**")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Button("Cancel Scheduled") {
                                screenTime.cancelScheduledFocus()
                            }.tint(.red)
                        }
                    }

                    Text("During a focus session, selected apps & domains are shielded. A warm‑up delay helps resist impulses before the session starts.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                // Next steps
                Section("Next steps") {
                    Text("Add the Shield UI Extension to display “Ask a Friend” when a blocked app is opened. The extension can defer and post a request to your shared App Group for approval in the main app.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("BuddyLock")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    NavigationLink {
                        ChallengeListView(challenges: challenges, buddies: buddies)
                    } label: {
                        Label("View Challenges", systemImage: "flag.2.crossed")
                    }

                    NavigationLink {
                        BuddyListView(service: buddies)
                    } label: {
                        Label("Add Buddies", systemImage: "person.badge.plus")
                    }
                }
            }
        }
        // First‑run auto‑prompt
        .task {
            if !didPromptForAuthorization && !screenTime.isAuthorized {
                didPromptForAuthorization = true
                await screenTime.requestAuthorization()
            }
        }
        // When a focus session completes, add minutes for the local user
        .onReceive(NotificationCenter.default.publisher(for: .focusSessionCompleted)) { note in
            if let minutes = note.userInfo?["minutes"] as? Int {
                challenges.recordLocalFocus(minutes: minutes)
            }
        }
    }
}

struct FocusCountdownBadge: View {
    let secondsRemaining: Int
    let phase: FocusSessionPhase

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: phase == .warmUp ? "hourglass" : "timer")
            Text(timeString(secondsRemaining))
                .monospacedDigit()
        }
        .padding(6)
        .background(.ultraThinMaterial, in: Capsule())
    }

    private func timeString(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }
}

#Preview {
    ContentView().environmentObject(ScreenTimeManager())
}
