import SwiftUI
#if canImport(FamilyControls)
import FamilyControls
#endif

struct AskBuddyView: View {
    @ObservedObject var buddyService: LocalBuddyService
    @ObservedObject var requestService: UnlockRequestService

    @EnvironmentObject var screenTime: ScreenTimeManager

    @AppStorage("BuddyLock.displayName")
    private var displayName: String = ""

    @State private var selectedBuddyIndex: Int = 0
    @State private var minutes: Int = 10
    @State private var reason: String = ""
    @State private var showingSentConfirmation = false

    var body: some View {
        Form {
            newRequestSection
            outgoingSection
        }
        .navigationTitle("Ask a Buddy")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    requestService.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .accessibilityLabel("Refresh")
            }
        }
        .onAppear {
            requestService.refresh()
        }
        .alert("Request sent", isPresented: $showingSentConfirmation) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your buddy will be able to approve or deny your unlock request from their Approvals screen.")
        }
    }

    // MARK: - Sections

    private var newRequestSection: some View {
        Section {
            if buddyService.buddies.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No buddies yet")
                        .font(.subheadline.weight(.semibold))
                    Text("Add at least one buddy so someone can approve your unlock requests.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else {
                Picker("Choose a buddy", selection: $selectedBuddyIndex) {
                    ForEach(Array(buddyService.buddies.enumerated()), id: \.offset) { index, buddy in
                        Text(buddy.buddyUserID).tag(index)
                    }
                }

                Stepper(
                    "\(minutes) minute\(minutes == 1 ? "" : "s")",
                    value: $minutes,
                    in: 5...60,
                    step: 5
                )

                TextField("Why do you need access? (optional)", text: $reason)
                    .lineLimit(1...3)

                Button {
                    sendRequest()
                } label: {
                    Label("Send request", systemImage: "paperplane.fill")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .disabled(!canSend)
            }
        } header: {
            Text("New unlock request")
        } footer: {
            Text("Your buddy will see who you are, how long you’re asking for, and your reason before deciding.")
        }
    }

    private var outgoingSection: some View {
        Section {
            if requestService.outgoing.isEmpty {
                Text("You haven’t sent any unlock requests yet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(requestService.outgoing.sorted { $0.createdAt.dateValue() > $1.createdAt.dateValue() }, id: \.stableID) { r in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("\(r.minutesRequested) minute\(r.minutesRequested == 1 ? "" : "s")")
                                .font(.subheadline.weight(.semibold))

                            Spacer()

                            StatusPill(req: r)
                        }

                        if let buddy = buddyService.buddies.first(where: { $0.remoteID == r.buddyID }) {
                            Text("To: \(buddy.displayName)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if let reason = r.reason, !reason.isEmpty {
                            Text("“\(reason)”")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Text(relativeDateString(from: r.createdAt.dateValue()))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        } header: {
            Text("Your recent requests")
        }
    }

    // MARK: - Actions

    private var canSend: Bool {
        !buddyService.buddies.isEmpty && minutes > 0
    }

    private func sendRequest() {
        guard !buddyService.buddies.isEmpty else { return }

        let buddy = buddyService.buddies[selectedBuddyIndex.clamped(to: 0..<(buddyService.buddies.count))]
        let name = displayName.isEmpty ? "You" : displayName

        guard let buddyID = buddy.remoteID else {
            print("Error: buddy has no remoteID")
            return
        }
        
        requestService.sendRequest(
            requesterName: name,
            buddyID: buddyID,
            minutes: minutes,
            reason: reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : reason
        )

        reason = ""
        showingSentConfirmation = true
    }

    private func relativeDateString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Helpers

private extension Int {
    func clamped(to range: Range<Int>) -> Int {
        return Swift.max(range.lowerBound, Swift.min(self, range.upperBound - 1))
    }
}

private struct StatusPill: View {
    let req: UnlockRequest

    var body: some View {
        switch req.decision {
        case .pending:
            Text("Pending")
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.thinMaterial, in: Capsule())
        case .approved:
            Text("Approved \(req.approvedMinutes ?? req.minutesRequested)m")
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.2), in: Capsule())
        case .denied:
            Text("Denied")
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.red.opacity(0.2), in: Capsule())
        }
    }
}
