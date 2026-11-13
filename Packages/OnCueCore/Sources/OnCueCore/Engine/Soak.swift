import Foundation

// MARK: - Soak test
//
// OnCue runs the sample show in Auto cut on the simulator switcher, song after song, for hours
// (`OnCue --soak <folder> --hours 24 --speed 5`). Every minute it records memory and how many
// shots were taken; every scripted take is compared with the moment the script planned it.
// The verdict: memory stops growing once warmed up, shots keep being taken to the end, and takes
// land on time (1 frame at 25 fps of tick time at normal speed; the tick grows with the speed).

public struct SoakSample: Equatable {
    /// Real seconds since the start.
    public var real: Double
    /// Show seconds since the start (real × speed).
    public var show: Double
    /// Physical memory footprint, MB.
    public var memoryMB: Double
    /// Scripted takes so far.
    public var takes: Int
    public init(real: Double, show: Double, memoryMB: Double, takes: Int) {
        self.real = real
        self.show = show
        self.memoryMB = memoryMB
        self.takes = takes
    }
}

public struct SoakVerdict: Equatable {
    public var pass: Bool
    public var lines: [String]
    public init(pass: Bool, lines: [String]) {
        self.pass = pass
        self.lines = lines
    }
}

public enum SoakReport {
    /// Allowed memory growth after the first quarter of the run (log entries and caches settle there).
    public static let memoryAllowanceMB = 64.0

    /// The latest a take may land, in show seconds: two engine ticks at this speed plus 40 ms.
    public static func latenessLimit(speed: Double) -> Double { 2 * speed / 60 + 0.04 }

    /// - Parameter lateness: per scripted take, show seconds after its planned moment (negative = early).
    public static func evaluate(samples: [SoakSample], lateness: [Double], speed: Double, plannedShowHours: Double) -> SoakVerdict {
        var lines: [String] = []
        var pass = true
        func fail(_ s: String) { pass = false; lines.append("FAIL: " + s) }
        guard let last = samples.last, samples.count >= 4 else {
            return SoakVerdict(pass: false, lines: ["FAIL: too few samples (\(samples.count)): the run stopped early"])
        }

        let hours = last.show / 3600
        lines.append(String(format: "Ran %.2f h of show time in %.2f h real at %.1f×.", hours, last.real / 3600, speed))
        if hours < plannedShowHours * 0.98 { fail(String(format: "stopped at %.2f h of the planned %.2f h", hours, plannedShowHours)) }

        // Memory: compare the end with the end of the first quarter.
        let quarter = samples.first { $0.show >= last.show * 0.25 } ?? samples[0]
        let peak = samples.map(\.memoryMB).max() ?? 0
        let growth = last.memoryMB - quarter.memoryMB
        let span = max((last.show - quarter.show) / 3600, 1e-9)
        lines.append(String(format: "Memory: %.0f MB after the first quarter, %.0f MB at the end (peak %.0f MB): %+.1f MB, %+.2f MB per show hour.",
                            quarter.memoryMB, last.memoryMB, peak, growth, growth / span))
        if growth > memoryAllowanceMB { fail(String(format: "memory grew %.0f MB after warm-up (limit %.0f MB)", growth, memoryAllowanceMB)) }

        // Takes keep happening to the end (no stall).
        let lastQuarter = samples.first { $0.show >= last.show * 0.75 } ?? samples[0]
        lines.append("Scripted takes: \(last.takes) (\(last.takes - lastQuarter.takes) in the last quarter).")
        if last.takes == 0 { fail("no shots were taken") }
        else if last.takes - lastQuarter.takes == 0 { fail("no shots were taken in the last quarter: the show stalled") }

        // Timing.
        if lateness.isEmpty {
            fail("no takes to time")
        } else {
            let sorted = lateness.sorted()
            let p50 = sorted[sorted.count / 2]
            let p99 = sorted[min(sorted.count - 1, Int(Double(sorted.count) * 0.99))]
            let worst = sorted.last!
            let early = sorted.first!
            let limit = latenessLimit(speed: speed)
            lines.append(String(format: "Take timing (show ms after plan): median %.1f, 99th percentile %.1f, latest %.1f, earliest %.1f; limit %.1f.",
                                p50 * 1000, p99 * 1000, worst * 1000, early * 1000, limit * 1000))
            if p99 > limit { fail(String(format: "99%% of takes should land within %.0f ms; the 99th percentile was %.0f ms", limit * 1000, p99 * 1000)) }
            if early < -0.005 { fail(String(format: "a take landed %.0f ms early", -early * 1000)) }
        }
        lines.append(pass ? "PASS" : "FAIL")
        return SoakVerdict(pass: pass, lines: lines)
    }

    public static func csv(_ samples: [SoakSample]) -> String {
        "real_s,show_s,memory_mb,takes\n" + samples.map {
            String(format: "%.0f,%.0f,%.1f,%d", $0.real, $0.show, $0.memoryMB, $0.takes)
        }.joined(separator: "\n") + "\n"
    }
}
