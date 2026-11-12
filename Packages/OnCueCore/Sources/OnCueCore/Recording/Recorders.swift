import Foundation
import Network

/// What records the rehearsal or show.
public enum RecorderKind: String, Codable, CaseIterable, Identifiable {
    case atem, hyperdeck, companion
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .atem: return "ATEM recording (Mini Pro, Extreme, Constellation)"
        case .hyperdeck: return "HyperDeck"
        case .companion: return "Through Companion (vMix and others)"
        }
    }
}

public struct RecorderConfig: Identifiable, Codable, Hashable {
    public var id = UUID()
    public var name: String
    public var kind: RecorderKind = .hyperdeck
    /// ATEM: which of the show's switchers records.
    public var switcherID: UUID?
    /// ATEM: also record every input (ISO), where the model can.
    public var iso: Bool = true
    /// HyperDeck: IP address (port 9993 unless given as host:port).
    public var host: String = ""
    /// Companion: the buttons that start and stop recording.
    public var startButton = CompanionButton()
    public var stopButton = CompanionButton()

    public init(name: String, kind: RecorderKind) {
        self.name = name
        self.kind = kind
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyCodingKey.self)
        id = try c.value("id", UUID())
        name = try c.value("name", "Recorder")
        kind = try c.enumValue("kind", .hyperdeck)
        switcherID = try c.value("switcherID", UUID?.none)
        iso = try c.value("iso", true)
        host = try c.value("host", "")
        startButton = try c.value("startButton", CompanionButton())
        stopButton = try c.value("stopButton", CompanionButton())
    }
}

/// A recording OnCue started, kept in the switch log so the files can be matched to it later.
public struct RecordingMark: Codable, Hashable {
    public var recorderID: UUID
    public var recorderName: String
    public var filename: String
    public var started: Date
    public var stopped: Date?
    public var timecode: String?

    public init(recorderID: UUID, recorderName: String, filename: String, started: Date, stopped: Date? = nil, timecode: String? = nil) {
        self.recorderID = recorderID
        self.recorderName = recorderName
        self.filename = filename
        self.started = started
        self.stopped = stopped
        self.timecode = timecode
    }
}

public struct RecorderLiveStatus: Equatable, Identifiable {
    public var id: UUID
    public var name: String
    public var kind: RecorderKind
    /// What the recorder reports (nil when it can't say, e.g. through Companion).
    public var recording: Bool?
    public var issue: String?
}

extension Show {
    @discardableResult
    public mutating func addRecorder(name: String, kind: RecorderKind) -> UUID {
        var r = RecorderConfig(name: name, kind: kind)
        if kind == .atem { r.switcherID = mainOutput?.switcherID }
        recorders.append(r)
        return r.id
    }

    public mutating func updateRecorder(_ id: UUID, _ change: (inout RecorderConfig) -> Void) {
        guard let i = recorders.firstIndex(where: { $0.id == id }) else { return }
        change(&recorders[i])
    }

    public mutating func deleteRecorder(_ id: UUID) { recorders.removeAll { $0.id == id } }

    /// A file name for tonight's recording: show, night and time, safe for every recorder.
    public func recordingName(date: Date = Date()) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HHmm"
        let raw = [name, settings.nightLabel, f.string(from: date)].filter { !$0.isEmpty }.joined(separator: " ")
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: " -_"))
        let cleaned = String(raw.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" })
        return String(cleaned.prefix(60)).trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - HyperDeck Ethernet Protocol

/// HyperDeck over TCP 9993: "record: name: X", "stop", and "transport info" for the status.
final class HyperDeckClient {
    var onChange: ((_ recording: Bool?, _ issue: String?) -> Void)?
    private(set) var recording: Bool?
    private(set) var issue: String?

    private let queue = DispatchQueue(label: "oncue.hyperdeck")
    private var connection: NWConnection?
    private var buffer = ""
    private var host = ""
    private var port: UInt16 = 9993
    private var active = false
    private var poll: DispatchSourceTimer?

    func connect(_ address: String) {
        let parts = address.split(separator: ":")
        host = parts.first.map(String.init) ?? address
        port = parts.count > 1 ? UInt16(parts[1]) ?? 9993 : 9993
        active = true
        open()
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now() + 2, repeating: 2)
        t.setEventHandler { [weak self] in self?.write("transport info") }
        t.resume()
        poll = t
    }

    func disconnect() {
        active = false
        poll?.cancel()
        poll = nil
        connection?.cancel()
        connection = nil
    }

    func record(name: String) {
        let clean = name.replacingOccurrences(of: "\n", with: " ")
        write(clean.isEmpty ? "record" : "record: name: \(clean)")
        write("transport info")
    }

    func stop() {
        write("stop")
        write("transport info")
    }

    private func open() {
        guard active, !host.isEmpty, let p = NWEndpoint.Port(rawValue: port) else { return }
        let conn = NWConnection(host: NWEndpoint.Host(host), port: p, using: .tcp)
        conn.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                self.set(recording: self.recording, issue: nil)
                self.write("transport info")
            case .failed, .waiting:
                conn.cancel()
                self.set(recording: nil, issue: "No answer from \(self.host)")
                self.queue.asyncAfter(deadline: .now() + 2) { if self.active, self.connection === conn { self.open() } }
            default: break
            }
        }
        connection = conn
        conn.start(queue: queue)
        receive(conn)
    }

    private func write(_ line: String) {
        queue.async { self.connection?.send(content: Data((line + "\n").utf8), completion: .idempotent) }
    }

    private func receive(_ conn: NWConnection) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] data, _, done, error in
            guard let self else { return }
            if let data, let text = String(data: data, encoding: .utf8) {
                self.buffer += text.replacingOccurrences(of: "\r", with: "")
                self.parse()
            }
            if done || error != nil {
                conn.cancel()
                if self.active { self.queue.asyncAfter(deadline: .now() + 2) { self.open() } }
            } else {
                self.receive(conn)
            }
        }
    }

    /// Responses are blocks: "208 transport info:\nstatus: record\n...\n\n", or one line ("200 ok").
    private func parse() {
        while let nl = buffer.firstIndex(of: "\n") {
            let first = String(buffer[..<nl])
            if first.hasSuffix(":") {
                // A block: ends with an empty line.
                guard let end = buffer.range(of: "\n\n") else { return }
                let block = String(buffer[..<end.lowerBound])
                buffer.removeSubrange(..<end.upperBound)
                handle(block)
            } else {
                buffer.removeSubrange(...nl)
                if !first.isEmpty { handle(first) }
            }
        }
    }

    private func handle(_ block: String) {
        let lines = block.split(separator: "\n").map(String.init)
        guard let first = lines.first, let code = Int(first.prefix(3)) else { return }
        if code == 208 {
            for line in lines.dropFirst() where line.hasPrefix("status:") {
                let status = line.dropFirst("status:".count).trimmingCharacters(in: .whitespaces)
                set(recording: status == "record", issue: nil)
            }
        } else if code >= 100 && code < 200 {
            // 1xx: an error, e.g. "105 disk full", "107 no disk" (Blackmagic's numbering varies by model).
            set(recording: recording, issue: first.dropFirst(4).capitalizedFirst)
        }
    }

    private func set(recording: Bool?, issue: String?) {
        self.recording = recording
        self.issue = issue
        DispatchQueue.main.async { self.onChange?(recording, issue) }
    }
}

private extension Substring {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
