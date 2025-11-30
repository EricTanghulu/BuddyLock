//
//  LoginView.swift
//  BuddyLock
//
//  Created by Stephanie Song on 11/29/25.
//


import SwiftUI

struct LoginView: View {
    @EnvironmentObject var auth: AuthViewModel

    @State private var email = ""
    @State private var password = ""

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                TextField("Email", text: $email)
                    .textFieldStyle(.roundedBorder)
                
                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)
                
                Button("Login") {
                    print("Login button tapped") // 🔹 confirm the button works
                    auth.signIn(email: email, password: password)
                }
                .padding()
                
                // Navigation link to Signup screen
                NavigationLink("Don't have an account? Sign up", destination: SignupView())
                    .padding(.top, 20)
            }
            .padding()
        }
    }
}
