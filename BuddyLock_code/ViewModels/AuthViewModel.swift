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
            print("Signup blocked: username was empty after normalization")
            return
        }

        print("Attempting signup with email:", normalizedEmail)
        Auth.auth().createUser(withEmail: normalizedEmail, password: password) { result, error in
            if let error = error {
                print("Signup full error info:", error) // full NSError
                print("Signup localizedDescription:", error.localizedDescription)
                return
            }
            
            guard let user = result?.user else {
                print("Signup failed: no user returned")
                return
            }
            
            print("User created successfully:", user.uid)
            self.userSession = user

            Task {
                do {
                    let profile = try await UserProfileStore.saveSignedInUserProfile(
                        userID: user.uid,
                        email: normalizedEmail,
                        username: normalizedUsername,
                        displayName: normalizedUsername
                    )
                    print("Profile saved to Firestore for:", profile.username)
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
            if let user = result?.user {
                print("Logged in successfully:", user.uid)       // 🔹 confirmation
                self.userSession = user
            } else {
                print("Login result returned nil user")
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
