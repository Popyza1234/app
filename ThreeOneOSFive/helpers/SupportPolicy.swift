import Foundation

/// dekpop 2.1 has no iOS version or build whitelist, and no version-based
/// branching in the file access path. Every version string is accepted —
/// including point releases such as `27.0.1`, four-component beta strings,
/// and any future major — on every device that can install the app.
enum ExploitSupportPolicy {
    static let minimumDeploymentTarget = "16.0"

    /// Human-readable summary used by the UI and documentation.
    static let supportedRangeSummary = "All iOS versions (16.0+)"

    /// File access is selected by runtime capability probes, never by version.
    static let accessPolicySummary = "Capability-based · identical on every iOS version"

    /// The single, testable version-acceptance entry point. Both parameters
    /// are intentionally ignored: there is no comparison, no whitelist and no
    /// maximum version. `27.0.1` is accepted exactly like `16.0` or `26.0`.
    static func accepts(version: String, build: String) -> Bool {
        true
    }

    /// Kernel exploit availability. Kept as a separate entry point so callers
    /// can still ask the question, but no version is excluded anymore.
    static func supportsKernelExploit(major: Int, minor: Int, patch: Int) -> Bool {
        true
    }

    /// No version/build check: any iOS version and any build (beta, release,
    /// or unknown) is accepted. `build` is kept in the signature for call-site
    /// compatibility; it is intentionally not inspected.
    static func isSupported(major: Int, minor: Int, patch: Int, build: String) -> Bool {
        accepts(version: "\(major).\(minor).\(patch)", build: build)
    }
}
