import SwiftUI

struct ApprovalsView: View {
    @ObservedObject var buddyService: LocalBuddyService
    @ObservedObject var requestService: UnlockRequestService

    @EnvironmentObject var screenTime: ScreenTimeManager

    @State private var approvingRequest: UnlockRequest?
    @State private var approveMinutes: Int = 10
    @State private var responseNote: String = ""

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
        .sheet(item: $approvingRequest) { request in
            approveSheet(for: request)
        }
    }

    private var incomingSection: some View {
        Section("Incoming") {
            if requestService.incoming.isEmpty {
                Text("No incoming requests.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(requestService.incoming.sorted(by: { $0.createdDate > $1.createdDate })) { request in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(request.requesterName)
                                    .font(.headline)
                                Text(request.audienceLabel)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                            StatusPill(request: request)
                        }

                        Text(request.progressSummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("Requested \(request.minutesRequested) minute\(request.minutesRequested == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(request.approvalRule.summary(for: request.recipientCount))
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if let target = request.targetDescription, !target.isEmpty {
                            Text("For: \(target)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if let reason = request.reason, !reason.isEmpty {
                            Text("“\(reason)”")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if !request.responses.isEmpty {
                            responseSummary(request.responses)
                        }

                        if requestService.canCurrentUserRespond(to: request) {
                            HStack {
                                Button(role: .destructive) {
                                    guard let requestID = request.id else { return }
                                    requestService.deny(requestID: requestID)
                                } label: {
                                    Text("Deny")
                                }

                                Spacer()

                                Button {
                                    approveMinutes = request.minutesRequested
                                    responseNote = ""
                                    approvingRequest = request
                                } label: {
                                    Text("Approve")
                                }
                                .buttonStyle(.borderedProminent)
                            }
                            .font(.footnote)
                        } else if let myResponse = requestService.currentUserResponse(for: request) {
                            Text(responseLine(for: myResponse, prefix: "You"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Text(relativeDateString(from: request.createdDate))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var outgoingSection: some View {
        Section("Your Requests") {
            if requestService.outgoing.isEmpty {
                Text("You haven’t sent any requests yet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(requestService.outgoing.sorted(by: { $0.createdDate > $1.createdDate })) { request in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(request.audienceLabel)
                                    .font(.headline)
                                Text("\(request.minutesRequested) minute\(request.minutesRequested == 1 ? "" : "s")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                            StatusPill(request: request)
                        }

                        Text(request.progressSummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if !request.responses.isEmpty {
                            responseSummary(request.responses)
                        }

                        Text(relativeDateString(from: request.createdDate))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private func approveSheet(for request: UnlockRequest) -> some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Approve unlock for \(request.requesterName)?")
                    .font(.headline)

                Text("You can approve their requested time or trim it down. Add a short note if you want to give context.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Stepper(
                    "\(approveMinutes) minute\(approveMinutes == 1 ? "" : "s")",
                    value: $approveMinutes,
                    in: 5...60,
                    step: 5
                )

                TextField("Optional note", text: $responseNote, axis: .vertical)
                    .lineLimit(2...4)
                    .textFieldStyle(.roundedBorder)

                Spacer()

                Button {
                    approve(request, minutes: approveMinutes, note: responseNote)
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
            .navigationTitle("Approve Request")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func approve(_ request: UnlockRequest, minutes: Int, note: String) {
        guard let requestID = request.id else { return }
        requestService.approve(
            requestID: requestID,
            minutes: max(1, minutes),
            note: note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : note
        )
    }

    private func responseSummary(_ responses: [UnlockApprovalResponse]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(responses) { response in
                Text(responseLine(for: response))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func responseLine(for response: UnlockApprovalResponse, prefix: String? = nil) -> String {
        let name = prefix ?? response.responderName
        let verb = response.vote == .approved ? "approved" : "denied"
        let minutesText: String
        if response.vote == .approved, let approvedMinutes = response.approvedMinutes {
            minutesText = " (\(approvedMinutes)m)"
        } else {
            minutesText = ""
        }
        let noteText = response.note.map { " - \($0)" } ?? ""
        return "\(name) \(verb)\(minutesText)\(noteText)"
    }

    private func relativeDateString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

private struct StatusPill: View {
    let request: UnlockRequest

    var body: some View {
        switch request.decision {
        case .pending:
            Text("Pending")
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.thinMaterial, in: Capsule())
        case .approved:
            Text("Approved \(request.approvedMinutes ?? request.minutesRequested)m")
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
