import SwiftUI

struct ApprovalsView: View {
    @ObservedObject var buddyService: LocalBuddyService
    @ObservedObject var requestService: UnlockRequestService

    @EnvironmentObject var screenTime: ScreenTimeManager

    @State private var approvingRequest: UnlockRequest?
    @State private var approveMinutes: Int = 10
    @State private var responseNote: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                incomingSection
                outgoingSection
            }
            .padding(.horizontal)
            .padding(.vertical, 16)
        }
        .background(Color(.systemGroupedBackground))
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
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(
                "Needs Your Response",
                subtitle: actionableIncoming.isEmpty
                    ? "Nothing is waiting on you right now."
                    : "Focus the card on the real decision: who asked, how long they want, why they asked, and what you want to do."
            )

            if actionableIncoming.isEmpty {
                emptyStateCard(
                    title: "All caught up",
                    subtitle: "You do not have any incoming unlock decisions waiting right now."
                )
            } else {
                VStack(spacing: 10) {
                    ForEach(actionableIncoming) { request in
                        incomingCard(for: request)
                    }
                }
            }
        }
    }

    private var outgoingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(
                "Awaiting Responses",
                subtitle: requestService.outgoing.isEmpty
                    ? "You have not asked for any unlocks yet."
                    : "Keep this area status-light: what you asked for, where it is stuck, and the latest responses."
            )

            if requestService.outgoing.isEmpty {
                emptyStateCard(
                    title: "No outgoing requests",
                    subtitle: "Send a request from Buddies when you need someone else to approve an unlock."
                )
            } else {
                VStack(spacing: 10) {
                    ForEach(requestService.outgoing.sorted(by: { $0.createdDate > $1.createdDate })) { request in
                        outgoingCard(for: request)
                    }
                }
            }
        }
    }

    private func incomingCard(for request: UnlockRequest) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                iconTile(systemImage: "checkmark.seal.fill", tint: .green)

                VStack(alignment: .leading, spacing: 4) {
                    Text(request.requesterName)
                        .font(.headline)
                    Text("Asked for \(request.minutesRequested) minute\(request.minutesRequested == 1 ? "" : "s")")
                        .font(.subheadline)

                    if let reason = request.reason, !reason.isEmpty {
                        Text("“\(reason)”")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else if let target = request.targetDescription, !target.isEmpty {
                        Text("For \(target)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                StatusPill(request: request)
            }

            HStack(spacing: 8) {
                metadataChip(title: request.audienceLabel, tint: .green)

                if request.recipientCount > 1 {
                    metadataChip(
                        title: request.approvalRule.summary(for: request.recipientCount),
                        tint: .secondary,
                        isMuted: true
                    )
                }
            }

            if !request.responses.isEmpty {
                responseSummary(request.responses)
            }

            HStack(spacing: 10) {
                Button("Deny") {
                    guard let requestID = request.id else { return }
                    requestService.deny(requestID: requestID)
                }
                .buttonStyle(.bordered)

                Button("Approve \(request.minutesRequested)m") {
                    approveMinutes = request.minutesRequested
                    responseNote = ""
                    approvingRequest = request
                }
                .buttonStyle(.borderedProminent)
            }
            .font(.footnote.weight(.semibold))

            Text(relativeDateString(from: request.createdDate))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .approvalCardStyle()
    }

    private func outgoingCard(for request: UnlockRequest) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                iconTile(systemImage: "hourglass", tint: .orange)

                VStack(alignment: .leading, spacing: 4) {
                    Text(request.audienceLabel)
                        .font(.headline)
                    Text("\(request.minutesRequested) minute\(request.minutesRequested == 1 ? "" : "s")")
                        .font(.subheadline)

                    if let reason = request.reason, !reason.isEmpty {
                        Text("“\(reason)”")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                StatusPill(request: request)
            }

            HStack(spacing: 8) {
                metadataChip(
                    title: request.progressSummary,
                    tint: request.decision == .pending ? .orange : .secondary,
                    isMuted: request.decision != .pending
                )

                if request.decision == .pending {
                    metadataChip(title: "\(request.pendingCount) still needed", tint: .secondary, isMuted: true)
                }
            }

            if !request.responses.isEmpty {
                responseSummary(request.responses)
            }

            Text(relativeDateString(from: request.createdDate))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .approvalCardStyle()
    }

    private func approveSheet(for request: UnlockRequest) -> some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Approve unlock for \(request.requesterName)?")
                    .font(.headline)

                Text("Approve the full time or trim it down. Add a short note only if the context matters.")
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

    private func sectionTitle(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title3.weight(.bold))
            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func emptyStateCard(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .approvalCardStyle()
    }

    private func iconTile(systemImage: String, tint: Color) -> some View {
        Image(systemName: systemImage)
            .font(.headline)
            .foregroundStyle(tint)
            .frame(width: 42, height: 42)
            .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func metadataChip(title: String, tint: Color, isMuted: Bool = false) -> some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(isMuted ? 0.1 : 0.12), in: Capsule())
    }

    private var actionableIncoming: [UnlockRequest] {
        requestService.incoming
            .filter { requestService.canCurrentUserRespond(to: $0) }
            .sorted(by: { $0.createdDate > $1.createdDate })
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

private extension View {
    func approvalCardStyle() -> some View {
        self
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}
