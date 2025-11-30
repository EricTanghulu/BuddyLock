import SwiftUI
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore

class AuthViewModel: ObservableObject {
    @Published var userSession: FirebaseAuth.User?

    init() {
        self.userSession = Auth.auth().currentUser
        listenForChanges()
    }

    func listenForChanges() {
        Auth.auth().addStateDidChangeListener { _, user in
            self.userSession = user
        }
    }
    
    func signUp(email: String, username: String, password: String) {
        print("Attempting signup with email:", email)
        Auth.auth().createUser(withEmail: email, password: password) { result, error in
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
            
            // Optional: save additional profile info in Firestore
            let data: [String: Any] = [
                "email": email,
                "username": username,
                "friends": []
            ]
            Firestore.firestore().collection("users").document(user.uid).setData(data) { err in
                if let err = err {
                    print("Error saving profile:", err.localizedDescription)
                } else {
                    print("Profile saved to Firestore")
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
