import SwiftUI

/// An application's icon in a session row, or a neutral placeholder of the same size
/// while the icon is unknown, loading or unavailable. Decorative for VoiceOver: the
/// row's name already identifies the application.
struct SessionIconView: View {
    let image: UIImage?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Edge length in points: 22 at the default Dynamic Type size, scaled like `.subheadline`
    /// (the row's name).
    nonisolated static func pointSize(for dynamicTypeSize: DynamicTypeSize) -> CGFloat {
        let traits = UITraitCollection(preferredContentSizeCategory: UIContentSizeCategory(dynamicTypeSize))
        return UIFontMetrics(forTextStyle: .subheadline).scaledValue(for: 22, compatibleWith: traits)
    }

    var body: some View {
        let size = Self.pointSize(for: dynamicTypeSize)
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
