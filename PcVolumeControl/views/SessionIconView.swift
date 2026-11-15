import SwiftUI

/// An application's icon in a session row, or a neutral placeholder of the same size
/// while the icon is unknown, loading or unavailable. Decorative for VoiceOver: the
/// row's name already identifies the application.
struct SessionIconView: View {
    /// Edge length at the default Dynamic Type size; scales with `.subheadline` like the name.
    static let basePointSize: CGFloat = 22

    let image: UIImage?

    @ScaledMetric(relativeTo: .subheadline) private var size = SessionIconView.basePointSize

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            } else {
                RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                    .fill(Color.white.opacity(0.12))
                Image(systemName: "waveform")
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.25)
                    .foregroundColor(.white.opacity(0.45))
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

#Preview {
    HStack {
        SessionIconView(image: nil)
        Text("Spotify")
            .font(.subheadline)
            .foregroundColor(.white)
    }
    .padding()
    .background(Color.almostBlack)
}
