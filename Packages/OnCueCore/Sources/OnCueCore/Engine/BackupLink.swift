import Foundation
import Network

/// Where the main Mac is in the show, sent to the backup Mac several times a second.
public struct BackupState: Codable, Equatable {
    public var showID: UUID
    public var itemID: UUID
    public var index: Int
    public var position: Double
    /// "standby", "running" or "stopped".
    public var transport: String
    /// Output id -> mode raw value.
    public var modes: [String: String]
    public var freeMode: Bool
    public var loopSectionID: UUID?
    public var sentAt: Date
}

/// What travels between the Macs: newline-delimited JSON.
public enum BackupMessage: Codable, Equatable {
    case state(BackupState)
    /// The whole show file, when it changes on the main Mac (and when the backup connects).
    case show(Data)
    case hello(machine: String)
}

/// The main Mac's side: serves the backup Macs that connect.
public final class BackupLinkServer {
    public static let defaultPort: UInt16 = 9123
    public var onClientsChanged: ((Int) -> Void)?
    public private(set) var port: UInt16 = 0

    private let queue = DispatchQueue(label: "oncue.backup.server")
    private var listener: NWListener?
    private var clients: [ObjectIdentifier: NWConnection] = [:]
    private var lastShow: Data?

    public init() {}

    public func start(port: UInt16 = BackupLinkServer.defaultPort, ready: ((Result<UInt16, Error>) -> Void)? = nil) {
        stop()
        do {
            let params = NWParameters.tcp
            params.allowLocalEndpointReuse = true
            let l = try NWListener(using: params, on: port == 0 ? .any : NWEndpoint.Port(rawValue: port) ?? .any)
            l.stateUpdateHandler = { [weak self, weak l] state in
                guard let self, let l else { return }
                switch state {
                case .ready:
                    self.port = l.port?.rawValue ?? port
                    let p = self.port
                    DispatchQueue.main.async { ready?(.success(p)) }
                case .failed(let e):
                    DispatchQueue.main.async { ready?(.failure(e)) }
                default: break
                }
            }
            l.newConnectionHandler = { [weak self] conn in self?.accept(conn) }
            l.start(queue: queue)
            listener = l
        } catch {
            ready?(.failure(error))
        }
    }

    public func stop() {
        listener?.cancel()
        listener = nil
        queue.async { [weak self] in
            self?.clients.values.forEach { $0.cancel() }
            self?.clients.removeAll()
        }
    }

    public func send(state: BackupState) { broadcast(.state(state)) }

    public func send(show: Data) {
        queue.async { self.lastShow = show }
        broadcast(.show(show))
    }

    private func broadcast(_ message: BackupMessage) {
        guard let line = BackupWire.encode(message) else { return }
        queue.async {
            for c in self.clients.values { c.send(content: line, completion: .idempotent) }
        }
    }

    private func accept(_ conn: NWConnection) {
        conn.stateUpdateHandler = { [weak self, weak conn] state in
            guard let self, let conn else { return }
            switch state {
            case .ready:
                self.clients[ObjectIdentifier(conn)] = conn
                if let show = self.lastShow, let line = BackupWire.encode(.show(show)) {
                    conn.send(content: line, completion: .idempotent)
                }
                self.notify()
                self.drain(conn)
            case .failed, .cancelled:
                if self.clients.removeValue(forKey: ObjectIdentifier(conn)) != nil { self.notify() }
            default: break
            }
        }
        conn.start(queue: queue)
    }

    private func drain(_ conn: NWConnection) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] _, _, done, error in
            if done || error != nil { conn.cancel() } else { self?.drain(conn) }
        }
    }

    private func notify() {
        let n = clients.count
        DispatchQueue.main.async { self.onClientsChanged?(n) }
    }
}

/// The backup Mac's side: connects to the main Mac and keeps reconnecting.
public final class BackupLinkClient {
    public var onMessage: ((BackupMessage) -> Void)?
    public var onConnectedChanged: ((Bool) -> Void)?

    private let queue = DispatchQueue(label: "oncue.backup.client")
    private var connection: NWConnection?
    private var buffer = Data()
    private var host = ""
    private var port: UInt16 = BackupLinkServer.defaultPort
    private var active = false
    private var connected = false

    public init() {}

    /// "192.168.10.20" or "192.168.10.20:9123".
    public func connect(to address: String) {
        let parts = address.split(separator: ":")
        host = parts.first.map(String.init) ?? address
        port = parts.count > 1 ? UInt16(parts[1]) ?? BackupLinkServer.defaultPort : BackupLinkServer.defaultPort
        active = true
        open()
    }

    public func disconnect() {
        active = false
        connection?.cancel()
        connection = nil
    }

    private func open() {
        guard active, !host.isEmpty, let p = NWEndpoint.Port(rawValue: port) else { return }
        connection?.cancel()
        buffer = Data()
        let conn = NWConnection(host: NWEndpoint.Host(host), port: p, using: .tcp)
        conn.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                self.setConnected(true)
                if let hello = BackupWire.encode(.hello(machine: Host.current().localizedName ?? "Backup")) {
                    conn.send(content: hello, completion: .idempotent)
                }
            case .failed, .waiting:
                self.setConnected(false)
                conn.cancel()
                self.queue.asyncAfter(deadline: .now() + 1) { self.open() }
            case .cancelled:
                self.setConnected(false)
            default: break
            }
        }
        connection = conn
        conn.start(queue: queue)
        receive(conn)
    }

    private func receive(_ conn: NWConnection) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 1 << 20) { [weak self] data, _, done, error in
            guard let self else { return }
            if let data {
                self.buffer.append(data)
                while let nl = self.buffer.firstIndex(of: 0x0A) {
                    let line = self.buffer[self.buffer.startIndex..<nl]
                    self.buffer.removeSubrange(self.buffer.startIndex...nl)
                    if let message = BackupWire.decode(Data(line)) {
                        DispatchQueue.main.async { self.onMessage?(message) }
                    }
                }
            }
            if done || error != nil {
                conn.cancel()
                self.setConnected(false)
                if self.active, conn === self.connection { self.queue.asyncAfter(deadline: .now() + 1) { self.open() } }
            } else {
                self.receive(conn)
            }
        }
    }

    private func setConnected(_ value: Bool) {
        guard value != connected else { return }
        connected = value
        DispatchQueue.main.async { self.onConnectedChanged?(value) }
    }
}

enum BackupWire {
    static func encode(_ m: BackupMessage) -> Data? {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .millisecondsSince1970
        guard var d = try? e.encode(m) else { return nil }
        d.append(0x0A)
        return d
    }

    static func decode(_ d: Data) -> BackupMessage? {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .millisecondsSince1970
        return try? dec.decode(BackupMessage.self, from: d)
    }
}
