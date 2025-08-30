//
//  HomeView.swift
//  BuddyLock
//
//  Created by Stephanie Song on 8/29/25.
//
//
import SwiftUI

struct HomeView: View {
    @EnvironmentObject var screenTime: ScreenTimeManager
    @StateObject var buddies = BuddyService()
    @StateObject private var challenges = ChallengeService()
    var body: some View {
        NavigationView {
            VStack (spacing: 20){
                // List of buddies
                if buddies.buddies.isEmpty {
                    Text("No buddies yet!")
                        .foregroundColor(.gray)
                } else {
                    List(buddies.buddies, id: \.id) { buddy in
                        Text(buddy.displayName)
                    }
                    .frame(height: 200)
                }
                
                // List of challenges
                if challenges.challenges.isEmpty {
                    Text("No challenges available")
                        .foregroundColor(.gray)
                } else {
                    List(challenges.challenges, id: \.id) { challenge in
                        Text(challenge.title)
                    }
                    .frame(height: 200)
                }
            }
            .padding()
            .navigationTitle("Home")
            
        }
    }
}
