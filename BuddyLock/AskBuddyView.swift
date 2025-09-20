import SwiftUI
#if canImport(FamilyControls)
import FamilyControls
#endif

struct AskBuddyView: View {
    @ObservedObject var buddyService: LocalBuddyService
    @ObservedObject var requestService: LocalUnlockRequestService

    @EnvironmentObject var screenTime: ScreenTimeManager

    @State private var selectedBuddyIndex: Int = 0
    @State private var minutes: Int = 10
    @State private var reason: String = ""

    // NEW: app selection toggle + chosen app
    @State private var limitToSpecificApp: Bool = false
    #if canImport(FamilyControls)
    @State private var selectedAppName: String? = nil
    #endif

    var body: some View {
        Form {
            Section("Choose a buddy") {
                if buddyService.buddies.isEmpty {
                    Text("You have no buddies yet. Add one in the Buddies screen.")
                        .foregroundStyle(.secondary)
                } else {
                    Picker("Buddy", selection: $selectedBuddyIndex) {
                        ForEach(buddyService.buddies.indices, id: \.self) { i in
                            Text(buddyService.buddies[i].displayName).tag(i)
                        }
                    }
                }
            }

            // NEW: optional app picker
            #if canImport(FamilyControls)
            Section("App (optional)") {
                Toggle("Request for a specific app", isOn: $limitToSpecificApp.animation())
                if limitToSpecificApp {
                    let appPairs = screenTime.resolvedAppNames() // [(token, name)]
                    if appPairs.isEmpty {
                        Text("No apps selected to shield. Choose apps in the main screen first.")
                            .font(.footnote).foregroundStyle(.secondary)
                    } else {
                        Picker("App", selection: Binding(
                            get: { selectedAppName ?? appPairs.first?.name },
                            set: { selectedAppName = $0 }
                        )) {
                            ForEach(appPairs.map { $0.name }, id: \.self) { name in
                                Text(name).tag(Optional(name))
                            }
                        }
                    }
                }
            }
            #endif

            Section("Request details") {
                Stepper("Minutes: \(minutes)", value: $minutes, in: 5...30, step: 5)
                TextField("Reason (optional)", text: $reason)
            }

            Section {
                Button {
                    guard !buddyService.buddies.isEmpty else { return }
                    let buddy = buddyService.buddies[selectedBuddyIndex]

                    #if canImport(FamilyControls)
                    let appNameToSend = limitToSpecificApp ? selectedAppName : nil
                    #else
                    let appNameToSend: String? = nil
                    #endif

                    requestService.sendRequest(
                        to: buddy,
                        requesterName: "You",
                        minutes: minutes,
                        reason: reason,
                        requestedAppName: appNameToSend
                    )
                } label: {
                    Label("Send Request", systemImage: "paperplane.fill")
                }
                .disabled(buddyService.buddies.isEmpty)
            }

            Section("Status") {
                if requestService.outgoing.isEmpty {
                    Text("No outgoing requests yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(requestService.outgoing) { r in
                        HStack(alignment: .top) {
                            VStack(alignment: .leading) {
                                let name = buddyService.buddies.first(where: { $0.id == r.buddyID })?.displayName ?? "Unknown"
                                Text("To: \(name)")
                                if let appName = r.requestedAppName {
                                    Text("App: \(appName)").font(.caption).foregroundStyle(.secondary)
                                }
                                Text("Requested \(r.minutesRequested) min")
                                    .font(.caption).foregroundStyle(.secondary)
                                if let reason = r.reason, !reason.isEmpty {
                                    Text("“\(reason)”").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            switch r.decision {
                            case .pending: Text("Pending").foregroundStyle(.secondary)
                            case .approved:
                                Text("Approved \(r.approvedMinutes ?? r.minutesRequested)m")
                                    .foregroundStyle(.green)
                            case .denied: Text("Denied").foregroundStyle(.red)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Ask a Buddy")
        .onAppear { requestService.refresh() }
    }
}
