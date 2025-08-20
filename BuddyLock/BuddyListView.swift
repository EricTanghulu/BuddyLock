
import SwiftUI

struct BuddyListView: View {
    @ObservedObject var service: LocalBuddyService
    @State private var newName: String = ""
    @State private var newRole: BuddyRole = .gatekeeper

    var body: some View {
        Form {
            Section("Add Buddy") {
                TextField("Display name", text: $newName)
                Picker("Role", selection: $newRole) {
                    ForEach(BuddyRole.allCases) { role in
                        Text(role.label).tag(role)
                    }
                }
                Button {
                    service.addBuddy(name: newName, role: newRole)
                    newName = ""
                    newRole = .gatekeeper
                } label: {
                    Label("Add Buddy", systemImage: "person.badge.plus")
                }
                .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            Section("Your Buddies") {
                if service.buddies.isEmpty {
                    Text("No buddies yet. Add someone to get started.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(service.buddies) { buddy in
                        HStack {
                            Image(systemName: "person.fill")
                            Text(buddy.displayName)
                            Spacer()
                            Text(buddy.role.label).foregroundStyle(.secondary)
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                service.removeBuddy(buddy)
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Buddies")
    }
}

struct BuddyApprovalCenterView: View {
    @ObservedObject var service: LocalBuddyService
    var onApprove: (Int) -> Void

    var body: some View {
        List {
            Section("Incoming Requests") {
                if service.incoming.isEmpty {
                    Text("No incoming requests.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(service.incoming) { req in
                        RequestRow(req: req, approve: { minutes in
                            service.approve(requestID: req.id, minutes: minutes)
                            onApprove(minutes)
                        }, deny: {
                            service.deny(requestID: req.id)
                        })
                    }
                }
            }

            Section("Your Outgoing Requests") {
                if service.outgoing.isEmpty {
                    Text("No outgoing requests yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(service.outgoing) { req in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("To buddy: \(req.buddyID.uuidString.prefix(6))…")
                                    .font(.subheadline)
                                Text("Requested \(req.minutesRequested) min")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            StatusPill(req: req)
                        }
                    }
                }
            }
        }
        .navigationTitle("Approvals")
    }
}

private struct RequestRow: View {
    let req: BuddyApprovalRequest
    var approve: (Int) -> Void
    var deny: () -> Void

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("\(req.requesterName) requests \(req.minutesRequested) min")
                    .font(.subheadline).bold()
                if let reason = req.reason, !reason.isEmpty {
                    Text("“\(reason)”").font(.footnote).foregroundStyle(.secondary)
                }
                Text(req.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            switch req.decision {
            case .pending:
                Menu {
                    Button("Approve 5 min") { approve(5) }
                    Button("Approve 10 min") { approve(10) }
                    Button("Approve \(req.minutesRequested) min") { approve(req.minutesRequested) }
                    Button(role: .destructive) { deny() } label: { Text("Deny") }
                } label: {
                    Label("Decide", systemImage: "checkmark.seal")
                }
            case .approved:
                StatusPill(req: req)
            case .denied:
                StatusPill(req: req)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct StatusPill: View {
    let req: BuddyApprovalRequest
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
