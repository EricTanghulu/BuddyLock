//
//  RootView.swift
//  BuddyLock
//
//  Created by Stephanie Song on 11/29/25.
//


import SwiftUI

struct RootView: View {
    @EnvironmentObject var auth: AuthViewModel

    var body: some View {
        if auth.userSession == nil {
            LoginView()   // ← Show this if NOT logged in
        } else {
            MainTabView() // ← Your existing entry point
        }
    }
}
