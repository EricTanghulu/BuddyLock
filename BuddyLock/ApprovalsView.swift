import SwiftUI
#if canImport(FamilyControls)
import FamilyControls
#endif

struct ApprovalsView: View {
    @ObservedObject var buddyService: LocalBuddyService
    @ObservedObject var requestService: LocalUnlockRequestService

    @EnvironmentObject var screenTime: ScreenTimeManager

    /// Fallback: general approve callback (kept for compatibility)
    var onApprove: (Int) -> Void

    var body: some View {
        List {
            Section("Incoming") {
                if requestService.incoming.isEmpty {
                    Text("No incoming requests.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(requestService.incoming) { r in
                        let displayName = buddyService.buddies.first(where: { $0.id == r.buddyID })?.displayName ?? "Buddy"
                        RequestRow(
                            req: r,
                            name: displayName,
                            onApprove: { mins in
                                approve(req: r, minutes: mins)
                            },
                            onDeny: {
                                requestService.deny(requestID: r.id)
                            }
                        )
                    }
                }
            }

            Section("Outgoing") {
                if requestService.outgoing.isEmpty {
                    Text("No outgoing requests yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(requestService.outgoing) { r in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                let name = buddyService.buddies.first(where: { $0.id == r.buddyID })?.displayName ?? "Buddy"
                                Text("To \(name)")
                                    .font(.subheadline)
                                if let appName = r.requestedAppName {
                                    Text("App: \(appName)").font(.caption).foregroundStyle(.secondary)
                                }
                                Text("Requested \(r.minutesRequested) min")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            StatusPill(req: r)
                        }
                    }
                }
            }

            // 👇 New: Manage Buddies section lives here (not in top bar)
            Section("Buddies") {
                NavigationLink {
                    BuddyListView(service: buddyService)
                } label: {
                    Label("Manage Buddies", systemImage: "person.badge.plus")
                }
                Text("Add or remove buddies. Buddies can approve unlock requests and join challenges.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Approvals")
        .toolbar {
            Button { requestService.refresh() } label: { Image(systemName: "arrow.clockwise") }
        }
    }

    private func approve(req: LocalUnlockRequest, minutes: Int) {
        requestService.approve(requestID: req.id, minutes: minutes)

        #if canImport(FamilyControls)
        if let appName = req.requestedAppName {
            // Try to find a token with this display name among currently selected (shielded) apps
            let pairs = screenTime.resolvedAppNames() // [(token, name)] – may be generic names if resolver isn't available
            if let match = pairs.first(where: { $0.name == appName }) {
                // Specific app exception: allow only this app for N minutes
                screenTime.grantTemporaryException(forApps: [match.token], minutes: minutes)
                return
            }
        }
        #endif

        // Fallback: lift all shields temporarily (existing general path)
        onApprove(minutes)
    }
}

private struct RequestRow: View {
    let req: LocalUnlockRequest
    let name: String
    var onApprove: (Int) -> Void
    var onDeny: () -> Void

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("\(req.requesterName) requests \(req.minutesRequested) min")
                    .font(.subheadline).bold()
                Text("for \(name)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let appName = req.requestedAppName {
                    Text("App: \(appName)").font(.caption).foregroundStyle(.secondary)
                }
                if let reason = req.reason, !reason.isEmpty {
                    Text("“\(reason)”").font(.footnote).foregroundStyle(.secondary)
                }
                Text(req.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            switch req.decision {
            case .pending:
                // Unique approve options: if requested is 5 or 10, only show those two; else show [5,10,requested]
                let base = [5, 10]
                let approveOptions: [Int] = base.contains(req.minutesRequested) ? base : (base + [req.minutesRequested])

                Menu {
                    ForEach(approveOptions, id: \.self) { mins in
                        Button("Approve \(mins) min") { onApprove(mins) }
                    }
                    Button(role: .destructive) { onDeny() } label: { Text("Deny") }
                } label: {
                    Label("Decide", systemImage: "checkmark.seal")
                }
            case .approved, .denied:
                StatusPill(req: req)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct StatusPill: View {
    let req: LocalUnlockRequest
    var body: some View {
        switch req.decision {
        case .pending:
            Text("Pending").padding(6).background(.thinMaterial, in: Capsule())
        case .approved:
            Text("Approved \(req.approvedMinutes ?? req.minutesRequested)m")
                .padding(6).background(.green.opacity(0.2), in: Capsule())
        case .denied:
            Text("Denied").padding(6).background(.red.opacity(0.2), in: Capsule())
        }
    }
}
