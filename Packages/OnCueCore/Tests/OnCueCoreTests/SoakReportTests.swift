import XCTest
@testable import OnCueCore

final class SoakReportTests: XCTestCase {
    private func run(memory: (Double) -> Double, takesPerHour: Int = 900, hours: Double = 24) -> [SoakSample] {
        var out: [SoakSample] = []
        var show = 0.0
        let end: Double = hours * 3600
        while show <= end {
            let h: Double = show / 3600
            let takes = Int(h * Double(takesPerHour))
            out.append(SoakSample(real: show / 5, show: show, memoryMB: memory(h), takes: takes))
            show += 300
        }
        return out
    }

    func testSteadyRunPasses() {
        let steady: (Double) -> Double = { h in h < 1 ? 80 + h * 40 : 120 + sin(h) * 3 }
        let v = SoakReport.evaluate(samples: run(memory: steady),
                                    lateness: [0.01, 0.02, 0.03, 0.05], speed: 5, plannedShowHours: 24)
        XCTAssertTrue(v.pass, v.lines.joined(separator: "\n"))
        XCTAssertEqual(v.lines.last, "PASS")
    }

    func testLeakFails() {
        let v = SoakReport.evaluate(samples: run(memory: { (h: Double) -> Double in 80 + h * 10 }), lateness: [0.01], speed: 5, plannedShowHours: 24)
        XCTAssertFalse(v.pass)
        XCTAssertTrue(v.lines.contains { $0.hasPrefix("FAIL: memory grew") })
    }

    func testStallAndShortRunFail() {
        var samples = run(memory: { (_: Double) -> Double in 100 })
        for k in samples.indices where samples[k].show > 20 * 3600 { samples[k].takes = samples.first { $0.show >= 20 * 3600 }!.takes }
        let v = SoakReport.evaluate(samples: samples, lateness: [0.01], speed: 5, plannedShowHours: 24)
        XCTAssertTrue(v.lines.contains { $0.contains("stalled") })
        let short = SoakReport.evaluate(samples: run(memory: { _ in 100 }, hours: 10), lateness: [0.01], speed: 5, plannedShowHours: 24)
        XCTAssertTrue(short.lines.contains { $0.contains("stopped at") })
    }

    func testLateAndEarlyTakesFail() {
        let late = SoakReport.evaluate(samples: run(memory: { (_: Double) -> Double in 100 }), lateness: Array(repeating: 0.5, count: 100), speed: 1, plannedShowHours: 24)
        XCTAssertTrue(late.lines.contains { $0.contains("99%") })
        let early = SoakReport.evaluate(samples: run(memory: { (_: Double) -> Double in 100 }), lateness: [-0.2, 0.01], speed: 1, plannedShowHours: 24)
        XCTAssertTrue(early.lines.contains { $0.contains("early") })
        XCTAssertEqual(SoakReport.latenessLimit(speed: 1), 2.0 / 60 + 0.04, accuracy: 1e-9)
    }

    func testCSV() {
        XCTAssertEqual(SoakReport.csv([SoakSample(real: 60, show: 300, memoryMB: 101.25, takes: 7)]), "real_s,show_s,memory_mb,takes\n60,300,101.2,7\n")
    }
}
