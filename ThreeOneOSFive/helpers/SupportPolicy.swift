import Foundation

/// dekpop accepts every iOS version that can install the app.
///
/// There is no version whitelist and no kernel exploit anymore. File access is
/// chosen at runtime from the safe container layers (direct read, MCM
/// activation, traversal grant and inode enumeration) plus folders the user
/// grants through the system document picker.
enum AppSupportPolicy {
    static let minimumDeploymentTarget = "16.0"

    /// Human-readable summary used by diagnostics and documentation.
    static let supportedRangeSummary = "All iOS versions (16.0+)"

    /// File access is selected by runtime capability probes, never by version.
    static let accessPolicySummary = "Capability-based · identical on every iOS version"

    /// Every version string is accepted, including point releases such as
    /// `27.0.1`, beta builds and future majors.
    static func accepts(version: String, build: String) -> Bool {
        true
    }

    static func isSupported(major: Int, minor: Int, patch: Int, build: String) -> Bool {
        accepts(version: "\(major).\(minor).\(patch)", build: build)
    }
}
