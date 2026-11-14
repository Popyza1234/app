import Foundation

/// A saved location that opens directly in the Files browser.
struct FolderShortcut: Identifiable, Codable, Equatable, Hashable {
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

    /// Path shown in the UI: relative to the container when possible.
    var relativePath: String {
        guard !containerPath.isEmpty, startPath.hasPrefix(containerPath + "/") else {
            return startPath
        }
        return String(startPath.dropFirst(containerPath.count + 1))
    }

    static func resolvedPath(path: String, containerPath: String) -> String {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return containerPath }
        if trimmed.hasPrefix("/") {
            return URL(fileURLWithPath: trimmed).standardizedFileURL.path
        }
        guard !containerPath.isEmpty else { return trimmed }
        return URL(fileURLWithPath: containerPath, isDirectory: true)
            .appendingPathComponent(trimmed)
            .standardizedFileURL
            .path
    }
}

/// Persistence for user-created folder shortcuts.
///
/// This used to live in `AssetSetService` together with the removed asset-set
/// feature. Keeping shortcuts in their own tiny store means the app no longer
/// compiles the asset-set models, views or apply pipeline at all.
enum ShortcutStore {
    static let storageFileName = "download-shortcuts.json"
    static let storageDirectoryName = "Shortcuts"

    static var workspaceURL: URL? {
        try? FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
    }

    static var storageDirectoryURL: URL? {
        guard let workspace = workspaceURL else { return nil }
        let dir = workspace.appendingPathComponent(storageDirectoryName, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Reads the old location first so existing installs keep their shortcuts
    /// after the Asset Sets feature is removed.
    static var legacyStorageURL: URL? {
        workspaceURL?
            .appendingPathComponent("AssetSets", isDirectory: true)
            .appendingPathComponent(storageFileName, isDirectory: false)
    }

    static var storageURL: URL? {
        storageDirectoryURL?.appendingPathComponent(storageFileName, isDirectory: false)
    }

    static func loadShortcuts() -> [FolderShortcut] {
        let candidates = [storageURL, legacyStorageURL].compactMap { $0 }
        for url in candidates {
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            do {
                let data = try Data(contentsOf: url)
                let shortcuts = try JSONDecoder().decode([FolderShortcut].self, from: data)
                if url == legacyStorageURL {
                    saveShortcuts(shortcuts)
                }
                return shortcuts
            } catch {
                log("shortcuts: failed to load \(url.path): \(error.localizedDescription)")
            }
        }
        return []
    }

    static func saveShortcuts(_ shortcuts: [FolderShortcut]) {
        guard let url = storageURL else { return }
        do {
            let data = try JSONEncoder().encode(shortcuts)
            try data.write(to: url, options: .atomic)
        } catch {
            log("shortcuts: failed to save: \(error.localizedDescription)")
        }
    }
}
