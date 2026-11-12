import Foundation
import Network

/// Listens for Art-Net DMX (ArtDmx on UDP 6454) from a lighting desk, for Trigger Routes.
/// Only the universes routes ask for are passed on, one event per channel per packet.
final class ArtNetListener {
    static let port: UInt16 = 6454
    var onEvent: ((TriggerEvent) -> Void)?
    /// Universe → channels (1–512) that routes listen to.
    var watched: [Int: Set<Int>] = [:]
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "oncue.artnet.in")
    private(set) var running = false
    private(set) var lastError: String?

    func start() {
        guard listener == nil else { return }
        do {
            let params = NWParameters.udp
            // A lighting program on the same Mac may already listen on 6454.
            params.allowLocalEndpointReuse = true
            let l = try NWListener(using: params, on: NWEndpoint.Port(rawValue: Self.port)!)
            l.newConnectionHandler = { [weak self] conn in
                guard let self else { return }
                conn.start(queue: self.queue)
                self.receive(conn)
            }
            l.stateUpdateHandler = { [weak self] state in
                if case .failed(let error) = state {
                    DispatchQueue.main.async { self?.lastError = "\(error)"; self?.running = false }
                }
            }
            l.start(queue: queue)
            listener = l
            running = true
            lastError = nil
        } catch {
            lastError = "\(error)"
            NSLog("OnCue: Art-Net listener failed: \(error)")
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
        running = false
    }

    private func receive(_ conn: NWConnection) {
        conn.receiveMessage { [weak self] data, _, _, error in
            if let self, let data, let dmx = ArtNetParser.parse([UInt8](data)) {
                let channels = DispatchQueue.main.sync { self.watched[dmx.universe] } ?? []
                if !channels.isEmpty {
                    let events = channels.filter { $0 <= dmx.levels.count }.map {
                        TriggerEvent(kind: .artNet, number: $0, value: Double(dmx.levels[$0 - 1]), universe: dmx.universe)
                    }
                    DispatchQueue.main.async { events.forEach { self.onEvent?($0) } }
                }
            }
            if error == nil { self?.receive(conn) }
        }
    }
}
