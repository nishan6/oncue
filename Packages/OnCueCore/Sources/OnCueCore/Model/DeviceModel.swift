import Foundation

// MARK: - Failover

public enum FailoverPolicy: String, Codable, CaseIterable, Identifiable {
    /// Switch to the parallel switcher on its own after the timeout, and log it.
    case automatic
    /// Ask in Live Mode; one key fails over.
    case ask
    public var id: String { rawValue }
    public var label: String { self == .automatic ? "Automatically" : "Ask me first" }
}

/// One failover or recovery, for the failover log.
public struct FailoverEvent: Identifiable, Equatable {
    public let id = UUID()
    public let time: Date
    public let switcherID: UUID
    public let message: String
}

// MARK: - Tally out

public enum TallyTransport: String, Codable, CaseIterable, Identifiable {
    case udp, tcp
    public var id: String { rawValue }
    public var label: String { rawValue.uppercased() }
}

/// Which number a camera's tally goes out on.
public enum TallyIndexMode: String, Codable, CaseIterable, Identifiable {
    /// Camera 3 → tally 3.
    case cameraNumber
    /// The switcher input it arrives on → that tally (how most multiviewers number them).
    case switcherInput
    public var id: String { rawValue }
    public var label: String { self == .cameraNumber ? "Camera number" : "Switcher input" }
}

/// A tally system or multiviewer OnCue sends TSL UMD tally (and camera names) to.
public struct TallyOutputConfig: Identifiable, Codable, Hashable {
    public var id = UUID()
    public var name: String = "Tally"
    public var enabled = true
    public var version: TSLVersion = .v50
    public var transport: TallyTransport = .udp
    public var host: String = ""
    public var port: Int = 8900
    /// TSL 5.0 screen number.
    public var screen: Int = 0
    public var indexMode: TallyIndexMode = .cameraNumber
    /// Send "1 Wide – Arjun" style names to the UMDs.
    public var sendNames = true
    /// Nothing leaves the Mac: OnCue shows what it would send, labelled SIMULATED.
    public var simulated = false
    public init(name: String = "Tally") { self.name = name }
}

extension Show {
    /// What every camera's tally should show now: red for the camera on program, green for the
    /// one on preview, and its UMD text.
    public func tallyStates(program: Int?, preview: Int?, switcherID: UUID?, config: TallyOutputConfig) -> [TallyState] {
        sortedCameras.compactMap { cam in
            let onThisSwitcher = switcherID == nil || cam.switcherID == switcherID || cam.switcherID == nil
            let index = config.indexMode == .cameraNumber ? cam.number : cam.input
            guard index >= 0 else { return nil }
            let text: String
            if config.sendNames {
                let who = cam.operatorName.isEmpty ? "" : " – \(cam.operatorName)"
                text = "\(cam.number) \(cam.name)\(who)".trimmingCharacters(in: .whitespaces)
            } else {
                text = ""
            }
            return TallyState(index: index,
                              program: onThisSwitcher && program == cam.input,
                              preview: onThisSwitcher && preview == cam.input && program != cam.input,
                              text: text)
        }
    }

    /// Encodes tally states for one output.
    public static func tallyPackets(_ states: [TallyState], config: TallyOutputConfig) -> [[UInt8]] {
        states.map { t in
            let packet: [UInt8]
            switch config.version {
            case .v31: packet = TSL.encode31(t)
            case .v40: packet = TSL.encode40(t)
            case .v50: packet = TSL.encode50(t, screen: config.screen, unicode: t.text.unicodeScalars.contains { !$0.isASCII })
            }
            return config.version == .v50 && config.transport == .tcp ? TSL.frameTCP(packet) : packet
        }
    }
}

// MARK: - Tally in

/// A tally source OnCue listens to (TSL 3.1 or 5.0 over UDP): a switcher or tally system that
/// reports what is really on program, so a manual cut on a switcher OnCue can't read back
/// directly (Ross, Panasonic, Roland through Companion) still pauses automation.
public struct TallyInputConfig: Identifiable, Codable, Hashable {
    public var id = UUID()
    public var name: String = "Tally in"
    public var enabled = true
    public var version: TSLVersion = .v50
    public var port: Int = 8901
    public var indexMode: TallyIndexMode = .cameraNumber
    /// The switcher whose program this tally reports.
    public var switcherID: UUID?
    public init(name: String = "Tally in") { self.name = name }
}

extension Show {
    /// The switcher input a tally index stands for.
    public func input(forTallyIndex index: Int, mode: TallyIndexMode, switcherID: UUID?) -> Int? {
        switch mode {
        case .switcherInput: return index
        case .cameraNumber:
            return cameras.first { $0.number == index && ($0.switcherID == nil || switcherID == nil || $0.switcherID == switcherID) }?.input
        }
    }
}
