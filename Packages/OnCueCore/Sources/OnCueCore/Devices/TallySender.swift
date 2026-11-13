import Foundation
import Network

/// Sends TSL tally packets to one tally system or multiviewer over UDP or TCP. Changes go out at
/// once; everything is sent again every second so a display that restarts catches up.
final class TallySender {
    private(set) var config: TallyOutputConfig
    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "oncue.tally.out")
    private var last: [Int: TallyState] = [:]
    private var lastFull: Double = 0
    /// What would be on the displays now (shown for simulated outputs).
    private(set) var current: [TallyState] = []
    private(set) var lastError: String?
    private(set) var packetsSent = 0

    init(config: TallyOutputConfig) {
        self.config = config
    }

    func update(config: TallyOutputConfig) {
        guard config != self.config else { return }
        let reconnect = config.host != self.config.host || config.port != self.config.port || config.transport != self.config.transport
        self.config = config
        last.removeAll()
        if reconnect { stop() }
    }

    func stop() {
        connection?.cancel()
        connection = nil
    }

    /// Sends what changed (all of it once a second).
    func send(_ states: [TallyState], now: Double) {
        current = states
        guard config.enabled else { return }
        let full = now - lastFull >= 1
        let changed = full ? states : states.filter { last[$0.index] != $0 }
        if full { lastFull = now }
        for s in states { last[s.index] = s }
        guard !changed.isEmpty, !config.simulated else { return }
        guard !config.host.isEmpty, let port = NWEndpoint.Port(rawValue: UInt16(clamping: config.port)) else {
            lastError = "No address set"
            return
        }
        if connection == nil {
            let c = NWConnection(host: NWEndpoint.Host(config.host), port: port, using: config.transport == .tcp ? .tcp : .udp)
            c.stateUpdateHandler = { [weak self] state in
                if case .failed(let error) = state { DispatchQueue.main.async { self?.lastError = "\(error)"; self?.connection = nil } }
                if case .ready = state { DispatchQueue.main.async { self?.lastError = nil } }
            }
            c.start(queue: queue)
            connection = c
        }
        for packet in Show.tallyPackets(changed, config: config) {
            connection?.send(content: Data(packet), completion: .contentProcessed { _ in })
            packetsSent += 1
        }
    }
}
