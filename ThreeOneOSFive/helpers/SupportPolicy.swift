import Foundation

/// The mechanism 3105 uses to reach app and system data on the current build.
enum DeviceAccessRoute: String {
    case kernel
    case badQuery
    case worseQuery
    case airLift
    case unsupported

    var titleKey: String {
        switch self {
        case .kernel: return "route.kernel"
        case .badQuery: return "route.bad_query"
        case .worseQuery: return "route.worse_query"
        case .airLift: return "route.air_lift"
        case .unsupported: return "route.unsupported"
        }
    }
}

enum ExploitSupportPolicy {
    static let verifiedIOS17Range = "17.0–17.7.x"
    static let verifiedIOS18Range = "18.0–18.7.1"
    static let verifiedIOS18AirLiftRange = "18.7.2–18.7.10"
    static let verifiedIOS26Range = "26.0–26.6.1"
    static let verifiedIOS26WorseQueryRange = "26.6.2–26.7.2"
    static let verifiedIOS27Range = "27.0–27.2.1"

    static let verifiedIOS26AllRange = "26.0–26.7.2"

    /// Kernel exploit builds. iOS 18.7.2 and later need AirLift instead.
    static func supportsKernelExploit(major: Int, minor: Int, patch: Int) -> Bool {
        guard minor >= 0, patch >= 0 else { return false }

        if major == 17 {
            return minor <= 7
        }

        if major == 18 {
            return minor < 7 || (minor == 7 && patch <= 1)
        }

        return false
    }

    static func accessRoute(
        major: Int,
        minor: Int,
        patch: Int,
        build: String
    ) -> DeviceAccessRoute {
        guard minor >= 0, patch >= 0 else { return .unsupported }

        if supportsKernelExploit(major: major, minor: minor, patch: patch) {
            return .kernel
        }

        if major == 18 {
            return (minor == 7 && (2...10).contains(patch)) ? .airLift : .unsupported
        }

        if major == 26 {
            if minor < 6 || (minor == 6 && patch <= 1) {
                return .badQuery
            }
            if minor == 6 || (minor == 7 && patch <= 2) {
                return .worseQuery
            }
            return .unsupported
        }

        // iOS 27.0 through 27.2.1 (including RC and 27.0.1 / 27.1) use
        // worse_query. Unlisted later builds stay unsupported.
        if major == 27, minor < 3 {
            return .worseQuery
        }

        return .unsupported
    }

    /// Kernel and bad_query builds use the kernel chain, and worse_query builds
    /// still try it first: the 2.0.1 offsets fall back to the newest verified
    /// table on 26.1+ and 27.x instead of failing the launch.
    static func usesKernelChain(
        major: Int,
        minor: Int,
        patch: Int,
        build: String
    ) -> Bool {
        switch accessRoute(
            major: major,
            minor: minor,
            patch: patch,
            build: build
        ) {
        case .kernel, .badQuery, .worseQuery:
            return true
        case .airLift, .unsupported:
            return false
        }
    }

    /// AirLift builds are recognised but cannot be served by this build's
    /// container and file services, so they are reported as unsupported.
    static func isSupported(
        major: Int,
        minor: Int,
        patch: Int,
        build: String
    ) -> Bool {
        switch accessRoute(
            major: major,
            minor: minor,
            patch: patch,
            build: build
        ) {
        case .kernel, .badQuery, .worseQuery:
            return true
        case .airLift, .unsupported:
            return false
        }
    }

    static func requiresAirLift(
        major: Int,
        minor: Int,
        patch: Int,
        build: String
    ) -> Bool {
        accessRoute(
            major: major,
            minor: minor,
            patch: patch,
            build: build
        ) == .airLift
    }
}
