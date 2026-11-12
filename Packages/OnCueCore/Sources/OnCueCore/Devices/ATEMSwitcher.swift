import Foundation
import Network

/// Native Blackmagic ATEM control over the switcher's UDP protocol (port 9910).
/// Works with every ATEM model (Mini, Extreme, SDI, Constellation, M/E models).
/// Packet layout follows the long-established open implementations (Skaarhoj / PyATEMMax).
final class ATEMSwitcher: SwitcherDevice {
    var config: SwitcherConfig
    private(set) var state = SwitcherState()
    var onChange: (() -> Void)?

    // Everything below is only touched on `queue`.
    private let queue = DispatchQueue(label: "oncue.atem")
    private var connection: NWConnection?
    private var sessionID: UInt16 = 0
    private var sessionLocked = false
    private var localPacketID: UInt16 = 0
    private var lastContact = Date()
    private var initDone = false
    private var wantConnected = false
    private var watchdog: DispatchSourceTimer?
    private var shadow = SwitcherState()
    private var me: UInt8 = 0

    private enum Flag: UInt8 {
        case ackRequest = 0x01, hello = 0x02, resend = 0x04, requestNextAfter = 0x08, ack = 0x10
    }

    init(config: SwitcherConfig) {
        self.config = config
    }

    deinit {
        watchdog?.cancel()
        connection?.cancel()
    }

    // MARK: SwitcherDevice

    func connect() {
        let host = config.host
        let me = UInt8(max(0, min(config.me, 7)))
        queue.async {
            self.me = me
            self.wantConnected = true
            self.open(host: host)
            self.startWatchdog(host: host)
        }
    }

    func disconnect() {
        queue.async {
            self.wantConnected = false
            self.watchdog?.cancel()
            self.watchdog = nil
            self.connection?.cancel()
            self.connection = nil
            self.initDone = false
            self.shadow.connected = false
            self.publish()
        }
    }

    func setProgram(_ source: Int) { send("CPgI", [me, 0, hi(source), lo(source)]) }
    func setPreview(_ source: Int) { send("CPvI", [me, 0, hi(source), lo(source)]) }
    func cut() { send("DCut", [me, 0, 0, 0]) }
    func auto() { send("DAut", [me, 0, 0, 0]) }
    func setAux(_ aux: Int, source: Int) { send("CAuS", [0x01, UInt8(clamping: aux), hi(source), lo(source)]) }
    func runMacro(_ index: Int) { send("MAct", [hi(index), lo(index), 0, 0]) }
    func setDSK(_ index: Int, onAir: Bool) { send("CDsL", [UInt8(clamping: index), onAir ? 1 : 0, 0, 0]) }
    func autoDSK(_ index: Int) { send("DDsA", [UInt8(clamping: index), 0, 0, 0]) }
    func setKeyer(_ index: Int, onAir: Bool) { send("CKOn", [me, UInt8(clamping: index), onAir ? 1 : 0, 0]) }
    func fadeToBlack() { send("FtbA", [me, 0x02, 0, 0]) }

    // MARK: Connection

    private func open(host: String) {
        connection?.cancel()
        connection = nil
        sessionID = 0
        sessionLocked = false
        localPacketID = 0
        initDone = false
        shadow = SwitcherState()
        publish()
        guard !host.isEmpty else { return }

        // "host" or "host:port" (the port is for testing against a local stand-in switcher).
        var name = host
        var port: UInt16 = 9910
        if let colon = host.lastIndex(of: ":"), let p = UInt16(host[host.index(after: colon)...]) {
            name = String(host[..<colon])
            port = p
        }
        let conn = NWConnection(host: NWEndpoint.Host(name), port: NWEndpoint.Port(rawValue: port) ?? 9910, using: .udp)
        connection = conn
        conn.stateUpdateHandler = { [weak self, weak conn] st in
            guard let self, let conn, conn === self.connection else { return }
            if case .ready = st { self.sendHello() }
        }
        conn.start(queue: queue)
        receive(on: conn)
        lastContact = Date()
    }

    private func startWatchdog(host: String) {
        watchdog?.cancel()
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now() + 1, repeating: 1)
        t.setEventHandler { [weak self] in
            guard let self, self.wantConnected else { return }
            if Date().timeIntervalSince(self.lastContact) > 5 {
                self.open(host: host)
            }
        }
        t.resume()
        watchdog = t
    }

    private func receive(on conn: NWConnection) {
        conn.receiveMessage { [weak self, weak conn] data, _, _, error in
            guard let self, let conn, conn === self.connection else { return }
            if let data, data.count >= 12 { self.handle([UInt8](data)) }
            if error == nil { self.receive(on: conn) }
        }
    }

    // MARK: Packets

    private func header(flags: Flag, length: Int, ackID: UInt16 = 0, packetID: UInt16 = 0) -> [UInt8] {
        var b = [UInt8](repeating: 0, count: 12)
        let word = (UInt16(flags.rawValue) << 11) | (UInt16(length) & 0x07FF)
        b[0] = UInt8(word >> 8); b[1] = UInt8(word & 0xFF)
        b[2] = UInt8(sessionID >> 8); b[3] = UInt8(sessionID & 0xFF)
        b[4] = UInt8(ackID >> 8); b[5] = UInt8(ackID & 0xFF)
        b[10] = UInt8(packetID >> 8); b[11] = UInt8(packetID & 0xFF)
        return b
    }

    private func sendHello() {
        var b = header(flags: .hello, length: 20)
        b.append(contentsOf: [UInt8](repeating: 0, count: 8))
        b[9] = 0x3A
        b[12] = 0x01
        connection?.send(content: Data(b), completion: .idempotent)
    }

    private func sendAck(_ remoteID: UInt16, helloAck: Bool = false) {
        var b = header(flags: .ack, length: 12, ackID: helloAck ? 0 : remoteID)
        if helloAck { b[9] = 0x03 }
        connection?.send(content: Data(b), completion: .idempotent)
    }

    private func send(_ name: String, _ payload: [UInt8]) {
        queue.async {
            guard self.initDone, let conn = self.connection else { return }
            self.localPacketID = (self.localPacketID + 1) & 0x7FFF
            let cmdLen = 8 + payload.count
            var b = self.header(flags: .ackRequest, length: 12 + cmdLen, packetID: self.localPacketID)
            b.append(UInt8(cmdLen >> 8)); b.append(UInt8(cmdLen & 0xFF))
            b.append(0); b.append(0)
            b.append(contentsOf: Array(name.utf8.prefix(4)))
            b.append(contentsOf: payload)
            conn.send(content: Data(b), completion: .idempotent)
        }
    }

    private func handle(_ p: [UInt8]) {
        let flags = p[0] >> 3
        let length = Int((UInt16(p[0]) << 8 | UInt16(p[1])) & 0x07FF)
        let session = UInt16(p[2]) << 8 | UInt16(p[3])
        let remoteID = UInt16(p[10]) << 8 | UInt16(p[11])
        let isHello = flags & Flag.hello.rawValue != 0

        if isHello {
            // Switcher accepted us (3 in byte 12 means fully booked).
            sessionID = session
            lastContact = Date()
            if p.count > 12, p[12] == 3 { return }
            sendAck(0, helloAck: true)
            return
        }

        if !sessionLocked {
            sessionID = session
            sessionLocked = true
        } else if session != sessionID {
            return
        }
        lastContact = Date()

        if flags & Flag.ackRequest.rawValue != 0 {
            sendAck(remoteID)
        }

        if !initDone && length == 12 && remoteID > 1 {
            initDone = true
            shadow.connected = true
            publish()
        }

        guard p.count > 12 else { return }
        parseCommands(p)
    }

    private func parseCommands(_ p: [UInt8]) {
        var i = 12
        var changed = false
        while i + 8 <= p.count {
            let len = Int(UInt16(p[i]) << 8 | UInt16(p[i + 1]))
            guard len >= 8, i + len <= p.count else { break }
            let name = String(bytes: p[(i + 4)..<(i + 8)], encoding: .ascii) ?? ""
            let d = Array(p[(i + 8)..<(i + len)])
            switch name {
            case "_pin":
                shadow.modelName = str(d, 0, 44); changed = true
            case "InPr" where d.count >= 22:
                let src = u16(d, 0)
                let long = str(d, 2, 20)
                shadow.inputNames[src] = long.isEmpty ? str(d, 22, 4) : long
                changed = true
            case "PrgI" where d.count >= 4:
                if d[0] == me { shadow.program = u16(d, 2); changed = true }
            case "PrvI" where d.count >= 4:
                if d[0] == me { shadow.preview = u16(d, 2); changed = true }
            case "TrPs" where d.count >= 2:
                if d[0] == me { shadow.inTransition = d[1] & 1 != 0; changed = true }
            case "AuxS" where d.count >= 4:
                shadow.aux[Int(d[0])] = u16(d, 2); changed = true
            case "InCm":
                if !initDone { initDone = true; shadow.connected = true; changed = true }
            default:
                break
            }
            i += len
        }
        if changed { publish() }
    }

    private func publish() {
        let snapshot = shadow
        DispatchQueue.main.async {
            self.state = snapshot
            self.onChange?()
        }
    }

    // MARK: Bytes

    private func u16(_ d: [UInt8], _ o: Int) -> Int { Int(UInt16(d[o]) << 8 | UInt16(d[o + 1])) }
    private func str(_ d: [UInt8], _ o: Int, _ n: Int) -> String {
        guard o < d.count else { return "" }
        let slice = d[o..<min(d.count, o + n)].prefix { $0 != 0 }
        return String(bytes: slice, encoding: .utf8) ?? ""
    }
    private func hi(_ v: Int) -> UInt8 { UInt8((v >> 8) & 0xFF) }
    private func lo(_ v: Int) -> UInt8 { UInt8(v & 0xFF) }
}
