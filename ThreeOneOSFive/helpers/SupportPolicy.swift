import Foundation

/// 3105 no longer gates device features behind a whitelist of iOS versions or
/// specific beta builds. Every iOS version that can install the app (the
/// deployment target is iOS 16.0) is enabled, including future releases.
enum ExploitSupportPolicy {
    static let minimumDeploymentTarget = "16.0"

    /// Human-readable summary used by the UI and documentation.
    static let supportedRangeSummary = "All iOS versions (16.0+)"

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
