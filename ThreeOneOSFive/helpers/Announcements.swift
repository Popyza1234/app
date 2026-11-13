import Foundation

/// An in-app announcement shown every time the app opens.
/// Add a new entry at the top of `announcements` to publish a new notice;
/// the first entry is the one displayed, on every launch.
struct DekpopAnnouncement: Identifiable {
    let id: String
    let title: String
    let body: String
    let imageName: String?
    let link: URL?
}

enum AnnouncementStore {
    static let announcements: [DekpopAnnouncement] = [
        DekpopAnnouncement(
            id: "welcome-1.5.0",
            title: "ยินดีต้อนรับสู่ dekpop 1.5.0",
            body: "หน้าแรกมีแท็บ แอป / ทางลัด / มอด เพิ่มทางลัดโฟลเดอร์ได้เองและคัดลอกพาธไฟล์มาวางได้ทันที ส่วนมอดมี KenModz และ Cheat iOS VIP เปิดในแอป พร้อมไอคอนใหม่ทั้งหมด",
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
