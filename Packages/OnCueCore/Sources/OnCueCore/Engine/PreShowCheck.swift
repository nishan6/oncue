import Foundation
import Network

/// One line of the pre-show check.
public struct CheckItem: Identifiable, Equatable {
    public enum Status: Equatable { case running, pass, warn, fail, info }
    public let id: String
    public let group: String
    public var title: String
    public var status: Status
    public var detail: String
}

/// Before doors: is everything the show needs reachable and set up? Checks only what OnCue can
/// actually know. A switcher answering is checked by connecting to it (nothing is sent to it);
/// whether a camera's source has picture is not reported by the switchers, so it is not claimed.
public final class PreShowCheck: ObservableObject {
    @Published public private(set) var items: [CheckItem] = []
    @Published public private(set) var running = false

    private let show: Show
    private let profile: MachineProfile
    private var devices: [SwitcherDevice] = []
    private let companion = CompanionClient()
    private var pending = 0
    private var probes: [NWConnection] = []
    /// How long to wait for each device.
    var timeout: TimeInterval = 5

    /// For tests: the MIDI sources and audio inputs this Mac has.
    var midiSources: () -> [String] = { MIDISources.names() }
    var audioInputs: () -> [String] = { AudioInputDevice.all().map(\.uid) }

    public init(show: Show, profile: MachineProfile) {
        self.show = show
        self.profile = profile
        companion.host = profile.companionHost
        companion.port = profile.companionPort
        companion.version = CompanionVersion(rawValue: profile.companionVersion) ?? .v3
    }

    deinit { devices.forEach { $0.disconnect() } }

    public var failures: Int { items.filter { $0.status == .fail }.count }
    public var warnings: Int { items.filter { $0.status == .warn }.count }

    /// Runs every check; device checks finish asynchronously on the main thread.
    public func run() {
        devices.forEach { $0.disconnect() }
        devices = []
        probes.forEach { $0.cancel() }
        probes = []
        items = []
        pending = 0
        running = true
        checkCameras()
        checkScript()
        checkSwitchers()
        checkTiming()
        checkControls()
        checkPTZ()
        checkOSC()
        checkLogs()
        finishIfDone()
    }

    // MARK: - Show

    private func checkCameras() {
        let g = "Cameras"
        if show.cameras.isEmpty {
            add(g, "cameras", "Cameras", .fail, "The show has no cameras.")
            return
        }
        let noInput = show.sortedCameras.filter { $0.input <= 0 }
        add(g, "inputs", "Every camera has a switcher input", noInput.isEmpty ? .pass : .fail,
            noInput.isEmpty ? "\(show.cameras.count) cameras" : "No input: " + noInput.map { "\($0.number) \($0.displayName)" }.joined(separator: ", "))
        var seen: [String: Camera] = [:]
        var clashes: [String] = []
        let main = show.mainOutput?.switcherID
        for cam in show.sortedCameras where cam.input > 0 {
            let key = "\((cam.switcherID ?? main)?.uuidString ?? "")#\(cam.input)"
            if let other = seen[key] { clashes.append("\(other.number) and \(cam.number) on input \(cam.input)") }
            seen[key] = cam
        }
        if !clashes.isEmpty { add(g, "clash", "Two cameras on one input", .warn, clashes.joined(separator: "; ")) }
        add(g, "signal", "Pictures", .info,
            "Switchers don't report whether a source has picture. Check every camera on the multiview.")
    }

    private func checkScript() {
        let g = "Script"
        var noCamera: [String] = []
        var missing: [String] = []
        var empty: [String] = []
        for item in show.items {
            let rows = show.shotRows(forItem: item.id)
            if rows.isEmpty { empty.append(item.title) }
            let a = rows.filter { $0.issues.contains { $0.kind == .noCamera } }.count
            let b = rows.filter { $0.issues.contains { $0.kind == .cameraMissing } }.count
            if a > 0 { noCamera.append("\(item.title) (\(a))") }
            if b > 0 { missing.append("\(item.title) (\(b))") }
        }
        add(g, "nocam", "Every shot has a camera", noCamera.isEmpty && missing.isEmpty ? .pass : .fail,
            noCamera.isEmpty && missing.isEmpty ? "\(show.items.count) songs and segments"
                : (noCamera.isEmpty ? "" : "No camera: " + noCamera.joined(separator: ", "))
                + (missing.isEmpty ? "" : (noCamera.isEmpty ? "" : ". ") + "Deleted camera: " + missing.joined(separator: ", ")))
        if !empty.isEmpty { add(g, "empty", "Songs without shots", .warn, empty.joined(separator: ", ")) }
        let ltcItems = show.items.filter { $0.syncMode == .ltc && $0.ltcStart.isEmpty }
        if !ltcItems.isEmpty {
            add(g, "ltcstart", "LTC start times", .info, "No LTC start set, so these start at the first timecode after GO: "
                + ltcItems.map(\.title).joined(separator: ", "))
        }
    }

    // MARK: - Switchers

    private func checkSwitchers() {
        let g = "Switchers"
        if show.switchers.isEmpty {
            add(g, "none", "Switcher", .fail, "No switcher is set up. Add one in Show Setup.")
            return
        }
        for config in show.switchers {
            let id = "sw-\(config.id.uuidString)"
            switch config.kind {
            case .simulator:
                add(g, id, config.name, .info, "Simulator: nothing real is switched.")
            case .companion:
                add(g, id, config.name, .running, "Asking Companion at \(profile.companionHost):\(profile.companionPort)…")
                pending += 1
                companion.ping { [weak self] ok in
                    DispatchQueue.main.async {
                        self?.update(id, ok ? .pass : .fail, ok ? "Companion answers. Its buttons can't report program, so OnCue assumes it."
                                                               : "Companion doesn't answer at \(self?.profile.companionHost ?? ""):\(self?.profile.companionPort ?? 0).")
                        self?.done()
                    }
                }
            case .atem:
                guard !config.host.isEmpty else {
                    add(g, id, config.name, .fail, "No IP address set.")
                    continue
                }
                add(g, id, config.name, .running, "Connecting to \(config.host)…")
                pending += 1
                let device = SwitcherFactory.make(config, companion: companion)
                devices.append(device)
                var finished = false
                let complete: (CheckItem.Status, String) -> Void = { [weak self] status, text in
                    guard !finished else { return }
                    finished = true
                    device.onChange = nil
                    self?.update(id, status, text)
                    if status == .pass { self?.checkInputs(on: device) }
                    device.disconnect()
                    self?.done()
                }
                device.onChange = {
                    // The state dump (names of the inputs) arrives just before the connection completes.
                    if device.state.connected {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            let model = device.state.modelName.isEmpty ? "Connected" : "Connected: \(device.state.modelName)"
                            complete(.pass, model)
                        }
                    }
                }
                device.connect()
                DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
                    complete(.fail, "No answer from \(config.host). Check the address and that this Mac is on the switcher's network.")
                }
            }
        }
    }

    /// Every camera's input exists on the switcher it is routed through.
    private func checkInputs(on device: SwitcherDevice) {
        let names = device.state.inputNames
        guard !names.isEmpty else { return }
        let config = device.config
        let main = show.mainOutput?.switcherID
        var needed: [(String, Int)] = []
        for cam in show.sortedCameras {
            if (cam.switcherID ?? main) == config.id, cam.input > 0 { needed.append(("\(cam.number) \(cam.displayName)", cam.input)) }
            for extra in cam.extraInputs where extra.switcherID == config.id { needed.append(("\(cam.number) \(cam.displayName)", extra.input)) }
        }
        for sub in show.switchers where sub.parentID == config.id && sub.feedInput > 0 {
            needed.append(("feed from \(sub.name)", sub.feedInput))
        }
        let missing = needed.filter { names[$0.1] == nil }
        let id = "in-\(config.id.uuidString)"
        if needed.isEmpty { return }
        if missing.isEmpty {
            let list = needed.map { "\($0.0) → \($0.1) \(names[$0.1] ?? "")" }.joined(separator: ", ")
            add("Switchers", id, "\(config.name) inputs", .pass, list)
        } else {
            add("Switchers", id, "\(config.name) inputs", .fail,
                "Not on this switcher: " + missing.map { "\($0.0) (input \($0.1))" }.joined(separator: ", "))
        }
    }

    // MARK: - Timing and controls

    private func checkTiming() {
        let g = "Timing"
        let modes = Set(show.items.map(\.syncMode))
        if modes.contains(.midiClock) {
            if profile.midiClockSource.isEmpty {
                add(g, "midi", "MIDI clock", .fail, "Songs follow MIDI clock but no clock source is chosen in Settings.")
            } else if midiSources().contains(profile.midiClockSource) {
                add(g, "midi", "MIDI clock", .pass, "\(profile.midiClockSource) is connected. Whether it is sending shows in Live Mode.")
            } else {
                add(g, "midi", "MIDI clock", .fail, "\(profile.midiClockSource) isn't connected to this Mac.")
            }
        }
        if modes.contains(.ltc) {
            if profile.ltcDeviceUID.isEmpty {
                add(g, "ltc", "LTC input", .fail, "Songs follow LTC but no audio input is chosen in Settings.")
            } else if audioInputs().contains(profile.ltcDeviceUID) {
                add(g, "ltc", "LTC input", .pass, "The audio input is connected. Whether timecode arrives shows in Live Mode.")
            } else {
                add(g, "ltc", "LTC input", .fail, "The chosen audio input isn't connected to this Mac.")
            }
        }
        if !modes.contains(.midiClock) && !modes.contains(.ltc) {
            add(g, "manual", "Timing", .info, "Every song is driven by taps, NEXT or the internal clock.")
        }
    }

    private func checkControls() {
        let g = "Controls"
        if !profile.controllerSource.isEmpty {
            let ok = midiSources().contains(profile.controllerSource)
            add(g, "controller", "MIDI controller", ok ? .pass : .warn,
                ok ? "\(profile.controllerSource) is connected." : "\(profile.controllerSource) isn't connected. The keyboard still works.")
        }
        let usesCompanion = profile.companionVariables || show.ptzCameras.contains { $0.proto == .companion }
        if usesCompanion && !show.switchers.contains(where: { $0.kind == .companion }) {
            add(g, "companion", "Companion", .running, "Asking Companion…")
            pending += 1
            companion.ping { [weak self] ok in
                DispatchQueue.main.async {
                    self?.update("companion", ok ? .pass : .warn, ok ? "Companion answers." : "Companion doesn't answer, so Stream Deck keys and Companion PTZ presets won't work.")
                    self?.done()
                }
            }
        }
    }

    // MARK: - PTZ, OSC, logs

    private func checkPTZ() {
        let g = "PTZ"
        for cam in show.ptzCameras {
            let id = "ptz-\(cam.id.uuidString)"
            switch cam.proto {
            case .panasonic, .viscaTCP:
                guard !cam.host.isEmpty else { add(g, id, cam.name, .fail, "No IP address set."); continue }
                let port = cam.proto == .panasonic ? 80 : cam.port
                add(g, id, cam.name, .running, "Connecting to \(cam.host)…")
                probe(host: cam.host, port: port) { [weak self] ok in
                    self?.update(id, ok ? .pass : .fail, ok ? "Answers at \(cam.host)." : "No answer at \(cam.host):\(port).")
                }
            case .viscaIP:
                add(g, id, cam.name, cam.host.isEmpty ? .fail : .info,
                    cam.host.isEmpty ? "No IP address set." : "VISCA over IP doesn't confirm delivery. Recall a preset to test it.")
            case .atemMacro:
                add(g, id, cam.name, .info, "Presets run ATEM macros \(cam.macroBase + 1) onwards.")
            case .companion:
                add(g, id, cam.name, .info, "Presets press Companion buttons.")
            }
        }
    }

    private func checkOSC() {
        for target in show.oscTargets {
            let valid = !target.host.isEmpty && (1...65535).contains(target.port)
            add("OSC", "osc-\(target.id.uuidString)", target.name, valid ? .info : .fail,
                valid ? "Sends to \(target.host):\(target.port). OSC doesn't confirm delivery; watch the receiving system."
                      : "Set a host and port in Show Setup.")
        }
    }

    private func checkLogs() {
        guard let folder = EngineController.defaultLogFolder(profile) else {
            add("This Mac", "logs", "Switch log folder", .fail, "No folder for switch logs. Choose one in Settings.")
            return
        }
        let probe = folder.appendingPathComponent(".oncue-write-test")
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try Data().write(to: probe)
            try? FileManager.default.removeItem(at: probe)
            let free = (try? folder.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]))?.volumeAvailableCapacityForImportantUsage
            let low = (free ?? .max) < 500_000_000
            add("This Mac", "logs", "Switch log folder", low ? .warn : .pass,
                folder.path + (low ? ". Less than 500 MB free." : ""))
        } catch {
            add("This Mac", "logs", "Switch log folder", .fail, "Can't write to \(folder.path): \(error.localizedDescription)")
        }
    }

    /// TCP reachability within the timeout.
    private func probe(host: String, port: Int, done: @escaping (Bool) -> Void) {
        guard let p = NWEndpoint.Port(rawValue: UInt16(clamping: port)) else { done(false); return }
        pending += 1
        let conn = NWConnection(host: NWEndpoint.Host(host), port: p, using: .tcp)
        probes.append(conn)
        var finished = false
        let finish: (Bool) -> Void = { [weak self] ok in
            DispatchQueue.main.async {
                guard !finished else { return }
                finished = true
                conn.cancel()
                done(ok)
                self?.done()
            }
        }
        conn.stateUpdateHandler = { state in
            switch state {
            case .ready: finish(true)
            case .failed, .cancelled: finish(false)
            default: break
            }
        }
        conn.start(queue: .global())
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { finish(false) }
    }

    // MARK: - Bookkeeping

    private func add(_ group: String, _ id: String, _ title: String, _ status: CheckItem.Status, _ detail: String) {
        items.append(CheckItem(id: id, group: group, title: title, status: status, detail: detail))
    }

    private func update(_ id: String, _ status: CheckItem.Status, _ detail: String) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        items[i].status = status
        items[i].detail = detail
    }

    private func done() {
        pending -= 1
        finishIfDone()
    }

    private func finishIfDone() {
        if pending <= 0 { running = false }
    }
}
