import Foundation

/// A one-shot in-app announcement shown when the app opens.
/// Add a new entry at the top of `announcements` (with a fresh `id`) to
/// publish a new notice; users who already dismissed an older `id` will see it.
struct DekpopAnnouncement: Identifiable {
    let id: String
    let title: String
    let body: String
    let imageName: String?
    let link: URL?
}

enum AnnouncementStore {
    private static let dismissedPrefix = "announcement.dismissed."

    static let announcements: [DekpopAnnouncement] = [
        DekpopAnnouncement(
            id: "welcome-1.5.0",
            title: "ยินดีต้อนรับสู่ dekpop 1.5.0",
            body: "หน้าแรกมีแท็บ แอป / ทางลัด / มอด เพิ่มทางลัดโฟลเดอร์ได้เองและคัดลอกพาธไฟล์มาวางได้ทันที ส่วนมอดมี KenModz และ Cheat iOS VIP เปิดในแอป พร้อมไอคอนใหม่ทั้งหมด",
            imageName: "announcement-banner",
            link: nil
        )
    ]

    static func pending() -> DekpopAnnouncement? {
        announcements.first { !isDismissed($0) }
    }

    static func markDismissed(_ announcement: DekpopAnnouncement) {
        UserDefaults.standard.set(true, forKey: dismissedPrefix + announcement.id)
    }

    private static func isDismissed(_ announcement: DekpopAnnouncement) -> Bool {
        UserDefaults.standard.bool(forKey: dismissedPrefix + announcement.id)
    }
}
