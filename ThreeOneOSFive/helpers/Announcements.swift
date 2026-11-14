import Foundation

/// An in-app announcement shown once after an update.
/// Add a new entry at the top of `announcements` to publish a new notice;
/// the first entry is the one displayed, and only until it is dismissed.
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
    static let seenKey = "dekpop.announcement.seen"

    static let announcements: [DekpopAnnouncement] = [
        DekpopAnnouncement(
            id: "ios27-safety-3.0.1",
            titleKey: "announcement.301_title",
            bodyKey: "announcement.301_body",
            imageName: "announcement-banner",
            link: nil
        ),
        DekpopAnnouncement(
            id: "smooth-files-3.0.0",
            titleKey: "announcement.300_title",
            bodyKey: "announcement.300_body",
            imageName: "announcement-banner",
            link: nil
        ),
        DekpopAnnouncement(
            id: "safe-files-2.1.0",
            titleKey: "announcement.200_title",
            bodyKey: "announcement.200_body",
            imageName: "announcement-banner",
            link: nil
        )
    ]

    /// The newest notice that has not been dismissed yet. It is shown after
    /// the launch screen exactly once, then remembered in `UserDefaults`.
    static var current: DekpopAnnouncement? {
        guard let latest = announcements.first else { return nil }
        let seen = UserDefaults.standard.string(forKey: seenKey)
        return seen == latest.id ? nil : latest
    }

    static func markSeen(_ announcement: DekpopAnnouncement) {
        UserDefaults.standard.set(announcement.id, forKey: seenKey)
    }
}
