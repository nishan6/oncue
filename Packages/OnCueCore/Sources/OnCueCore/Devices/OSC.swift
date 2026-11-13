import Foundation
import Network

enum OSCValue: Equatable {
    case int(Int32)
    case float(Float)
    case string(String)
}

enum OSC {
    /// Encode one OSC message.
    static func encode(address: String, args: [OSCValue]) -> Data {
        var d = Data()
        d.append(padded(address))
        var tags = ","
        for a in args {
            switch a {
            case .int: tags += "i"
            case .float: tags += "f"
            case .string: tags += "s"
            }
        }
        d.append(padded(tags))
        for a in args {
            switch a {
            case .int(let v):
                var be = v.bigEndian
                d.append(Data(bytes: &be, count: 4))
            case .float(let v):
                var be = v.bitPattern.bigEndian
                d.append(Data(bytes: &be, count: 4))
            case .string(let s):
                d.append(padded(s))
            }
        }
        return d
    }

    private static func padded(_ s: String) -> Data {
        var d = Data(s.utf8)
        d.append(0)
        while d.count % 4 != 0 { d.append(0) }
        return d
    }

    /// Parse "1 0.5 hello \"two words\"" into OSC arguments.
    static func parseArgs(_ text: String) -> [OSCValue] {
        var out: [OSCValue] = []
        var token = ""
        var inQuote = false
        func flush() {
            guard !token.isEmpty else { return }
            if let i = Int32(token) { out.append(.int(i)) }
            else if let f = Float(token) { out.append(.float(f)) }
            else { out.append(.string(token)) }
            token = ""
        }
        for ch in text {
            if ch == "\"" {
                if inQuote { out.append(.string(token)); token = "" }
                inQuote.toggle()
            } else if ch == " " && !inQuote {
                flush()
            } else {
                token.append(ch)
            }
        }
        if inQuote { out.append(.string(token)) } else { flush() }
        return out
    }

    /// Every message in a packet: one message, or a bundle (nested bundles included).
    static func decodeAll(_ data: Data) -> [(String, [OSCValue])] {
        let b = [UInt8](data)
        guard b.count >= 16, b.starts(with: Array("#bundle".utf8) + [0]) else {
            return decode(data).map { [$0] } ?? []
        }
        var out: [(String, [OSCValue])] = []
        var i = 16                                              // "#bundle\0" + 8-byte time tag
        while i + 4 <= b.count {
            let size = Int(UInt32(b[i]) << 24 | UInt32(b[i + 1]) << 16 | UInt32(b[i + 2]) << 8 | UInt32(b[i + 3]))
            i += 4
            guard size > 0, i + size <= b.count else { break }
            out += decodeAll(Data(b[i..<(i + size)]))
            i += size
        }
        return out
    }

    /// Decode a single (non-bundle) OSC message: address and arguments.
    static func decode(_ data: Data) -> (String, [OSCValue])? {
        let b = [UInt8](data)
        var i = 0
        func readString() -> String? {
            guard i < b.count, let end = b[i...].firstIndex(of: 0) else { return nil }
            let s = String(bytes: b[i..<end], encoding: .utf8)
            i = (end + 4) & ~3
            return s
        }
        guard let address = readString(), address.hasPrefix("/") else { return nil }
        guard i < b.count, let tags = readString(), tags.hasPrefix(",") else { return (address, []) }
        var args: [OSCValue] = []
        for t in tags.dropFirst() {
            switch t {
            case "i":
                guard i + 4 <= b.count else { return (address, args) }
                let v = Int32(bitPattern: UInt32(b[i]) << 24 | UInt32(b[i + 1]) << 16 | UInt32(b[i + 2]) << 8 | UInt32(b[i + 3]))
                args.append(.int(v)); i += 4
            case "f":
                guard i + 4 <= b.count else { return (address, args) }
                let bits = UInt32(b[i]) << 24 | UInt32(b[i + 1]) << 16 | UInt32(b[i + 2]) << 8 | UInt32(b[i + 3])
                args.append(.float(Float(bitPattern: bits))); i += 4
            case "s":
                if let s = readString() { args.append(.string(s)) }
            default:
                return (address, args)
            }
        }
        return (address, args)
    }
}

/// Sends OSC to targets (Resolume, Disguise, CasparCG, lighting desks...).
final class OSCSender {
    private let queue = DispatchQueue(label: "oncue.osc.out")
    private var connections: [String: NWConnection] = [:]

    func send(host: String, port: Int, address: String, args: [OSCValue]) {
        guard !host.isEmpty, let p = NWEndpoint.Port(rawValue: UInt16(clamping: port)) else { return }
        let key = "\(host):\(port)"
        let data = OSC.encode(address: address, args: args)
        queue.async {
            let conn: NWConnection
            if let c = self.connections[key] {
                conn = c
            } else {
                conn = NWConnection(host: NWEndpoint.Host(host), port: p, using: .udp)
                conn.start(queue: self.queue)
                self.connections[key] = conn
            }
            conn.send(content: data, completion: .idempotent)
        }
    }
}

/// Listens for OSC control messages: /oncue/<command> [camera number].
/// Lets Companion (and so the Stream Deck XL) drive OnCue.
final class OSCControlListener {
    var onCommand: ((String, [OSCValue]) -> Void)?
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "oncue.osc.in")
    private(set) var port: Int = 0

    func start(port: Int) {
        stop()
        guard let p = NWEndpoint.Port(rawValue: UInt16(clamping: port)), port > 0 else { return }
        self.port = port
        do {
            let l = try NWListener(using: .udp, on: p)
            l.newConnectionHandler = { [weak self] conn in
                guard let self else { return }
                conn.start(queue: self.queue)
                self.receive(conn)
            }
            l.start(queue: queue)
            listener = l
        } catch {
            NSLog("OnCue: OSC listener failed on port \(port): \(error)")
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    private func receive(_ conn: NWConnection) {
        conn.receiveMessage { [weak self] data, _, _, error in
            if let data, let msg = OSC.decode(data) {
                DispatchQueue.main.async { self?.onCommand?(msg.0, msg.1) }
            }
            if error == nil { self?.receive(conn) }
        }
    }
}
