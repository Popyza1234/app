import SwiftUI

/// One-time release notice shown after the launch screen.
///
/// Performance contract: one static gradient header, one flat card surface, a
/// single small shadow and a 0.18 s fade. There is no photo (the old card
/// decoded a 1 MB JPEG on every appearance), no material blur and no
/// continuous animation, so opening the notice cannot stutter a low-end phone.
struct AnnouncementView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL
    let announcement: DekpopAnnouncement
    let onDismiss: () -> Void

    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.black.opacity(appeared ? 0.42 : 0)
                .ignoresSafeArea()
                .onTapGesture(perform: close)
                .accessibilityHidden(true)

            card
                .opacity(appeared ? 1 : 0)
                .scaleEffect(appeared ? 1 : 0.97)
        }
        .onAppear {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                appeared = true
            }
        }
    }

    private var card: some View {
        VStack(spacing: 0) {
            header
            content
        }
        .background(Color(uiColor: .systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: DekpopRadius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DekpopRadius.large, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.8)
        )
        .shadow(
            color: .black.opacity(colorScheme == .dark ? 0.38 : 0.14),
            radius: 12,
            x: 0,
            y: 6
        )
        .padding(.horizontal, 22)
        .frame(maxWidth: 420)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            DekpopWordmark(compact: true, onBrand: true)
                .layoutPriority(1)

            Spacer(minLength: 8)

            Text(language.text("announcement.version", DekpopBrand.version))
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.white.opacity(0.20)))
                .fixedSize()

            Button(action: close) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color.white.opacity(0.22)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(language.text("common.close"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                AppTheme.brandGradient
                LinearGradient(
                    colors: [Color.white.opacity(0.14), Color.clear],
                    startPoint: .topLeading,
                    endPoint: .center
                )
            }
        )
    }

    // MARK: - Body

    private var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "megaphone.fill")
                    .font(.system(size: 10, weight: .bold))
                Text(language.text("announcement.badge").uppercased())
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .tracking(1.3)
            }
            .foregroundStyle(AppTheme.accent)

            Text(language.text(announcement.titleKey))
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            ScrollView {
                Text(language.text(announcement.bodyKey))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 150)

            Divider().opacity(0.5)

            HStack(spacing: 10) {
                Button(language.text("announcement.got_it"), action: close)
                    .buttonStyle(AnnouncementPrimaryButtonStyle())

                if let link = announcement.link {
                    Button {
                        openURL(link)
                    } label: {
                        Label(
                            language.text("announcement.open_link"),
                            systemImage: "arrow.up.right.square"
                        )
                    }
                    .buttonStyle(DekpopQuietButtonStyle())
                }
            }
        }
        .padding(18)
    }

    private func close() {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.16)) {
            appeared = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0 : 0.16)) {
            onDismiss()
        }
    }
}

/// Flat accent button for the single action on the notice. It deliberately
/// skips the gradient style's large shadow because this card already floats
/// above a dimmed screen.
private struct AnnouncementPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .frame(maxWidth: .infinity, minHeight: 46)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(configuration.isPressed
                          ? AppTheme.accent.opacity(0.86)
                          : AppTheme.accent)
            )
            .animation(DekpopMotion.tap, value: configuration.isPressed)
    }
}
