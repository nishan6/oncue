import Foundation
import Network

/// Serves the crew page on the local network: the page itself, the current state as JSON, live
/// updates as Server-Sent Events (phones reconnect by themselves after Wi-Fi drops), and venue
/// comments. Only answers on the chosen network address when one is set.
public final class CrewServer {
    /// A comment posted from a phone (called on the main thread).
    public var onComment: ((_ itemID: String?, _ cueID: String?, _ author: String, _ text: String) -> Void)?
    /// Number of phones following live updates (called on the main thread).
    public var onClientsChanged: ((Int) -> Void)?

    public private(set) var port: UInt16 = 0
    public private(set) var isRunning = false

    private let queue = DispatchQueue(label: "oncue.crew")
    private var listener: NWListener?
    private var streams: [ObjectIdentifier: NWConnection] = [:]
    private var stateJSON = Data("{}".utf8)
    private var allowedHost: String?
    private var heartbeat: DispatchSourceTimer?

    public init() {}

    deinit {
        heartbeat?.cancel()
        listener?.cancel()
    }

    /// Starts listening. `onlyAddress`: answer only on this local IPv4 address (the crew network).
    public func start(port: UInt16, onlyAddress: String? = nil, ready: ((Result<UInt16, Error>) -> Void)? = nil) {
        stop()
        allowedHost = onlyAddress
        do {
            let params = NWParameters.tcp
            params.allowLocalEndpointReuse = true
            let l = try NWListener(using: params, on: port == 0 ? .any : NWEndpoint.Port(rawValue: port) ?? .any)
            l.stateUpdateHandler = { [weak self, weak l] state in
                guard let self, let l else { return }
                switch state {
                case .ready:
                    self.port = l.port?.rawValue ?? port
                    self.isRunning = true
                    let p = self.port
                    DispatchQueue.main.async { ready?(.success(p)) }
                case .failed(let error):
                    self.isRunning = false
                    DispatchQueue.main.async { ready?(.failure(error)) }
                default:
                    break
                }
            }
            l.newConnectionHandler = { [weak self] conn in self?.accept(conn) }
            l.start(queue: queue)
            listener = l
            startHeartbeat()
        } catch {
            ready?(.failure(error))
        }
    }

    public func stop() {
        heartbeat?.cancel()
        heartbeat = nil
        listener?.cancel()
        listener = nil
        queue.async { [weak self] in
            guard let self else { return }
            self.streams.values.forEach { $0.cancel() }
            self.streams.removeAll()
        }
        isRunning = false
    }

    /// New state for every phone.
    public func update(_ snapshot: CrewSnapshot) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        guard let data = try? encoder.encode(snapshot) else { return }
        queue.async {
            self.stateJSON = data
            let event = Data("data: ".utf8) + data + Data("\n\n".utf8)
            for conn in self.streams.values { conn.send(content: event, completion: .idempotent) }
        }
    }

    // MARK: - Connections

    private func accept(_ conn: NWConnection) {
        conn.stateUpdateHandler = { [weak self, weak conn] state in
            guard let self, let conn else { return }
            switch state {
            case .ready:
                if let allowed = self.allowedHost, !allowed.isEmpty,
                   case .hostPort(let host, _)? = conn.currentPath?.localEndpoint {
                    let local = "\(host)".split(separator: "%").first.map(String.init) ?? "\(host)"
                    if local != allowed && local != "127.0.0.1" && local != "::1" {
                        conn.cancel()
                        return
                    }
                }
                self.receive(conn, buffer: Data())
            case .failed, .cancelled:
                self.dropStream(conn)
            default:
                break
            }
        }
        conn.start(queue: queue)
    }

    private func dropStream(_ conn: NWConnection) {
        if streams.removeValue(forKey: ObjectIdentifier(conn)) != nil { notifyClients() }
    }

    private func notifyClients() {
        let count = streams.count
        DispatchQueue.main.async { self.onClientsChanged?(count) }
    }

    private func receive(_ conn: NWConnection, buffer: Data) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, complete, error in
            guard let self else { return }
            var buffer = buffer
            if let data { buffer.append(data) }
            if let request = HTTPRequest.parse(buffer) {
                self.respond(to: request, on: conn)
            } else if complete || error != nil || buffer.count > 1_000_000 {
                conn.cancel()
            } else {
                self.receive(conn, buffer: buffer)
            }
        }
    }

    private func respond(to request: HTTPRequest, on conn: NWConnection) {
        switch (request.method, request.path) {
        case ("GET", "/"), ("GET", "/index.html"):
            send(conn, status: "200 OK", type: "text/html; charset=utf-8", body: Data(CrewPage.html.utf8))
        case ("GET", "/api/state"):
            send(conn, status: "200 OK", type: "application/json", body: stateJSON)
        case ("GET", "/events"):
            let head = "HTTP/1.1 200 OK\r\nContent-Type: text/event-stream\r\nCache-Control: no-cache\r\nConnection: keep-alive\r\nX-Accel-Buffering: no\r\n\r\n"
            let first = Data(head.utf8) + Data("retry: 1500\n\ndata: ".utf8) + stateJSON + Data("\n\n".utf8)
            conn.send(content: first, completion: .idempotent)
            streams[ObjectIdentifier(conn)] = conn
            notifyClients()
            receiveUntilClosed(conn)
        case ("POST", "/api/comment"):
            struct Posted: Decodable { var itemID: String?; var cueID: String?; var author: String?; var text: String }
            if let posted = try? JSONDecoder().decode(Posted.self, from: request.body) {
                DispatchQueue.main.async { self.onComment?(posted.itemID, posted.cueID, posted.author ?? "", posted.text) }
                send(conn, status: "204 No Content", type: "text/plain", body: Data())
            } else {
                send(conn, status: "400 Bad Request", type: "text/plain", body: Data("Bad comment".utf8))
            }
        default:
            send(conn, status: "404 Not Found", type: "text/plain", body: Data("Not found".utf8))
        }
    }

    /// Keeps an event stream open; drops it when the phone goes away.
    private func receiveUntilClosed(_ conn: NWConnection) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 1024) { [weak self] _, _, complete, error in
            if complete || error != nil {
                conn.cancel()
                self?.dropStream(conn)
            } else {
                self?.receiveUntilClosed(conn)
            }
        }
    }

    private func send(_ conn: NWConnection, status: String, type: String, body: Data) {
        let head = "HTTP/1.1 \(status)\r\nContent-Type: \(type)\r\nContent-Length: \(body.count)\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n"
        conn.send(content: Data(head.utf8) + body, completion: .contentProcessed { _ in conn.cancel() })
    }

    private func startHeartbeat() {
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now() + 10, repeating: 10)
        t.setEventHandler { [weak self] in
            guard let self else { return }
            for conn in self.streams.values { conn.send(content: Data(": ping\n\n".utf8), completion: .idempotent) }
        }
        t.resume()
        heartbeat = t
    }
}

/// A parsed HTTP request (enough for the crew page).
struct HTTPRequest {
    let method: String
    let path: String
    let body: Data

    /// Returns nil until the headers and the whole body have arrived.
    static func parse(_ data: Data) -> HTTPRequest? {
        guard let headerEnd = data.range(of: Data("\r\n\r\n".utf8)) else { return nil }
        guard let head = String(data: data[..<headerEnd.lowerBound], encoding: .utf8) else { return nil }
        let lines = head.components(separatedBy: "\r\n")
        let parts = lines.first?.split(separator: " ") ?? []
        guard parts.count >= 2 else { return nil }
        var length = 0
        for line in lines.dropFirst() {
            let pair = line.split(separator: ":", maxSplits: 1)
            if pair.count == 2, pair[0].trimmingCharacters(in: .whitespaces).lowercased() == "content-length" {
                length = Int(pair[1].trimmingCharacters(in: .whitespaces)) ?? 0
            }
        }
        let bodyStart = headerEnd.upperBound
        guard data.count - bodyStart >= length else { return nil }
        let path = String(parts[1]).split(separator: "?").first.map(String.init) ?? "/"
        return HTTPRequest(method: String(parts[0]), path: path, body: data[bodyStart..<(bodyStart + length)])
    }
}

/// This Mac's IPv4 network addresses (for choosing the crew network and the QR code).
public struct NetworkAddress: Hashable, Identifiable {
    public var id: String { interface + address }
    public let interface: String
    public let address: String

    public static func all() -> [NetworkAddress] {
        var result: [NetworkAddress] = []
        var list: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&list) == 0, let first = list else { return [] }
        defer { freeifaddrs(list) }
        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let ifa = cursor {
            defer { cursor = ifa.pointee.ifa_next }
            guard let addr = ifa.pointee.ifa_addr, addr.pointee.sa_family == UInt8(AF_INET) else { continue }
            let flags = Int32(ifa.pointee.ifa_flags)
            guard flags & IFF_UP != 0, flags & IFF_LOOPBACK == 0 else { continue }
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            if getnameinfo(addr, socklen_t(addr.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0 {
                result.append(NetworkAddress(interface: String(cString: ifa.pointee.ifa_name), address: String(cString: host)))
            }
        }
        return result
    }
}
