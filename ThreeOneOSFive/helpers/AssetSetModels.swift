import Foundation
import SwiftUI

/// A reusable asset set (character/outfit/weapon pack) made from the user's own files.
/// This is intentionally generic: it does not target any specific game's bundle.
struct AssetSet: Identifiable, Codable, Equatable, Hashable {
    var id = UUID()
    var name: String
    var category: AssetCategory
    var version: String
    var iconName: String
    var createdAt: Date
    var items: [AssetItem]
}

struct AssetItem: Identifiable, Codable, Equatable, Hashable {
    var id = UUID()
    var relativePath: String
    var displayName: String
    var slot: AssetSlot
}

enum AssetCategory: String, Codable, CaseIterable, Identifiable {
    case character = "character"
    case outfit = "outfit"
    case weapon = "weapon"
    case bundle = "bundle"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .character: return "person.fill"
        case .outfit: return "tshirt.fill"
        case .weapon: return "scope"
        case .bundle: return "cube.box.fill"
        }
    }

    func localizedName(language: AppLanguage) -> String {
        language.text("asset.category.\(rawValue)")
    }
}

enum AssetSlot: String, Codable, CaseIterable, Identifiable {
    case head = "head"
    case face = "face"
    case body = "body"
    case pants = "pants"
    case shoes = "shoes"
    case accessory = "accessory"
    case weapon = "weapon"
    case other = "other"

    var id: String { rawValue }

    func localizedName(language: AppLanguage) -> String {
        language.text("asset.slot.\(rawValue)")
    }
}

struct AssetSetApplicationResult: Equatable {
    let set: AssetSet
    let targetDirectory: URL
    let copiedCount: Int
    let skippedCount: Int
    let failedCount: Int
}
