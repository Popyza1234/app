import Foundation

/// Checks whether this device's traffic is really leaving through our proxy.
///
/// Asking a plain-HTTP echo endpoint for the caller's address returns the
/// egress IP: with the Wi-Fi proxy set correctly that answer is the proxy's own
/// address, which is the address the activation API binds UIDs to. Plain HTTP
/// is deliberate — it works before the CA is trusted, so the check can tell the
/// user what is wrong instead of failing on TLS.
enum ProxyRouteCheck {
    enum Result: Equatable {
        case throughProxy(ip: String, milliseconds: Int)
        case direct(ip: String, milliseconds: Int)
        case failed(String)
    }

    /// Two echo services so one being unreachable does not fail the check.
    private static let echoURLs = [
        URL(string: "http://ifconfig.me/ip"),
        URL(string: "http://ipv4.icanhazip.com")
    ].compactMap { $0 }

    static func run(expectedProxyHost: String) async -> Result {
        var lastError = "no endpoint"

        for url in echoURLs {
            var request = URLRequest(url: url)
            request.timeoutInterval = 10
            request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            request.setValue("curl/8.4.0", forHTTPHeaderField: "User-Agent")

            let started = Date()
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                let milliseconds = Int(Date().timeIntervalSince(started) * 1000)

                guard let http = response as? HTTPURLResponse else {
                    lastError = "no HTTP response"
                    continue
                }
                guard (200..<300).contains(http.statusCode) else {
                    lastError = "HTTP \(http.statusCode)"
                    continue
                }

                let ip = String(decoding: data, as: UTF8.self)
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                guard !ip.isEmpty, ip.count <= 64, !ip.contains("<") else {
                    lastError = "unexpected answer"
                    continue
                }

                return ip == expectedProxyHost
                    ? .throughProxy(ip: ip, milliseconds: milliseconds)
                    : .direct(ip: ip, milliseconds: milliseconds)
            } catch {
                lastError = error.localizedDescription
            }
        }

        return .failed(lastError)
    }
}
