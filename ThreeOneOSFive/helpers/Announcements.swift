import Foundation

/// An in-app announcement shown every time the app opens.
/// Add a new entry at the top of `announcements` to publish a new notice;
/// the first entry is the one displayed, on every launch.
struct DekpopAnnouncement: Identifiable {
    let id: String
    /// Localization keys — the app ships exactly English and Thai, so the
    /// notice follows the selected language instead of being hard-coded.
    let titleKey: String
    let bodyKey: String
    let imageName: String?
    let link: URL?
}

enum AnnouncementStore {
    static let announcements: [DekpopAnnouncement] = [
        DekpopAnnouncement(
            id: "safe-files-2.1.0",
            titleKey: "announcement.200_title",
            bodyKey: "announcement.200_body",
            imageName: "announcement-banner",
            link: nil
        )
    ]

    /// The notice shown after the launch screen — always the newest one,
    /// every single launch.
    static var current: DekpopAnnouncement? {
        announcements.first
    }
}
