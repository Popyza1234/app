import SwiftUI

/// Full-screen announcement card shown after the launch screen on every app
/// launch. Dismissing it only closes the card for this session.
struct AnnouncementView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openURL) private var openURL
    let announcement: DekpopAnnouncement
    let onDismiss: () -> Void

    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.black.opacity(appeared ? 0.45 : 0)
                .ignoresSafeArea()
                .onTapGesture { close() }

            card
                .scaleEffect(appeared ? 1 : 0.86)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 24)
        }
        .onAppear {
            withAnimation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.82)) {
                appeared = true
            }
        }
    }

    private var card: some View {
        VStack(spacing: 0) {
            if let imageName = announcement.imageName {
                Image(imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 190)
                    .clipped()
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    Label(
                        language.text("announcement.badge"),
                        systemImage: "megaphone.fill"
                    )
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.accent)
                    Spacer()
                    Button {
                        close()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(language.text("common.close"))
                }

                Text(language.text(announcement.titleKey))
                    .font(.title3.weight(.bold))

                ScrollView {
                    Text(language.text(announcement.bodyKey))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxHeight: 140)

                HStack(spacing: 10) {
                    Button {
                        close()
                    } label: {
                        Text(language.text("announcement.got_it"))
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(AppTheme.softGradient, in: Capsule())
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)

                    if let link = announcement.link {
                        Button {
                            openURL(link)
                        } label: {
                            Label(
                                language.text("announcement.open_link"),
                                systemImage: "arrow.up.right.square"
                            )
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(
                                Capsule()
                                    .strokeBorder(AppTheme.accent.opacity(0.4), lineWidth: 1)
                            )
                            .foregroundStyle(AppTheme.accent)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 4)
            }
            .padding(18)
        }
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(uiColor: .systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(AppTheme.accent.opacity(0.14), lineWidth: 1)
        )
        .shadow(color: AppTheme.brandMiddle.opacity(0.30), radius: 24, x: 0, y: 10)
        .padding(.horizontal, 26)
        .frame(maxWidth: 420)
    }

    private func close() {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.22)) {
            appeared = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0 : 0.22)) {
            onDismiss()
        }
    }
}
