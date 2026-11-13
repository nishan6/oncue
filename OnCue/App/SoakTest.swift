import AppKit
import Darwin
import OnCueCore

/// Long-run check used by CI: `OnCue --soak <folder> [--hours 24] [--speed 5]`.
///
/// Runs the sample show in Live Mode on the simulator switcher in Auto cut, song after song, with
/// the crew page server and its Multi View data updating, for the given hours of show time. The
/// engine clock runs `speed` times faster than real time (1 = real time). Writes soak.csv (memory
/// and takes every minute), soak-result.txt and the switch log to <folder>. Exit code 0 = pass.
enum SoakTest {
    private static var folder: URL!
    private static var controller: EngineController?
    private static var crew: CrewServer?
    private static var show = Show.sample()
    private static var order: [UUID] = []
    private static var itemIndex = 0
    private static var goDate = Date()
    private static var start = Date()
    private static var speed = 5.0
    private static var hours = 24.0
    private static var samples: [SoakSample] = []
    private static var lateness: [Double] = []
    private static var takes = 0
    private static var seenEntries = 0
    private static var timers: [Timer] = []

    static func runIfRequested() {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "--soak"), i + 1 < args.count else { return }
        folder = URL(fileURLWithPath: args[i + 1], isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        if let k = args.firstIndex(of: "--hours"), k + 1 < args.count, let h = Double(args[k + 1]) { hours = h }
        if let k = args.firstIndex(of: "--speed"), k + 1 < args.count, let s = Double(args[k + 1]) { speed = max(s, 1) }
        say(String(format: "soak: %.2f h of show time at %.1f× (about %.2f h real)", hours, speed, hours / speed))
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { begin() }
    }

    private static func begin() {
        var s = Show.sample()
        for k in s.items.indices { s.items[k].syncMode = .freeRun }
        order = s.items.filter { $0.timeBase != .order && s.shotRows(forItem: $0.id).count >= 2 }.map(\.id)
        guard let first = order.first else { return finish(SoakVerdict(pass: false, lines: ["FAIL: the sample show has no timed songs"])) }
        show = s.forLive(ShotVocabulary())

        EngineController.setTimeScale(speed)
        let c = EngineController(show: show, itemID: first, profile: MachineProfile(), logFolder: folder)
        controller = c
        c.connectSwitcher()

        let server = CrewServer()
        server.start(port: 0)
        crew = server

        start = Date()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            c.setMode(.cut)
            go()
            timers.append(Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { _ in watch() })
            timers.append(Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in sample() })
            sample()
        }
        // A run that hangs still ends and reports.
        let limit = hours * 3600 / speed + 1800
        DispatchQueue.main.asyncAfter(deadline: .now() + limit) { stop() }
    }

    private static func go() {
        goDate = Date()
        controller?.go()
    }

    private static func watch() {
        guard let c = controller else { return }
        collectTakes(c)
        let status = c.status
        // The crew page and the Multi View are fed the same way as in a show.
        let snap = show.crewSnapshot(status: status, position: status.position, running: status.positionMoving, scriptVersion: 0)
        _ = snap.multiViewColumns()
        crew?.update(snap)

        if Double(Date().timeIntervalSince(start)) * speed >= hours * 3600 { return stop() }
        // Next song when this one has run out (wrap to the first after the last).
        let end = show.itemEnd(forItem: status.itemID)
        if status.transport != .running || status.position >= end {
            itemIndex = (itemIndex + 1) % order.count
            c.load(itemID: order[itemIndex])
            c.setMode(.cut)
            go()
        }
    }

    /// Times every new scripted take against its planned moment in the song.
    private static func collectTakes(_ c: EngineController) {
        let entries = c.log.entries
        guard entries.count > seenEntries else { return }
        for e in entries[seenEntries...] where e.kind == .scripted {
            takes += 1
            guard let itemID = e.itemID, let item = show.item(itemID), let n = e.shotNumber,
                  let row = show.shotRows(forItem: itemID).first(where: { $0.number == n }) else { continue }
            let planned = goDate.addingTimeInterval(item.seconds(for: row.cue.at) / speed)
            lateness.append(e.date.timeIntervalSince(planned) * speed)
        }
        seenEntries = entries.count
    }

    private static func sample() {
        let real = Date().timeIntervalSince(start)
        samples.append(SoakSample(real: real, show: real * speed, memoryMB: footprintMB(), takes: takes))
        try? SoakReport.csv(samples).write(to: folder.appendingPathComponent("soak.csv"), atomically: true, encoding: .utf8)
        if samples.count % 30 == 1 {
            say(String(format: "soak: %.2f h show, %.0f MB, %d takes", real * speed / 3600, samples.last!.memoryMB, takes))
        }
    }

    private static func stop() {
        guard let c = controller else { return }
        collectTakes(c)
        sample()
        timers.forEach { $0.invalidate() }
        c.saveLog()
        c.shutdown()
        controller = nil
        crew?.stop()
        finish(SoakReport.evaluate(samples: samples, lateness: lateness, speed: speed, plannedShowHours: hours))
    }

    private static func finish(_ verdict: SoakVerdict) {
        for line in verdict.lines { say(line) }
        let text = verdict.lines.joined(separator: "\n") + "\n"
        try? text.write(to: folder.appendingPathComponent("soak-result.txt"), atomically: true, encoding: .utf8)
        exit(verdict.pass ? 0 : 1)
    }

    private static func say(_ s: String) {
        print(s)
        fflush(stdout)
    }

    static func footprintMB() -> Double {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let kr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return kr == KERN_SUCCESS ? Double(info.phys_footprint) / 1_048_576 : 0
    }
}
