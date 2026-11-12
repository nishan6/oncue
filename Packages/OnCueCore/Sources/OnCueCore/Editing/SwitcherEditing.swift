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
}
