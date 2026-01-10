import SwiftUI

struct BuddyListView: View {
    @ObservedObject var service: LocalBuddyService
    @State private var newName: String = ""

    var body: some View {
        Form {
            Section("Add Buddy") {
                HStack {
                    TextField("Display name", text: $newName)
                    Button {
                        service.addBuddy(LocalBuddy(remoteID: "remote1",     // buddy doc ID
                                                    buddyUserID: "buddyID",               // friend's auth UID
                                                    ownerID: "akame" ))
                        newName = ""
                    } label: {
                        Label("Add", systemImage: "plus.circle.fill")
                    }
                    .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                Text("Buddies you add here can approve short exceptions (demo) and join challenges later.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Your Buddies") {
                if service.buddies.isEmpty {
                    Text("No buddies yet. Add one above.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(service.buddies) { buddy in
                        HStack {
                            Image(systemName: "person.fill")
                            Text(buddy.buddyUserID)
                            Spacer()
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                service.removeBuddy(buddy)
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Buddies")
    }
}
