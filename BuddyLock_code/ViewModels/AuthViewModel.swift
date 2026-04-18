import SwiftUI
import FirebaseAuth

class AuthViewModel: ObservableObject {
    @Published var userSession: FirebaseAuth.User?
    private var authStateListener: AuthStateDidChangeListenerHandle?

    init() {
        self.userSession = Auth.auth().currentUser
        listenForChanges()
    }

    deinit {
        if let authStateListener {
            Auth.auth().removeStateDidChangeListener(authStateListener)
        }
    }

    func listenForChanges() {
        authStateListener = Auth.auth().addStateDidChangeListener { _, user in
            self.userSession = user
        }
    }
    
    func signUp(email: String, username: String, password: String) {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedUsername = UserProfileStore.normalizeUsername(username)
        guard !normalizedUsername.isEmpty else {
            return
        }

        Auth.auth().createUser(withEmail: normalizedEmail, password: password) { result, error in
            if let error = error {
                print("Signup localizedDescription:", error.localizedDescription)
                return
            }
            
            guard let user = result?.user else {
                return
            }
            
            self.userSession = user

            Task {
                do {
                    _ = try await UserProfileStore.saveSignedInUserProfile(
                        userID: user.uid,
                        email: normalizedEmail,
                        username: normalizedUsername,
                        displayName: normalizedUsername
                    )
                } catch {
                    print("Error saving profile:", error.localizedDescription)
                }
            }
        }
    }


    func signIn(email: String, password: String) {
        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            if let error = error {
                print("Login error:", error.localizedDescription)
                return
            }
            self.userSession = result?.user
        }
    }

    func signOut() {
        do {
            try Auth.auth().signOut()
            self.userSession = nil
        } catch {
            print("Sign out error:", error.localizedDescription)
        }
    }
}
