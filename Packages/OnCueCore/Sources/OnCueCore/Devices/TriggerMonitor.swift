import Foundation

/// Listens for incoming triggers while Trigger Routes is open and Live Mode is not running, so
/// you can see what arrives, learn a route from it, and check which routes it would fire.
/// (In Live Mode the engine owns these ports.)
public final class TriggerMonitor: ObservableObject {
    public struct Arrival: Identifiable, Equatable {
        public let id = UUID()
        public let date: Date
        public let event: TriggerEvent
        /// Names of the routes it matched.
        public let routes: [String]
    }

    @Published public private(set) var arrivals: [Arrival] = []
    @Published public private(set) var listening = false
    @Published public private(set) var problems: [String] = []
    /// Set by Learn: the next event is handed here instead of being listed only.
    public var onLearn: ((TriggerEvent) -> Void)?

    private let osc = OSCControlListener()
    private var midi: MIDIManager?
    private let artNet = ArtNetListener()
    private var router = TriggerRouter(routes: [])

    public init() {}

    /// - Parameters:
    ///   - oscPort: this Mac's OSC control port (Settings › This Mac).
    ///   - artNetUniverses: universes to show levels from (all channels that move are listed).
    public func start(oscPort: Int, routes: [TriggerRoute], artNetUniverses: Set<Int>) {
        stop()
        router.update(routes: routes)
        problems = []
        osc.onCommand = { [weak self] address, args in
            var value: Double?
            if let first = args.first {
                switch first {
                case .int(let v): value = Double(v)
                case .float(let v): value = Double(v)
                default: break
                }
            }
            self?.arrived(TriggerEvent(kind: .osc, address: address, value: value))
        }
        if oscPort > 0 { osc.start(port: oscPort) } else { problems.append("No OSC port is set for this Mac (Settings › This Mac).") }
        let m = MIDIManager()
        m.listenForTriggers = true
        m.onTrigger = { [weak self] event in self?.arrived(event) }
        midi = m
        if !artNetUniverses.isEmpty {
            artNet.watched = Dictionary(uniqueKeysWithValues: artNetUniverses.map { ($0, Set(1...512)) })
            artNet.onEvent = { [weak self] event in self?.arrivedLevel(event) }
            artNet.start()
            if let e = artNet.lastError { problems.append("Art-Net: \(e)") }
        }
        listening = true
    }

    public func update(routes: [TriggerRoute]) { router.update(routes: routes) }

    public func stop() {
        osc.stop()
        midi = nil
        artNet.stop()
        listening = false
    }

    public func clear() { arrivals.removeAll() }

    private var lastLevels: [String: Double] = [:]

    /// Art-Net repeats every channel ~40 times a second: only changes are listed.
    private func arrivedLevel(_ event: TriggerEvent) {
        let key = "\(event.universe):\(event.number)"
        if lastLevels[key] == event.value { return }
        let first = lastLevels[key] == nil
        lastLevels[key] = event.value
        if first && (event.value ?? 0) == 0 { return }
        arrived(event)
    }

    private func arrived(_ event: TriggerEvent) {
        if let learn = onLearn {
            onLearn = nil
            learn(event)
        }
        let names = router.match(event).map { $0.route.name.isEmpty ? $0.route.input.summary : $0.route.name }
        arrivals.insert(Arrival(date: Date(), event: event, routes: names), at: 0)
        if arrivals.count > 200 { arrivals.removeLast(arrivals.count - 200) }
    }
}

extension TriggerInput {
    /// A route input that matches this event (Learn).
    public static func learned(from e: TriggerEvent) -> TriggerInput {
        var i = TriggerInput(kind: e.kind)
        switch e.kind {
        case .osc: i.address = e.address
        case .midiNote: i.number = e.number; i.channel = e.channel
        case .midiCC: i.number = e.number; i.channel = e.channel
        case .midiProgram: i.channel = e.channel
        case .msc: i.msc = e.msc ?? .go
        case .artNet: i.universe = e.universe; i.number = e.number
        }
        return i
    }
}
