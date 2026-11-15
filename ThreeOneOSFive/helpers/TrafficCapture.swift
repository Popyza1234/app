import Foundation

/// One captured HTTP exchange.
struct TrafficEntry: Identifiable, Hashable {
    enum Source: String, Hashable {
        case app
        case proxy
    }

    let id: String
    let source: Source
    let method: String
    let url: String
    let status: Int?
    let started: Date
    let duration: Double
    let requestHeaders: [String: String]
    let responseHeaders: [String: String]
    let requestBody: String?
    let responseBody: String?

    /// Short host + path for the list row.
    var shortTarget: String {
        guard let parsed = URL(string: url) else { return url }
        let path = parsed.path.isEmpty ? "/" : parsed.path
        return (parsed.host ?? "") + path
    }

    var statusColorKey: String {
        guard let status else { return "none" }
        switch status {
        case ..<300: return "ok"
        case ..<400: return "redirect"
        case ..<500: return "client"
        default: return "server"
        }
    }

    /// Enough to replay the call from a terminal.
    var curlCommand: String {
        var parts = ["curl -X \(method) '\(url)'"]
        for (key, value) in requestHeaders.sorted(by: { $0.key < $1.key }) {
            parts.append("-H '\(key): \(value)'")
        }
        if let requestBody, !requestBody.isEmpty {
            let escaped = requestBody.replacingOccurrences(of: "'", with: "'\\''")
            parts.append("--data '\(escaped)'")
        }
        return parts.joined(separator: " \\\n  ")
    }
}

/// Ring buffer of what the app itself sent, so the traffic screen has something
/// to show without any server-side capture.
@MainActor
final class TrafficRecorder: ObservableObject {
    static let shared = TrafficRecorder()

    @Published private(set) var entries: [TrafficEntry] = []

    private let limit = 200
    private let bodyLimit = 4000

    private init() {}

    func record(
        method: String,
        url: String,
        status: Int?,
        started: Date,
        duration: Double,
        requestHeaders: [String: String],
        responseHeaders: [String: String] = [:],
        requestBody: String? = nil,
        responseBody: String? = nil
    ) {
        let entry = TrafficEntry(
            id: UUID().uuidString,
            source: .app,
            method: method.uppercased(),
            url: url,
            status: status,
            started: started,
            duration: duration,
            requestHeaders: requestHeaders,
            responseHeaders: responseHeaders,
            requestBody: clipped(requestBody),
            responseBody: clipped(responseBody)
        )

        entries.insert(entry, at: 0)
        if entries.count > limit {
            entries.removeLast(entries.count - limit)
        }
    }

    func clear() {
        entries.removeAll()
    }

    private func clipped(_ text: String?) -> String? {
        guard let text, !text.isEmpty else { return nil }
        return text.count > bodyLimit ? String(text.prefix(bodyLimit)) + "…" : text
    }
}

/// Pulls capture history from a mitmproxy instance.
///
/// mitmweb serves the flows its UI uses under `/flows`; that is the shape parsed
/// here, so pointing the app at `http://<host>:8081` with the token configured in
/// `proxy-capture/mitm_addon.py` is enough. A plain array, `{"data": [...]}` and
/// `{"flows": [...]}` are all accepted.
struct FlowClient {
    struct Config: Equatable {
        var baseURL: String = UserDefaults.standard.string(forKey: "traffic.flowBase") ?? ""
        var token: String = UserDefaults.standard.string(forKey: "traffic.flowToken") ?? ""

        func save() {
            UserDefaults.standard.set(baseURL, forKey: "traffic.flowBase")
            UserDefaults.standard.set(token, forKey: "traffic.flowToken")
        }
    }

    enum Failure: Error {
        case badURL
        case transport(String)
        case decoding
    }

    static func fetch(_ config: Config, limit: Int = 120) async throws -> [TrafficEntry] {
        var trimmed = config.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw Failure.badURL }
        while trimmed.hasSuffix("/") { trimmed.removeLast() }
        guard let url = URL(string: trimmed.hasSuffix("/flows") ? trimmed : trimmed + "/flows") else {
            throw Failure.badURL
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        if !config.token.isEmpty {
            request.setValue(config.token, forHTTPHeaderField: "X-Capture-Token")
            request.setValue("Bearer \(config.token)", forHTTPHeaderField: "Authorization")
        }

        let started = Date()
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw Failure.transport(error.localizedDescription)
        }

        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        await MainActor.run {
            TrafficRecorder.shared.record(
                method: "GET",
                url: url.absoluteString,
                status: status,
                started: started,
                duration: Date().timeIntervalSince(started) * 1000,
                requestHeaders: request.allHTTPHeaderFields ?? [:],
                responseBody: String(data: data.prefix(2000), encoding: .utf8)
            )
        }

        guard (200..<300).contains(status) else {
            throw Failure.transport("HTTP \(status)")
        }

        guard let root = try? JSONSerialization.jsonObject(with: data) else {
            throw Failure.decoding
        }

        let raw: [[String: Any]]
        if let array = root as? [[String: Any]] {
            raw = array
        } else if let object = root as? [String: Any],
                  let list = (object["data"] ?? object["flows"]) as? [[String: Any]] {
            raw = list
        } else {
            throw Failure.decoding
        }

        return raw.prefix(limit).compactMap(parse)
    }

    // MARK: - Parsing

    private static func parse(_ object: [String: Any]) -> TrafficEntry? {
        // mitmweb ships request/response objects; the addon can also emit a flat
        // shape, so both are handled.
        let request = object["request"] as? [String: Any] ?? object
        let response = object["response"] as? [String: Any]

        let method = string(request["method"]) ?? string(object["method"]) ?? "GET"
        let url = string(request["pretty_url"])
            ?? string(object["url"])
            ?? composeURL(request)
        guard !url.isEmpty else { return nil }

        let status = int(response?["status_code"]) ?? int(object["status"])

        let stamp = double(object["timestamp"])
            ?? double(object["started_at"])
            ?? double(request["timestamp"])
        let started = stamp.map { Date(timeIntervalSince1970: $0) } ?? Date()

        let duration = double(object["duration"]) ?? double(object["time"]) ?? 0

        return TrafficEntry(
            id: string(object["id"]) ?? UUID().uuidString,
            source: .proxy,
            method: method.uppercased(),
            url: url,
            status: status,
            started: started,
            duration: duration,
            requestHeaders: headers(request["headers"]),
            responseHeaders: headers(response?["headers"]),
            requestBody: body(request),
            responseBody: body(response)
        )
    }

    private static func composeURL(_ request: [String: Any]) -> String {
        let scheme = string(request["scheme"]) ?? "https"
        let host = string(request["host"]) ?? ""
        let port = int(request["port"]) ?? 0
        let path = string(request["path"]) ?? "/"
        guard !host.isEmpty else { return "" }
        let defaultPort = (scheme == "https" && port == 443) || (scheme == "http" && port == 80) || port == 0
        return "\(scheme)://\(host)\(defaultPort ? "" : ":\(port)")\(path)"
    }

    private static func headers(_ value: Any?) -> [String: String] {
        if let dictionary = value as? [String: String] { return dictionary }
        if let pairs = value as? [[String: Any]] {
            var result: [String: String] = [:]
            for pair in pairs {
                guard let name = string(pair["name"]) ?? (pair.keys.first) else { continue }
                result[name] = string(pair[name]) ?? string(pair["value"]) ?? ""
            }
            return result
        }
        if let list = value as? [Any], list.count % 2 == 0 {
            var result: [String: String] = [:]
            var index = 0
            while index < list.count {
                if let name = string(list[index]), let value = string(list[index + 1]) {
                    result[name] = value
                }
                index += 2
            }
            return result
        }
        return [:]
    }

    private static func body(_ object: [String: Any]?) -> String? {
        if let text = string(object?["content"]) { return text }
        if let text = string(object?["text"]) { return text }
        if let text = string(object?["body"]) { return text }
        return nil
    }

    private static func string(_ value: Any?) -> String? {
        if let text = value as? String, !text.isEmpty { return text }
        if let number = value as? NSNumber { return number.stringValue }
        return nil
    }

    private static func int(_ value: Any?) -> Int? {
        if let number = value as? NSNumber { return number.intValue }
        if let text = value as? String { return Int(text) }
        return nil
    }

    private static func double(_ value: Any?) -> Double? {
        if let number = value as? NSNumber { return number.doubleValue }
        if let text = value as? String { return Double(text) }
        return nil
    }
}
