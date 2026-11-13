import Foundation

/// Live state a switcher reports back (or that OnCue assumes, for Companion).
struct SwitcherState: Equatable {
    var connected = false
    var program = 0
    var preview = 0
    var inTransition = false
    var aux: [Int: Int] = [:]
    var inputNames: [Int: String] = [:]
    var modelName = ""
    /// Program/preview are known only from our own commands (Companion has no read-back).
    var assumed = false
}

/// Common interface for every switcher OnCue can drive. All methods are called on the main thread;
/// implementations call `onChange` on the main thread.
protocol SwitcherDevice: AnyObject {
    var config: SwitcherConfig { get set }
    var state: SwitcherState { get }
    var onChange: (() -> Void)? { get set }

    func connect()
    func disconnect()

    func setProgram(_ source: Int)
    func setPreview(_ source: Int)
    func cut()
    func auto()
    func setAux(_ aux: Int, source: Int)
    func runMacro(_ index: Int)
    func setDSK(_ index: Int, onAir: Bool)
    func autoDSK(_ index: Int)
    func setKeyer(_ index: Int, onAir: Bool)
    func fadeToBlack()
}

/// Factory.
enum SwitcherFactory {
    static func make(_ config: SwitcherConfig, companion: CompanionClient) -> SwitcherDevice {
        switch config.kind {
        case .atem: return ATEMSwitcher(config: config)
        case .vmix: return VMixSwitcher(config: config)
        case .ross: return RossTalkSwitcher(config: config)
        case .panasonicHS410: return PanasonicHS410Switcher(config: config)
        case .rolandV160: return RolandV160Switcher(config: config)
        case .rolandV60: return RolandV60Switcher(config: config)
        case .obs: return OBSSwitcher(config: config)
        case .companion: return CompanionSwitcher(config: config, client: companion)
        case .simulator: return SimulatedSwitcher(config: config)
        }
    }
}

// MARK: - Simulator

/// In-app switcher for testing at home. Behaves like an ATEM: mixes take ~1 s.
final class SimulatedSwitcher: SwitcherDevice {
    var config: SwitcherConfig
    private(set) var state = SwitcherState()
    var onChange: (() -> Void)?

    init(config: SwitcherConfig) {
        self.config = config
        state.program = 1
        state.preview = 2
        state.modelName = "OnCue simulator"
        for i in 1...max(config.inputCount, 1) { state.inputNames[i] = "Input \(i)" }
    }

    func connect() { state.connected = true; notify() }
    func disconnect() { state.connected = false; notify() }

    func setProgram(_ source: Int) { state.program = source; notify() }
    func setPreview(_ source: Int) { state.preview = source; notify() }

    func cut() {
        let p = state.program
        state.program = state.preview
        state.preview = p
        notify()
    }

    func auto() {
        state.inTransition = true
        notify()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self else { return }
            self.state.inTransition = false
            self.cut()
        }
    }

    func setAux(_ aux: Int, source: Int) { state.aux[aux] = source; notify() }
    func runMacro(_ index: Int) {}
    func setDSK(_ index: Int, onAir: Bool) {}
    func autoDSK(_ index: Int) {}
    func setKeyer(_ index: Int, onAir: Bool) {}
    func fadeToBlack() {}

    private func notify() { onChange?() }
}

// MARK: - Companion

/// Any switcher Companion can drive (vMix, Ross, Panasonic, Roland...). OnCue presses the
/// Companion buttons you map per input. Companion does not report tally back, so program/preview
/// shown in OnCue are what OnCue last asked for.
final class CompanionSwitcher: SwitcherDevice {
    var config: SwitcherConfig
    private(set) var state = SwitcherState()
    var onChange: (() -> Void)?
    private let client: CompanionClient

    init(config: SwitcherConfig, client: CompanionClient) {
        self.config = config
        self.client = client
        state.assumed = true
    }

    func connect() {
        client.ping { [weak self] ok in
            DispatchQueue.main.async {
                self?.state.connected = ok
                self?.onChange?()
            }
        }
    }

    func disconnect() { state.connected = false; onChange?() }

    func setProgram(_ source: Int) {
        guard let b = config.companion.buttons(for: source) else { return }
        if b.program.enabled {
            client.press(b.program)
        } else if b.preview.enabled && config.companion.cut.enabled {
            client.press(b.preview)
            client.press(config.companion.cut)
        }
        state.program = source
        onChange?()
    }

    func setPreview(_ source: Int) {
        guard let b = config.companion.buttons(for: source), b.preview.enabled else { return }
        client.press(b.preview)
        state.preview = source
        onChange?()
    }

    func cut() {
        guard config.companion.cut.enabled else { return }
        client.press(config.companion.cut)
        // Swap via a local copy: two inout accesses into `state` at once break exclusivity.
        (state.program, state.preview) = (state.preview, state.program)
        onChange?()
    }

    func auto() {
        guard config.companion.auto.enabled else { return }
        client.press(config.companion.auto)
        // Swap via a local copy: two inout accesses into `state` at once break exclusivity.
        (state.program, state.preview) = (state.preview, state.program)
        onChange?()
    }

    func setAux(_ aux: Int, source: Int) {}
    func runMacro(_ index: Int) {}
    func setDSK(_ index: Int, onAir: Bool) {}
    func autoDSK(_ index: Int) {}
    func setKeyer(_ index: Int, onAir: Bool) {}
    func fadeToBlack() {}
}
