    
import SwiftUI

#if canImport(FamilyControls)
import FamilyControls
#endif

struct ContentView: View {
    @EnvironmentObject var screenTime: ScreenTimeManager
    @State private var showPicker = false
    @State private var focusMinutes: Int = 25

    var body: some View {
        NavigationStack {
            Form {
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

                Section("Block / Shield") {
                    Toggle("Activate shield now", isOn: Binding(
                        get: { screenTime.isShieldActive },
                        set: { newValue in
                            if newValue { screenTime.applyShield() } else { screenTime.clearShield() }
                        }
                    ))
                    Stepper("Focus session: \(focusMinutes) min", value: $focusMinutes, in: 5...120, step: 5)
                    HStack {
                        Button("Start Focus Session") {
                            Task { await screenTime.startFocusSession(minutes: focusMinutes) }
                        }
                        Spacer()
                        Button("Stop Focus") { screenTime.stopFocusSession() }
                            .tint(.secondary)
                    }
                    Text("When a shielded app is opened, your Shield UI extension (included as sample code) can show 'Ask a Friend' / 'Not now' buttons.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Next steps") {
                    Text("Invite buddies, implement network approvals, and wire up the Shield UI extension to call `.defer` while you wait for a friend's response.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("BuddyLock")
        }
    }
}

#Preview {
    ContentView().environmentObject(ScreenTimeManager())
}
