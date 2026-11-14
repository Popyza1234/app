import Foundation
import Darwin

enum ContainerDiscoveryMerger {
    static func canonicalPath(_ rawPath: String) -> String {
        var path = (rawPath as NSString).standardizingPath
        if path == "/var" || path.hasPrefix("/var/") {
            path = "/private" + path
        }
        while path.count > 1 && path.hasSuffix("/") {
            path.removeLast()
        }
        return path
    }

    static func merge<Element>(
        enumerated: [Element],
        identified: [Element],
        path: (Element) -> String
    ) -> [Element] {
        var result: [Element] = []
        var indexByPath: [String: Int] = [:]

        for element in enumerated {
            let key = canonicalPath(path(element))
            guard !key.isEmpty, indexByPath[key] == nil else { continue }
            indexByPath[key] = result.count
            result.append(element)
        }

        for element in identified {
            let key = canonicalPath(path(element))
            guard !key.isEmpty else { continue }
            if let index = indexByPath[key] {
                result[index] = element
            } else {
                indexByPath[key] = result.count
                result.append(element)
            }
        }
        return result
    }
}

/// dekpop 2.0 — universal, capability-based file access policy.
///
/// The browser used to branch on `majorVersion >= 26`: older releases got
/// direct reads and newer ones were forced through `bad_query` grants, with a
/// failed sandbox escape treated as a fatal error. That is why iOS 27+ could
/// not open any files. There is now a single chain on every iOS version:
///
///   1. direct `FileManager` read (MHA-C2 entitlement / sandbox escape)
///   2. MCM container activation
///   3. `bad_query` traversal grant + retry
///   4. `bad_query_list` inode walk + raw MCM metadata plist reads
///
/// Layers are probed at runtime; a failing layer never disables the others.
enum ContainerAccessPolicy {
    /// Label shown in Settings. Deliberately version-neutral.
    static let engineLabel = "Universal · direct / MCM / grant / inode"

    private static let lock = NSLock()
    private static var consecutiveGrantFailures = 0
    private static var grantsPaused = false
    private static let maxConsecutiveFailures = 3

    /// A traversal grant is issued once for the container root; nested folders
    /// inherit that sandbox extension, and `ContainerStore.listFiles` adds a
    /// direct-read / inode fallback for any subfolder that is still denied.
    /// The decision is capability-based (`shouldAttemptGrant`), never version
    /// based — so iOS 27+ gets the same attempt as older releases.
    static func shouldRequestGrant(isRoot: Bool) -> Bool {
        isRoot && shouldAttemptGrant
    }

    static func shouldAttemptMCM(bundleID: String?) -> Bool {
        guard let bundleID = bundleID?.trimmingCharacters(in: .whitespacesAndNewlines),
              !bundleID.isEmpty else {
            return false
        }
        return UUID(uuidString: bundleID) == nil
    }

    static var shouldAttemptGrant: Bool {
        lock.lock(); defer { lock.unlock() }
        return !grantsPaused
    }

    /// Re-enable grant probing at the start of every browser reload so a
    /// capability that appears later in the process lifetime is picked up
    /// instead of being cached as unavailable.
    static func resetProbing() {
        lock.lock(); defer { lock.unlock() }
        consecutiveGrantFailures = 0
        grantsPaused = false
    }

    /// `bad_query` is cheap when it works but does a dlopen/XPC round trip on
    /// every call. After a few consecutive failures in one reload we stop
    /// retrying it and rely on direct + inode + metadata reads instead.
    static func recordGrantResult(_ handle: Int64) {
        lock.lock(); defer { lock.unlock() }
        if handle >= 0 {
            consecutiveGrantFailures = 0
            grantsPaused = false
            return
        }
        consecutiveGrantFailures += 1
        if consecutiveGrantFailures >= maxConsecutiveFailures, !grantsPaused {
            grantsPaused = true
            log("access: traversal grants unavailable on this build — continuing with direct + inode + metadata reads")
        }
    }
}

enum ContainerBundleCandidateResolver {
    static func candidates(
        savedStateNames: [String],
        preferenceFileNames: [String],
        artifactNames: [String] = []
    ) -> [String] {
        var result: [String] = []
        var seen = Set<String>()

        func append(_ rawIdentifier: String, allowAppleIdentifier: Bool) {
            let identifier = rawIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
            guard isValidBundleIdentifier(identifier),
                  !identifier.hasPrefix("group."),
                  !identifier.hasPrefix("systemgroup."),
                  (allowAppleIdentifier || !identifier.hasPrefix("com.apple.")),
                  seen.insert(identifier).inserted else {
                return
            }
            result.append(identifier)
        }

        for name in savedStateNames where name.hasSuffix(".savedState") {
            append(String(name.dropLast(".savedState".count)), allowAppleIdentifier: true)
        }

        for name in preferenceFileNames where name.hasSuffix(".plist") {
            append(String(name.dropLast(".plist".count)), allowAppleIdentifier: false)
        }

        for name in artifactNames {
            if name.hasSuffix(".binarycookies") {
                append(String(name.dropLast(".binarycookies".count)), allowAppleIdentifier: true)
            } else if let separator = name.range(of: " - ") {
                append(String(name[..<separator.lowerBound]), allowAppleIdentifier: true)
            } else {
                append(name, allowAppleIdentifier: true)
            }
        }

        return result
    }

    static func isValidBundleIdentifier(_ value: String) -> Bool {
        guard !value.isEmpty,
              value.utf8.count <= 255,
              value.contains("."),
              !value.contains(".."),
              value.first != ".",
              value.last != "." else {
            return false
        }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ".-_"))
        return value.unicodeScalars.allSatisfy { allowed.contains($0) }
    }

    static func confirmedCandidate(
        candidates: [String],
        launchServicesIdentifiers: Set<String>
    ) -> String? {
        candidates.first { launchServicesIdentifiers.contains($0) }
    }
}

enum LaunchServicesCandidateExtractor {
    private static func isIdentifierByte(_ byte: UInt8) -> Bool {
        switch byte {
        case 45, 46, 48...57, 65...90, 95, 97...122:
            return true
        default:
            return false
        }
    }

    static func identifiers(from data: Data, limit: Int = 65_536) -> [String] {
        guard limit > 0, !data.isEmpty else { return [] }

        return data.withUnsafeBytes { rawBuffer in
            let bytes = rawBuffer.bindMemory(to: UInt8.self)
            var result: [String] = []
            var seen = Set<String>()
            var index = 0

            while index < bytes.count, result.count < limit {
                guard isIdentifierByte(bytes[index]) else {
                    index += 1
                    continue
                }

                let start = index
                while index < bytes.count, isIdentifierByte(bytes[index]) {
                    index += 1
                }
                let length = index - start
                guard (3...255).contains(length),
                      let identifier = String(bytes: bytes[start..<index], encoding: .utf8),
                      ContainerBundleCandidateResolver.isValidBundleIdentifier(identifier),
                      !identifier.hasPrefix("group."),
                      !identifier.hasPrefix("systemgroup."),
                      seen.insert(identifier).inserted else {
                    continue
                }
                result.append(identifier)
            }

            return result
        }
    }
}

enum MHAIdentifierCatalog {
    static func identifiers(
        dynamic: [String],
        installed: [String],
        research: [String],
        custom: [String],
        launchServices: [String],
        limit: Int = 65_536
    ) -> [String] {
        guard limit > 0 else { return [] }

        var result: [String] = []
        var seen = Set<String>()
        for source in [dynamic, installed, research, custom, launchServices] {
            for rawIdentifier in source where result.count < limit {
                let identifier = rawIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
                guard ContainerBundleCandidateResolver.isValidBundleIdentifier(identifier),
                      !identifier.hasPrefix("group."),
                      !identifier.hasPrefix("systemgroup."),
                      seen.insert(identifier).inserted else {
                    continue
                }
                result.append(identifier)
            }
            if result.count == limit { break }
        }
        return result
    }
}

enum AppDataCatalogMerger {
    static func merge<Element>(
        identified: [Element],
        fallback: [Element],
        identifier: (Element) -> String,
        path: (Element) -> String
    ) -> [Element] {
        var result: [Element] = []
        var seenIdentifiers = Set<String>()
        var identifiedPaths = Set<String>()

        for element in identified {
            let bundleID = identifier(element)
            let canonicalPath = ContainerDiscoveryMerger.canonicalPath(path(element))
            guard !bundleID.isEmpty,
                  !canonicalPath.isEmpty,
                  seenIdentifiers.insert(bundleID).inserted else {
                continue
            }
            identifiedPaths.insert(canonicalPath)
            result.append(element)
        }

        for element in fallback {
            let bundleID = identifier(element)
            let canonicalPath = ContainerDiscoveryMerger.canonicalPath(path(element))
            guard !bundleID.isEmpty,
                  !canonicalPath.isEmpty,
                  !identifiedPaths.contains(canonicalPath),
                  seenIdentifiers.insert(bundleID).inserted else {
                continue
            }
            result.append(element)
        }
        return result
    }
}

enum ContainerPresentationPolicy {
    static func shouldShow(bundleID: String) -> Bool {
        UUID(uuidString: bundleID) == nil
    }
}

enum AppDisplayNamePolicy {
    static func resolve(bundleID: String, candidates: [String?]) -> String {
        let fallback = bundleID.trimmingCharacters(in: .whitespacesAndNewlines)
        for rawCandidate in candidates {
            guard let rawCandidate else { continue }
            let candidate = rawCandidate.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !candidate.isEmpty,
                  candidate.utf8.count <= 256,
                  candidate.rangeOfCharacter(from: .controlCharacters) == nil,
                  candidate.caseInsensitiveCompare(fallback) != .orderedSame,
                  UUID(uuidString: candidate) == nil else {
                continue
            }
            return candidate
        }
        return fallback
    }
}

struct ApplicationBundleMetadata: Equatable {
    let bundleID: String
    let displayName: String
    let version: String
}

enum ApplicationBundleMetadataReader {
    static func metadata(
        from plistData: Data,
        localizedInfo: [String: Any]? = nil
    ) -> ApplicationBundleMetadata? {
        guard let info = try? PropertyListSerialization.propertyList(
            from: plistData,
            options: [],
            format: nil
        ) as? [String: Any],
              let rawBundleID = info["CFBundleIdentifier"] as? String else {
            return nil
        }

        let bundleID = rawBundleID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard ContainerBundleCandidateResolver.isValidBundleIdentifier(bundleID) else {
            return nil
        }

        let displayName = AppDisplayNamePolicy.resolve(
            bundleID: bundleID,
            candidates: [
                localizedInfo?["CFBundleDisplayName"] as? String,
                localizedInfo?["CFBundleName"] as? String,
                info["CFBundleDisplayName"] as? String,
                info["CFBundleName"] as? String
            ]
        )
        let version = (info["CFBundleShortVersionString"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return ApplicationBundleMetadata(
            bundleID: bundleID,
            displayName: displayName,
            version: version
        )
    }
}

// MARK: - Compatibility diagnostics

/// One probe result shown in the in-app compatibility report.
struct CompatibilityProbe: Identifiable, Hashable {
    let id: String
    let titleKey: String
    let detail: String
    let succeeded: Bool
}

/// Runs the same access layers the Files browser uses and reports which ones
/// actually work on this device. This makes an iOS 27.0.1 failure diagnosable
/// instead of looking like "the version is not supported".
enum CompatibilitySelfTest {
    struct Report {
        let version: String
        let build: String
        let device: String
        let versionAccepted: Bool
        let probes: [CompatibilityProbe]
    }

    static func run() -> Report {
        // A fresh probe must not inherit a paused grant state from an earlier
        // reload, otherwise it would report "unavailable" wrongly.
        ContainerAccessPolicy.resetProbing()
        let fm = FileManager.default
        var probes: [CompatibilityProbe] = []

        func add(_ id: String, _ key: String, _ ok: Bool, _ detail: String) {
            probes.append(CompatibilityProbe(id: id, titleKey: key, detail: detail, succeeded: ok))
        }

        let accepted = AppSupportPolicy.accepts(
            version: AppInfo.osVersion,
            build: AppInfo.osBuild
        )
        add("version", "compat.version", accepted,
            "iOS \(AppInfo.osVersion) (\(AppInfo.osBuild))")

        // The app's own Documents folder always works — no entitlement or
        // exploit needed. This is the guaranteed fallback on every iOS build.
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first
        let docsReadable = docs.map { (try? fm.contentsOfDirectory(atPath: $0.path)) != nil } ?? false
        add("documents", "compat.documents", docsReadable,
            docs?.lastPathComponent ?? "unavailable")

        let root = ContainerStore.appDataRoot
        do {
            let names = try fm.contentsOfDirectory(atPath: root)
            add("direct", "compat.direct", !names.isEmpty, "\(names.count) entries")
        } catch {
            add("direct", "compat.direct", false, "unreadable · \(error.localizedDescription)")
        }

        var lookupError: NSString?
        let mcmPath = MCMActivateContainerPath(2, "com.apple.mobilesafari", false, &lookupError)
        // Interpolation avoids relying on how the ObjC NSString* bridge is
        // imported on each SDK, so this compiles on every Xcode version.
        let mcmDetail = mcmPath.map { "\($0)" }
            ?? lookupError.map { "\($0)" }
            ?? "no path"
        add("mcm", "compat.mcm", mcmPath != nil, mcmDetail)

        let grant = ContainerStore.grantContainerAccess(root)
        if grant >= 0 { bad_query_release(grant) }
        add("grant", "compat.grant", grant >= 0, "handle \(grant)")

        let inodeNames = ContainerStore.enumerateDirectories(path: root)
        add("inode", "compat.inode", !inodeNames.isEmpty, "\(inodeNames.count) entries")

        // Traversal-grant matrix. Tries every `part_domain` depth and both
        // container classes the app has used, so "iOS 27 denies all of them"
        // is visible instead of one opaque -3.
        var matrixDetail = "no report"
        if let reportPointer = bad_query_diagnose(root) {
            matrixDetail = String(cString: reportPointer)
            free(reportPointer)
        }
        add("grant_matrix", "compat.grant_matrix",
            matrixDetail.contains(": OK"), matrixDetail)

        let report = Report(
            version: AppInfo.osVersion,
            build: AppInfo.osBuild,
            device: AppInfo.displayMachineName,
            versionAccepted: accepted,
            probes: probes
        )
        for probe in report.probes {
            log("compat[\(probe.id)] \(probe.succeeded ? "OK" : "FAIL") — \(probe.detail)")
        }
        return report
    }

    /// Shared text form used by the report's copy button and the Files banner,
    /// so a screenshot is never needed to send diagnostics.
    static func plainText(for report: Report) -> String {
        var lines = [
            "dekpop \(DekpopBrand.version) (\(DekpopBrand.build))",
            "iOS \(report.version) (\(report.build)) · \(report.device)",
            "versionAccepted=\(report.versionAccepted)"
        ]
        for probe in report.probes {
            lines.append("\(probe.id): \(probe.succeeded ? "OK" : "FAIL") — \(probe.detail)")
        }
        // The access-layer probes print their own progress to stdout, which
        // `setupLogCapture` mirrors into AppLog. Include the tail here so the
        // copied report alone contains the exact check that failed, instead of
        // requiring a second trip to a log screen.
        let tail = AppLog.shared.tail(120)
        if !tail.isEmpty {
            lines.append("--- log (last \(tail.count) lines) ---")
            lines.append(contentsOf: tail)
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - Safe folders (system document picker)

/// A user-granted folder from the Files app. Access is stored as a
/// security-scoped bookmark, so it works on every iOS version without any
/// private entitlement.
struct SafeFolder: Identifiable, Hashable {
    let id: String
    let name: String
    let bookmarkData: Data
}

enum SafeFolderBookmarks {
    private static let storageKey = "dekpop.safeFolders.v1"

    static func load() -> [SafeFolder] {
        guard let raw = UserDefaults.standard.array(forKey: storageKey) as? [[String: String]] else {
            return []
        }
        return raw.compactMap { item in
            guard let id = item["id"],
                  let name = item["name"],
                  let base64 = item["bookmark"],
                  let data = Data(base64Encoded: base64) else { return nil }
            return SafeFolder(id: id, name: name, bookmarkData: data)
        }
    }

    @discardableResult
    static func add(url: URL) -> Bool {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? url.bookmarkData(
            options: [],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) else { return false }
        var folders = load().filter { $0.name != url.lastPathComponent }
        folders.append(SafeFolder(
            id: UUID().uuidString,
            name: url.lastPathComponent,
            bookmarkData: data
        ))
        save(folders)
        return true
    }

    /// Resolves the bookmark and keeps the security scope active for the rest
    /// of this launch so FileBrowserView can read the folder by path.
    static func resolve(_ folder: SafeFolder) -> URL? {
        var stale = false
        guard let url = try? URL(
            resolvingBookmarkData: folder.bookmarkData,
            options: [],
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        ) else { return nil }
        _ = url.startAccessingSecurityScopedResource()
        return url
    }

    static func remove(id: String) {
        save(load().filter { $0.id != id })
    }

    private static func save(_ folders: [SafeFolder]) {
        let raw: [[String: String]] = folders.map {
            ["id": $0.id, "name": $0.name, "bookmark": $0.bookmarkData.base64EncodedString()]
        }
        UserDefaults.standard.set(raw, forKey: storageKey)
    }
}
