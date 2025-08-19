
import Foundation

/// Protocol you can implement with CloudKit, Firebase, Supabase, or your own backend.
protocol BuddyApprovalService {
    func sendUnlockRequest(targetAppBundleID: String, forMinutes minutes: Int, reason: String?) async throws
    func observeDecision(requestID: UUID) async throws -> ApprovalDecision
}

enum ApprovalDecision {
    case approved(minutes: Int)
    case denied
    case timedOut
}

struct LocalEchoApprovalService: BuddyApprovalService {
    func sendUnlockRequest(targetAppBundleID: String, forMinutes minutes: Int, reason: String?) async throws {
        // TODO: Implement a real push to your buddy.
        print("DEBUG: Pretend we sent an approval request for \(targetAppBundleID)")
    }

    func observeDecision(requestID: UUID) async throws -> ApprovalDecision {
        // Stubbed: auto-approve after a delay to simulate a buddy approval.
        try await Task.sleep(nanoseconds: 2_000_000_000)
        return .approved(minutes: 10)
    }
}
