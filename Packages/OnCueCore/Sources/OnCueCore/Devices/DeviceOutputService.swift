import Foundation
import Network
import CoreMIDI

/// Sends Device commands cues: MIDI and MSC to a MIDI destination, strings over TCP/UDP or a
/// serial port, HTTP requests, and DMX over Art-Net or sACN (refreshed every second, and at
/// 30 Hz while fading). Simulated targets send nothing; the last few sends are kept for display.
final class DeviceOutputService {
    struct Sent: Identifiable, Equatable {
        let id = UUID()
        let time: Date
        let targetID: UUID
        let summary: String
        let simulated: Bool
        let error: String?
    }

    private(set) var recent: [Sent] = []
    private var connections: [UUID: NWConnection] = [:]
    private var serial: [UUID: Int32] = [:]
    private var midiClient = MIDIClientRef()
    private var midiOut = MIDIPortRef()
    private var mixer = DMXMixer()
    private var lastDMX: [UUID: Double] = [:]
    private var sequence: UInt8 = 0
    private let cid = UUID()
    private let queue = DispatchQueue(label: "oncue.device.out")

    deinit { stop() }

    func stop() {
        connections.values.forEach { $0.cancel() }
        connections.removeAll()
        serial.values.forEach { close($0) }
        serial.removeAll()
    }

    func send(_ payload: DeviceSend, to target: DeviceTarget, now: Double) {
        var error: String?
        if !target.simulated {
            switch target.kind {
            case .midi: error = sendMIDI(payload, to: target)
            case .tcp, .udp:
                if let bytes = payload.kind == .text ? DeviceWire.text(payload.text, ending: target.lineEnding) : nil {
                    error = sendNetwork(bytes, to: target)
                }
            case .serial:
                error = sendSerial(DeviceWire.text(payload.text, ending: target.lineEnding), to: target)
            case .http: error = sendHTTP(payload, to: target)
            case .artNet, .sACN: break
            }
        }
        if target.kind == .artNet || target.kind == .sACN, payload.kind == .dmx {
            mixer.set(target: target.id, channel: payload.dmxChannel, level: payload.dmxLevel, fade: payload.dmxFade, now: now)
            if !target.simulated { sendDMX(target, now: now) }
        }
        record(target, payload.summary, error: error)
    }

    /// Keeps DMX alive (every second) and runs fades (about 30 Hz).
    func tick(targets: [DeviceTarget], now: Double) {
        let changed = mixer.advance(now: now)
        for t in targets where (t.kind == .artNet || t.kind == .sACN) && !t.simulated {
            let last = lastDMX[t.id] ?? 0
            if changed.contains(t.id) ? now - last >= 1.0 / 30 : (now - last >= 1 && lastDMX[t.id] != nil) {
                sendDMX(t, now: now)
            }
        }
    }

    func dmxLevels(_ target: UUID) -> [UInt8] { mixer.bytes(target: target) }

    // MARK: Transports

    private func record(_ target: DeviceTarget, _ summary: String, error: String?) {
        recent.insert(Sent(time: Date(), targetID: target.id, summary: summary, simulated: target.simulated, error: error), at: 0)
        if recent.count > 50 { recent.removeLast(recent.count - 50) }
        if let error { NSLog("OnCue device \(target.name): \(error)") }
    }

    private func connection(_ target: DeviceTarget, host: String, port: Int, udp: Bool) -> NWConnection? {
        if let c = connections[target.id] { return c }
        guard !host.isEmpty, let p = NWEndpoint.Port(rawValue: UInt16(clamping: port)), port > 0 else { return nil }
        let c = NWConnection(host: NWEndpoint.Host(host), port: p, using: udp ? .udp : .tcp)
        c.stateUpdateHandler = { [weak self] state in
            if case .failed = state { DispatchQueue.main.async { self?.connections[target.id] = nil } }
        }
        c.start(queue: queue)
        connections[target.id] = c
        return c
    }

    private func sendNetwork(_ bytes: [UInt8], to target: DeviceTarget) -> String? {
        guard let c = connection(target, host: target.host, port: target.port, udp: target.kind == .udp) else { return "No address set" }
        c.send(content: Data(bytes), completion: .contentProcessed { _ in })
        return nil
    }

    private func sendDMX(_ target: DeviceTarget, now: Double) {
        sequence = sequence &+ 1
        let levels = mixer.bytes(target: target.id)
        let packet: [UInt8]
        let host: String
        if target.kind == .artNet {
            packet = DeviceWire.artDmx(universe: target.universe, levels: levels, sequence: sequence == 0 ? 1 : sequence)
            host = target.host.isEmpty ? "255.255.255.255" : target.host
        } else {
            packet = DeviceWire.sACN(universe: target.universe, levels: levels, sequence: sequence, cid: cid)
            host = target.host.isEmpty ? DeviceWire.sACNMulticast(universe: target.universe) : target.host
        }
        lastDMX[target.id] = now
        guard let c = connection(target, host: host, port: target.port > 0 ? target.port : (target.kind == .artNet ? 6454 : 5568), udp: true) else { return }
        c.send(content: Data(packet), completion: .contentProcessed { _ in })
    }

    private func sendHTTP(_ payload: DeviceSend, to target: DeviceTarget) -> String? {
        guard let url = DeviceWire.url(payload, base: target.baseURL) else { return "Not a valid address" }
        var request = URLRequest(url: url, timeoutInterval: 3)
        request.httpMethod = payload.method.rawValue
        if payload.method != .get, !payload.body.isEmpty { request.httpBody = Data(payload.body.utf8) }
        URLSession.shared.dataTask(with: request) { _, response, error in
            if let error { NSLog("OnCue HTTP \(url): \(error.localizedDescription)") }
            else if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                NSLog("OnCue HTTP \(url): status \(http.statusCode)")
            }
        }.resume()
        return nil
    }

    private func sendMIDI(_ payload: DeviceSend, to target: DeviceTarget) -> String? {
        guard let bytes = DeviceWire.midi(payload) else { return "Not a MIDI message" }
        if midiClient == 0 {
            MIDIClientCreateWithBlock("OnCue device out" as CFString, &midiClient) { _ in }
            MIDIOutputPortCreate(midiClient, "OnCue out" as CFString, &midiOut)
        }
        var dest: MIDIEndpointRef?
        for i in 0..<MIDIGetNumberOfDestinations() {
            let d = MIDIGetDestination(i)
            var name: Unmanaged<CFString>?
            MIDIObjectGetStringProperty(d, kMIDIPropertyDisplayName, &name)
            if (name?.takeRetainedValue() as String?) == target.midiDestination { dest = d; break }
        }
        guard let dest else { return "MIDI destination “\(target.midiDestination)” not found" }
        let size = 1024
        let buffer = UnsafeMutableRawPointer.allocate(byteCount: size, alignment: 8)
        defer { buffer.deallocate() }
        let list = buffer.assumingMemoryBound(to: MIDIPacketList.self)
        var packet = MIDIPacketListInit(list)
        packet = MIDIPacketListAdd(list, size, packet, 0, bytes.count, bytes)
        MIDISend(midiOut, dest, list)
        return nil
    }

    private func sendSerial(_ bytes: [UInt8], to target: DeviceTarget) -> String? {
        var fd = serial[target.id] ?? -1
        if fd < 0 {
            guard !target.serialPath.isEmpty else { return "No serial port set" }
            fd = open(target.serialPath, O_RDWR | O_NOCTTY | O_NONBLOCK)
            guard fd >= 0 else { return "Can't open \(target.serialPath)" }
            var t = termios()
            tcgetattr(fd, &t)
            cfmakeraw(&t)
            let speed = speed_t(target.baud)
            cfsetispeed(&t, speed)
            cfsetospeed(&t, speed)
            t.c_cflag |= tcflag_t(CLOCAL | CREAD)
            tcsetattr(fd, TCSANOW, &t)
            serial[target.id] = fd
        }
        let written = bytes.withUnsafeBufferPointer { write(fd, $0.baseAddress, $0.count) }
        return written == bytes.count ? nil : "Serial write failed"
    }
}

/// Listens for TSL tally (3.1 or 5.0 over UDP) and reports the index on program.
final class TallyListener {
    var onProgram: ((Int) -> Void)?
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "oncue.tally.in")
    private(set) var lastError: String?
    private let version: TSLVersion

    init(version: TSLVersion) { self.version = version }

    func start(port: Int) {
        guard listener == nil, let p = NWEndpoint.Port(rawValue: UInt16(clamping: port)) else { return }
        do {
            let params = NWParameters.udp
            params.allowLocalEndpointReuse = true
            let l = try NWListener(using: params, on: p)
            l.newConnectionHandler = { [weak self] conn in
                guard let self else { return }
                conn.start(queue: self.queue)
                self.receive(conn)
            }
            l.start(queue: queue)
            listener = l
        } catch {
            lastError = "\(error)"
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    private func receive(_ conn: NWConnection) {
        conn.receiveMessage { [weak self] data, _, _, error in
            guard let self else { return }
            if let data {
                let bytes = [UInt8](data)
                var programs: [Int] = []
                switch self.version {
                case .v31, .v40:
                    var k = 0
                    while k + 18 <= bytes.count {
                        if let t = TSL.decode31(Array(bytes[k..<(k + 18)])), t.program { programs.append(t.index) }
                        k += self.version == .v40 ? 22 : 18
                    }
                case .v50:
                    programs = TSL.decode50(bytes)?.tallies.filter(\.program).map(\.index) ?? []
                }
                if let first = programs.first { DispatchQueue.main.async { self.onProgram?(first) } }
            }
            if error == nil { self.receive(conn) }
        }
    }
}
