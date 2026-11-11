import Foundation

/// Presses buttons in Bitfocus Companion over its HTTP API.
/// Companion 3.x+: POST /api/location/<page>/<row>/<column>/press
/// Companion 2.x:  GET  /press/bank/<page>/<bank>
final class CompanionClient {
    var host: String = "127.0.0.1"
    var port: Int = 8000
    var version: CompanionVersion = .v3

    private let session: URLSession = {
        let c = URLSessionConfiguration.ephemeral
        c.timeoutIntervalForRequest = 2
        c.httpMaximumConnectionsPerHost = 4
        return URLSession(configuration: c)
    }()

    private var base: String { "http://\(host):\(port)" }

    func press(_ b: CompanionButton) {
        guard b.enabled else { return }
        var req: URLRequest
        switch version {
        case .v3:
            guard let url = URL(string: "\(base)/api/location/\(b.page)/\(b.row)/\(b.column)/press") else { return }
            req = URLRequest(url: url)
            req.httpMethod = "POST"
        case .v2:
            guard let url = URL(string: "\(base)/press/bank/\(b.page)/\(b.bank)") else { return }
            req = URLRequest(url: url)
            req.httpMethod = "GET"
        }
        session.dataTask(with: req) { [weak self] _, response, _ in
            // Fall back to the 2.x API automatically if 3.x paths are not found.
            guard let self, self.version == .v3, (response as? HTTPURLResponse)?.statusCode == 404 else { return }
            if let url = URL(string: "\(self.base)/press/bank/\(b.page)/\(b.bank)") {
                self.session.dataTask(with: url).resume()
            }
        }.resume()
    }

    /// Reachability check used by the pre-show check and the status bar.
    func ping(_ done: @escaping (Bool) -> Void) {
        guard let url = URL(string: base) else { done(false); return }
        session.dataTask(with: url) { _, response, _ in
            done(response is HTTPURLResponse)
        }.resume()
    }
}
