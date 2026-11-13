import Foundation

// MARK: - Consoles (wave c)
//
// Named actions for lighting, sound and graphics consoles, on top of Device commands: a cue
// says "GO cue 12" or "Mute channel 3" and OnCue writes the console's own message. Each
// console's notes say where its protocol comes from; all stay Built until tested on the desk.

public enum ConsoleKind: String, Codable, CaseIterable, Identifiable {
    case grandMA3, grandMA2, avolites, xpression, resolume, x32, wing, yamahaRCP, allenHeath
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .grandMA3: return "grandMA3 (OSC)"
        case .grandMA2: return "grandMA2 (Telnet)"
        case .avolites: return "Avolites Titan (WebAPI)"
        case .wing: return "Behringer WING (OSC)"
        case .xpression: return "Ross XPression (RossTalk)"
        case .resolume: return "Resolume Arena / Avenue (OSC)"
        case .x32: return "Behringer X32 / Midas M32 (OSC)"
        case .yamahaRCP: return "Yamaha CL / QL / TF (RCP)"
        case .allenHeath: return "Allen & Heath dLive / Avantis / SQ (MIDI over TCP)"
        }
    }
    public var defaultPort: Int {
        switch self {
        case .grandMA3: return 8000
        case .grandMA2: return 30000
        case .avolites: return 4430
        case .wing: return 2223
        case .xpression: return 7788
        case .resolume: return 7000
        case .x32: return 10023
        case .yamahaRCP: return 49280
        case .allenHeath: return 51325
        }
    }
    /// UDP for the OSC consoles, TCP for the rest.
    public var udp: Bool { self == .grandMA3 || self == .resolume || self == .x32 || self == .wing }
    /// Avolites is driven over HTTP.
    public var http: Bool { self == .avolites }

    public var actions: [ConsoleActionKind] {
        switch self {
        case .grandMA3, .grandMA2: return [.goCue, .goNext, .command]
        case .avolites: return [.goNext]
        case .wing: return [.mute, .fader]
        case .xpression: return [.take, .takeOut, .cueGraphic, .next, .clearLayer]
        case .resolume: return [.playClip, .column, .clearLayer]
        case .x32: return [.scene, .mute, .fader]
        case .yamahaRCP: return [.scene, .mute, .fader]
        case .allenHeath: return [.scene, .mute]
        }
    }

    public var notes: String {
        switch self {
        case .grandMA3: return "Turn on OSC input in the MA3 (In & Out › OSC) with \"Receive Command\" and the prefix set below. Built from MA3's OSC documentation."
        case .grandMA2: return "Turn on Telnet in the MA2 (Setup › Console › Global Settings). OnCue logs in with the user and password set below. Built from the MA2 command-line documentation."
        case .avolites: return "Titan WebAPI on port 4430. GO plays the next cue on the playback with the user number set as the sequence. Going to a specific cue isn't built yet. Built from Avolites' Titan API reference."
        case .wing: return "WING OSC on port 2223: mute and fader in dB. Scene recall over OSC isn't confirmed yet, so it isn't offered. Built from the WING remote protocols document."
        case .xpression: return "RossTalk on port 7788. Framebuffer 1 is RossTalk 0. Built from Ross's XPression RossTalk command list."
        case .resolume: return "Turn on OSC input in Resolume's Preferences › OSC (default port 7000). Built from Resolume's OSC documentation."
        case .x32: return "X32 and M32 listen for OSC on port 10023. Built from the widely used X32 OSC reference (not an official Behringer document)."
        case .yamahaRCP: return "Yamaha's remote control protocol on port 49280. Built from community documentation of the protocol, not an official Yamaha specification: test before a show."
        case .allenHeath: return "MIDI over TCP on port 51325, base MIDI channel set below. Scenes use bank select and program change; mutes use note on. Built from Allen & Heath's MIDI protocol documents."
        }
    }
}

public enum ConsoleActionKind: String, Codable, CaseIterable, Identifiable {
    case goCue, goNext, command, scene, mute, fader, take, takeOut, cueGraphic, next, clearLayer, playClip, column
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .goCue: return "Go to cue"
        case .goNext: return "GO (next cue)"
        case .command: return "Command line"
        case .scene: return "Recall scene"
        case .mute: return "Mute / unmute"
        case .fader: return "Fader level"
        case .take: return "Take graphic to air"
        case .takeOut: return "Take graphic off air"
        case .cueGraphic: return "Cue graphic (ready, not on air)"
        case .next: return "Next in sequencer"
        case .clearLayer: return "Clear layer"
        case .playClip: return "Play clip"
        case .column: return "Trigger column"
        }
    }
}

public struct ConsoleAction: Codable, Hashable {
    public var kind: ConsoleActionKind = .goCue
    /// Cue, scene, take ID, clip or column number.
    public var number: Double = 1
    /// Sequence / executor / cue list / framebuffer number.
    public var list: Int = 1
    /// Channel (sound) or layer (graphics, Resolume).
    public var channel: Int = 1
    public var on: Bool = true
    /// Fader level in dB.
    public var level: Double = 0
    /// Raw command line (grandMA).
    public var text: String = ""
    public init(kind: ConsoleActionKind = .goCue) { self.kind = kind }

    public var summary: String {
        let n = number == number.rounded() ? String(Int(number)) : String(number)
        switch kind {
        case .goCue: return "Go to cue \(n) (list \(list))"
        case .goNext: return "GO list \(list)"
        case .command: return text.isEmpty ? "(empty command)" : text
        case .scene: return "Recall scene \(n)"
        case .mute: return "\(on ? "Mute" : "Unmute") ch \(channel)"
        case .fader: return "Ch \(channel) fader \(String(format: "%+.1f", level)) dB"
        case .take: return "Take \(n) to air (FB \(list), layer \(channel))"
        case .takeOut: return "Take \(n) off air"
        case .cueGraphic: return "Cue \(n) (FB \(list), layer \(channel))"
        case .next: return "Sequencer NEXT"
        case .clearLayer: return "Clear layer \(channel)"
        case .playClip: return "Play layer \(channel) clip \(n)"
        case .column: return "Column \(n)"
        }
    }
}

/// One message on the wire.
public enum ConsoleMessage: Equatable {
    case osc(String, [ConsoleOSCValue])
    case line(String)
    case bytes([UInt8])
    /// HTTP GET path (with query) on the console.
    case http(String)
}

public enum ConsoleOSCValue: Equatable {
    case int(Int)
    case float(Double)
    case string(String)
}

/// Console settings kept on the device target.
public struct ConsoleSettings: Codable, Hashable {
    public var kind: ConsoleKind = .grandMA3
    /// grandMA3 OSC prefix.
    public var prefix: String = "gma3"
    /// grandMA2 login.
    public var user: String = "administrator"
    public var password: String = ""
    /// Allen & Heath base MIDI channel (1–16).
    public var midiChannel: Int = 1
    /// Yamaha TF scenes use a different library name.
    public var yamahaTF = false
    /// Resolume: the port OnCue listens on for Resolume's OSC output (Preferences › OSC › Output).
    public var feedbackPort: Int = 7001
    public init(kind: ConsoleKind = .grandMA3) { self.kind = kind }
}

public enum ConsoleWire {
    /// The messages for one action. Empty when the console can't do it.
    public static func messages(_ a: ConsoleAction, settings s: ConsoleSettings) -> [ConsoleMessage] {
        let n = a.number
        let whole = Int(n.rounded())
        let num = n == n.rounded() ? String(whole) : String(n)
        switch s.kind {
        case .grandMA3:
            let address = "/" + s.prefix.trimmingCharacters(in: CharacterSet(charactersIn: "/ ")) + "/cmd"
            switch a.kind {
            case .goCue: return [.osc(address, [.string("Goto Sequence \(a.list) Cue \(num)")])]
            case .goNext: return [.osc(address, [.string("Go+ Sequence \(a.list)")])]
            case .command: return a.text.isEmpty ? [] : [.osc(address, [.string(a.text)])]
            default: return []
            }
        case .grandMA2:
            switch a.kind {
            case .goCue: return [.line("Goto Executor \(a.list) Cue \(num)")]
            case .goNext: return [.line("Go Executor \(a.list)")]
            case .command: return a.text.isEmpty ? [] : [.line(a.text)]
            default: return []
            }
        case .avolites:
            switch a.kind {
            case .goNext: return [.http("/titan/script/2/CueLists/Play?handle_userNumber=\(max(1, a.list))")]
            default: return []
            }
        case .wing:
            let ch = max(1, min(a.channel, 40))
            switch a.kind {
            case .mute: return [.osc("/ch/\(ch)/mute", [.int(a.on ? 1 : 0)])]
            case .fader: return [.osc("/ch/\(ch)/fdr", [.float(max(-144, min(a.level, 10)))])]
            default: return []
            }
        case .xpression:
            let fb = max(0, a.list - 1)
            switch a.kind {
            case .take: return [.line("TAKE \(whole):\(fb):\(a.channel)")]
            case .takeOut: return [.line("SEQO \(whole)")]
            case .cueGraphic: return [.line("CUE \(whole):\(fb):\(a.channel)")]
            case .next: return [.line("NEXT")]
            case .clearLayer: return [.line("CLFB \(fb):\(a.channel)")]
            default: return []
            }
        case .resolume:
            switch a.kind {
            case .playClip: return [.osc("/composition/layers/\(a.channel)/clips/\(whole)/connect", [.int(1)])]
            case .column: return [.osc("/composition/columns/\(whole)/connect", [.int(1)])]
            case .clearLayer: return [.osc("/composition/layers/\(a.channel)/clear", [.int(1)])]
            default: return []
            }
        case .x32:
            let ch = String(format: "%02d", max(1, min(a.channel, 32)))
            switch a.kind {
            case .scene: return [.osc("/-action/goscene", [.int(max(0, min(whole, 99)))])]
            case .mute: return [.osc("/ch/\(ch)/mix/on", [.int(a.on ? 0 : 1)])]
            case .fader: return [.osc("/ch/\(ch)/mix/fader", [.float(x32Fader(dB: a.level))])]
            default: return []
            }
        case .yamahaRCP:
            let ch = max(1, a.channel) - 1
            switch a.kind {
            case .scene: return [.line(s.yamahaTF ? "ssrecall_ex scene_a \(whole)" : "ssrecall_ex MIXER:Lib/Scene \(whole)")]
            case .mute: return [.line("set MIXER:Current/InCh/Fader/On \(ch) 0 \(a.on ? 0 : 1)")]
            case .fader:
                let v = a.level <= -138 ? -32768 : Int((max(-138, min(a.level, 10)) * 100).rounded())
                return [.line("set MIXER:Current/InCh/Fader/Level \(ch) 0 \(v)")]
            default: return []
            }
        case .allenHeath:
            let base = UInt8(max(1, min(s.midiChannel, 16)) - 1)
            switch a.kind {
            case .scene:
                let index = max(1, whole) - 1
                return [.bytes([0xB0 | base, 0x00, UInt8(index / 128), 0xC0 | base, UInt8(index % 128)])]
            case .mute:
                let note = UInt8(clamping: max(1, min(a.channel, 128)) - 1)
                return [.bytes([0x90 | base, note, a.on ? 0x7F : 0x3F, 0x90 | base, note, 0x00])]
            default: return []
            }
        }
    }

    /// X32 fader law: dB to the 0…1 float the console expects.
    public static func x32Fader(dB: Double) -> Double {
        let d = min(dB, 10)
        let f: Double
        if d >= -10 { f = (d + 30) / 40 }
        else if d >= -30 { f = (d + 50) / 80 }
        else if d >= -60 { f = (d + 70) / 160 }
        else if d >= -90 { f = (d + 90) / 480 }
        else { f = 0 }
        return max(0, min(f, 1))
    }

    /// Lines sent once after connecting (grandMA2 login).
    public static func greeting(_ s: ConsoleSettings) -> [String] {
        s.kind == .grandMA2 ? ["Login \"\(s.user)\" \"\(s.password)\""] : []
    }
}

/// What a console reported back.
public struct ConsoleReadBack: Equatable {
    public var scene: Int?
    public var muted: Set<Int> = []
    /// Resolume: the clip connected (playing) on each layer.
    public var layerClips: [Int: Int] = [:]
    public init() {}

    /// Resolume OSC output: /composition/layers/L/clips/C/connected with 0 empty, 1 loaded,
    /// 2 previewed, 3 connected, 4 connected and previewed. A layer's stop message can arrive
    /// after the next clip's start, so a stop only clears the layer if that clip was the one shown.
    public mutating func applyResolume(address: String, value: Int?) -> Bool {
        let parts = address.split(separator: "/")
        guard parts.count == 6, parts[0] == "composition", parts[1] == "layers", parts[3] == "clips", parts[5] == "connected",
              let layer = Int(parts[2]), let clip = Int(parts[4]), let v = value else { return false }
        if v >= 3 {
            guard layerClips[layer] != clip else { return false }
            layerClips[layer] = clip
            return true
        }
        guard layerClips[layer] == clip else { return false }
        layerClips[layer] = nil
        return true
    }

    /// X32/M32 replies and /xremote updates. Returns true when something changed.
    public mutating func apply(address: String, value: Int?) -> Bool {
        if address == "/-show/prepos/current", let v = value, v != scene {
            scene = v
            return true
        }
        let parts = address.split(separator: "/")
        if parts.count == 4, parts[0] == "ch", parts[2] == "mix", parts[3] == "on", let ch = Int(parts[1]), let v = value {
            let wasMuted = muted.contains(ch)
            if v == 0 { muted.insert(ch) } else { muted.remove(ch) }
            return wasMuted != (v == 0)
        }
        return false
    }

    public var summary: String {
        var parts: [String] = []
        if let scene { parts.append("scene \(scene)") }
        if !muted.isEmpty { parts.append("muted " + muted.sorted().map(String.init).joined(separator: ", ")) }
        for layer in layerClips.keys.sorted() { parts.append("layer \(layer) clip \(layerClips[layer]!)") }
        return parts.isEmpty ? "connected, nothing reported yet" : parts.joined(separator: " · ")
    }
}
