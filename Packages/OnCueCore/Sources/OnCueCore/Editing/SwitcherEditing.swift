import Foundation

extension Show {
    /// The switcher the main output is cut on, created (as the simulator) if the show has none.
    @discardableResult
    public mutating func ensureMainSwitcher() -> UUID {
        if let id = mainOutput?.switcherID, switcher(id) != nil { return id }
        if switchers.isEmpty { switchers.append(SwitcherConfig(name: "Simulator", kind: .simulator, role: .main)) }
        let id = switchers[0].id
        if outputs.isEmpty {
            outputs.append(OutputConfig(name: "Program", switcherID: id))
        } else {
            outputs[0].switcherID = id
        }
        return id
    }

    public mutating func updateSwitcher(_ id: UUID, _ change: (inout SwitcherConfig) -> Void) {
        guard let i = switchers.firstIndex(where: { $0.id == id }) else { return }
        change(&switchers[i])
    }

    /// Cameras whose switcher input is not set, so automation cannot cut to them.
    public var camerasWithoutInput: [Camera] {
        sortedCameras.filter { $0.input <= 0 }
    }

    // MARK: OSC targets and PTZ cameras

    @discardableResult
    public mutating func addOSCTarget(name: String) -> UUID {
        let target = OSCTarget(name: name)
        oscTargets.append(target)
        return target.id
    }

    public mutating func updateOSCTarget(_ id: UUID, _ change: (inout OSCTarget) -> Void) {
        guard let i = oscTargets.firstIndex(where: { $0.id == id }) else { return }
        change(&oscTargets[i])
    }

    /// Deletes an OSC target; cues that used it keep their address but no target.
    public mutating func deleteOSCTarget(_ id: UUID) {
        oscTargets.removeAll { $0.id == id }
        for i in items.indices {
            for t in items[i].tracks.indices {
                for c in items[i].tracks[t].cues.indices where items[i].tracks[t].cues[c].oscTargetID == id {
                    items[i].tracks[t].cues[c].oscTargetID = nil
                }
            }
        }
    }

    @discardableResult
    public mutating func addPTZCamera(name: String) -> UUID {
        let cam = PTZCamera(name: name)
        ptzCameras.append(cam)
        return cam.id
    }

    public mutating func updatePTZCamera(_ id: UUID, _ change: (inout PTZCamera) -> Void) {
        guard let i = ptzCameras.firstIndex(where: { $0.id == id }) else { return }
        change(&ptzCameras[i])
    }

    public mutating func deletePTZCamera(_ id: UUID) {
        ptzCameras.removeAll { $0.id == id }
        for i in items.indices {
            for t in items[i].tracks.indices {
                for c in items[i].tracks[t].cues.indices where items[i].tracks[t].cues[c].ptzCameraID == id {
                    items[i].tracks[t].cues[c].ptzCameraID = nil
                }
            }
        }
    }

    /// Companion buttons for an input on a switcher, created if missing.
    public mutating func updateCompanionButtons(switcherID: UUID, input: Int, _ change: (inout CompanionInputButtons) -> Void) {
        updateSwitcher(switcherID) { config in
            if let k = config.companion.inputs.firstIndex(where: { $0.input == input }) {
                change(&config.companion.inputs[k])
            } else {
                var buttons = CompanionInputButtons(input: input)
                change(&buttons)
                config.companion.inputs.append(buttons)
            }
        }
    }
}

// MARK: - Operator monitors

extension Show {
    @discardableResult
    public mutating func addMonitor(name: String, kind: MonitorKind) -> UUID {
        let m = MonitorConfig(name: name, kind: kind)
        settings.monitors.append(m)
        return m.id
    }

    public mutating func updateMonitor(_ id: UUID, _ change: (inout MonitorConfig) -> Void) {
        guard let i = settings.monitors.firstIndex(where: { $0.id == id }) else { return }
        change(&settings.monitors[i])
    }

    public mutating func deleteMonitor(_ id: UUID) {
        settings.monitors.removeAll { $0.id == id }
    }
}

extension EngineStatus {
    /// True while a timing source is actually moving the position, so countdowns can be shown.
    public var positionMoving: Bool {
        transport == .running && (timingSignal || timing == .internalClock)
    }
}
