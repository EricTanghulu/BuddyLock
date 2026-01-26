import SwiftUI
#if canImport(FamilyControls)
import FamilyControls
#endif

struct ApprovalsView: View {
    @ObservedObject var buddyService: LocalBuddyService
    @ObservedObject var requestService: UnlockRequestService

    @EnvironmentObject var screenTime: ScreenTimeManager

    /// Fallback: general approve callback (kept for compatibility)
    var onApprove: (Int) -> Void

    @State private var approvingRequest: UnlockRequest?
    @State private var approveMinutes: Int = 10

    var body: some View {
        List {
            incomingSection
            outgoingSection
        }
        .navigationTitle("Approvals")
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
        .sheet(item: $approvingRequest) { req in
            approveSheet(for: req)
        }
    }

    // MARK: - Sections

    private var incomingSection: some View {
        Section {
            if requestService.incoming.isEmpty {
                Text("No incoming requests.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(requestService.incoming.sorted(by: { $0.createdDate > $1.createdDate })) { r in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(r.requesterName)
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            StatusPill(req: r)
                        }

                        Text("Requested: \(r.minutesRequested) minute\(r.minutesRequested == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if let buddy = buddyService.buddies.first(where: { $0.remoteID == r.buddyID }) {
                            Text("Buddy: \(buddy.displayName)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        if let reason = r.reason, !reason.isEmpty {
                            Text("“\(reason)”")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Text(relativeDateString(from: r.createdDate))
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        if r.decision == .pending {
                            HStack {
                                
                                Button(role: .destructive) {
                                    guard let requestID = r.id else {
                                        print("Error: request has no ID")
                                        return
                                    }
                                    requestService.deny(requestID: requestID)
                                } label: {
                                    Text("Deny")
                                }

                                Spacer()

                                Button {
                                    approveMinutes = r.minutesRequested
                                    approvingRequest = r
                                } label: {
                                    Text("Approve")
                                }
                                .buttonStyle(.borderedProminent)
                            }
                            .font(.footnote)
                            .padding(.top, 4)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        } header: {
            Text("Incoming")
        }
    }

    private var outgoingSection: some View {
        Section {
            if requestService.outgoing.isEmpty {
                Text("You haven’t sent any requests yet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(requestService.outgoing.sorted(by: { $0.createdDate > $1.createdDate })) { r in
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

                        Text(relativeDateString(from: r.createdDate))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        } header: {
            Text("Your requests")
        }
    }

    // MARK: - Approve sheet

    private func approveSheet(for req: UnlockRequest) -> some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Approve unlock for \(req.requesterName)?")
                    .font(.headline)

                Text("Requested \(req.minutesRequested) minute\(req.minutesRequested == 1 ? "" : "s"). You can adjust the time below.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Stepper(
                    "\(approveMinutes) minute\(approveMinutes == 1 ? "" : "s")",
                    value: $approveMinutes,
                    in: 5...60,
                    step: 5
                )

                Spacer()

                Button {
                    approve(req, minutes: approveMinutes)
                    approvingRequest = nil
                } label: {
                    Text("Approve unlock")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button(role: .cancel) {
                    approvingRequest = nil
                } label: {
                    Text("Cancel")
                        .frame(maxWidth: .infinity)
                }
            }
            .padding()
            .navigationTitle("Approve request")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Actions

    private func approve(_ req: UnlockRequest, minutes: Int) {
        let clamped = max(1, minutes)
        // Grant the actual exception now
        screenTime.grantTemporaryException(minutes: clamped)
        // Update our local store to mark it approved
        
        guard let requestID = req.id else {
            print("Error: request has no ID")
            return
        }

        requestService.approve(requestID: requestID, minutes: clamped)

        // And call the fallback callback (for compatibility)
        onApprove(clamped)
    }

    private func relativeDateString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// Reuse StatusPill from above

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
