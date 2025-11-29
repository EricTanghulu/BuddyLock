//
//  ScreenTimeDefaultsSettingsView.swift
//  BuddyLock
//
//  Created by Eric Tang on 11/29/25.
//


import SwiftUI

struct ScreenTimeDefaultsSettingsView: View {
    @AppStorage("BuddyLock.settings.defaultFocusMinutes")
    private var defaultFocusMinutes: Int = 25

    @AppStorage("BuddyLock.settings.defaultWarmupMinutes")
    private var defaultWarmupMinutes: Int = 5

    var body: some View {
        Form {
            Section {
                Stepper(value: $defaultFocusMinutes, in: 5...180, step: 5) {
                    HStack {
                        Text("Default focus length")
                        Spacer()
                        Text("\(defaultFocusMinutes) min").foregroundStyle(.secondary)
                    }
                }

                Stepper(value: $defaultWarmupMinutes, in: 0...30, step: 1) {
                    HStack {
                        Text("Warm-up before focus")
                        Spacer()
                        Text(defaultWarmupMinutes == 0 ? "Off" : "\(defaultWarmupMinutes) min")
                            .foregroundStyle(.secondary)
                    }
                }
            } footer: {
                Text("These values are used when creating new focus sessions or challenges.")
                    .font(.footnote)
            }
        }
        .navigationTitle("Screen Time")
    }
}

#Preview {
    NavigationStack {
        ScreenTimeDefaultsSettingsView()
    }
}