import FirebaseAuth
import FirebaseFirestore
import Foundation

struct RemoteUserProfile {
    let userID: String
    let email: String?
    let username: String
    let displayName: String

    init(
        userID: String,
        email: String?,
        username: String,
        displayName: String
    ) {
        self.userID = userID
        self.email = email
        self.username = username
        self.displayName = displayName
    }

    init?(userID: String, data: [String: Any]) {
        guard let username = UserProfileStore.readUsername(from: data) else {
            return nil
        }

        self.init(
            userID: userID,
            email: data["email"] as? String,
            username: username,
            displayName: UserProfileStore.displayName(
                from: data,
                fallbackUsername: username,
                fallbackEmail: data["email"] as? String
            )
        )
    }
}

enum UserProfileStore {
    private static let db = Firestore.firestore()
    private static let defaults = UserDefaults.standard
    private static let displayNameDefaultsKey = "BuddyLock.displayName"

    static func normalizeUsername(_ username: String) -> String {
        username
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    static func normalizeDisplayName(_ displayName: String?) -> String? {
        let trimmed = displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    static func fallbackDisplayName(username: String, email: String?) -> String {
        if !username.isEmpty {
            return username
        }

        let emailPrefix = email?
            .split(separator: "@")
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return emailPrefix?.isEmpty == false ? emailPrefix! : "Buddy"
    }

    static func readUsername(from data: [String: Any]) -> String? {
        let rawUsername = (data["username"] as? String) ?? (data["handle"] as? String) ?? ""
        let username = normalizeUsername(rawUsername)
        return username.isEmpty ? nil : username
    }

    static func displayName(
        from data: [String: Any],
        fallbackUsername: String,
        fallbackEmail: String?
    ) -> String {
        normalizeDisplayName(data["displayName"] as? String)
            ?? normalizeDisplayName(data["username"] as? String)
            ?? fallbackDisplayName(username: fallbackUsername, email: fallbackEmail)
    }

    static func persistLocalDisplayName(_ displayName: String) {
        defaults.set(displayName, forKey: displayNameDefaultsKey)
    }

    static func fetchProfile(userID: String) async throws -> RemoteUserProfile? {
        let snapshot = try await db.collection("users").document(userID).getDocument()
        guard let data = snapshot.data() else { return nil }
        return RemoteUserProfile(userID: userID, data: data)
    }

    static func fetchProfile(username: String) async throws -> RemoteUserProfile? {
        let normalizedUsername = normalizeUsername(username)
        guard !normalizedUsername.isEmpty else { return nil }

        let usernameSnapshot = try await db.collection("usernames")
            .document(normalizedUsername)
            .getDocument()

        guard let data = usernameSnapshot.data(),
              let userID = data["uid"] as? String else {
            return nil
        }

        if let profile = try await fetchProfile(userID: userID) {
            return profile
        }

        return RemoteUserProfile(
            userID: userID,
            email: nil,
            username: normalizedUsername,
            displayName: normalizeDisplayName(data["displayName"] as? String)
                ?? fallbackDisplayName(username: normalizedUsername, email: nil)
        )
    }

    static func saveSignedInUserProfile(
        userID: String,
        email: String,
        username: String,
        displayName: String?
    ) async throws -> RemoteUserProfile {
        let normalizedUsername = normalizeUsername(username)
        guard !normalizedUsername.isEmpty else {
            throw NSError(
                domain: "UserProfileStore",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Username cannot be empty."]
            )
        }

        let resolvedDisplayName = normalizeDisplayName(displayName)
            ?? fallbackDisplayName(username: normalizedUsername, email: email)

        let userPayload: [String: Any] = [
            "email": email,
            "username": normalizedUsername,
            "displayName": resolvedDisplayName,
            "friends": [],
            "updatedAt": FieldValue.serverTimestamp(),
        ]
        let usernamePayload: [String: Any] = [
            "uid": userID,
            "username": normalizedUsername,
            "displayName": resolvedDisplayName,
            "updatedAt": FieldValue.serverTimestamp(),
        ]

        let batch = db.batch()
        batch.setData(userPayload, forDocument: db.collection("users").document(userID), merge: true)
        batch.setData(
            usernamePayload,
            forDocument: db.collection("usernames").document(normalizedUsername),
            merge: true
        )
        try await batch.commit()

        persistLocalDisplayName(resolvedDisplayName)

        return RemoteUserProfile(
            userID: userID,
            email: email,
            username: normalizedUsername,
            displayName: resolvedDisplayName
        )
    }

    static func updateCurrentUserDisplayName(_ displayName: String) async throws {
        guard let user = Auth.auth().currentUser else { return }

        let normalizedDisplayName = normalizeDisplayName(displayName)
        let currentProfile = try await fetchProfile(userID: user.uid)

        let username = currentProfile?.username ?? normalizeUsername(user.email ?? "")
        let resolvedDisplayName = normalizedDisplayName
            ?? fallbackDisplayName(username: username, email: user.email)

        var userPayload: [String: Any] = [
            "displayName": resolvedDisplayName,
            "updatedAt": FieldValue.serverTimestamp(),
        ]
        if currentProfile == nil, !username.isEmpty {
            userPayload["username"] = username
        }
        if let email = user.email {
            userPayload["email"] = email
        }

        try await db.collection("users").document(user.uid).setData(userPayload, merge: true)

        if !username.isEmpty {
            try await db.collection("usernames").document(username).setData([
                "uid": user.uid,
                "username": username,
                "displayName": resolvedDisplayName,
                "updatedAt": FieldValue.serverTimestamp(),
            ], merge: true)
        }

        persistLocalDisplayName(resolvedDisplayName)
    }
}
