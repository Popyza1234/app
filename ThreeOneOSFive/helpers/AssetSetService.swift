import Foundation

/// Persistence and apply/export logic for user-created asset sets.
/// Everything lives in the dekpop document workspace so it is reachable from
/// the Files browser and survives app updates.
enum AssetSetService {
    static let storageFileName = "asset-sets.json"
    static let setDirectoryName = "AssetSets"

    static var workspaceURL: URL? {
        try? FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
    }

    static var assetSetsDirectoryURL: URL? {
        guard let workspace = workspaceURL else { return nil }
        let dir = workspace.appendingPathComponent(setDirectoryName, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static var storageURL: URL? {
        assetSetsDirectoryURL?.appendingPathComponent(storageFileName, isDirectory: false)
    }

    // MARK: - Load / Save

    static func loadSets() -> [AssetSet] {
        guard let url = storageURL,
              FileManager.default.fileExists(atPath: url.path) else { return [] }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([AssetSet].self, from: data)
        } catch {
            log("asset-sets: failed to load: \(error.localizedDescription)")
            return []
        }
    }

    static func saveSets(_ sets: [AssetSet]) {
        guard let url = storageURL else {
            log("asset-sets: no storage URL")
            return
        }
        do {
            let data = try JSONEncoder().encode(sets)
            try data.write(to: url, options: .atomic)
        } catch {
            log("asset-sets: failed to save: \(error.localizedDescription)")
        }
    }

    // MARK: - Shortcuts

    static let shortcutsFileName = "download-shortcuts.json"

    static var shortcutsStorageURL: URL? {
        assetSetsDirectoryURL?.appendingPathComponent(shortcutsFileName, isDirectory: false)
    }

    static func loadShortcuts() -> [FolderShortcut] {
        guard let url = shortcutsStorageURL,
              FileManager.default.fileExists(atPath: url.path) else { return [] }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([FolderShortcut].self, from: data)
        } catch {
            log("shortcuts: failed to load: \(error.localizedDescription)")
            return []
        }
    }

    static func saveShortcuts(_ shortcuts: [FolderShortcut]) {
        guard let url = shortcutsStorageURL else { return }
        do {
            let data = try JSONEncoder().encode(shortcuts)
            try data.write(to: url, options: .atomic)
        } catch {
            log("shortcuts: failed to save: \(error.localizedDescription)")
        }
    }

    // MARK: - Items on disk

    static func directoryURL(for set: AssetSet) -> URL? {
        assetSetsDirectoryURL?.appendingPathComponent(set.id.uuidString, isDirectory: true)
    }

    static func fileURL(for item: AssetItem, in set: AssetSet) -> URL? {
        guard !item.relativePath.isEmpty, let dir = directoryURL(for: set) else { return nil }
        return dir.appendingPathComponent(item.relativePath, isDirectory: false)
    }

    static func importFiles(
        urls: [URL],
        into set: AssetSet,
        slot: AssetSlot
    ) -> [(AssetItem, Result<URL, Error>)] {
        guard let dir = directoryURL(for: set) else { return [] }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        return urls.map { source in
            let scoped = source.startAccessingSecurityScopedResource()
            defer {
                if scoped { source.stopAccessingSecurityScopedResource() }
            }

            let displayName = sanitizedItemName(source.lastPathComponent)
            let storedName = safeItemName(displayName, in: dir)
            let destination = dir.appendingPathComponent(storedName, isDirectory: false)
            let item = AssetItem(relativePath: storedName, displayName: displayName, slot: slot)
            do {
                try FileManager.default.copyItem(at: source, to: destination)
                return (item, .success(destination))
            } catch {
                return (item, .failure(error))
            }
        }
    }

    static func deleteItemFile(_ item: AssetItem, in set: AssetSet) {
        guard let url = fileURL(for: item, in: set) else { return }
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            log("asset-sets: failed to remove \(url.lastPathComponent): \(error.localizedDescription)")
        }
    }

    static func deleteItemFiles(of set: AssetSet) {
        guard let dir = directoryURL(for: set) else { return }
        try? FileManager.default.removeItem(at: dir)
    }

    // MARK: - Apply

    static func apply(
        set: AssetSet,
        to targetDirectoryURL: URL,
        conflictPolicy: FileConflictPolicy = .replace
    ) -> AssetSetApplicationResult {
        let fileManager = FileManager.default
        let target = targetDirectoryURL.standardizedFileURL
        let scoped = target.startAccessingSecurityScopedResource()
        defer {
            if scoped { target.stopAccessingSecurityScopedResource() }
        }

        if let containerRoot = containerRootPath(for: target.path) {
            _ = ContainerStore.grantContainerAccess(containerRoot)
        }

        if let ownDirectory = directoryURL(for: set),
           target.path == ownDirectory.standardizedFileURL.path {
            log("asset-sets: refusing to apply into the set storage directory")
            return AssetSetApplicationResult(
                set: set,
                targetDirectory: target,
                copiedCount: 0,
                skippedCount: 0,
                failedCount: set.items.count
            )
        }

        do {
            try fileManager.createDirectory(at: target, withIntermediateDirectories: true)
        } catch {
            log("asset-sets: cannot create \(target.path): \(error.localizedDescription)")
            return AssetSetApplicationResult(
                set: set,
                targetDirectory: target,
                copiedCount: 0,
                skippedCount: 0,
                failedCount: set.items.count
            )
        }

        var copied = 0
        var skipped = 0
        var failed = 0

        for item in set.items {
            guard let source = fileURL(for: item, in: set),
                  fileManager.fileExists(atPath: source.path) else {
                failed += 1
                continue
            }
            let destination = target.appendingPathComponent(source.lastPathComponent, isDirectory: false)
            if conflictPolicy == .fail && fileManager.fileExists(atPath: destination.path) {
                skipped += 1
                continue
            }
            do {
                _ = try FileManagerService.transferItem(
                    at: source,
                    into: target,
                    mode: .copy,
                    conflictPolicy: conflictPolicy
                )
                copied += 1
            } catch FileManagerOperationError.itemAlreadyExists {
                skipped += 1
            } catch {
                log("asset-sets: failed to copy \(item.displayName): \(error.localizedDescription)")
                failed += 1
            }
        }

        log("asset-sets: applied \"\(set.name)\" -> \(target.path): \(copied) copied, \(skipped) skipped, \(failed) failed")
        return AssetSetApplicationResult(
            set: set,
            targetDirectory: target,
            copiedCount: copied,
            skippedCount: skipped,
            failedCount: failed
        )
    }

    // MARK: - Helpers

    private static func sanitizedItemName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleaned = trimmed
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
        guard !cleaned.isEmpty, cleaned != ".", cleaned != ".." else { return "file" }
        return cleaned
    }

    private static func safeItemName(_ name: String, in directory: URL) -> String {
        var candidate = name
        var suffix = 2
        let fileManager = FileManager.default
        while fileManager.fileExists(atPath: directory.appendingPathComponent(candidate).path) {
            let ext = (name as NSString).pathExtension
            let base = (name as NSString).deletingPathExtension
            candidate = ext.isEmpty ? "\(base) \(suffix)" : "\(base) \(suffix).\(ext)"
            suffix += 1
        }
        return candidate
    }

    private static func containerRootPath(for path: String) -> String? {
        for root in [ContainerStore.appDataRoot, ContainerStore.systemDataRoot] {
            let prefix = root.hasSuffix("/") ? root : root + "/"
            guard path.hasPrefix(prefix) else { continue }
            guard let component = path.dropFirst(prefix.count).split(separator: "/").first else { continue }
            return prefix + String(component)
        }
        return nil
    }
}
