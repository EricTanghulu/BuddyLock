import SwiftUI

#if canImport(FamilyControls)
import FamilyControls
#endif

struct ContentView: View {
    @EnvironmentObject var screenTime: ScreenTimeManager
    @State private var showPicker = false
    @State private var focusMinutes: Int = 30
    // Use 'warmUpSeconds' to match ScreenTimeManager API
    @State private var warmUpSeconds: Int = 0

    var body: some View {
        NavigationStack {
            Form {
                // Authorization
                Section("Authorization") {
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(screenTime.authorizationLabel)
                            .foregroundStyle(screenTime.isAuthorized ? .green : .secondary)
                    }
                    Button("Request Screen Time Permission") {
                        Task { await screenTime.requestAuthorization() }
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

                // Lock Controls
                Section("Lock Controls") {
                    Toggle("Activate lock now", isOn: Binding(
                        get: { screenTime.isShieldActive },
                        set: { newValue in
                            if newValue { screenTime.applyShield() } else { screenTime.clearShield() }
                        }
                    ))
                    Stepper("Focus length: \(focusMinutes) min", value: $focusMinutes, in: 5...180, step: 5)
                    Stepper("Warm-up: \(warmUpSeconds) sec", value: $warmUpSeconds, in: 0...30, step: 5)

                    HStack {
                        if screenTime.focusState.isActive {
                            Button(role: .destructive) {
                                screenTime.cancelFocusSession()
                            } label: {
                                Label("Stop Focus", systemImage: "stop.circle.fill")
                            }
                        } else {
                            Button {
                                // Call the manager API with the correct parameter name
                                screenTime.startFocusSession(minutes: focusMinutes, warmUpSeconds: warmUpSeconds)
                            } label: {
                                Label("Start Focus Session", systemImage: "play.circle.fill")
                            }
                        }

                        Spacer()

                        if let remaining = screenTime.focusState.secondsRemaining,
                           let phase = screenTime.focusState.phase {
                            FocusCountdownBadge(secondsRemaining: remaining, phase: phase)
                        }
                    }

                    Text("During a focus session, selected apps & domains are shielded. A warm-up delay helps resist impulses before the session starts.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                // Next steps
                Section("Next steps") {
                    Text("Add the Lock UI Extension to show a custom overlay with “Ask a Friend”, and wire it to temporarily lift shields when a buddy approves.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("BuddyLock")
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
