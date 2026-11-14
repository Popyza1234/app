import Foundation
import Network
import UIKit

/// Serves the certificate profile from 127.0.0.1, so iOS can install it with no
/// download link, no hosting and no trip through the Files app.
///
/// The app starts a one-file HTTP server, hands its loopback URL to Safari, and
/// Safari shows the normal "Profile Downloaded" flow in Settings. iOS still asks
/// the user to confirm the install and the trust step — that part cannot be
/// automated — but nothing has to be downloaded from the internet first.
final class LocalProfileServer {
    static let shared = LocalProfileServer()

    private var listener: NWListener?
    private var payload = Data()
    private var fileName = "profile.mobileconfig"
    private var stopWorkItem: DispatchWorkItem?
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid

    private init() {}

    /// Starts the server and returns the loopback URL for the profile.
    func start(data: Data, fileName: String) async throws -> URL {
        stop()

        payload = data
        self.fileName = fileName

        let listener = try NWListener(using: .tcp, on: .any)
        self.listener = listener
        listener.newConnectionHandler = { [weak self] connection in
            self?.serve(connection)
        }

        beginBackgroundTask()

        let port: UInt16 = try await withCheckedThrowingContinuation { continuation in
            var resumed = false
            let resume: (Result<UInt16, Error>) -> Void = { result in
                guard !resumed else { return }
                resumed = true
                continuation.resume(with: result)
            }

            listener.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    resume(.success(listener.port?.rawValue ?? 0))
                case .failed(let error):
                    resume(.failure(error))
                case .cancelled:
                    resume(.failure(NWError.posix(.ECANCELED)))
                case .setup, .waiting:
                    break
                @unknown default:
                    break
                }
            }

            listener.start(queue: .main)
        }

        guard port != 0,
              let url = URL(string: "http://127.0.0.1:\(port)/\(fileName)") else {
            stop()
            throw NWError.posix(.EINVAL)
        }

        scheduleAutoStop()
        return url
    }

    func stop() {
        stopWorkItem?.cancel()
        stopWorkItem = nil
        listener?.cancel()
        listener = nil
        endBackgroundTask()
    }

    // MARK: - Serving

    private func serve(_ connection: NWConnection) {
        connection.stateUpdateHandler = { state in
            if case .failed = state {
                connection.cancel()
            }
        }
        connection.start(queue: .main)

        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] _, _, _, error in
            guard let self, error == nil else {
                connection.cancel()
                return
            }

            let header = """
            HTTP/1.1 200 OK\r
            Content-Type: application/x-apple-aspen-config\r
            Content-Length: \(self.payload.count)\r
            Content-Disposition: attachment; filename="\(self.fileName)"\r
            Cache-Control: no-store\r
            Connection: close\r
            \r

            """

            var response = Data(header.utf8)
            response.append(self.payload)

            connection.send(content: response, completion: .contentProcessed { _ in
                connection.cancel()
            })

            // Safari may ask twice (download + retry); keep serving for a bit.
            self.scheduleAutoStop()
        }
    }

    private func scheduleAutoStop() {
        stopWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.stop()
        }
        stopWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 180, execute: item)
    }

    // MARK: - Background time

    private func beginBackgroundTask() {
        guard backgroundTask == .invalid else { return }
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "profile-install") { [weak self] in
            self?.endBackgroundTask()
        }
    }

    private func endBackgroundTask() {
        guard backgroundTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
    }
}
