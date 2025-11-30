//
//  SignupView.swift
//  BuddyLock
//
//  Created by Stephanie Song on 11/29/25.
//


import SwiftUI

struct SignupView: View {
    @EnvironmentObject var auth: AuthViewModel
    
    @State private var email = ""
    @State private var username = ""
    @State private var password = ""
    
    var body: some View {
        VStack(spacing: 16) {
            TextField("Email", text: $email)
                .textFieldStyle(.roundedBorder)
                .autocapitalization(.none)
            
            TextField("Username", text: $username)
                .textFieldStyle(.roundedBorder)
            
            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)
            
            Button("Create Account") {
                print("Signup button tapped 2")
                auth.signUp(email: email, username: username, password: password)
            }
            .padding()
        }
        .padding()
    }
}
