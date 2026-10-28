import SwiftUI

/// The pill that opens a video call. `isLive` makes it glow softly while the
/// meeting is about to start or already running.
struct JoinButton: View {
    var large = false
    var isLive = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: large ? 5 : 4) {
                Image(systemName: "video.fill")
                    .font(.system(size: large ? 10 : 8.5))
                Text("Join")
            }
        }
        .buttonStyle(JoinButtonStyle(large: large, isLive: isLive))
        .help("Join meeting")
    }
}

private struct JoinButtonStyle: ButtonStyle {
    let large: Bool
    let isLive: Bool

    func makeBody(configuration: Configuration) -> some View {
        Pill(configuration: configuration, large: large, isLive: isLive)
    }

    private struct Pill: View {
        let configuration: Configuration
        let large: Bool
        let isLive: Bool

        @State private var isHovered = false
        @State private var glowing = false

        var body: some View {
            configuration.label
                .font(.system(size: large ? 12 : 10, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, large ? 12 : 8)
                .padding(.vertical, large ? 5 : 3.5)
                .background(Capsule().fill(Color.accentColor.gradient))
                // A thin top highlight gives the pill a bit of depth.
                .overlay(
                    Capsule().strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.4), .white.opacity(0.05)],
                            startPoint: .top, endPoint: .bottom
                        ),
                        lineWidth: 0.5
                    )
                )
                .shadow(
                    color: Color.accentColor.opacity(glowing || isHovered ? 0.55 : 0.25),
                    radius: glowing || isHovered ? 5 : 1.5,
                    y: 1
                )
                .brightness(configuration.isPressed ? -0.06 : isHovered ? 0.06 : 0)
                .scaleEffect(configuration.isPressed ? 0.94 : isHovered ? 1.04 : 1)
                .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isHovered)
                .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
                .contentShape(Capsule())
                .onHover { isHovered = $0 }
                .onAppear {
                    guard isLive else { return }
                    withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                        glowing = true
                    }
                }
        }
    }
}
