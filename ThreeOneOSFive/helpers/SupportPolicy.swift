import Foundation

/// dekpop 2.0 has no iOS version or build whitelist, and no version-based
/// branching in the file access path. Every iOS version that can install the
/// app (deployment target iOS 16.0) gets the same capability-based Files
/// browser, including iOS 27 and any future major.
enum ExploitSupportPolicy {
    static let minimumDeploymentTarget = "16.0"

    /// Human-readable summary used by the UI and documentation.
    static let supportedRangeSummary = "All iOS versions (16.0+)"

    /// File access is selected by runtime capability probes, never by version.
    static let accessPolicySummary = "Capability-based · identical on every iOS version"

    /// Kernel exploit availability. Kept as a separate entry point so callers
    /// can still ask the question, but no version is excluded anymore.
    static func supportsKernelExploit(major: Int, minor: Int, patch: Int) -> Bool {
        true
    }

    /// No version/build check: any iOS version and any build (beta, release,
    /// or unknown) is accepted. `build` is kept in the signature for call-site
    /// compatibility; it is intentionally not inspected.
    static func isSupported(major: Int, minor: Int, patch: Int, build: String) -> Bool {
        true
    }
}
