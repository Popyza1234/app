import Foundation

/// Builds an installable configuration profile for the proxy's root CA.
///
/// iOS never lets an app trust a root certificate silently — the profile has to
/// go through Settings → Profile Downloaded and then be trusted in Certificate
/// Trust Settings. What this helper removes is the download step: the profile
/// carries the certificate inside it, is written straight into the app's
/// Documents folder (visible in Files because UIFileSharingEnabled is on) and
/// can be shared to Files or AirDrop from here.
enum CertificateInstaller {
    static let profileFileName = "dekpop-proxy-ca.mobileconfig"

    /// mitmproxy root CA served by the proxy at http://mitm.it/cert/cer
    /// SHA-256 69:C6:12:96:13:F1:3A:E3:01:04:45:B9:A4:CE:07:3A:82:7A:58:C3:F8:3C:DE:24:B7:F3:F6:3C:3B:78:54:8D
    /// Valid 2026-11-01 → 2036-10-29. Replace this constant if the provider
    /// regenerates its CA.
    private static let certificatePEM = """
    -----BEGIN CERTIFICATE-----
    MIIDNTCCAh2gAwIBAgIUCJxlDqL9lzXTxUYLs46/Lu1ad9kwDQYJKoZIhvcNAQEL
    BQAwKDESMBAGA1UEAwwJbWl0bXByb3h5MRIwEAYDVQQKDAltaXRtcHJveHkwHhcN
    MjYxMTAxMjI1MDM4WhcNMzYxMDI5MjI1MDM4WjAoMRIwEAYDVQQDDAltaXRtcHJv
    eHkxEjAQBgNVBAoMCW1pdG1wcm94eTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCC
    AQoCggEBANI4KWJNGBoB6WHriGp1vVwGqbYwPkr8xxBhr54H2lPknczwPBxycXfz
    H4trbGx+0vjIRkvS77SIQcyktD82MfJqsbeLGWpV6WQA9sLDDUT4pT/9srozIUdD
    /flKvHOIsWI7AtRyzTmYT4TT9foMvIsXxaDoQKVXNHLxreX/rxj7Ru8lOe8Q5kyL
    v/Sw3/FNz64n2K8l70zvatB8lM0uITJfbPwWXirA5gZXZfu1p0f3YzW6ADkAuLCG
    Z9aaVH99nZfIeJs6lfWAOM6hjgQ4nBUeLCb4AfDUbXQMwRb+b3QREzzu+xvX0x2g
    ZnCjo3Dg8OJQ9it/io0l5RM8OMN9ImcCAwEAAaNXMFUwDwYDVR0TAQH/BAUwAwEB
    /zATBgNVHSUEDDAKBggrBgEFBQcDATAOBgNVHQ8BAf8EBAMCAQYwHQYDVR0OBBYE
    FGm5QAnW3dCDMN5c13naM4TFo8HBMA0GCSqGSIb3DQEBCwUAA4IBAQAS2EAfHF75
    rBGURi+vlsxoehY/pobISwGE3r22fA3s/DP8CRqzxq0IRdVxZLbEyMUKvGY/ZOq6
    rF3D9L5dHbuagMLTvCg45pOR1emTNs/uFJEASXKrmJeSDO42msHcK6PG5zhhubHS
    15unV/osZaVZ+W8NI1pmjm/tx3uvFhMemQRtsMdU8X2aWvBEdQIZBwFRBrgjxEWw
    +rtJfxP87tgzvuSuoTKEK8sdSzKBAZ48AY3dc4vyBcGfqoaUX8nXB8J6EEFrVMGS
    OGi+KzbjidlEIwouhkjeqnsjkYlsi5ZaySnqXE5e0xh2GnrNQjR6q/yjp3UJEm6I
    DaJU7JyOQEo2
    -----END CERTIFICATE-----
    """

    enum InstallError: Error {
        case invalidCertificate
        case encodeFailed
    }

    static var certificateData: Data? {
        let base64 = certificatePEM
            .split(separator: "\n", omittingEmptySubsequences: true)
            .filter { !$0.hasPrefix("-----") }
            .joined()
        return Data(base64Encoded: base64)
    }

    static func makeProfile() throws -> Data {
        guard let der = certificateData else { throw InstallError.invalidCertificate }

        let rootPayload: [String: Any] = [
            "PayloadCertificateFileName": "mitmproxy-ca-cert.cer",
            "PayloadContent": der,
            "PayloadDescription": "mitmproxy root certificate used by the activation proxy.",
            "PayloadDisplayName": "mitmproxy CA",
            "PayloadIdentifier": "com.dekpop.proxy.ca.mitmproxy",
            "PayloadType": "com.apple.security.root",
            "PayloadUUID": "B1C2D3E4-1111-4A2B-9C3D-000000000001",
            "PayloadVersion": 1
        ]

        let profile: [String: Any] = [
            "PayloadContent": [rootPayload],
            "PayloadDisplayName": "dekpop · proxy certificate",
            "PayloadDescription": "Installs the proxy root certificate so HTTPS can be inspected.",
            "PayloadIdentifier": "com.dekpop.proxy.profile",
            "PayloadOrganization": "dekpop",
            "PayloadRemovalDisallowed": false,
            "PayloadType": "Configuration",
            "PayloadUUID": "B1C2D3E4-1111-4A2B-9C3D-000000000002",
            "PayloadVersion": 1
        ]

        do {
            return try PropertyListSerialization.data(
                fromPropertyList: profile,
                format: .xml,
                options: 0
            )
        } catch {
            throw InstallError.encodeFailed
        }
    }

    /// Writes the profile into Documents and returns its URL. The file shows up
    /// in the Files app under *On My iPhone → dekpop*.
    @discardableResult
    static func writeProfileToDocuments() throws -> URL {
        let data = try makeProfile()
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = directory.appendingPathComponent(profileFileName)
        try data.write(to: url, options: .atomic)
        return url
    }
}
