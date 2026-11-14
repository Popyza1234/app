import SwiftUI

/// Screen-fit decisions in one place, so every screen reacts the same way to a
/// narrow iPhone SE, a tall Dynamic Island phone, or a very wide layout.
///
/// The point is that content never touches the bezel and never stretches into
/// unreadably long lines: the inset grows with the screen and the body is
/// clamped to `maxContentWidth`, then centred.
enum DekpopLayout {
    /// Horizontal inset for a screen of this width.
    static func inset(for width: CGFloat) -> CGFloat {
        switch width {
        case ..<340: return 12
        case ..<380: return 14
        case ..<430: return 16
        case ..<560: return 22
        default: return 28
        }
    }

    /// Text and cards stop growing here, however wide the screen gets.
    static let maxContentWidth: CGFloat = 640

    /// Vertical rhythm tightens on short screens so more fits above the fold.
    static func spacing(for height: CGFloat) -> CGFloat {
        height < 700 ? 13 : 16
    }

    /// Fallback width used before the first measurement lands (iPhone portrait).
    static let defaultWidth: CGFloat = 390
}

struct DekpopWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

extension View {
    /// Reports the width this view is laid out at, so a screen can size its
    /// insets without wrapping the whole body in a GeometryReader.
    func dekpopMeasureWidth(_ onChange: @escaping (CGFloat) -> Void) -> some View {
        background(
            GeometryReader { proxy in
                Color.clear.preference(key: DekpopWidthKey.self, value: proxy.size.width)
            }
        )
        .onPreferenceChange(DekpopWidthKey.self, perform: onChange)
    }

    /// Keeps a scrollable body clear of the screen edges, clamps it to a
    /// comfortable line length and centres it on wide layouts.
    ///
    /// The inset has to be applied *before* the flexible frame, otherwise the
    /// body claims the full width and the padding pushes it past the bezel.
    func dekpopContentWidth(inset: CGFloat) -> some View {
        padding(.horizontal, inset)
            .frame(maxWidth: DekpopLayout.maxContentWidth, alignment: .leading)
            .frame(maxWidth: .infinity)
    }
}
