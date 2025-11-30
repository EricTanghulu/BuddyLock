import SwiftUI

/// The create menu overlay:
/// - Shows a lightly dimmed version of whatever tab you were on
/// - Shows a pop-up card at the bottom
/// - Calls `onSelect` for New Challenge / New Moment
struct CreateTabView: View {
    @ObservedObject var challenges: ChallengeService
    @ObservedObject var buddies: LocalBuddyService

    /// Called when the user chooses an option
    var onSelect: (CreateDestination) -> Void

    /// Called when the user closes the pop-up fully (X or background tap, after animation)
    var onClose: () -> Void

    // Controls the card's slide animation
    @State private var cardVisible: Bool = false
    // Controls the dim background opacity
    @State private var overlayOpacity: Double = 0.0

    var body: some View {
        ZStack(alignment: .bottom) {
            // Dim transparent overlay so underlying tab is visible
            Color.black.opacity(overlayOpacity)
                .ignoresSafeArea()
                .onTapGesture {
                    closeWithAnimation {
                        onClose()
                    }
                }

            // POP-UP CARD
            VStack(spacing: 20) {
                // Grabber
                Capsule()
                    .frame(width: 40, height: 5)
                    .foregroundStyle(.secondary.opacity(0.7))
                    .padding(.top, 10)

                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Create")
                            .font(.title2.bold())
                        Text("Start something new with your buddies.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        closeWithAnimation {
                            onClose()
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.semibold))
                            .padding(8)
                            .background(
                                Circle()
                                    .fill(Color(.systemBackground))
                            )
                    }
                    .buttonStyle(.plain)
                }

                // Actions
                VStack(spacing: 12) {
                    // New Challenge
                    Button {
                        // Do NOT close the popup; just open the sheet on top
                        onSelect(.challenge)
                    } label: {
                        CreateRow(
                            icon: "flag.2.crossed",
                            title: "New Challenge",
                            subtitle: "Set up a duel or group focus challenge"
                        )
                    }

                    // New Moment (Post + Story combined)
                    Button {
                        // Popup stays open underneath while sheet is presented
                        onSelect(.moment)
                    } label: {
                        CreateRow(
                            icon: "square.and.pencil",
                            title: "New Moment",
                            subtitle: "Share a post or story"
                        )
                    }
                }
                .padding(.bottom, 8)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 24)
            .background(
                // The pop-up itself is fully opaque; only the overlay is dimmed
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color(.systemBackground))
            )
            .shadow(radius: 30)
            .padding(.horizontal, 12)
            .padding(.bottom, 0)
            // --- Card animation only ---
            .offset(y: cardVisible ? 0 : 260)
            .opacity(cardVisible ? 1 : 0.4)
        }
        .background(Color.clear) // no extra dark block
        .ignoresSafeArea(edges: .bottom)
        .onAppear {
            animateOpen()
        }
    }

    // MARK: - Animations

    private func animateOpen() {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            cardVisible = true
        }
        withAnimation(.easeOut(duration: 0.18)) {
            overlayOpacity = 0.12
        }
    }

    /// Animate the card & background down, then run completion (close)
    private func closeWithAnimation(_ completion: @escaping () -> Void) {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
            cardVisible = false
        }
        withAnimation(.easeInOut(duration: 0.2)) {
            overlayOpacity = 0.0
        }

        let delay = 0.22
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            completion()
        }
    }
}

// MARK: - Row for each create action

private struct CreateRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.primary.opacity(0.06))
                    .frame(width: 42, height: 42)

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary.opacity(0.7))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .contentShape(Rectangle())
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color(.systemBackground)
            .ignoresSafeArea()

        VStack {
            Text("Underlying tab content")
            Spacer()
        }

        CreateTabView(
            challenges: ChallengeService(),
            buddies: LocalBuddyService(),
            onSelect: { _ in },
            onClose: {}
        )
    }
}
