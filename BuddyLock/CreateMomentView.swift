import SwiftUI

struct CreateMomentView: View {
    @Environment(\.dismiss) private var dismiss

    enum MomentType: String, CaseIterable, Identifiable {
        case post = "Post"
        case story = "Story"

        var id: String { rawValue }
    }

    @State private var selectedType: MomentType = .post
    @State private var text: String = ""
    @State private var includeMedia: Bool = true
    @State private var tagAsFocusResult: Bool = true

    var body: some View {
        Form {
            Section {
                Picker("Type", selection: $selectedType) {
                    ForEach(MomentType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section(selectedType == .post ? "Post" : "Story") {
                TextField(
                    selectedType == .post
                        ? "Write a caption..."
                        : "Add a quick update...",
                    text: $text,
                    axis: .vertical
                )
                .lineLimit(3...6)

                Toggle(
                    selectedType == .post
                        ? "Include image/video"
                        : "Tag as focus result",
                    isOn: selectedType == .post
                        ? $includeMedia
                        : $tagAsFocusResult
                )
            }

            Section {
                Button {
                    // TODO: Hook this into your backend / feed logic
                    dismiss()
                } label: {
                    HStack {
                        Spacer()
                        Text(selectedType == .post ? "Share Post" : "Post Story")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("New Moment")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.backward")
                        Text("Create")
                    }
                }
            }
        }
    }
}

// MARK: - Previews

#Preview {
    NavigationStack {
        CreateMomentView()
    }
}
