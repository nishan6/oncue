import Foundation
import Network
import CryptoKit

// MARK: - Text-over-TCP switchers (vMix, and the base for Roland and RossTalk)

/// A switcher driven with text lines over TCP. Reconnects every 2 s while wanted; replies are
/// split into lines and handed to `received(line:)` on the main thread.
class LineSwitcher: SwitcherDevice {
    var config: SwitcherConfig
    var state = SwitcherState()
    var onChange: (() -> Void)?
    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "oncue.switcher.line")
    private var buffer = Data()
    private var wanted = false
    private var retry: DispatchWorkItem?
    var defaultPort: Int { 0 }
    var terminator: String { "\r\n" }
    /// Bytes that end a reply.
    var delimiters: Set<UInt8> { [0x0A, 0x0D] }

    init(config: SwitcherConfig) {
        self.config = config
    }

    /// host or host:port.
    var endpoint: (String, Int) {
        let parts = config.host.split(separator: ":")
        if parts.count == 2, let p = Int(parts[1]) { return (String(parts[0]), p) }
        return (config.host, defaultPort)
    }

    func connect() {
        wanted = true
        open()
    }

    func disconnect() {
        wanted = false
        retry?.cancel()
        connection?.cancel()
        connection = nil
        setConnected(false)
    }

    private func open() {
        connection?.cancel()
        let (host, port) = endpoint
        guard wanted, !host.isEmpty, let p = NWEndpoint.Port(rawValue: UInt16(clamping: port)), port > 0 else { return }
        let c = NWConnection(host: NWEndpoint.Host(host), port: p, using: .tcp)
        c.stateUpdateHandler = { [weak self] s in
            DispatchQueue.main.async {
                guard let self else { return }
                switch s {
                case .ready:
                    self.setConnected(true)
                    self.didConnect()
                case .failed, .cancelled:
                    if self.state.connected { self.setConnected(false) }
                    self.scheduleRetry()
                case .waiting:
                    self.scheduleRetry()
                default: break
                }
            }
        }
        connection = c
        c.start(queue: queue)
        receive(c)
    }

    private func scheduleRetry() {
        guard wanted else { return }
        retry?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.open() }
        retry = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: work)
    }

    private func receive(_ c: NWConnection) {
        c.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, done, error in
            guard let self else { return }
            if let data { self.buffer.append(data); self.drain() }
            if done || error != nil { DispatchQueue.main.async { self.setConnected(false); self.scheduleRetry() } }
            else { self.receive(c) }
        }
    }

    private func drain() {
        let ends = delimiters
        while let k = buffer.firstIndex(where: { ends.contains($0) }) {
            let line = String(decoding: buffer[buffer.startIndex..<k], as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            buffer.removeSubrange(buffer.startIndex...k)
            if !line.isEmpty { DispatchQueue.main.async { self.received(line: line) } }
        }
    }

    func sendLine(_ line: String) {
        guard state.connected, let c = connection else { return }
        c.send(content: Data((line + terminator).utf8), completion: .contentProcessed { _ in })
    }

    func setConnected(_ on: Bool) {
        guard state.connected != on else { return }
        state.connected = on
        onChange?()
    }

    func changed() { onChange?() }

    // Subclasses
    func didConnect() {}
    func received(line: String) {}
    func setProgram(_ source: Int) {}
    func setPreview(_ source: Int) {}
    func cut() {}
    func auto() {}
    func setAux(_ aux: Int, source: Int) {}
    func runMacro(_ index: Int) {}
    func setDSK(_ index: Int, onAir: Bool) {}
    func autoDSK(_ index: Int) {}
    func setKeyer(_ index: Int, onAir: Bool) {}
    func fadeToBlack() {}
}

// MARK: - vMix (TCP API, port 8099)

/// vMix TCP API: FUNCTION commands, and SUBSCRIBE TALLY for program and preview read-back.
/// Inputs are vMix input numbers. DSKs are the four overlay channels; macros are vMix scripts
/// named "Macro N"; keys are not mapped.
final class VMixSwitcher: LineSwitcher {
    override var defaultPort: Int { 8099 }

    override func didConnect() {
        state.modelName = "vMix"
        sendLine("SUBSCRIBE TALLY")
    }

    override func received(line: String) {
        if let t = VMixProtocol.parseTally(line) {
            state.program = t.program ?? state.program
            state.preview = t.preview ?? state.preview
            changed()
        }
    }

    override func setProgram(_ source: Int) { sendLine("FUNCTION CutDirect Input=\(source)") }
    override func setPreview(_ source: Int) { sendLine("FUNCTION PreviewInput Input=\(source)") }
    override func cut() { sendLine("FUNCTION Cut") }
    override func auto() { sendLine("FUNCTION Fade") }
    override func runMacro(_ index: Int) { sendLine("FUNCTION ScriptStart Value=Macro \(index + 1)") }
    override func setDSK(_ index: Int, onAir: Bool) {
        let n = max(1, min(index + 1, 4))
        sendLine("FUNCTION OverlayInput\(n)\(onAir ? "In" : "Out")")
    }
    override func autoDSK(_ index: Int) { sendLine("FUNCTION OverlayInput\(max(1, min(index + 1, 4)))") }
    override func fadeToBlack() { sendLine("FUNCTION FadeToBlack") }
}

public enum VMixProtocol {
    /// "TALLY OK 0121": one digit per input from input 1; 1 = program, 2 = preview.
    public static func parseTally(_ line: String) -> (program: Int?, preview: Int?)? {
        guard line.hasPrefix("TALLY OK ") else { return nil }
        let digits = Array(line.dropFirst("TALLY OK ".count))
        var program: Int?, preview: Int?
        for (k, d) in digits.enumerated() {
            if d == "1", program == nil { program = k + 1 }
            if d == "2", preview == nil { preview = k + 1 }
        }
        return (program, preview)
    }
}

// MARK: - OBS (obs-websocket 5, port 4455)

/// OBS Studio through obs-websocket 5. Inputs are scenes, numbered top to bottom as OBS lists
/// them (1 = top). Preview needs Studio Mode; without it, setting preview does nothing and a cut
/// puts the scene straight on program.
final class OBSSwitcher: SwitcherDevice {
    var config: SwitcherConfig
    var state = SwitcherState()
    var onChange: (() -> Void)?
    private var task: URLSessionWebSocketTask?
    private var wanted = false
    private var scenes: [String] = []
    private var studioMode = false
    private var requestID = 0
    /// Password, from the host field after a "#": "192.168.1.5:4455#secret".
    private var password: String { config.host.split(separator: "#", maxSplits: 1).dropFirst().first.map(String.init) ?? "" }
    private var address: String {
        let host = String(config.host.split(separator: "#", maxSplits: 1).first ?? "")
        return host.contains(":") ? host : host + ":4455"
    }

    init(config: SwitcherConfig) { self.config = config }

    func connect() {
        wanted = true
        open()
    }

    func disconnect() {
        wanted = false
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        set(connected: false)
    }

    private func open() {
        guard wanted, let url = URL(string: "ws://\(address)") else { return }
        let t = URLSession.shared.webSocketTask(with: url)
        task = t
        t.resume()
        listen(t)
    }

    private func retry() {
        guard wanted else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in self?.open() }
    }

    private func listen(_ t: URLSessionWebSocketTask) {
        t.receive { [weak self] result in
            DispatchQueue.main.async {
                guard let self, t === self.task else { return }
                switch result {
                case .success(.string(let text)): self.handle(text); self.listen(t)
                case .success(.data(let data)): self.handle(String(decoding: data, as: UTF8.self)); self.listen(t)
                case .success: self.listen(t)
                case .failure:
                    self.set(connected: false)
                    self.retry()
                }
            }
        }
    }

    private func handle(_ text: String) {
        guard let json = try? JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any],
              let op = json["op"] as? Int, let d = json["d"] as? [String: Any] else { return }
        switch op {
        case 0: // Hello
            var identify: [String: Any] = ["rpcVersion": 1, "eventSubscriptions": 4]   // Scenes events
            if let auth = d["authentication"] as? [String: Any], let challenge = auth["challenge"] as? String,
               let salt = auth["salt"] as? String {
                identify["authentication"] = OBSProtocol.authentication(password: password, salt: salt, challenge: challenge)
            }
            send(op: 1, identify)
        case 2: // Identified
            set(connected: true)
            state.modelName = "OBS Studio"
            request("GetSceneList")
            request("GetStudioModeEnabled")
        case 5: // Event
            let type = d["eventType"] as? String
            let data = d["eventData"] as? [String: Any] ?? [:]
            switch type {
            case "CurrentProgramSceneChanged": program(named: data["sceneName"] as? String)
            case "CurrentPreviewSceneChanged": preview(named: data["sceneName"] as? String)
            case "SceneListChanged": request("GetSceneList")
            case "StudioModeStateChanged": studioMode = data["studioModeEnabled"] as? Bool ?? studioMode
            default: break
            }
        case 7: // RequestResponse
            let type = d["requestType"] as? String
            let data = d["responseData"] as? [String: Any] ?? [:]
            if type == "GetSceneList" {
                scenes = OBSProtocol.sceneOrder(data["scenes"] as? [[String: Any]] ?? [])
                for (k, name) in scenes.enumerated() { state.inputNames[k + 1] = name }
                program(named: data["currentProgramSceneName"] as? String)
                preview(named: data["currentPreviewSceneName"] as? String)
            } else if type == "GetStudioModeEnabled" {
                studioMode = data["studioModeEnabled"] as? Bool ?? false
            }
        default: break
        }
    }

    private func program(named name: String?) {
        guard let name, let k = scenes.firstIndex(of: name) else { return }
        state.program = k + 1
        onChange?()
    }

    private func preview(named name: String?) {
        guard let name, let k = scenes.firstIndex(of: name) else { return }
        state.preview = k + 1
        onChange?()
    }

    private func set(connected: Bool) {
        guard state.connected != connected else { return }
        state.connected = connected
        onChange?()
    }

    private func send(op: Int, _ d: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: ["op": op, "d": d]) else { return }
        task?.send(.string(String(decoding: data, as: UTF8.self))) { _ in }
    }

    private func request(_ type: String, _ data: [String: Any] = [:]) {
        requestID += 1
        var d: [String: Any] = ["requestType": type, "requestId": "oncue-\(requestID)"]
        if !data.isEmpty { d["requestData"] = data }
        send(op: 6, d)
    }

    private func scene(_ input: Int) -> String? { input >= 1 && input <= scenes.count ? scenes[input - 1] : nil }

    func setProgram(_ source: Int) {
        if let s = scene(source) { request("SetCurrentProgramScene", ["sceneName": s]) }
    }

    func setPreview(_ source: Int) {
        guard let s = scene(source) else { return }
        if studioMode { request("SetCurrentPreviewScene", ["sceneName": s]) } else { state.preview = source; onChange?() }
    }

    /// A cut puts the preview scene straight on program.
    func cut() { setProgram(state.preview) }

    /// A transition runs OBS's current transition in Studio Mode; without it, it is a cut.
    func auto() {
        if studioMode { request("TriggerStudioModeTransition") } else { setProgram(state.preview) }
    }

    func setAux(_ aux: Int, source: Int) {}
    func runMacro(_ index: Int) {}
    func setDSK(_ index: Int, onAir: Bool) {}
    func autoDSK(_ index: Int) {}
    func setKeyer(_ index: Int, onAir: Bool) {}
    func fadeToBlack() {}
}

public enum OBSProtocol {
    /// obs-websocket 5 authentication: base64(sha256(base64(sha256(password + salt)) + challenge)).
    public static func authentication(password: String, salt: String, challenge: String) -> String {
        let secret = Data(SHA256.hash(data: Data((password + salt).utf8))).base64EncodedString()
        return Data(SHA256.hash(data: Data((secret + challenge).utf8))).base64EncodedString()
    }

    /// GetSceneList returns scenes bottom-up (sceneIndex 0 = bottom). OnCue numbers them as OBS
    /// shows them, top to bottom.
    public static func sceneOrder(_ scenes: [[String: Any]]) -> [String] {
        scenes.sorted { ($0["sceneIndex"] as? Int ?? 0) > ($1["sceneIndex"] as? Int ?? 0) }
            .compactMap { $0["sceneName"] as? String }
    }
}

// MARK: - Ross (RossTalk, TCP 7788): Carbonite, Graphite, Ultrix Carbonite, Acuity

/// RossTalk commands. RossTalk doesn't report back, so program and preview are assumed from
/// OnCue's own commands; add a TSL tally input from the switcher to catch manual cuts.
/// M/E numbers are the switcher's own (M/E setting 1 = "ME:1"). Macros run custom controls in
/// bank 1 (macro 1 = CC 1:01). DSKs map to keyers on the program M/E.
final class RossTalkSwitcher: LineSwitcher {
    override var defaultPort: Int { 7788 }
    private var me: Int { config.me + 1 }

    override func didConnect() {
        state.modelName = "Ross (RossTalk)"
        state.assumed = true
        changed()
    }

    override func setProgram(_ source: Int) { sendLine(RossTalk.program(me: me, input: source)); state.program = source; changed() }
    override func setPreview(_ source: Int) { sendLine(RossTalk.preview(me: me, input: source)); state.preview = source; changed() }
    override func cut() { sendLine("MECUT ME:\(me)"); swap() }
    override func auto() { sendLine("MEAUTO ME:\(me)"); swap() }
    override func setAux(_ aux: Int, source: Int) { sendLine("XPT AUX:\(aux + 1):IN:\(source)") }
    override func runMacro(_ index: Int) { sendLine(RossTalk.customControl(index)) }
    override func setDSK(_ index: Int, onAir: Bool) { sendLine("KEYAUTO\(onAir ? "ON" : "OFF") ME:\(me):\(index + 1)") }
    override func autoDSK(_ index: Int) { sendLine("KEYAUTO ME:\(me):\(index + 1)") }
    override func setKeyer(_ index: Int, onAir: Bool) { sendLine("KEYCUT\(onAir ? "ON" : "OFF") ME:\(me):\(index + 1)") }
    override func fadeToBlack() { sendLine("FTB") }

    private func swap() {
        let p = state.program
        state.program = state.preview
        state.preview = p
        changed()
    }
}

public enum RossTalk {
    public static func program(me: Int, input: Int) -> String { "XPT ME:\(me):PGM:IN:\(input)" }
    public static func preview(me: Int, input: Int) -> String { "XPT ME:\(me):PST:IN:\(input)" }
    /// Macro index 0 → "CC 1:01".
    public static func customControl(_ index: Int) -> String {
        let n = max(0, index)
        return String(format: "CC %d:%02d", n / 99 + 1, n % 99 + 1)
    }
}

// MARK: - Roland

/// Roland V-160HD and V-80HD (LAN control, TCP 8023): plain ASCII commands ending in ";" and a
/// 4-digit password sent first (host "ip#1234"). Inputs are "INPUT1"…; program and preview are
/// polled with QPGM and QPST.
final class RolandV160Switcher: LineSwitcher {
    override var defaultPort: Int { 8023 }
    override var terminator: String { "" }
    override var delimiters: Set<UInt8> { [0x0A, 0x0D, 0x3B, 0x06] }
    private var poll: Timer?

    override var endpoint: (String, Int) {
        let host = String(config.host.split(separator: "#").first ?? "")
        let parts = host.split(separator: ":")
        if parts.count == 2, let p = Int(parts[1]) { return (String(parts[0]), p) }
        return (host, defaultPort)
    }

    private var password: String { config.host.split(separator: "#", maxSplits: 1).dropFirst().first.map(String.init) ?? "" }

    override func didConnect() {
        state.modelName = "Roland V-160HD / V-80HD"
        if !password.isEmpty { sendLine(password + "\r\n") }
        poll?.invalidate()
        poll = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.sendLine("QPGM;QPST;")
        }
    }

    override func disconnect() {
        poll?.invalidate()
        poll = nil
        super.disconnect()
    }

    override func received(line: String) {
        for reply in RolandProtocol.replies(line) {
            if let n = RolandProtocol.inputNumber(reply, command: "PGM") { if state.program != n { state.program = n; changed() } }
            if let n = RolandProtocol.inputNumber(reply, command: "PST") { if state.preview != n { state.preview = n; changed() } }
        }
    }

    override func setProgram(_ source: Int) { sendLine("PGM:INPUT\(source);") }
    override func setPreview(_ source: Int) { sendLine("PST:INPUT\(source);") }
    override func cut() { sendLine("CUT;") }
    override func auto() { sendLine("ATO;") }
    override func setDSK(_ index: Int, onAir: Bool) { sendLine("DSK:DSK\(index + 1),\(onAir ? "ON" : "OFF");") }
    override func autoDSK(_ index: Int) { sendLine("DSK:DSK\(index + 1);") }
}

/// Roland V-60HD (TCP 8023): STX before each command, inputs numbered from 0, tally polled
/// with TLY (0 dark, 1 red, 2 green for channels 1–8).
final class RolandV60Switcher: LineSwitcher {
    override var defaultPort: Int { 8023 }
    override var terminator: String { "" }
    override var delimiters: Set<UInt8> { [0x0A, 0x0D, 0x3B, 0x06] }
    private var poll: Timer?

    override func didConnect() {
        state.modelName = "Roland V-60HD"
        poll?.invalidate()
        poll = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.sendLine("\u{02}TLY;")
        }
    }

    override func disconnect() {
        poll?.invalidate()
        poll = nil
        super.disconnect()
    }

    override func received(line: String) {
        for reply in RolandProtocol.replies(line) {
            if let t = RolandProtocol.tally(reply) {
                if let p = t.program, p != state.program { state.program = p; changed() }
                if let v = t.preview, v != state.preview { state.preview = v; changed() }
            }
        }
    }

    override func setProgram(_ source: Int) { sendLine("\u{02}PGM:\(max(0, source - 1));") }
    override func setPreview(_ source: Int) { sendLine("\u{02}PST:\(max(0, source - 1));") }
    override func cut() { sendLine("\u{02}CUT;") }
    override func auto() { sendLine("\u{02}ATO;") }
    override func autoDSK(_ index: Int) { sendLine("\u{02}DSK;") }
}

public enum RolandProtocol {
    /// Splits "PGM:HDMI2,INPUT2;ACK;" into ["PGM:HDMI2,INPUT2", "ACK"], dropping STX and ACK bytes.
    public static func replies(_ line: String) -> [String] {
        line.replacingOccurrences(of: "\u{02}", with: "").replacingOccurrences(of: "\u{06}", with: "")
            .split(separator: ";").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    /// "PGM:HDMI2,INPUT2" → 2.
    public static func inputNumber(_ reply: String, command: String) -> Int? {
        guard reply.hasPrefix(command + ":") else { return nil }
        let params = reply.dropFirst(command.count + 1).split(separator: ",")
        for p in params where p.hasPrefix("INPUT") { if let n = Int(p.dropFirst(5)) { return n } }
        return nil
    }

    /// "TLY:0,1,2,0,0,0,0,0" → program 2, preview 3 (channels counted from 1).
    public static func tally(_ reply: String) -> (program: Int?, preview: Int?)? {
        guard reply.hasPrefix("TLY:") else { return nil }
        let values = reply.dropFirst(4).split(separator: ",").map { Int($0.trimmingCharacters(in: .whitespaces)) ?? 0 }
        return (values.firstIndex(of: 1).map { $0 + 1 }, values.firstIndex(of: 2).map { $0 + 1 })
    }
}

// MARK: - Panasonic AV-HS410 (TCP 60040)

/// STX/ETX framed 4-letter commands. Inputs 1–13 are materials 50–62; program and preview are
/// polled with QBSC. Keys, DSK and macros are not mapped yet.
final class PanasonicHS410Switcher: LineSwitcher {
    override var defaultPort: Int { 60040 }
    override var terminator: String { "\u{03}" }
    override var delimiters: Set<UInt8> { [0x03, 0x0A, 0x0D] }
    private var poll: Timer?

    override func didConnect() {
        state.modelName = "Panasonic AV-HS410"
        poll?.invalidate()
        poll = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.sendLine("\u{02}QBSC:02")
            self?.sendLine("\u{02}QBSC:03")
        }
    }

    override func disconnect() {
        poll?.invalidate()
        poll = nil
        super.disconnect()
    }

    override func received(line: String) {
        for reply in line.split(whereSeparator: { $0 == "\u{02}" || $0 == "\u{03}" }) {
            guard let r = PanasonicProtocol.busStatus(String(reply)) else { continue }
            if r.bus == 2, let n = r.input, n != state.program { state.program = n; changed() }
            if r.bus == 3, let n = r.input, n != state.preview { state.preview = n; changed() }
        }
    }

    override func setProgram(_ source: Int) { sendLine("\u{02}" + PanasonicProtocol.selectBus(2, input: source)) }
    override func setPreview(_ source: Int) { sendLine("\u{02}" + PanasonicProtocol.selectBus(3, input: source)) }
    override func cut() { sendLine("\u{02}SCUT:00") }
    override func auto() { sendLine("\u{02}SAUT:00:0:0") }
}

public enum PanasonicProtocol {
    /// Input n → material 49 + n (Input 1 = 50).
    public static func selectBus(_ bus: Int, input: Int) -> String {
        String(format: "SBUS:%02d:%02d", bus, 49 + max(1, min(input, 13)))
    }

    /// "ABSC:02:51:1" → bus 2, input 2.
    public static func busStatus(_ reply: String) -> (bus: Int, input: Int?)? {
        let parts = reply.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: ":")
        guard parts.count >= 3, parts[0] == "ABSC", let bus = Int(parts[1]), let material = Int(parts[2]) else { return nil }
        return (bus, (50...62).contains(material) ? material - 49 : nil)
    }
}

// MARK: - Panasonic AV-UHS500, AV-HS6000, AV-UHS5000 (TCP 62000)

/// Crosspoint control (SBUS on ME1 PGM = 01 and PVW = 02, inputs numbered as the switcher's
/// SDI/IN numbers) and read-back (QBSC). Panasonic's published LAN protocol has no transition
/// command, so a cut sets program directly and an auto transition is also a cut. The switcher
/// drops a connection that is silent for 20 s; polling every half second keeps it open.
final class PanasonicCrosspointSwitcher: LineSwitcher {
    override var defaultPort: Int { 62000 }
    override var terminator: String { "\u{03}" }
    override var delimiters: Set<UInt8> { [0x03, 0x0A, 0x0D] }
    private var poll: Timer?

    override func didConnect() {
        state.modelName = "Panasonic AV-UHS500 / HS6000"
        poll?.invalidate()
        poll = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.sendLine("\u{02}QBSC:01")
            self?.sendLine("\u{02}QBSC:02")
        }
    }

    override func disconnect() {
        poll?.invalidate()
        poll = nil
        super.disconnect()
    }

    override func received(line: String) {
        for reply in line.split(whereSeparator: { $0 == "\u{02}" || $0 == "\u{03}" }) {
            guard let r = PanasonicProtocol.crosspoint(String(reply)) else { continue }
            if r.bus == 1, r.input != state.program { state.program = r.input; changed() }
            if r.bus == 2, r.input != state.preview { state.preview = r.input; changed() }
        }
    }

    override func setProgram(_ source: Int) { sendLine("\u{02}" + PanasonicProtocol.crosspointSelect(bus: 1, input: source)) }
    override func setPreview(_ source: Int) { sendLine("\u{02}" + PanasonicProtocol.crosspointSelect(bus: 2, input: source)) }
    override func cut() { setProgram(state.preview) }
    override func auto() { setProgram(state.preview) }
}

extension PanasonicProtocol {
    public static func crosspointSelect(bus: Int, input: Int) -> String {
        String(format: "SBUS:%02d:%02d", bus, max(1, input))
    }

    /// "ABSC:01:05" or "ABUS:01:05" → bus 1, input 5.
    public static func crosspoint(_ reply: String) -> (bus: Int, input: Int)? {
        let parts = reply.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: ":")
        guard parts.count >= 3, parts[0] == "ABSC" || parts[0] == "ABUS", let bus = Int(parts[1]), let input = Int(parts[2]) else { return nil }
        return (bus, input)
    }
}
