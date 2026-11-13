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
    var destination: AssetSetDestination? = nil
    var lastAppliedAt: Date? = nil
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

/// A saved install location so a set can be downloaded with one tap.
struct AssetSetDestination: Codable, Equatable, Hashable {
    enum Kind: String, Codable, CaseIterable, Identifiable {
        case app
        case workspace
        case custom

        var id: String { rawValue }

        func localizedName(language: AppLanguage) -> String {
            language.text("downloads.target_\(rawValue)")
        }

        var iconName: String {
            switch self {
            case .app: return "app"
            case .workspace: return "folder.fill"
            case .custom: return "folder"
            }
        }
    }

    var kind: Kind
    var path: String
    var subfolder: String
    var displayName: String

    var normalizedSubfolder: String {
        subfolder
            .split(separator: "/")
            .map(String.init)
            .filter { !$0.isEmpty && $0 != "." && $0 != ".." }
            .joined(separator: "/")
    }

    var summary: String {
        let base = displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? path
            : displayName
        return normalizedSubfolder.isEmpty ? base : base + "/" + normalizedSubfolder
    }

    func targetURL(workspaceURL: URL?) -> URL? {
        let base: URL?
        switch kind {
        case .workspace:
            base = workspaceURL
        case .app, .custom:
            base = path.isEmpty ? nil : URL(fileURLWithPath: path, isDirectory: true)
        }
        guard let base else { return nil }
        return normalizedSubfolder.isEmpty
            ? base
            : base.appendingPathComponent(normalizedSubfolder, isDirectory: true)
    }
}

/// A saved location that opens directly in the Files browser.
struct DownloadShortcut: Identifiable, Codable, Equatable, Hashable {
    var id = UUID()
    var name: String
    var containerPath: String
    var startPath: String
    var bundleID: String?
    var createdAt: Date

    var fileBrowserDestination: FileBrowserDestination {
        FileBrowserDestination(
            containerPath: containerPath,
            startPath: startPath,
            title: name,
            bundleID: bundleID
        )
    }
}
